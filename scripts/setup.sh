#!/bin/bash
# ArchServer Setup Script
# Replicates the full server configuration from scratch on Arch Linux

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Prerequisites ──────────────────────────────────────────────────────────────
check_root() {
  [[ $EUID -ne 0 ]] && error "Run this script as root or with sudo."
}

install_packages() {
  info "Installing base packages..."
  pacman -Syu --noconfirm
  pacman -S --noconfirm \
    nginx \
    openssh \
    docker \
    docker-compose \
    wireguard-tools \
    starship \
    curl \
    git
  info "Packages installed."
}

# ── Services ───────────────────────────────────────────────────────────────────
setup_nginx() {
  info "Configuring Nginx..."
  cp "$REPO_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
  systemctl enable --now nginx
  info "Nginx configured and started."
}

setup_ssh() {
  info "Configuring SSH..."
  cp "$REPO_DIR/ssh/sshd_config" /etc/ssh/sshd_config
  systemctl enable --now sshd
  info "SSH configured and started."
}

setup_docker() {
  info "Enabling Docker..."
  systemctl enable --now docker
  usermod -aG docker "$SUDO_USER"
  info "Docker enabled. Re-login for group changes to take effect."
}

setup_seafile() {
  info "Setting up Seafile..."
  mkdir -p /opt/seafile /opt/seafile-caddy /opt/seadoc-data /opt/seafile-mysql/db /opt/seafile-data

  cp "$REPO_DIR/seafile/seafile-server.yml" /opt/seafile/
  cp "$REPO_DIR/seafile/caddy.yml"          /opt/seafile/
  cp "$REPO_DIR/seafile/seadoc.yml"         /opt/seafile/

  if [[ ! -f /opt/seafile/.env ]]; then
    cp "$REPO_DIR/seafile/.env.example" /opt/seafile/.env
    warn ".env created from template. Edit /opt/seafile/.env before starting!"
  else
    warn "/opt/seafile/.env already exists, skipping."
  fi

  info "Seafile files deployed to /opt/seafile/"
  info "Run: cd /opt/seafile && docker compose up -d"
}

setup_wireguard() {
  info "Setting up WireGuard..."
  if [[ ! -f /etc/wireguard/wg0.conf ]]; then
    cp "$REPO_DIR/wireguard/wg0.conf.template" /etc/wireguard/wg0.conf
    chmod 600 /etc/wireguard/wg0.conf
    warn "WireGuard template deployed. Edit /etc/wireguard/wg0.conf with your keys!"
    warn "Generate keys with: wg genkey | tee privatekey | wg pubkey > publickey"
  else
    warn "/etc/wireguard/wg0.conf already exists, skipping."
  fi
  systemctl enable wg-quick@wg0
  info "WireGuard enabled (not started — configure first)."
}

setup_dotfiles() {
  info "Installing dotfiles..."
  STARSHIP_DIR="${HOME}/.config"
  [[ -n "$SUDO_USER" ]] && STARSHIP_DIR="/home/$SUDO_USER/.config"
  mkdir -p "$STARSHIP_DIR"
  cp "$REPO_DIR/dotfiles/starship.toml" "$STARSHIP_DIR/starship.toml"
  info "starship.toml installed."

  if ! grep -q 'eval "$(starship init' "${HOME}/.zshrc" 2>/dev/null; then
    echo 'eval "$(starship init zsh)"' >> "${HOME}/.zshrc"
    info "Starship init added to .zshrc"
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  check_root
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║      ArchServer Setup Script         ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  install_packages
  setup_nginx
  setup_ssh
  setup_docker
  setup_seafile
  setup_wireguard
  setup_dotfiles

  echo ""
  info "Setup complete! Next steps:"
  echo "  1. Edit /opt/seafile/.env with your credentials"
  echo "  2. Edit /etc/wireguard/wg0.conf with your keys"
  echo "  3. cd /opt/seafile && docker compose up -d"
  echo "  4. systemctl start wg-quick@wg0"
  echo "  5. Re-login for Docker group membership"
}

main "$@"
