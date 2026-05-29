#!/usr/bin/env bash

set -euo pipefail

# Nilo Linux Runner installer
# Usage: curl -sfL https://raw.githubusercontent.com/caimito/nilo-runner/main/install.sh | sudo bash
#
# This script downloads and installs the Nilo Linux Runner from the public
# distribution repository. The runner binaries are published there so users
# can install without needing access to the private source repository.

GITHUB_OWNER="caimito"
GITHUB_REPO="nilo-runner"
BINARY_NAME="nilo-runner-linux"
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/var/lib/nilo-runner"
VERSION="latest"

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      log_error "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

download_binary() {
  local url="$1"
  local output="$2"

  log_info "Downloading binary from $url"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries=3 -O "$output" "$url"
  else
    log_error "Neither curl nor wget is available"
    exit 1
  fi
}

get_latest_release_url() {
  local arch="$1"
  local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/${VERSION}"

  log_info "Looking up latest release from GitHub"

  local release_json
  if command -v curl >/dev/null 2>&1; then
    release_json=$(curl -fsSL "$api_url" 2>/dev/null || true)
  elif command -v wget >/dev/null 2>&1; then
    release_json=$(wget -qO- "$api_url" 2>/dev/null || true)
  fi

  if [[ -z "$release_json" ]]; then
    return 1
  fi

  local asset_url
  asset_url=$(echo "$release_json" | awk '
    /"browser_download_url"/ {
      gsub(/.*"browser_download_url": "/, "")
      gsub(/".*/, "")
      print
    }
  ' | grep "${BINARY_NAME}-${arch}" | head -n1)

  if [[ -n "$asset_url" ]]; then
    echo "$asset_url"
    return 0
  fi

  return 1
}

prompt_required() {
  local prompt_text="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -rp "$prompt_text" value
    value=$(echo "$value" | xargs)
    if [[ -z "$value" ]]; then
      echo "This field is required. Please try again." >&2
    fi
  done
  echo "$value"
}

prompt_optional() {
  local prompt_text="$1"
  local default_value="${2:-}"
  local value
  read -rp "$prompt_text" value
  value=$(echo "$value" | xargs)
  if [[ -z "$value" && -n "$default_value" ]]; then
    echo "$default_value"
  else
    echo "$value"
  fi
}

# --- Main ---

if [[ "$EUID" -ne 0 ]]; then
  log_error "This script must be run as root (use sudo)"
  exit 1
fi

echo ""
echo "=== Nilo Linux Runner Installation ==="
echo ""

REMOTE_URL=$(prompt_required "Remote Nilo base URL (e.g. https://app.niloassistant.com): ")
REGISTRATION_KEY=$(prompt_required "Runner registration key: ")
DEVICE_NAME=$(prompt_optional "Device name [$(hostname)]: " "$(hostname)")

echo ""
log_info "Remote URL: $REMOTE_URL"
log_info "Device name: $DEVICE_NAME"

ARCH=$(detect_arch)
log_info "Detected architecture: $ARCH"

# Determine binary URL
if DOWNLOAD_URL=$(get_latest_release_url "$ARCH"); then
  log_info "Found release binary URL"
else
  log_error "Could not find release binary. Ensure a GitHub release exists with asset '${BINARY_NAME}-${ARCH}'."
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BINARY_PATH="$TMP_DIR/$BINARY_NAME"
download_binary "$DOWNLOAD_URL" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

# Verify binary works
if ! "$BINARY_PATH" --help >/dev/null 2>&1; then
  log_error "Downloaded binary does not appear to be valid"
  exit 1
fi

log_info "Installing Nilo Linux Runner..."

# Install binary
cp "$BINARY_PATH" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Create data directory
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

# Install systemd service
SERVICE_FILE="/etc/systemd/system/nilo-runner.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nilo Linux Runner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BINARY_NAME}
Restart=always
RestartSec=10
Environment="NILO_RUNNER_REMOTE_URL=${REMOTE_URL}"
Environment="NILO_RUNNER_REGISTRATION_KEY=${REGISTRATION_KEY}"
Environment="NILO_RUNNER_DEVICE_NAME=${DEVICE_NAME}"
Environment="NILO_RUNNER_LOG_LEVEL=info"
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR}
WorkingDirectory=${DATA_DIR}
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable nilo-runner.service

echo ""
log_info "Installation complete."
echo ""
echo "Start the runner with:"
echo "  sudo systemctl start nilo-runner"
echo ""
echo "Check status with:"
echo "  sudo systemctl status nilo-runner"
echo ""
echo "View logs with:"
echo "  sudo journalctl -u nilo-runner -f"
