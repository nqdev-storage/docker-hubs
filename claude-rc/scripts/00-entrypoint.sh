#!/usr/bin/env bash
# Entrypoint của image (chạy dưới tini): khởi tạo dữ liệu rồi chạy lệnh CMD.
# Mục đích: bind mount (./data/claude-config, ./data/claude-memory-hub) che mất settings.json, commands,
# hook và runtime claude-memory-hub đã cài trong image -> chép bổ sung từ bản gốc, KHÔNG ghi đè file đã có.
set -uo pipefail

DEFAULTS_DIR="${IMAGE_DEFAULTS_DIR:-/home/node/.image-defaults}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MEMORY_HUB_DIR="$HOME/.claude-memory-hub"

log() { echo "[entrypoint] $*"; }

# seed <nguồn> <đích>: chép file còn thiếu, giữ nguyên file đã tồn tại (login, settings người dùng sửa, DB)
seed() {
  local src="$1" dst="$2"
  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  cp -a -n "$src"/. "$dst"/ 2>/dev/null || true
}

seed "$DEFAULTS_DIR/claude" "$CLAUDE_DIR"
seed "$DEFAULTS_DIR/claude-memory-hub" "$MEMORY_HUB_DIR"

# Runtime claude-memory-hub phải có thì hook mới chạy được; thiếu thì cài lại, không chặn khởi động nếu lỗi (vd mất mạng)
if [ ! -f "$MEMORY_HUB_DIR/dist/hooks/session-start.js" ]; then
  log "Thiếu runtime claude-memory-hub, cài lại..."
  bunx claude-memory-hub@latest install || log "Cài claude-memory-hub thất bại, bỏ qua (chạy tay: bunx claude-memory-hub@latest install)"
fi

# Cài Java + Maven khi INSTALL_JAVA_MAVEN bật (true/1/yes); mặc định tắt để khởi động nhanh. Script bỏ qua nếu đã cài đủ phiên bản,
# lỗi (vd mất mạng) chỉ cảnh báo, không chặn khởi động
case "${INSTALL_JAVA_MAVEN:-false}" in
  true | TRUE | 1 | yes | YES)
    log "INSTALL_JAVA_MAVEN bật, chạy 10-install-java-maven.sh..."
    "$(dirname "$0")/10-install-java-maven.sh" || log "Cài Java/Maven thất bại, bỏ qua (chạy tay: 10-install-java-maven.sh)"
    ;;
esac

exec "$@"
