mod caller_icon;
mod dialog;
mod process;
mod prompt;
mod transport;
mod wayland_blur;

use anyhow::{Context, Result, bail};
use prompt::Kind;
use transport::{Event, Request};

fn main() {
    match run() {
        Ok(status) => std::process::exit(status),
        Err(error) => {
            eprintln!("egui-askpass: {error:#}");
            std::process::exit(1);
        }
    }
}

fn run() -> Result<i32> {
    process::protect_secrets()?;
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("--demo") => {
            dialog::preview()?;
            Ok(0)
        }
        Some("--serve") => {
            if args.len() != 5 {
                bail!("invalid internal UI arguments");
            }
            let (server, events) = transport::serve(
                args[1].parse()?,
                args[2].parse()?,
                args[3].clone(),
                args[4].clone().into(),
            )?;
            let initial = match events
                .recv_timeout(transport::STARTUP_TIMEOUT)
                .context("waiting for first prompt")?
            {
                Event::Show(prompt) => prompt,
                _ => return Ok(1),
            };
            dialog::run(server, events, initial)?;
            Ok(0)
        }
        Some("--help") | None => {
            println!("Usage: egui-askpass PROMPT\n       egui-askpass --demo");
            Ok(0)
        }
        Some(prompt) => {
            let hint = std::env::var("SSH_ASKPASS_PROMPT").unwrap_or_default();
            let kind = Kind::classify(prompt, &hint);
            transport::ask(Request {
                kind,
                prompt: prompt.to_owned(),
                requester: process::parent_name(),
                app_icon: caller_icon::for_parent(),
            })
        }
    }
}
