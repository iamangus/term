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

OPENCODE_BIN="${HOME}/.opencode/bin/opencode"
oc_serve_pid=""
if [ ! -x "${OPENCODE_BIN}" ]; then
  log "opencode binary not found at ${OPENCODE_BIN} — installing"
  mkdir -p "${HOME}/.opencode"
  curl -fsSL https://opencode.ai/install | bash
fi
if [ -x "${OPENCODE_BIN}" ]; then
  log "Upgrading opencode to latest"
  "${OPENCODE_BIN}" upgrade >/dev/null 2>&1 || log "WARNING: opencode upgrade failed — continuing"
  if pgrep -u "$(id -u)" "^opencode$" >/dev/null 2>&1; then
    log "opencode serve already running"
  else
    log "Starting opencode serve on 0.0.0.0:4096"
    :> /tmp/opencode.log
    nohup "${OPENCODE_BIN}" serve --hostname 0.0.0.0 --port 4096 > /tmp/opencode.log 2>&1 &
    oc_serve_pid=$!
    log "opencode serve PID: ${oc_serve_pid}"
    sleep 2
    if kill -0 "${oc_serve_pid}" 2>/dev/null; then
      log "opencode serve running"
    else
      log "ERROR: opencode serve exited immediately"
      tail -20 /tmp/opencode.log
    fi
  fi
else
  log "opencode install failed — skipping"
fi

oc_pid=""
if command -v openchamber >/dev/null 2>&1; then
  if pgrep -u "$(id -u)" "^openchamber$" >/dev/null 2>&1; then
    log "OpenChamber already running"
  else
    log "Starting OpenChamber"
    OC_RUN_DIR="${HOME}/.config/openchamber/run"
    if [ -n "$(ls -A "${OC_RUN_DIR}" 2>/dev/null)" ]; then
      log "WARNING: Unclean shutdown detected — cleaning stale run state"
      rm -rf "${OC_RUN_DIR}"/*
    fi
    :> /tmp/openchamber.log
    OPENCODE_BINARY="${OPENCODE_BIN}" \
    OPENCODE_SKIP_START=true \
    OPENCODE_HOST=http://127.0.0.1:4096 \
    OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN=true \
      nohup openchamber --host 0.0.0.0 > /tmp/openchamber.log 2>&1 &
    oc_pid=$!
    log "OpenChamber PID: ${oc_pid}"
    sleep 2
    if kill -0 "${oc_pid}" 2>/dev/null; then
      log "OpenChamber running"
    else
      log "ERROR: OpenChamber exited immediately"
      tail -20 /tmp/openchamber.log
    fi
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
  [ -n "${oc_serve_pid}" ] && kill -TERM "${oc_serve_pid}" 2>/dev/null || true
  kill -TERM "${sshd_pid}" 2>/dev/null || true
  for _ in $(seq 5); do
    killers=$(kill -0 "${sshd_pid}" 2>/dev/null && echo 1 || echo 0)
    [ -n "${oc_pid}" ] && kill -0 "${oc_pid}" 2>/dev/null && killers=1
    [ -n "${oc_serve_pid}" ] && kill -0 "${oc_serve_pid}" 2>/dev/null && killers=1
    [ "${killers}" = "0" ] && break
    sleep 1
  done
  exit 0
}
trap shutdown TERM INT QUIT

wait "${sshd_pid}"
