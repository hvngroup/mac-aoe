#!/bin/bash
# Add a tester to the spike hub and print their WireGuard client config.
#
#   sudo ./add-peer.sh dong-mac            # saves /etc/wireguard/peers/dong-mac.conf
#   sudo ./add-peer.sh dong-mac --print    # also prints it (to pipe or copy)
#
# The config holds the tester's private and preshared keys, so by default it
# is only written to a root-only file, never to the terminal: copy the file
# (scp) and send it through a private channel (1Password, a Drive file shared
# with that person only), never chat.
# Spike only: keys are generated here; the product generates them on the
# player's machine.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=hub-common.sh
. ./hub-common.sh

require_root
load_settings
name="${1:-}"
print=0
[ "${2:-}" = "--print" ] && print=1
printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]{0,31}$' || die "Tên không hợp lệ (a-z, 0-9, '-', tối đa 32 ký tự): '$name'"

if [ -f "$HUB_DIR/peers/$name.conf" ]; then
  log "Người thử '$name' đã có: $HUB_DIR/peers/$name.conf"
  if [ "$print" -eq 1 ]; then cat "$HUB_DIR/peers/$name.conf"; fi
  exit 0
fi

# Next free address from 10.77.0.11 (10.77.0.1-10 stay reserved for servers).
used="$(cat "$HUB_DIR"/peers/*.peer 2>/dev/null | sed -n 's|^AllowedIPs = \(.*\)/32$|\1|p' || true)"
ip=""
for third in $(seq 0 255); do
  for fourth in $(seq 1 254); do
    [ "$third" -eq 0 ] && [ "$fourth" -le 10 ] && continue
    candidate="$SUBNET_PREFIX.$third.$fourth"
    if ! printf '%s\n' "$used" | grep -qx "$candidate"; then ip="$candidate"; break 2; fi
  done
done
[ -n "$ip" ] || die "Hết địa chỉ trong $SUBNET_PREFIX.0.0/16."

umask 077
priv="$(wg genkey)"
pub="$(printf '%s' "$priv" | wg pubkey)"
psk="$(wg genpsk)"

cat > "$HUB_DIR/peers/$name.peer" <<PEER
[Peer]
# $name
PublicKey = $pub
PresharedKey = $psk
AllowedIPs = $ip/32
PEER

cat > "$HUB_DIR/peers/$name.conf" <<CONF
# HVN AOE spike - $name
[Interface]
PrivateKey = $priv
Address = $ip/16

[Peer]
PublicKey = $(cat "$HUB_DIR/server.pub")
PresharedKey = $psk
Endpoint = $AOE_HUB_ENDPOINT:$AOE_HUB_PORT
AllowedIPs = $SUBNET_PREFIX.0.0/16
PersistentKeepalive = 25
CONF

render_wg_conf
sync_iface
log "Đã thêm '$name' với IP ảo $ip."
log "Cấu hình (có khoá bí mật, gửi riêng cho người thử): $HUB_DIR/peers/$name.conf"
if [ "$print" -eq 1 ]; then cat "$HUB_DIR/peers/$name.conf"; fi
