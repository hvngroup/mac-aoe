#!/bin/bash
# Set up the HVN AOE spike hub on an Ubuntu 24.04 VPS:
# WireGuard on wg0 (10.77.0.1/16, UDP 51820) that forwards only DirectPlay
# traffic (TCP/UDP 2300-2400 and 47624, plus ping) between connected players.
#
#   sudo ./setup-hub.sh
#
# Environment: AOE_HUB_ENDPOINT (default aoe.hvn.works), AOE_HUB_PORT (51820),
# AOE_HUB_DIR (/etc/wireguard), AOE_HUB_NO_INSTALL=1 (skip apt),
# AOE_HUB_NO_SYSTEMD=1 (bring wg0 up with wg-quick instead of a systemd unit).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=hub-common.sh
. ./hub-common.sh

require_root
ENDPOINT="${AOE_HUB_ENDPOINT:-aoe.hvn.works}"
PORT="${AOE_HUB_PORT:-51820}"

if [ -z "${AOE_HUB_NO_INSTALL:-}" ]; then
  log "Cài WireGuard và nftables"
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireguard-tools nftables iptables >/dev/null
fi

umask 077
mkdir -p "$HUB_DIR/peers"
if [ ! -f "$HUB_DIR/server.key" ]; then
  log "Sinh khoá máy chủ"
  wg genkey > "$HUB_DIR/server.key"
fi
wg pubkey < "$HUB_DIR/server.key" > "$HUB_DIR/server.pub"

printf 'AOE_HUB_ENDPOINT=%s\nAOE_HUB_PORT=%s\n' "$ENDPOINT" "$PORT" > "$HUB_SETTINGS"

# Firewall scoped to wg0 so other services on the VPS are untouched.
cat > "$HUB_DIR/aoe-hub.nft" <<NFT
table inet aoe_hub {}
delete table inet aoe_hub
table inet aoe_hub {
  chain forward {
    type filter hook forward priority filter; policy accept;
    iifname "$IFACE" oifname "$IFACE" ct state established,related accept
    iifname "$IFACE" oifname "$IFACE" icmp type echo-request accept
    iifname "$IFACE" oifname "$IFACE" meta l4proto { tcp, udp } th dport { 2300-2400, 47624 } accept
    iifname "$IFACE" counter drop
  }
}
NFT

# shellcheck disable=SC2034  # read by render_wg_conf
AOE_HUB_PORT="$PORT"
render_wg_conf

log "Bật chuyển tiếp IPv4"
if [ -z "${AOE_HUB_NO_SYSTEMD:-}" ]; then
  echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-aoe-hub.conf
fi
sysctl -q -w net.ipv4.ip_forward=1

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Mở cổng $PORT/udp và cho chuyển tiếp wg0 trên ufw"
  ufw allow "$PORT/udp" >/dev/null
  ufw route allow in on "$IFACE" out on "$IFACE" >/dev/null
fi

if wg show "$IFACE" >/dev/null 2>&1; then
  sync_iface
  nft -f "$HUB_DIR/aoe-hub.nft"
  eval "$FORWARD_RULE_UP"
elif [ -n "${AOE_HUB_NO_SYSTEMD:-}" ]; then
  wg-quick up "$HUB_DIR/$IFACE.conf"
else
  # Start after Docker (if any) so its firewall setup at boot comes first.
  # After= on a unit that does not exist is ignored.
  mkdir -p "/etc/systemd/system/wg-quick@$IFACE.service.d"
  printf '[Unit]\nAfter=docker.service\n' > "/etc/systemd/system/wg-quick@$IFACE.service.d/after-docker.conf"
  systemctl daemon-reload
  systemctl enable --now "wg-quick@$IFACE" >/dev/null
fi

log "Hub sẵn sàng: $ENDPOINT:$PORT/udp, địa chỉ hub $HUB_ADDR"
log "Khoá công khai của hub: $(cat "$HUB_DIR/server.pub")"
log "Thêm người thử: sudo ./add-peer.sh <ten>"
