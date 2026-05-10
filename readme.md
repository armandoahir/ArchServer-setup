# ArchServer Setup

Configuration and setup scripts for my Arch Linux home server running on an old laptop.

## Stack

| Service | Role |
|---|---|
| **Nextcloud** | Self-hosted cloud storage |
| **Jellyfin** | Media server |
| **Nginx** | Web server / static file serving |
| **OpenSSH** | Remote access |
| **Docker + Compose** | Container runtime |
| **WireGuard** | VPN |
| **Starship** | Shell prompt |

## Repository Structure

```
ArchServer-setup/
├── nextcloud/
│   └── nextcloud.yml               # MariaDB + Nextcloud containers
├── jellyfin/
│   └── jellyfin.yml                # Jellyfin media server
├── media/
│   ├── compress_media.sh           # Compress/convert photos and videos
│   ├── compress_media.env.example  # Config template
│   ├── compress_media.env          # Local config (in .gitignore)
│   ├── media_report.sh             # Space usage report (source vs destination)
│   └── README.md                   # Full documentation for media scripts
├── nginx/
│   └── nginx.conf                  # Nginx main config
├── ssh/
│   └── sshd_config                 # SSH daemon config
├── wireguard/
│   └── wg0.conf.template           # WireGuard config template (no secrets)
├── dotfiles/
│   └── starship.toml               # Starship prompt config
├── scripts/
│   └── setup.sh                    # Full setup script
├── seafile/                        # Seafile stack (removed, kept for reference)
│   ├── seafile-server.yml
│   ├── caddy.yml
│   └── seadoc.yml
├── .env.example                    # Seafile env template (legacy)
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

### 3. Start Nextcloud

```bash
cp nextcloud/nextcloud.yml /opt/nextcloud/nextcloud.yml
cd /opt/nextcloud
docker compose -f nextcloud.yml up -d
```

Nextcloud will be available at `http://<server-ip>:8082`.

Data is stored in `/home/nextcloud-data/data/`.

### 4. Start Jellyfin

```bash
cd /opt/jellyfin   # or wherever you deploy it
docker compose -f /path/to/jellyfin.yml up -d
```

Jellyfin will be available at `http://<server-ip>:8083`.

### 5. Configure WireGuard

```bash
wg genkey | tee privatekey | wg pubkey > publickey
nano /etc/wireguard/wg0.conf   # fill in keys from template
sudo systemctl enable --now wg-quick@wg0
```

## Media Scripts

The `media/` folder contains scripts to compress and convert photos and videos, designed for use with Nextcloud.

See [`media/README.md`](media/README.md) for full documentation.

Quick example:

```bash
./media/compress_media.sh \
  --source /home/nextcloud-data/data/data/arma/files/Toshiba \
  --dest /mnt/nextcloud_hdd/Foto-compresse \
  --exclude "Arma Logo" --exclude "Files"
```

Features: MP4/MOV → H.265, HEIC → JPG, dry-run mode, idempotent (safe to re-run).

## WireGuard

The actual config with private keys lives only on the server at `/etc/wireguard/wg0.conf` and is excluded from git. Only the template is tracked.

```bash
# Server keys
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

# Per-client keys
wg genkey | tee client_private.key | wg pubkey > client_public.key
```

## Important

Files that are **never** pushed to this repo:

- `/etc/wireguard/*.conf` — WireGuard configs with private keys
- `media/compress_media.env` — local paths and config
- Any `*.pem`, `*.key`, `*.crt` files

See `.gitignore` for the full list.
