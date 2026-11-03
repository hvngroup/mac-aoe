#!/bin/bash
# Remove a tester from the spike hub.   sudo ./remove-peer.sh dong-mac
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=hub-common.sh
. ./hub-common.sh

require_root
load_settings
name="${1:-}"
[ -f "$HUB_DIR/peers/$name.peer" ] || die "Không có người thử '$name'."
rm -f "$HUB_DIR/peers/$name.peer" "$HUB_DIR/peers/$name.conf"
render_wg_conf
sync_iface
log "Đã xoá '$name'."
