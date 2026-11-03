#!/bin/bash
# Integration test for the spike hub scripts, run as root on Linux.
# Builds three network namespaces (hub, player A, player B), runs the real
# setup-hub.sh / add-peer.sh / remove-peer.sh inside the hub namespace and
# checks what the firewall lets through between players.
#
#   sudo ./test-hub.sh
#
# Needs: ip (iproute2), wg + wg-quick (wireguard-tools), nft, nc (openbsd),
# ping, and either the WireGuard kernel module or wireguard-go in PATH.
set -u
cd "$(dirname "$0")" || exit 1
HERE="$(pwd -P)"
WORK="$(mktemp -d)"
PASS=0
FAIL=0
export WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1   # allow wireguard-go when no kernel module

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check()     { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else fail "$n"; fi; }
check_not() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$n"; else ok "$n"; fi; }
in_ns() { local ns="$1"; shift; ip netns exec "aoe-$ns" "$@"; }

cleanup() {
  for ns in a b; do in_ns "$ns" wg-quick down "$WORK/$ns.conf" >/dev/null 2>&1; done
  in_ns hub wg-quick down "$WORK/hub/wg0.conf" >/dev/null 2>&1
  for ns in hub a b; do ip netns del "aoe-$ns" 2>/dev/null; done
  pkill -f "nc -l" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- topology: A and B each reach the hub's public address 203.0.113.1 ---
for ns in hub a b; do ip netns add "aoe-$ns"; in_ns "$ns" ip link set lo up; done
in_ns hub ip addr add 203.0.113.1/32 dev lo
if [ -n "${AOE_TEST_DOCKER:-}" ]; then
  # What Docker (and so Coolify) leaves on a host: forwarding dropped by
  # default, with the DOCKER-USER chain jumped to first for local rules.
  echo "== simulating a Docker/Coolify host"
  in_ns hub iptables -P FORWARD DROP
  in_ns hub iptables -N DOCKER-USER
  in_ns hub iptables -A DOCKER-USER -j RETURN
  in_ns hub iptables -A FORWARD -j DOCKER-USER
fi
i=0
for ns in a b; do
  i=$((i + 1))
  ip link add "h-$ns" type veth peer name "p-$ns"
  ip link set "h-$ns" netns aoe-hub
  ip link set "p-$ns" netns "aoe-$ns"
  in_ns hub ip addr add "192.0.2.$((i * 4 + 1))/30" dev "h-$ns"
  in_ns hub ip link set "h-$ns" up
  in_ns "$ns" ip addr add "192.0.2.$((i * 4 + 2))/30" dev "p-$ns"
  in_ns "$ns" ip link set "p-$ns" up
  in_ns "$ns" ip route add default via "192.0.2.$((i * 4 + 1))"
done

echo "== setup-hub.sh"
export AOE_HUB_DIR="$WORK/hub" AOE_HUB_ENDPOINT=203.0.113.1 AOE_HUB_NO_INSTALL=1 AOE_HUB_NO_SYSTEMD=1
check "setup-hub.sh brings wg0 up" in_ns hub "$HERE/setup-hub.sh"
# Check the socket itself: wireguard-go reports listen-port 0 through "wg show".
check "hub listens on UDP 51820" sh -c "ip netns exec aoe-hub ss -uln | grep -q ':51820 '"
check "firewall table loaded" in_ns hub nft list table inet aoe_hub
check "setup-hub.sh is idempotent" in_ns hub "$HERE/setup-hub.sh"
check "exactly one FORWARD accept for wg0 after re-running setup" sh -c "[ \$(ip netns exec aoe-hub iptables -S FORWARD | grep -c -- '-i wg0 -o wg0 -j ACCEPT') -eq 1 ]"

echo "== add-peer.sh"
in_ns hub "$HERE/add-peer.sh" player-a > "$WORK/a.conf" 2>/dev/null
in_ns hub "$HERE/add-peer.sh" player-b > "$WORK/b.conf" 2>/dev/null
check "player A gets 10.77.0.11" grep -q "Address = 10.77.0.11/16" "$WORK/a.conf"
check "player B gets 10.77.0.12" grep -q "Address = 10.77.0.12/16" "$WORK/b.conf"
check "client routes only 10.77.0.0/16 (split tunnel)" grep -q "AllowedIPs = 10.77.0.0/16" "$WORK/a.conf"
check "client config points at the hub endpoint" grep -q "Endpoint = 203.0.113.1:51820" "$WORK/a.conf"
check "re-adding a peer prints the same config" sh -c "ip netns exec aoe-hub '$HERE/add-peer.sh' player-a 2>/dev/null | cmp -s - '$WORK/a.conf'"
check_not "invalid peer names are rejected" in_ns hub "$HERE/add-peer.sh" "Bad Name"
check "hub has two peers" sh -c "[ \$(ip netns exec aoe-hub wg show wg0 peers | wc -l) -eq 2 ]"
check "peer keys stay private (mode 600)" sh -c "[ \$(stat -c %a '$WORK/hub/peers/player-a.conf') = 600 ]"

echo "== players connect"
check "player A tunnel up" in_ns a wg-quick up "$WORK/a.conf"
check "player B tunnel up" in_ns b wg-quick up "$WORK/b.conf"
check "A reaches the hub (10.77.0.1)" in_ns a ping -c 2 -W 2 10.77.0.1
check "A pings B through the hub" in_ns a ping -c 2 -W 2 10.77.0.12

echo "== firewall between players"
# TCP 2300: DirectPlay stream port
in_ns b sh -c 'nc -l 2300 > '"$WORK"'/tcp2300.out' & sleep 0.5
in_ns a sh -c 'echo dplay-tcp | nc -w 2 -N 10.77.0.12 2300' >/dev/null 2>&1; sleep 0.5
check "TCP 2300 (DirectPlay) A to B passes" grep -q dplay-tcp "$WORK/tcp2300.out"
# UDP 47624: DirectPlay enumeration port
in_ns b sh -c 'timeout 3 nc -u -l 47624 > '"$WORK"'/udp47624.out' & sleep 0.5
in_ns a sh -c 'echo dplay-udp | nc -u -w 1 10.77.0.12 47624' >/dev/null 2>&1; sleep 1
check "UDP 47624 (DirectPlay) A to B passes" grep -q dplay-udp "$WORK/udp47624.out"
# TCP 22 must be blocked even if B listens on it
in_ns b sh -c 'timeout 4 nc -l 22 > '"$WORK"'/tcp22.out' & sleep 0.5
in_ns a sh -c 'echo ssh-probe | nc -w 2 -N 10.77.0.12 22' >/dev/null 2>&1; sleep 0.5
check_not "TCP 22 A to B is blocked" grep -q ssh-probe "$WORK/tcp22.out"
check "blocked packets are counted on the hub" sh -c "ip netns exec aoe-hub nft list table inet aoe_hub | grep -Eq 'counter packets [1-9]'"
check_not "players cannot use the hub to reach the Internet side" in_ns a ping -c 1 -W 2 -I 10.77.0.11 192.0.2.10

echo "== remove-peer.sh"
check "remove player B" in_ns hub "$HERE/remove-peer.sh" player-b
check "hub has one peer left" sh -c "[ \$(ip netns exec aoe-hub wg show wg0 peers | wc -l) -eq 1 ]"
check_not "A can no longer reach B" in_ns a ping -c 1 -W 2 10.77.0.12
in_ns hub "$HERE/add-peer.sh" player-c > "$WORK/c.conf" 2>/dev/null
check "freed address is reused" grep -q "Address = 10.77.0.12/16" "$WORK/c.conf"

echo
echo "Kết quả: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
