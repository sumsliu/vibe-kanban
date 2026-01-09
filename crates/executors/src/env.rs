use std::collections::HashMap;

use tokio::process::Command;

use crate::command::CmdOverrides;

/// Environment variables to inject into executor processes
#[derive(Debug, Clone, Default)]
pub struct ExecutionEnv {
    pub vars: HashMap<String, String>,
}

impl ExecutionEnv {
    pub fn new() -> Self {
        Self {
            vars: HashMap::new(),
        }
    }

    /// Create a new ExecutionEnv with inherited environment variables from the current process.
    /// This is useful for inheriting Docker container environment variables.
    /// Only inherits variables that match the specified prefixes.
    pub fn with_inherited_vars(prefixes: &[&str]) -> Self {
        let mut env = Self::new();
        for (key, value) in std::env::vars() {
            for prefix in prefixes {
                if key.starts_with(prefix) {
                    env.insert(&key, &value);
                    break;
                }
            }
        }
        env
    }

    /// Inherit specific environment variables from the current process.
    pub fn inherit_vars(&mut self, var_names: &[&str]) {
        for name in var_names {
            if let Ok(value) = std::env::var(name) {
                self.insert(*name, value);
            }
        }
    }

    /// Insert an environment variable
    pub fn insert(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.vars.insert(key.into(), value.into());
    }

    /// Merge additional vars into this env. Incoming keys overwrite existing ones.
    pub fn merge(&mut self, other: &HashMap<String, String>) {
        self.vars
            .extend(other.iter().map(|(k, v)| (k.clone(), v.clone())));
    }

    /// Return a new env with overrides applied. Overrides take precedence.
    pub fn with_overrides(mut self, overrides: &HashMap<String, String>) -> Self {
        self.merge(overrides);
        self
    }

    /// Return a new env with profile env from CmdOverrides merged in.
    pub fn with_profile(self, cmd: &CmdOverrides) -> Self {
        if let Some(ref profile_env) = cmd.env {
            self.with_overrides(profile_env)
        } else {
            self
        }
    }

    /// Apply all environment variables to a Command
    pub fn apply_to_command(&self, command: &mut Command) {
        for (key, value) in &self.vars {
            command.env(key, value);
        }
    }

    pub fn contains_key(&self, key: &str) -> bool {
        self.vars.contains_key(key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profile_overrides_runtime_env() {
        let mut base = ExecutionEnv::default();
        base.insert("VK_PROJECT_NAME", "runtime");
        base.insert("FOO", "runtime");

        let mut profile = HashMap::new();
        profile.insert("FOO".to_string(), "profile".to_string());
        profile.insert("BAR".to_string(), "profile".to_string());

        let merged = base.with_overrides(&profile);

        assert_eq!(merged.vars.get("VK_PROJECT_NAME").unwrap(), "runtime");
        assert_eq!(merged.vars.get("FOO").unwrap(), "profile"); // overrides
        assert_eq!(merged.vars.get("BAR").unwrap(), "profile");
    }
}
