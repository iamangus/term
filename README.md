# term

AlmaLinux-based SSH dev box container. Spawns a user, pulls SSH keys from GitHub, and runs an SSH daemon — nothing else.

## Quick Start

```bash
docker run -d \
  -p 2222:22 \
  -e USER_NAME=angus \
  -e GH_USER_NAME=iamangus \
  ghcr.io/iamangus/term:latest

ssh -p 2222 angus@localhost
```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `USER_NAME` | Yes | Local username to create |
| `GH_USER_NAME` | Yes | GitHub username (SSH public keys fetched from `https://github.com/<user>.keys`) |
| `OPENCHAMBER_UI_PASSWORD` | No | Password for the OpenChamber web UI. If set, OpenChamber starts automatically on port 3000 |
| `TZ` | No | Timezone, defaults to `America/Chicago` |

## What Happens on Start

1. A user is created with zsh as the default shell and passwordless `sudo`
2. SSH keys are pulled from GitHub and written to `~/.ssh/authorized_keys`
3. `opencode serve` starts on `0.0.0.0:4096` (headless server, external)
4. `openchamber` starts on `0.0.0.0:3000`, connecting to the opencode server via loopback
5. `sshd` starts in the foreground on port 22

## Installed Tools

### Languages & Runtimes
- **Go** (golang)
- **Node.js 23** (via dnf module)
- **Python 3** + pip
- **GCC / G++**

### Shell & Editors
- **zsh** (default shell)
- **tmux**
- **vim**

### Kubernetes & Infra
- **kubectl** + **k9s** (`0.50.16`)
- **opentofu**
- **sops** (`3.8.1`)

### CLI & Utilities
- **gh** (GitHub CLI)
- **git**
- **make**, **jq**, **yq**
- **curl**, **wget**, **rsync**
- **htop**, **tree**, **file**
- **ipmitool**

### Networking & Debugging
- **bind-utils** (`dig`, `nslookup`)
- **nmap-ncat**
- **openssh-server**

### AI & Agents
- **OpenCode** (via `opencode` CLI)
- **OpenChamber** (web UI for OpenCode, via `openchamber` CLI)

### Browser
- **Chromium** (headless)

## Building

```bash
docker build -t term .
```

## Image Registry

Pushed to `ghcr.io/iamangus/term` on merge to `main`. Tags: `latest` and a Unix timestamp tag.
