use std::{
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Read, Write},
    net::Shutdown,
    os::{
        fd::{AsRawFd, FromRawFd},
        unix::{
            fs::{FileTypeExt, MetadataExt, OpenOptionsExt, PermissionsExt},
            net::{UnixListener, UnixStream},
        },
    },
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use anyhow::{Context, Result, bail};
use std::sync::mpsc::{self, Receiver, Sender};

use crate::{process, prompt::Kind};
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

pub const STARTUP_TIMEOUT: Duration = Duration::from_secs(10);
const FRAME_TIMEOUT: Duration = Duration::from_secs(5);
const MAX_FRAME: u64 = 65536;

#[derive(Deserialize, Serialize)]
pub struct Request {
    pub kind: Kind,
    pub prompt: String,
    #[serde(default)]
    pub requester: String,
    #[serde(default)]
    pub app_icon: Option<PathBuf>,
}

pub struct Prompt {
    pub id: u64,
    pub request: Request,
    pub response: UnixStream,
}

impl Prompt {
    pub fn respond(mut self, input: Option<&str>) {
        // stdout is reserved for the original OpenSSH child, never the UI process.
        let result = (|| -> std::io::Result<()> {
            self.response.write_all(&[u8::from(input.is_none())])?;
            if let Some(input) = input {
                self.response.write_all(input.as_bytes())?;
                self.response.write_all(b"\n")?;
            }
            self.response.shutdown(Shutdown::Write)
        })();
        if result.is_err() {
            let _ = self.response.shutdown(Shutdown::Both);
        }
    }
}

pub enum Event {
    Show(Prompt),
    Disconnected(u64),
    ParentExited,
}

pub struct Server {
    path: PathBuf,
    socket_identity: (u64, u64),
}

impl Server {
    pub fn retire(&self) {
        let Ok(_lock) = socket_lock(&self.path) else {
            return;
        };
        // Stop new helpers finding a window that is already closing. A later
        // window may bind the same path before this process finishes exiting.
        if fs::metadata(&self.path)
            .is_ok_and(|metadata| (metadata.dev(), metadata.ino()) == self.socket_identity)
        {
            let _ = fs::remove_file(&self.path);
        }
    }
}

fn socket_lock(path: &Path) -> Result<File> {
    // One persistent lock per runtime directory avoids per-request lock files
    // and the race introduced by unlinking a lock while another helper waits.
    let lock = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path.with_file_name("egui-askpass.lock"))?;
    let metadata = lock.metadata()?;
    if !metadata.is_file()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.permissions().mode() & 0o077 != 0
    {
        bail!("invalid askpass socket lock");
    }
    lock.lock().context("locking askpass socket setup")?;
    Ok(lock)
}

impl Drop for Server {
    fn drop(&mut self) {
        self.retire();
    }
}

pub fn ask(request: Request) -> Result<i32> {
    let parent = unsafe { libc::getppid() } as u32;
    let stamp = process::stamp(parent)?;
    let runtime =
        PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR is not set")?);
    let metadata = fs::metadata(&runtime)?;
    if !metadata.is_dir()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.permissions().mode() & 0o077 != 0
    {
        bail!("XDG_RUNTIME_DIR must be a private directory owned by the current user");
    }
    let path = runtime.join(format!("egui-askpass-{parent}-{stamp}.sock"));

    let lock = socket_lock(&path)?;
    let mut stream = match UnixStream::connect(&path) {
        Ok(stream) => stream,
        Err(error) => {
            if error.kind() == std::io::ErrorKind::ConnectionRefused {
                fs::remove_file(&path).context("removing stale askpass socket")?;
            }
            match UnixListener::bind(&path) {
                Ok(listener) => {
                    fs::set_permissions(&path, fs::Permissions::from_mode(0o600))?;
                    let fd = listener.as_raw_fd();
                    // Hand the listening socket to the UI atomically. Other askpass
                    // invocations can connect even while the UI is starting.
                    if unsafe { libc::fcntl(fd, libc::F_SETFD, 0) } == -1 {
                        bail!("could not pass the UI socket to the child");
                    }
                    let spawned = Command::new(std::env::current_exe()?)
                        .args(["--serve", &fd.to_string(), &parent.to_string(), &stamp])
                        .arg(&path)
                        .stdin(Stdio::null())
                        .stdout(Stdio::null())
                        .stderr(Stdio::inherit())
                        .spawn();
                    drop(listener);
                    if let Err(error) = spawned {
                        let _ = fs::remove_file(&path);
                        return Err(error.into());
                    }
                }
                Err(error) if error.kind() == std::io::ErrorKind::AddrInUse => {}
                Err(error) => return Err(error.into()),
            }
            UnixStream::connect(&path).context("connecting to the askpass window")?
        }
    };
    // Never hold the setup lock while waiting for a user or a touch notification.
    drop(lock);

    serde_json::to_writer(&mut stream, &request)?;
    stream.write_all(b"\n")?;
    let mut reply = Zeroizing::new(Vec::new());
    stream.take(4096).read_to_end(&mut reply)?;
    if reply.first() != Some(&0) {
        return Ok(1);
    }
    std::io::stdout().lock().write_all(&reply[1..])?;
    Ok(0)
}

fn validate_listener(fd: i32) -> Result<()> {
    if fd < 3 {
        bail!("invalid UI listener descriptor");
    }
    for (option, expected) in [(libc::SO_TYPE, libc::SOCK_STREAM), (libc::SO_ACCEPTCONN, 1)] {
        let mut value: libc::c_int = 0;
        let mut len = std::mem::size_of_val(&value) as libc::socklen_t;
        // SAFETY: value and len point to live buffers of the advertised size.
        let result = unsafe {
            libc::getsockopt(
                fd,
                libc::SOL_SOCKET,
                option,
                (&mut value as *mut libc::c_int).cast(),
                &mut len,
            )
        };
        if result != 0 || value != expected {
            bail!("UI descriptor is not a listening stream socket");
        }
    }
    // SAFETY: sockaddr_storage can hold every socket address family.
    let mut address: libc::sockaddr_storage = unsafe { std::mem::zeroed() };
    let mut len = std::mem::size_of_val(&address) as libc::socklen_t;
    let result = unsafe {
        libc::getsockname(
            fd,
            (&mut address as *mut libc::sockaddr_storage).cast(),
            &mut len,
        )
    };
    if result != 0 || address.ss_family as libc::c_int != libc::AF_UNIX {
        bail!("UI listener must be a Unix socket");
    }
    Ok(())
}

pub fn serve(
    fd: i32,
    parent: u32,
    stamp: String,
    path: PathBuf,
) -> Result<(Server, Receiver<Event>)> {
    validate_listener(fd)?;
    // SAFETY: validated as a live Unix listener, inherited exclusively by this process.
    let listener = unsafe { UnixListener::from_raw_fd(fd) };
    if unsafe { libc::fcntl(fd, libc::F_SETFD, libc::FD_CLOEXEC) } == -1 {
        return Err(std::io::Error::last_os_error()).context("protecting UI listener descriptor");
    }
    if listener.local_addr()?.as_pathname() != Some(path.as_path()) {
        bail!("UI listener path does not match its socket");
    }
    let metadata = fs::symlink_metadata(&path)?;
    if !metadata.file_type().is_socket() || metadata.uid() != unsafe { libc::geteuid() } {
        bail!("invalid UI socket path");
    }
    let socket_identity = (metadata.dev(), metadata.ino());
    let (sender, events) = mpsc::channel();
    let connections = sender.clone();
    thread::spawn(move || {
        for (id, connection) in listener.incoming().enumerate() {
            let Ok(connection) = connection else { break };
            let sender = connections.clone();
            thread::spawn(move || {
                let _ = receive(id as u64, connection, sender);
            });
        }
    });
    thread::spawn(move || {
        loop {
            thread::sleep(Duration::from_millis(500));
            if process::stamp(parent).ok().as_deref() != Some(stamp.as_str()) {
                let _ = sender.send(Event::ParentExited);
                break;
            }
        }
    });
    Ok((
        Server {
            path,
            socket_identity,
        },
        events,
    ))
}

fn receive(id: u64, connection: UnixStream, sender: Sender<Event>) -> Result<()> {
    connection.set_read_timeout(Some(FRAME_TIMEOUT))?;
    let mut reader = BufReader::new(connection.try_clone()?);
    let mut line = String::new();
    (&mut reader).take(MAX_FRAME).read_line(&mut line)?;
    if !line.ends_with('\n') {
        bail!("incomplete or oversized askpass request");
    }
    let request = serde_json::from_str(&line)?;
    // Touch helpers may stay connected indefinitely. Only the initial frame is timed.
    connection.set_read_timeout(None)?;
    sender.send(Event::Show(Prompt {
        id,
        request,
        response: connection,
    }))?;
    // OpenSSH kills informational askpass children with SIGTERM. EOF lets the
    // separate UI retire that notification without handling signals in the UI.
    let _ = reader.read(&mut [0u8; 1]);
    let _ = sender.send(Event::Disconnected(id));
    Ok(())
}
