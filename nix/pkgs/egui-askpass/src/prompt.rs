use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Clone, Copy, Deserialize, Serialize, PartialEq)]
pub enum Kind {
    Pin,
    Touch,
    Secret,
    Confirm,
    Notice,
}

impl Kind {
    pub fn classify(prompt: &str, hint: &str) -> Self {
        match hint {
            "confirm" => Self::Confirm,
            "none" if prompt.starts_with("Confirm user presence") => Self::Touch,
            "none" => Self::Notice,
            _ if prompt.starts_with("Enter PIN") => Self::Pin,
            _ => Self::Secret,
        }
    }

    pub fn interactive(self) -> bool {
        matches!(self, Self::Pin | Self::Secret | Self::Confirm)
    }

    pub fn input(self) -> bool {
        matches!(self, Self::Pin | Self::Secret)
    }
}

#[derive(Default)]
pub struct KeyIdentity {
    pub kind: Option<String>,
    pub fingerprint: Option<String>,
    pub filename: Option<String>,
}

impl KeyIdentity {
    pub fn from_prompt(prompt: &str) -> Self {
        let kind = prompt
            .split_whitespace()
            .find(|word| matches!(*word, "ED25519-SK" | "ECDSA-SK"))
            .map(str::to_owned);
        let fingerprint = prompt
            .split_whitespace()
            .find(|word| word.starts_with("SHA256:"))
            .map(|word| word.trim_end_matches([':', '.', '\'', '"']).to_owned());
        // Direct ssh supplies the filename here; ssh-agent supplies a fingerprint.
        // Preserve spaces and colons in filenames by removing only the final ':'
        // that OpenSSH adds to its PIN prompt.
        let filename = prompt
            .strip_prefix("Enter PIN for ")
            .and_then(|prompt| prompt.trim_end().strip_suffix(':'))
            .and_then(|prompt| prompt.split_once(" key "))
            .filter(|(kind, name)| {
                matches!(*kind, "ED25519-SK" | "ECDSA-SK")
                    && !name.is_empty()
                    && !name.starts_with("SHA256:")
            })
            .map(|(_, name)| name.to_owned());
        Self {
            kind,
            fingerprint,
            filename,
        }
    }

    pub fn description(&self) -> String {
        if let Some(filename) = &self.filename {
            let name = Path::new(filename)
                .file_name()
                .map(|name| name.to_string_lossy())
                .unwrap_or_else(|| filename.as_str().into());
            return format!("the key “{name}”");
        }
        let kind = self.kind.as_deref().unwrap_or("security");
        match &self.fingerprint {
            Some(fingerprint) => format!("the {kind} key ({fingerprint})"),
            None => format!("your {kind} key"),
        }
    }

    pub fn details(&self) -> String {
        [
            self.filename.as_deref(),
            self.kind.as_deref(),
            self.fingerprint.as_deref(),
        ]
        .into_iter()
        .flatten()
        .collect::<Vec<_>>()
        .join("\n")
    }
}
