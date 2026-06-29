#!/bin/sh
set -eu

ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
ANSIBLE_SSH_KEY="${ANSIBLE_SSH_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEpk6Yd/5yIDQDKEL5v0VVAmpbSiP5iXn+tYCku8aA09 ansible}"
INSTALL_SUDO="${INSTALL_SUDO:-auto}"

SUDOERS_DIR="/etc/sudoers.d"
SUDOERS_FILE="${SUDOERS_DIR}/90-ansible-agent-${ANSIBLE_USER}"
TMP_SUDOERS=""

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$TMP_SUDOERS" ] && [ -f "$TMP_SUDOERS" ]; then
    rm -f "$TMP_SUDOERS"
  fi
}

trap cleanup EXIT INT TERM

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "run this script as root"
  fi
}

validate_user_name() {
  case "$ANSIBLE_USER" in
    ""|"-"*|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*)
      die "ANSIBLE_USER contains unsupported characters"
      ;;
  esac
}

select_shell() {
  if [ -x /bin/bash ]; then
    printf '%s\n' /bin/bash
  else
    printf '%s\n' /bin/sh
  fi
}

install_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    return
  fi

  case "$INSTALL_SUDO" in
    0|false|False|FALSE|no|No|NO)
      log "sudo is not installed; skipping installation because INSTALL_SUDO=$INSTALL_SUDO"
      return
      ;;
  esac

  log "sudo is not installed; trying to install it"

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y sudo
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y sudo
  elif command -v yum >/dev/null 2>&1; then
    yum install -y sudo
  elif command -v pacman >/dev/null 2>&1; then
    pacman -S --noconfirm --needed sudo
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache sudo
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install sudo
  else
    die "sudo is not installed and no supported package manager was found"
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo installation did not provide sudo"
}

get_user_home() {
  awk -F: -v name="$ANSIBLE_USER" '$1 == name { print $6; exit }' /etc/passwd
}

create_user() {
  user_shell="$(select_shell)"

  if id "$ANSIBLE_USER" >/dev/null 2>&1; then
    log "user '$ANSIBLE_USER' already exists"
    return
  fi

  log "creating user '$ANSIBLE_USER'"

  if command -v useradd >/dev/null 2>&1; then
    useradd -m -s "$user_shell" "$ANSIBLE_USER"
  elif command -v adduser >/dev/null 2>&1; then
    if adduser --help 2>&1 | grep -q -- '--disabled-password'; then
      adduser --disabled-password --gecos "" --shell "$user_shell" "$ANSIBLE_USER"
    else
      adduser -D -s "$user_shell" "$ANSIBLE_USER"
    fi
  else
    die "neither useradd nor adduser was found"
  fi
}

lock_password() {
  if command -v passwd >/dev/null 2>&1; then
    passwd -l "$ANSIBLE_USER" >/dev/null 2>&1 || true
  fi
}

install_ssh_key() {
  user_home="$(get_user_home)"
  [ -n "$user_home" ] || die "could not determine home directory for '$ANSIBLE_USER'"
  [ "$user_home" != "/" ] || die "refusing to use / as home directory"

  user_group="$(id -gn "$ANSIBLE_USER")"
  ssh_dir="${user_home}/.ssh"
  authorized_keys="${ssh_dir}/authorized_keys"

  if [ ! -d "$user_home" ]; then
    mkdir -p "$user_home"
    chown "$ANSIBLE_USER:$user_group" "$user_home"
    chmod 755 "$user_home"
  fi

  mkdir -p "$ssh_dir"
  touch "$authorized_keys"

  if ! grep -qxF "$ANSIBLE_SSH_KEY" "$authorized_keys"; then
    printf '%s\n' "$ANSIBLE_SSH_KEY" >> "$authorized_keys"
    log "added SSH key for '$ANSIBLE_USER'"
  else
    log "SSH key is already present for '$ANSIBLE_USER'"
  fi

  chown -R "$ANSIBLE_USER:$user_group" "$ssh_dir"
  chmod 700 "$ssh_dir"
  chmod 600 "$authorized_keys"
}

configure_sudoers() {
  mkdir -p "$SUDOERS_DIR"
  chmod 755 "$SUDOERS_DIR"

  TMP_SUDOERS="${SUDOERS_FILE}.tmp.$$"
  umask 077
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$ANSIBLE_USER" > "$TMP_SUDOERS"

  if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$TMP_SUDOERS" >/dev/null
  fi

  chown root:root "$TMP_SUDOERS" 2>/dev/null || true
  chmod 0440 "$TMP_SUDOERS"
  mv "$TMP_SUDOERS" "$SUDOERS_FILE"
  TMP_SUDOERS=""

  log "configured passwordless sudo in '$SUDOERS_FILE'"
}

require_root
validate_user_name
install_sudo
create_user
lock_password
install_ssh_key
configure_sudoers

log "done"
