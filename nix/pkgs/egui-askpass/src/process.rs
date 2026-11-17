use std::{fs, io};

use anyhow::{Context, Result};

pub fn protect_secrets() -> Result<()> {
    let limit = libc::rlimit {
        rlim_cur: 0,
        rlim_max: 0,
    };
    // SAFETY: limit points to a valid rlimit. Both modes run this before input.
    if unsafe { libc::setrlimit(libc::RLIMIT_CORE, &limit) } != 0 {
        return Err(io::Error::last_os_error()).context("disabling core dumps");
    }
    // A piped core collector ignores RLIMIT_CORE; dumpability must also be off.
    if unsafe { libc::prctl(libc::PR_SET_DUMPABLE, 0, 0, 0, 0) } != 0 {
        return Err(io::Error::last_os_error()).context("protecting process memory");
    }
    Ok(())
}

pub fn parent_name() -> String {
    name(unsafe { libc::getppid() } as u32).unwrap_or_else(|| "Unknown process".into())
}

pub fn name(pid: u32) -> Option<String> {
    fs::read_link(format!("/proc/{pid}/exe"))
        .ok()
        .and_then(|path| path.file_name()?.to_str().map(str::to_owned))
        // ssh-agent disables tracing, which also prevents reading /proc/PID/exe.
        // Its process name remains readable without inspecting command arguments.
        .or_else(|| fs::read_to_string(format!("/proc/{pid}/comm")).ok())
        .map(|name| {
            executable_name(name.trim_end_matches('\n'))
                .chars()
                .filter(|ch| !ch.is_control())
                .collect::<String>()
        })
        .filter(|name| !name.is_empty())
}

pub fn executable_name(name: &str) -> &str {
    // Nix wrappers often exec a sibling named .application-wrapped.
    name.rsplit('/')
        .next()
        .unwrap_or(name)
        .trim_start_matches('.')
        .trim_end_matches("-wrapped")
}

pub fn stamp(pid: u32) -> Result<String> {
    let stat = fs::read_to_string(format!("/proc/{pid}/stat"))?;
    // Field 22 (starttime), following the parenthesized command name.
    Ok(stat
        .rsplit_once(')')
        .context("invalid process stat")?
        .1
        .split_whitespace()
        .nth(19)
        .context("missing process start time")?
        .to_owned())
}
