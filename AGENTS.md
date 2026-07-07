# Repository Guidelines

## Project Structure & Module Organization

This repository is intentionally small. `bootstrap-ansible-user.sh` is the main executable script; it creates an `ansible` user, installs an SSH key, locks password login, and configures passwordless sudo. `README.md` contains the public usage snippet for running the script from a tagged GitHub URL. There are currently no separate source, test, or asset directories.

Keep new files at the repository root unless the project grows enough to justify structure. If tests are added, prefer a clear `tests/` directory and name fixtures after the behavior they support.

## Build, Test, and Development Commands

There is no build step. Useful local checks are:

```sh
sh -n bootstrap-ansible-user.sh
```

Checks POSIX shell syntax without executing the script.

```sh
shellcheck bootstrap-ansible-user.sh
```

Runs static analysis if ShellCheck is installed. Treat warnings seriously, especially around quoting, portability, and command failure handling.

Because the script modifies users, SSH files, sudoers, and packages, run full behavior tests only in a disposable VM or container, never on a workstation you cannot reset.

## Coding Style & Naming Conventions

Write portable POSIX `sh`; do not rely on Bash-only syntax. Use two-space indentation inside functions and control blocks, matching the current script. Keep variables uppercase for configurable settings and constants, such as `ANSIBLE_USER` and `SUDOERS_DIR`. Use lowercase snake_case for function names, such as `install_ssh_key`.

Quote variable expansions by default. Prefer small, single-purpose functions with clear failure messages via `die`.

## Testing Guidelines

At minimum, run `sh -n bootstrap-ansible-user.sh` after edits. When changing package installation, sudoers handling, user creation, or SSH key installation, also test on at least one fresh target system matching the affected package manager path (`apt-get`, `dnf`, `pacman`, `apk`, etc.).

Manual tests should verify idempotency: a second run should not duplicate SSH keys or fail because the user already exists.

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries, for example `Simplify README.md` and `Add bootstrap script`. Keep the subject concise and describe the changed behavior.

Pull requests should include the reason for the change, commands or environments used for testing, and any compatibility impact for supported Linux distributions. For README changes, ensure the versioned URL matches the intended release tag.

## Security & Configuration Tips

Do not commit private keys or host-specific secrets. Review changes to the default `ANSIBLE_SSH_KEY`, sudoers path, and root checks carefully because they affect remote administrative access.
