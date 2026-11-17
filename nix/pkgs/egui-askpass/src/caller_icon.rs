//! Best-effort caller identification from process ancestry and desktop entries.
//! An SSH agent has no ancestry link to its clients, so never guess past it.

use crate::process::{executable_name, name};

use std::{
    collections::HashSet,
    env, fs,
    path::{Path, PathBuf},
};

pub fn for_parent() -> Option<PathBuf> {
    let mut pid = unsafe { libc::getppid() } as u32;
    let mut callers = Vec::new();
    for _ in 0..32 {
        if pid <= 1 {
            break;
        }
        if let Some(name) = name(pid) {
            if name.contains("ssh-agent") {
                return None;
            }
            if matches!(
                name.as_str(),
                "systemd" | "niri" | "sway" | "gnome-shell" | "kwin_wayland"
            ) {
                break;
            }
            callers.push(name);
        }
        let Some(parent) = fs::read_to_string(format!("/proc/{pid}/stat"))
            .ok()
            .and_then(|stat| {
                stat.rsplit_once(')')?
                    .1
                    .split_whitespace()
                    .nth(1)?
                    .parse()
                    .ok()
            })
        else {
            break;
        };
        if parent == pid {
            break;
        }
        pid = parent;
    }
    if callers.is_empty() {
        return None;
    }

    let directories = data_directories();
    let mut seen = HashSet::new();
    let mut matches = Vec::new();
    for directory in &directories {
        let Ok(entries) = fs::read_dir(directory.join("applications")) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path
                .extension()
                .is_none_or(|extension| extension != "desktop")
                || !seen.insert(entry.file_name())
            {
                continue;
            }
            let Ok(contents) = fs::read_to_string(&path) else {
                continue;
            };
            if entry_value(&contents, "Hidden") == Some("true") {
                continue;
            }
            let Some(icon) = entry_value(&contents, "Icon") else {
                continue;
            };
            let stem = path.file_stem().and_then(|name| name.to_str());
            let executable = entry_value(&contents, "TryExec")
                .or_else(|| entry_value(&contents, "Exec"))
                .and_then(exec_program);
            let window_class = entry_value(&contents, "StartupWMClass");
            if let Some(rank) = callers.iter().position(|caller| {
                [stem, executable, window_class]
                    .into_iter()
                    .flatten()
                    .any(|name| executable_name(name).eq_ignore_ascii_case(caller))
            }) {
                matches.push((rank, icon.to_owned()));
            }
        }
    }
    matches.sort_by_key(|(rank, _)| *rank);
    matches
        .into_iter()
        .find_map(|(_, icon)| find_png(&icon, &directories))
}

fn exec_program(command: &str) -> Option<&str> {
    let command = command.trim();
    if let Some(quoted) = command.strip_prefix('"') {
        return quoted.split_once('"').map(|(program, _)| program);
    }
    let mut words = command.split_whitespace();
    let first = words.next()?;
    if executable_name(first) == "env" {
        words.find(|word| !word.starts_with('-') && !word.contains('='))
    } else {
        Some(first)
    }
}

fn entry_value<'a>(contents: &'a str, key: &str) -> Option<&'a str> {
    let mut in_entry = false;
    for line in contents.lines().map(str::trim) {
        if line.starts_with('[') {
            in_entry = line == "[Desktop Entry]";
        } else if in_entry {
            if let Some((name, value)) = line.split_once('=') {
                if name.trim() == key {
                    return Some(value.trim());
                }
            }
        }
    }
    None
}

fn data_directories() -> Vec<PathBuf> {
    let mut directories = Vec::new();
    if let Some(path) = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share")))
    {
        directories.push(path);
    }
    directories.extend(env::split_paths(
        &env::var_os("XDG_DATA_DIRS").unwrap_or_else(|| "/usr/local/share:/usr/share".into()),
    ));
    directories.retain(|path| path.is_absolute());
    directories
}

fn find_png(icon: &str, directories: &[PathBuf]) -> Option<PathBuf> {
    let path = Path::new(icon);
    if path.is_absolute() {
        return (path.extension().is_some_and(|ext| ext == "png") && path.is_file())
            .then(|| path.to_owned());
    }
    if icon.contains('/') {
        return None;
    }
    let name = format!("{}.png", icon.strip_suffix(".png").unwrap_or(icon));
    // Use the application's own hicolor PNG, keeping icon loading independent
    // of a desktop toolkit or SVG renderer. 48px is ample for the small badge.
    for size in [
        "48x48", "48x48@2", "64x64", "32x32@2", "32x32", "128x128", "256x256", "512x512", "24x24",
        "22x22", "16x16",
    ] {
        for directory in directories {
            let path = directory
                .join("icons/hicolor")
                .join(size)
                .join("apps")
                .join(&name);
            if path.is_file() {
                return Some(path);
            }
        }
    }
    for directory in directories {
        for subdir in ["icons", "pixmaps"] {
            let path = directory.join(subdir).join(&name);
            if path.is_file() {
                return Some(path);
            }
        }
    }
    None
}
