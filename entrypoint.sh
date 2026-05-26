#!/bin/bash
set -eu

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- validate required env ---
if [ -z "${USER_NAME:-}" ]; then
  log "ERROR: USER_NAME is required"
  exit 1
fi
if [ -z "${GH_USER_NAME:-}" ]; then
  log "ERROR: GH_USER_NAME is required"
  exit 1
fi

# --- create user ---
log "Creating user: ${USER_NAME}"
useradd -s "$(which zsh)" -m "${USER_NAME}"

echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER_NAME}"

chsh -s "$(which zsh)" "${USER_NAME}"

# --- SSH setup ---
SSH_DIR="/home/${USER_NAME}/.ssh"

if [ ! -d "${SSH_DIR}" ]; then
  log "Setting up SSH directory"
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  chown -R "${USER_NAME}:${USER_NAME}" "${SSH_DIR}"
fi

if [ ! -f "${SSH_DIR}/authorized_keys" ]; then
  log "Fetching SSH keys from GitHub for ${GH_USER_NAME}"
  curl -fsSL "https://github.com/${GH_USER_NAME}.keys" > "${SSH_DIR}/authorized_keys"
  chmod 600 "${SSH_DIR}/authorized_keys"
  chown "${USER_NAME}:${USER_NAME}" "${SSH_DIR}/authorized_keys"
fi

# --- start OpenChamber ---
if command -v openchamber >/dev/null 2>&1; then
  log "Starting OpenChamber as ${USER_NAME}"
  su - "${USER_NAME}" -c "nohup openchamber --host 0.0.0.0 >/dev/null 2>&1 &"
else
  log "OpenChamber not found on PATH — skipping"
fi

# --- run SSH daemon ---
log "Starting sshd"
exec /usr/sbin/sshd -D
