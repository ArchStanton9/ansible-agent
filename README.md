# ansible-agent

Bootstrap script for creating an Ansible user on a fresh VPS.

The script creates the `ansible` user, installs the SSH public key from this
repository, locks password login for that user when supported by the OS, and
adds a sudoers rule for passwordless `sudo`.

## Security note

Running a public script as root through `curl | sh` or `wget | sh` is convenient,
but it is also equivalent to giving that script full control over the server.
Inspect the script before running it, and prefer pinning the URL to a reviewed
commit or tag instead of always using `main`.

## Usage

Review the script first:

```sh
SCRIPT_URL="https://raw.githubusercontent.com/ArchStanton9/ansible-agent/main/bootstrap-ansible-user.sh"
curl -fsSL "$SCRIPT_URL"
```

Run it as `root` with `curl`:

```sh
SCRIPT_URL="https://raw.githubusercontent.com/ArchStanton9/ansible-agent/main/bootstrap-ansible-user.sh"
curl -fsSL "$SCRIPT_URL" | sh
```

Or run it as `root` with `wget`:

```sh
SCRIPT_URL="https://raw.githubusercontent.com/ArchStanton9/ansible-agent/main/bootstrap-ansible-user.sh"
wget -qO- "$SCRIPT_URL" | sh
```

After that, Ansible can connect as:

```sh
ssh ansible@YOUR_SERVER_IP
```

## Configuration

By default the script creates user `ansible` and installs this SSH public key:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEpk6Yd/5yIDQDKEL5v0VVAmpbSiP5iXn+tYCku8aA09 ansible
```

You can override the local username:

```sh
curl -fsSL "$SCRIPT_URL" | ANSIBLE_USER=deploy sh
```

If `sudo` is not installed, the script tries to install it with the detected
package manager. To disable that behavior:

```sh
curl -fsSL "$SCRIPT_URL" | INSTALL_SUDO=0 sh
```

## What it changes

- Creates the configured user if it does not exist.
- Creates `/home/<user>/.ssh/authorized_keys`.
- Adds the SSH public key idempotently.
- Locks the user's password when the system supports `passwd -l`.
- Writes `/etc/sudoers.d/90-ansible-agent-<user>` with:

```text
<user> ALL=(ALL) NOPASSWD: ALL
```
