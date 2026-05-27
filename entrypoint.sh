#!/bin/bash
set -eu

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ===== ROOT PHASE =====
if [ "$(id -u)" = "0" ]; then
  if [ -z "${USER_NAME:-}" ]; then
    log "ERROR: USER_NAME is required"
    exit 1
  fi
  if [ -z "${GH_USER_NAME:-}" ]; then
    log "ERROR: GH_USER_NAME is required"
    exit 1
  fi

  if ! id "${USER_NAME}" &>/dev/null; then
    log "Creating user: ${USER_NAME}"
    useradd -s "$(which zsh)" -m "${USER_NAME}"
  fi

  TARGET_SHELL=$(which zsh)
  CURRENT_SHELL=$(getent passwd "${USER_NAME}" | cut -d: -f7)
  if [ "${CURRENT_SHELL}" != "${TARGET_SHELL}" ]; then
    log "Setting shell for ${USER_NAME}"
    chsh -s "${TARGET_SHELL}" "${USER_NAME}"
  fi

  cat > "/etc/sudoers.d/${USER_NAME}" <<EOF
${USER_NAME} ALL=(ALL) NOPASSWD: ALL
Defaults:${USER_NAME} !requiretty
EOF

  SSH_DIR="/home/${USER_NAME}/.ssh"
  if [ ! -d "${SSH_DIR}" ]; then
    log "Setting up SSH directory"
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    chown -R "${USER_NAME}:${USER_NAME}" "${SSH_DIR}"
  fi

  if [ ! -f "${SSH_DIR}/authorized_keys" ]; then
    log "Fetching SSH keys from GitHub for ${GH_USER_NAME}"
    if curl -fsSL "https://github.com/${GH_USER_NAME}.keys" > "${SSH_DIR}/authorized_keys"; then
      chmod 600 "${SSH_DIR}/authorized_keys"
      chown "${USER_NAME}:${USER_NAME}" "${SSH_DIR}/authorized_keys"
    else
      log "WARNING: Failed to fetch SSH keys — container will start without them"
      rm -f "${SSH_DIR}/authorized_keys"
    fi
  fi

  log "Dropping privileges to ${USER_NAME}"
  exec su - "${USER_NAME}" -c "exec $0"
fi

# ===== USER PHASE =====

oc_pid=""
if command -v openchamber >/dev/null 2>&1; then
  if pgrep -u "$(id -u)" "^openchamber$" >/dev/null 2>&1; then
    log "OpenChamber already running"
  else
    log "Starting OpenChamber"
    OPENCODE_BINARY="${HOME}/.opencode/bin/opencode" \
      nohup openchamber --host 0.0.0.0 >/dev/null 2>&1 &
    oc_pid=$!
    log "OpenChamber PID: ${oc_pid}"
  fi
else
  log "OpenChamber not found on PATH — skipping"
fi

log "Starting sshd"
sudo /usr/sbin/sshd -D &
sshd_pid=$!
log "sshd PID: ${sshd_pid}"

shutdown() {
  log "Received shutdown signal"
  [ -n "${oc_pid}" ] && kill -TERM "${oc_pid}" 2>/dev/null || true
  kill -TERM "${sshd_pid}" 2>/dev/null || true
  for _ in $(seq 10); do
    kill -0 "${sshd_pid}" 2>/dev/null || break
    sleep 1
  done
  exit 0
}
trap shutdown TERM INT QUIT

wait
