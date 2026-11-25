#!/usr/bin/env bash
# Cài / cập nhật plugin Claude Code từ marketplace nqdev (https://github.com/nqdev-storage/claude-plugin-nqdev).
# Dùng:  20-install-nqdev-plugin.sh [install|update]        (mặc định: install)
# Biến:  NQDEV_PLUGINS="nqdev"   (cách nhau bởi dấu cách, vd "nqdev vhs"; "all" = mọi plugin trong marketplace)
#        NQDEV_MARKETPLACE_URL=https://github.com/nqdev-storage/claude-plugin-nqdev.git
# Kết quả nằm trong ~/.claude/plugins (bind mount ./data/claude-config) nên giữ qua các lần recreate container.
# Restart claude (restart container) sau khi cài/cập nhật để plugin có hiệu lực.
set -euo pipefail

MARKETPLACE_URL="${NQDEV_MARKETPLACE_URL:-https://github.com/nqdev-storage/claude-plugin-nqdev.git}"
MARKETPLACE_NAME="nqdev-marketplace" # = "name" trong .claude-plugin/marketplace.json của repo
PLUGINS="${NQDEV_PLUGINS:-nqdev}"
ACTION="${1:-install}"

log() { echo "[20-install-nqdev-plugin] $*"; }

has_marketplace() { claude plugin marketplace list --json | grep -q "\"$MARKETPLACE_NAME\""; }
has_plugin() { claude plugin list --json | grep -q "\"$1@$MARKETPLACE_NAME\""; }

# NQDEV_PLUGINS=all -> lấy mọi plugin khai báo trong marketplace.json của bản đã clone (gọi sau khi add/update marketplace)
resolve_plugins() {
  [ "$PLUGINS" = "all" ] || return 0
  local manifest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/marketplaces/$MARKETPLACE_NAME/.claude-plugin/marketplace.json"
  PLUGINS="$(node -e 'console.log(require(process.argv[1]).plugins.map(p => p.name).join(" "))' "$manifest")"
  log "NQDEV_PLUGINS=all -> $PLUGINS"
}

case "$ACTION" in
  install)
    # Idempotent: marketplace/plugin đã có thì bỏ qua, để entrypoint gọi mỗi lần khởi động không tốn thời gian
    if has_marketplace; then
      log "Marketplace $MARKETPLACE_NAME đã có, bỏ qua"
    else
      log "Thêm marketplace $MARKETPLACE_URL"
      claude plugin marketplace add "$MARKETPLACE_URL"
    fi
    resolve_plugins
    for p in $PLUGINS; do
      if has_plugin "$p"; then
        log "Plugin $p đã cài, bỏ qua (cập nhật: 20-install-nqdev-plugin.sh update)"
      else
        log "Cài plugin $p@$MARKETPLACE_NAME"
        claude plugin install "$p@$MARKETPLACE_NAME" --scope user
      fi
    done
    ;;
  update)
    has_marketplace || { log "Chưa có marketplace, chạy 'install' trước" >&2; exit 1; }
    log "Cập nhật marketplace $MARKETPLACE_NAME"
    claude plugin marketplace update "$MARKETPLACE_NAME"
    resolve_plugins
    for p in $PLUGINS; do
      if has_plugin "$p"; then
        log "Cập nhật plugin $p@$MARKETPLACE_NAME"
        claude plugin update "$p@$MARKETPLACE_NAME" --scope user
      else
        log "Plugin $p chưa cài, cài mới"
        claude plugin install "$p@$MARKETPLACE_NAME" --scope user
      fi
    done
    ;;
  *)
    log "Hành động không hợp lệ: $ACTION (dùng install|update)" >&2
    exit 1
    ;;
esac

log "Xong. Restart claude/container để áp dụng plugin."
