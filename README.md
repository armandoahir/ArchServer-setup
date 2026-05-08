# ArchServer Setup

Configuration and setup scripts for my Arch Linux home server running on a repurposed laptop.

## Stack

| Service | Role |
|---|---|
| **Nginx** | Web server / static file serving |
| **OpenSSH** | Remote access |
| **Docker + Compose** | Container runtime |
| **Seafile** | Self-hosted cloud storage |
| **SeaDoc** | Collaborative document editing |
| **Caddy (docker-proxy)** | Reverse proxy with automatic routing |
| **WireGuard** | VPN |
| **Starship** | Shell prompt |

## Repository Structure

```
ArchServer-setup/
├── nginx/
│   └── nginx.conf              # Nginx main config
├── ssh/
│   └── sshd_config             # SSH daemon config
├── seafile/
│   ├── seafile-server.yml      # MariaDB + Redis + Seafile containers
│   ├── caddy.yml               # Caddy reverse proxy container
│   ├── seadoc.yml              # SeaDoc collaborative editor
│   └── .env.example            # Environment variables template
├── wireguard/
│   └── wg0.conf.template       # WireGuard config template (no secrets)
├── dotfiles/
│   └── starship.toml           # Starship prompt config
├── scripts/
│   └── setup.sh                # Full setup script
└── .gitignore
```

## Fresh Install

### 1. Clone the repo

```bash
git clone https://github.com/<your-username>/ArchServer-setup.git
cd ArchServer-setup
```

### 2. Run the setup script

```bash
sudo bash scripts/setup.sh
```

This installs all packages and deploys configs. It will **not** overwrite existing `.env` or WireGuard keys.

### 3. Configure secrets

```bash
# Seafile
cp seafile/.env.example /opt/seafile/.env
nano /opt/seafile/.env   # fill in passwords, hostname, JWT key

# WireGuard
wg genkey | tee privatekey | wg pubkey > publickey
nano /etc/wireguard/wg0.conf   # fill in keys
```

### 4. Start services

```bash
# Seafile stack
cd /opt/seafile
docker compose up -d

# WireGuard
sudo systemctl start wg-quick@wg0
```

## Seafile

Seafile runs as a Docker Compose stack split across three files:

- `seafile-server.yml` — MariaDB, Redis, Seafile core
- `caddy.yml` — Caddy reverse proxy (routes via Docker labels)
- `seadoc.yml` — SeaDoc collaborative editor

All sensitive values (passwords, JWT key) live in `/opt/seafile/.env` — **never committed to git**.

To generate a secure JWT key:
```bash
openssl rand -base64 32
```

## WireGuard

The actual config with private keys lives only on the server at `/etc/wireguard/wg0.conf` and is excluded from git via `.gitignore`. Only the template is tracked.

Key generation:
```bash
# Server keys
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

# Per-client keys
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Optional preshared key
wg genpsk > preshared.key
```

## ⚠️ Security Notes

Files that are **never** pushed to this repo:
- `/etc/ssh/ssh_host_*_key` — SSH host private keys
- `/etc/wireguard/*.conf` — WireGuard configs with private keys
- `/opt/seafile/.env` — Seafile secrets
- Any `*.pem`, `*.key`, `*.crt` files

See `.gitignore` for the full list.
