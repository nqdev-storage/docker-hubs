#!/usr/bin/env bash
# Cài .NET SDK vào thư mục của user bằng dotnet-install.sh chính thức của Microsoft, không cần root.
# Dùng:  30-install-dotnet.sh
# Biến:  DOTNET_CHANNEL=8.0  DOTNET_ROOT=/home/node/.local/opt/dotnet
# Kết quả: $DOTNET_ROOT/dotnet (khớp DOTNET_ROOT / PATH trong image). ICU (libicu72) đã có sẵn trong image.
set -euo pipefail

DOTNET_CHANNEL="${DOTNET_CHANNEL:-8.0}"
DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.local/opt/dotnet}"

log() { echo "[30-install-dotnet] $*"; }

if [ -x "$DOTNET_ROOT/dotnet" ] && "$DOTNET_ROOT/dotnet" --list-sdks | grep -q "^${DOTNET_CHANNEL}\."; then
  log ".NET SDK ${DOTNET_CHANNEL} đã có ở $DOTNET_ROOT, bỏ qua"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Tải dotnet-install.sh"
curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$TMP_DIR/dotnet-install.sh"

log "Cài .NET SDK ${DOTNET_CHANNEL} vào $DOTNET_ROOT (lần đầu tải ~200MB)"
bash "$TMP_DIR/dotnet-install.sh" --channel "$DOTNET_CHANNEL" --install-dir "$DOTNET_ROOT" --no-path

"$DOTNET_ROOT/dotnet" --list-sdks
log "Xong."
