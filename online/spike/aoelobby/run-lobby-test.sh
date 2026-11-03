#!/bin/bash
# Test aoelobby.exe under Wine with lobbytarget.exe standing in for the game.
# Checks that the lobby launches the registered application with the role,
# session GUID, player name and host address aoelobby was given.
#
#   ./run-lobby-test.sh            (needs wine, i686-w64-mingw32-gcc; xvfb-run on headless Linux)
set -u
cd "$(dirname "$0")" || exit 1
HERE="$(pwd -P)"
WORK="$(mktemp -d)"
export WINEPREFIX="${WINEPREFIX:-$WORK/prefix}" WINEDEBUG="${WINEDEBUG:--all}"
PASS=0
FAIL=0
TEST_APP_GUID="{3B0F6A1E-9C2D-4F5B-8E7A-1D2C3B4A5F60}"
SESSION_GUID="{D1E2F3A4-B5C6-4D7E-8F90-A1B2C3D4E5F6}"
APP_DIR_WIN='C:\aoelobbytest'

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
expect() { # name file key=value  (the Windows program writes CRLF lines)
  if tr -d '\r' < "$2" 2>/dev/null | grep -qxF -- "$3"; then ok "$1"; else fail "$1" "missing '$3' in $(tr '\r\n' '  ' < "$2" 2>/dev/null)"; fi
}
check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else fail "$n"; fi; }
cleanup() { wineserver -k 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

echo "== build"
for prog in aoelobby lobbytarget; do
  if i686-w64-mingw32-gcc -O2 -Wall -o "$WORK/$prog.exe" "$HERE/$prog.c" -ldplayx -ldxguid -lole32 -luuid; then
    ok "$prog.exe builds"
  else
    fail "$prog.exe builds"; exit 1
  fi
done

echo "== register the stand-in game"
wineboot -i >/dev/null 2>&1
APP_DIR="$WINEPREFIX/drive_c/aoelobbytest"
mkdir -p "$APP_DIR"
cp "$WORK/lobbytarget.exe" "$APP_DIR/"
key='HKLM\Software\Microsoft\DirectPlay\Applications\AoeLobbyTarget'
wine reg add "$key" /v Guid /d "$TEST_APP_GUID" /f /reg:32 >/dev/null 2>&1
wine reg add "$key" /v File /d lobbytarget.exe /f /reg:32 >/dev/null 2>&1
wine reg add "$key" /v Path /d "$APP_DIR_WIN" /f /reg:32 >/dev/null 2>&1
wine reg add "$key" /v CurrentDirectory /d "$APP_DIR_WIN" /f /reg:32 >/dev/null 2>&1
wine reg add "$key" /v CommandLine /d "result.txt" /f /reg:32 >/dev/null 2>&1
wineserver -w

run_case() { # role extra-args...
  local role="$1"; shift
  rm -f "$APP_DIR/result.txt"
  wine "$WORK/aoelobby.exe" "$role" --app-guid "$TEST_APP_GUID" --session-guid "$SESSION_GUID" "$@" --wait 8 \
    > "$WORK/$role.json" 2> "$WORK/$role.err"
  echo $? > "$WORK/$role.rc"
  for _ in $(seq 1 40); do [ -s "$APP_DIR/result.txt" ] && break; sleep 0.25; done
  cp "$APP_DIR/result.txt" "$WORK/$role.result" 2>/dev/null || : > "$WORK/$role.result"
}

echo "== join"
run_case join --name PlayerB --host 10.77.0.11 --session "Phong 1"
check "aoelobby join exits 0" test "$(cat "$WORK/join.rc")" = 0
check "aoelobby reports the launch" grep -q '"event":"launched"' "$WORK/join.json"
expect "game sees a join request" "$WORK/join.result" "join_session=1"
expect "game gets the host's virtual IP" "$WORK/join.result" "inet=10.77.0.11"
expect "game uses the TCP/IP service provider" "$WORK/join.result" "sp_tcpip=1"
expect "game gets the room's session GUID" "$WORK/join.result" "session_guid=$SESSION_GUID"
expect "game gets the player name" "$WORK/join.result" "player_name=PlayerB"

echo "== host"
run_case host --name PlayerA --session "Phong 1" --max 4
check "aoelobby host exits 0" test "$(cat "$WORK/host.rc")" = 0
expect "game sees a create request" "$WORK/host.result" "create_session=1"
expect "game gets the session name" "$WORK/host.result" "session_name=Phong 1"
expect "game gets the player limit" "$WORK/host.result" "max_players=4"
expect "host address is left empty (DirectPlay picks the local one)" "$WORK/host.result" "inet="

echo "== result reporting (informational: depends on the DirectPlay in use)"
printf '       game SendLobbyMessage: %s\n' "$(tr -d '\r' < "$WORK/join.result" | sed -n 's/^send_lobby_message=//p')"
if grep -q '"event":"app_message","data":"result:winner=1"' "$WORK/join.json"; then
  echo "       aoelobby received the game's lobby message"
else
  echo "       aoelobby did not receive a lobby message (Wine's dplayx stubs lobby messages)"
fi

echo
echo "Kết quả: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
