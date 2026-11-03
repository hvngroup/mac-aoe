#!/bin/bash
# Test suite for aoe-mac. Runs on macOS and Linux with bash 3.2+.
# Uses a fake Wine by default; set AOE_TEST_REAL_WINE=1 to also run an
# install against the real Wine on PATH (needs a display on Linux: xvfb-run).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
AOE_MAC="$ROOT/aoe-mac"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1" "expected [$2], got [$3]"; fi
}
assert_file() { if [ -e "$2" ]; then ok "$1"; else fail "$1" "missing $2"; fi; }
check() { # name command... -> pass when the command succeeds
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi
}
check_not() { # name command... -> pass when the command fails
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$name"; else ok "$name"; fi
}
assert_contains() { # name file pattern
  if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else fail "$1" "[$3] not in $2"; fi
}

# A tiny stand-in for the game repo with the files aoe-mac touches.
make_fixture() {
  local d="$1"
  mkdir -p "$d/data" "$d/data2" "$d/savegame" "$d/.git" "$d/data2_daominah"
  echo exe > "$d/empires.exe"
  echo exe > "$d/EMPIRESX.EXE"
  echo ror > "$d/data/empires.dat"
  echo ror > "$d/data/empires.dat.backup"
  echo de > "$d/data/empires_definitive_edition.dat"
  echo mace > "$d/data/empires_mace_overpowered.dat"
  echo original > "$d/data/empires_original.dat"
  printf '[WINDOWMODE]\r\nUseCursorClip=1\r\nUseWindowMode=1\r\nBorder=1\r\n' > "$d/data/wndmode.ini"
  echo dll > "$d/data/wndmode.dll"
  echo ai > "$d/data2/Default.ai"
  echo save > "$d/savegame/repo.gmx"
  echo readme > "$d/README.md"
  echo tool > "$d/data2_daominah/tool.py"
}

run() { "$AOE_MAC" "$@" >"$WORK/out" 2>&1; }

echo "== unit: helpers"
(
  # shellcheck source=lib/common.sh
  . "$ROOT/lib/common.sh"
  # shellcheck source=lib/wine.sh
  . "$ROOT/lib/wine.sh"
  # shellcheck source=lib/game.sh
  . "$ROOT/lib/game.sh"
  AOE_HOME="$WORK/unit" init_paths
  mkdir -p "$AOE_HOME"
  config_set FOO bar
  config_set FOO baz
  config_set PATHY "/a b/c=d"
  echo "$(config_get FOO)|$(config_get PATHY)|$(config_get MISSING dflt)|$(grep -c '^FOO=' "$AOE_CONFIG")"
  printf '[S]\r\nA=1\r\nB=2\r\n' > "$WORK/t.ini"
  ini_set "$WORK/t.ini" B 7
  ini_set "$WORK/t.ini" C 9
  echo "$(ini_get "$WORK/t.ini" B)|$(ini_get "$WORK/t.ini" C)|$(grep -c $'\r$' "$WORK/t.ini")"
  render_template "$ROOT/templates/aoe-registry.reg.in" | grep -E '^"(CDPath|InstallationDirectory)"' | head -n 2 | tr '\n' ' '
  echo
  echo "$(balance_file_for de)|$(balance_file_for nope)"
  github_zip_url https://github.com/hvngroup/age_of_empires_ror_hd.git master
) > "$WORK/unit.out" 2>&1
assert_eq "config set/get keeps last value, allows '=' and spaces" "baz|/a b/c=d|dflt|1" "$(sed -n 1p "$WORK/unit.out")"
assert_eq "ini_set replaces, appends and keeps CRLF" "7|9|4" "$(sed -n 2p "$WORK/unit.out")"
assert_eq "registry template escapes Windows paths" '"CDPath"="C:\\Games\\AoE\\" "InstallationDirectory"="C:\\Games\\AoE" ' "$(sed -n 3p "$WORK/unit.out")"
assert_eq "balance profile lookup" "empires_definitive_edition.dat|" "$(sed -n 4p "$WORK/unit.out")"
assert_eq "github zip fallback URL" "https://codeload.github.com/hvngroup/age_of_empires_ror_hd/zip/refs/heads/master" "$(sed -n 5p "$WORK/unit.out")"

echo "== integration: fake Wine"
# shellcheck disable=SC2031  # the unit block above runs in its own subshell
export AOE_HOME="$WORK/home with space"
export AOE_WINE="$ROOT/tests/fake-wine/wine"
unset AOE_PREFIX
PREFIX="$AOE_HOME/prefix"
GAME="$PREFIX/drive_c/Games/AoE"
make_fixture "$WORK/src"
# Local stand-in for the cnc-ddraw release zip.
mkdir -p "$WORK/cnc" && echo cncdll > "$WORK/cnc/ddraw.dll" && echo ini > "$WORK/cnc/ddraw.ini"
(cd "$WORK/cnc" && zip -q ../cnc-ddraw.zip ddraw.dll ddraw.ini)
sha256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
export AOE_CNC_DDRAW_URL="file://$WORK/cnc-ddraw.zip"
export AOE_CNC_DDRAW_SHA256
AOE_CNC_DDRAW_SHA256="$(sha256 "$WORK/cnc-ddraw.zip")"

run status --quiet; assert_eq "status --quiet fails before install" "1" "$?"
run play; assert_eq "play refuses before install" "1" "$?"
run install --source "$WORK/src"; rc=$?
assert_eq "install succeeds" "0" "$rc"
[ "$rc" -eq 0 ] || cat "$WORK/out"
assert_file "game copied" "$GAME/empires.exe"
assert_file "AI scripts copied" "$GAME/data2/Default.ai"
if [ "$(uname -s)" = "Darwin" ]; then
  run display; assert_eq "macOS install defaults to cnc-ddraw" "cnc" "$(cat "$WORK/out")"
fi
if [ -e "$GAME/.git" ] || [ -e "$GAME/data2_daominah" ] || [ -e "$GAME/README.md" ]; then
  fail "repo-only files excluded"
else
  ok "repo-only files excluded"
fi
assert_contains "game registry imported" "$PREFIX/imported.reg" '"InstallationDirectory"="C:\\Games\\AoE"'
assert_contains "DirectPlay lobby registry imported" "$PREFIX/imported.reg" '"File"="EmpiresX.Exe"'
assert_contains "Mac driver settings imported" "$PREFIX/imported.reg" '"LeftCommandIsCtrl"="y"'
assert_contains "32-bit regedit used" "$PREFIX/fake-wine.log" 'syswow64\regedit.exe /S'
run status --quiet; assert_eq "status --quiet ok after install" "0" "$?"
run doctor; assert_eq "doctor reports ready" "0" "$?"

run balance de; assert_eq "balance de" "de" "$(cat "$GAME/data/empires.dat")"
run balance current; assert_eq "balance current detects de" "de" "$(cat "$WORK/out")"
run balance bogus; assert_eq "balance rejects unknown profile" "1" "$?"
run display fullscreen; assert_eq "display fullscreen" "0" "$(grep UseWindowMode "$GAME/data/wndmode.ini" | tr -d '\r' | cut -d= -f2)"
assert_eq "wndmode.ini keeps CRLF" "4" "$(grep -c $'\r$' "$GAME/data/wndmode.ini")"
run display; assert_eq "display status" "fullscreen" "$(cat "$WORK/out")"
run display native; check_not "native mode switches wndmode.dll off" test -e "$GAME/data/wndmode.dll"
run display; assert_eq "display status native" "native" "$(cat "$WORK/out")"
run play; assert_eq "native mode passes the wndmode flags to the game" "$GAME|C:\\Games\\AoE\\empires.exe nostartup systemmemory mfill" "$(tail -n 1 "$PREFIX/launches.log")"
run play single custom; assert_eq "explicit game args win over native defaults" "$GAME|C:\\Games\\AoE\\empires.exe custom" "$(tail -n 1 "$PREFIX/launches.log")"
run update; check_not "update keeps wndmode.dll off in native mode" test -e "$GAME/data/wndmode.dll"
run display windowed; assert_file "windowed mode restores wndmode.dll" "$GAME/data/wndmode.dll"
run display fullscreen
run display cnc; assert_eq "cnc mode places cnc-ddraw's ddraw.dll" "cncdll" "$(cat "$GAME/ddraw.dll" 2>/dev/null)"
assert_eq "cnc mode is borderless fullscreen" "true" "$(grep '^fullscreen=' "$GAME/ddraw.ini" | cut -d= -f2)"
assert_contains "cnc config keeps AoE's own section" "$GAME/ddraw.ini" "[empires]"
check_not "cnc mode switches wndmode.dll off" test -e "$GAME/data/wndmode.dll"
run display; assert_eq "display status cnc" "cnc" "$(cat "$WORK/out")"
run play; run logs
assert_contains "cnc mode loads ddraw.dll from the game folder" "$WORK/out" "WINEDLLOVERRIDES=ddraw=n,b"
assert_eq "cnc mode passes the wndmode flags to the game" "$GAME|C:\\Games\\AoE\\empires.exe nostartup systemmemory mfill" "$(tail -n 1 "$PREFIX/launches.log")"
assert_eq "cnc uses the GDI renderer by default" "gdi" "$(grep '^renderer=' "$GAME/ddraw.ini" | cut -d= -f2)"
run renderer opengl; assert_eq "renderer command rewrites ddraw.ini" "opengl" "$(grep '^renderer=' "$GAME/ddraw.ini" | cut -d= -f2)"
run renderer; assert_eq "renderer status" "opengl" "$(cat "$WORK/out")"
run renderer vulkan; assert_eq "renderer rejects unknown values" "1" "$?"
run renderer gdi
run display cnc-window; assert_eq "cnc-window mode is windowed" "false" "$(grep '^fullscreen=' "$GAME/ddraw.ini" | cut -d= -f2)"
run display; assert_eq "display status cnc-window" "cnc-window" "$(cat "$WORK/out")"
assert_eq "renderer choice survives display changes" "gdi" "$(grep '^renderer=' "$GAME/ddraw.ini" | cut -d= -f2)"
run update; assert_file "update keeps cnc-ddraw" "$GAME/ddraw.dll"
check_not "update keeps wndmode.dll off in cnc mode" test -e "$GAME/data/wndmode.dll"
run directplay; assert_eq "DirectPlay defaults to Wine's" "wine" "$(cat "$WORK/out")"
# Stand-in for Microsoft's DirectX redistributable: bsdtar auto-detects the
# format, so a zip holding a zip named dxnt.cab exercises the same path.
mkdir -p "$WORK/dx"
for f in dplayx.dll dpwsockx.dll dpmodemx.dll dplaysvr.exe; do echo "ms-$f" > "$WORK/dx/$f"; done
(cd "$WORK/dx" && zip -q dxnt.cab dplayx.dll dpwsockx.dll dpmodemx.dll dplaysvr.exe && zip -q ../dxredist.exe dxnt.cab)
SYS32="$PREFIX/drive_c/windows/syswow64"
echo game-dplayx > "$GAME/dplayx.dll"
AOE_DXREDIST_URL="file://$WORK/dxredist.exe" AOE_DXREDIST_SHA256="$(sha256 "$WORK/dxredist.exe")" run directplay microsoft; rc=$?
assert_eq "directplay microsoft succeeds" "0" "$rc"
[ "$rc" -eq 0 ] || cat "$WORK/out"
check_not "downloaded DirectX package is removed after extraction" ls "$AOE_HOME/cache"/directx_feb2010_redist-*.exe
assert_eq "Microsoft dplayx.dll installed in the 32-bit system folder" "ms-dplayx.dll" "$(cat "$SYS32/dplayx.dll" 2>/dev/null)"
assert_eq "Microsoft dpwsockx.dll installed" "ms-dpwsockx.dll" "$(cat "$SYS32/dpwsockx.dll" 2>/dev/null)"
assert_eq "dplaysvr.exe installed" "ms-dplaysvr.exe" "$(cat "$SYS32/dplaysvr.exe" 2>/dev/null)"
check_not "the game's lone XP dplayx.dll is switched off" test -e "$GAME/dplayx.dll"
run play multi; run logs
assert_contains "microsoft mode prefers the native DirectPlay set" "$WORK/out" "WINEDLLOVERRIDES=ddraw=n,b;dplayx=n,b;dpwsockx=n,b;dpmodemx=n,b;dplaysvr.exe=n,b"
echo wine-placeholder > "$SYS32/dplayx.dll"
run update; assert_eq "update re-applies DirectPlay without downloading again" "ms-dplayx.dll" "$(cat "$SYS32/dplayx.dll" 2>/dev/null)"
check_not "update keeps the game's dplayx.dll off" test -e "$GAME/dplayx.dll"
run directplay native; assert_eq "legacy 'native' maps to microsoft" "microsoft" "$("$AOE_MAC" directplay)"
run directplay bogus; assert_eq "directplay rejects unknown values" "1" "$?"
run directplay wine; run play multi; run logs
check_not "Wine DirectPlay sets no dplayx override" grep -q "dplayx=n,b" "$WORK/out"
assert_eq "wine mode restores the game's dplayx.dll" "game-dplayx" "$(cat "$GAME/dplayx.dll" 2>/dev/null)"
rm -rf "$SYS32"/*.aoe-mac-ms
AOE_DXREDIST_URL="file://$WORK/dxredist.exe" AOE_DXREDIST_SHA256=0000 run directplay microsoft
assert_eq "DirectX download rejected on checksum mismatch" "1" "$?"
assert_eq "failed install leaves DirectPlay on wine" "wine" "$("$AOE_MAC" directplay)"
run display fullscreen; check_not "wndmode modes switch cnc-ddraw off" test -e "$GAME/ddraw.dll"
assert_file "wndmode modes restore wndmode.dll" "$GAME/data/wndmode.dll"
run play; run logs
check_not "wndmode modes do not override ddraw" grep -q "WINEDLLOVERRIDES=ddraw" "$WORK/out"
rm -f "$AOE_HOME/cache"/cnc-ddraw-*.zip "$GAME/ddraw.dll.aoe-mac-off"
AOE_CNC_DDRAW_SHA256=0000 run display cnc; assert_eq "cnc download rejected on checksum mismatch" "1" "$?"
check_not "nothing installed after checksum mismatch" test -e "$GAME/ddraw.dll"

echo usersave > "$GAME/savegame/mine.gmx"
echo changed > "$WORK/src/data2/Default.ai"
run update; assert_eq "update succeeds" "0" "$?"
assert_eq "update pulls new files" "changed" "$(cat "$GAME/data2/Default.ai")"
assert_eq "update keeps player saves" "usersave" "$(cat "$GAME/savegame/mine.gmx")"
assert_eq "update re-applies balance" "de" "$(cat "$GAME/data/empires.dat")"
assert_eq "update re-applies display" "0" "$(grep UseWindowMode "$GAME/data/wndmode.ini" | tr -d '\r' | cut -d= -f2)"

run play single nostartup; assert_eq "play single" "0" "$?"
run play multi; assert_eq "play multi" "0" "$?"
assert_eq "game launched from its folder with args" "$GAME|C:\\Games\\AoE\\empires.exe nostartup" "$(tail -n 2 "$PREFIX/launches.log" | head -n 1)"
assert_eq "multiplayer uses EMPIRESX.EXE" "$GAME|C:\\Games\\AoE\\EMPIRESX.EXE" "$(tail -n 1 "$PREFIX/launches.log")"
FAKE_WINE_EXIT=3 run play; assert_eq "play propagates game exit code" "3" "$?"
check "game log written" ls "$AOE_HOME/logs"/game-*.log
run logs; assert_eq "logs prints the latest log" "0" "$?"
assert_contains "log records the exit code" "$WORK/out" "=== exit code: 3"
assert_contains "log header records the Wine build" "$WORK/out" "wine     : $ROOT/tests/fake-wine/wine (wine-fake-1.0)"
assert_contains "log header records the command" "$WORK/out" "command  : empires.exe"
assert_contains "Wine errors are logged by default" "$WORK/out" "WINEDEBUG=err+all,fixme-all,+loaddll"
run logs --path; check "logs --path points to a file" test -f "$(cat "$WORK/out")"
FAKE_WINE_SLEEP=30 "$AOE_MAC" play >"$WORK/out" 2>&1 &
playpid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$PREFIX/fake-game.pid" ] && break; sleep 0.5; done
assert_contains "play explains that the terminal waits for the game" "$WORK/out" "Terminal sẽ chờ đến khi bạn thoát game"
kill -TERM "$playpid"; wait "$playpid"; rc=$?
assert_eq "stopping a hung game exits with 130" "130" "$rc"
assert_contains "stopping kills the game's Wine processes" "$PREFIX/wineserver.log" "killed"
run logs; assert_contains "log records the stop" "$WORK/out" "=== stopped by user"
FAKE_WINE_SLEEP=30 "$AOE_MAC" play >/dev/null 2>&1 &
playpid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$PREFIX/fake-game.pid" ] && break; sleep 0.5; done
run stop; assert_eq "aoe-mac stop succeeds" "0" "$?"
wait "$playpid"; rc=$?
assert_eq "aoe-mac stop ends a running game" "0" "$([ "$rc" -ne 0 ] && echo 0 || echo "rc=$rc")"

echo "== build-app"
run build-app --output "$WORK/apps"; assert_eq "build-app succeeds" "0" "$?"
APP="$WORK/apps/AoE RoR.app"
assert_file "launcher present" "$APP/Contents/MacOS/aoe-launcher"
check "launcher executable" test -x "$APP/Contents/MacOS/aoe-launcher"
assert_file "toolkit embedded" "$APP/Contents/Resources/toolkit/lib/game.sh"
assert_file "setup.command present" "$APP/Contents/Resources/toolkit/setup.command"
assert_contains "Info.plist executable" "$APP/Contents/Info.plist" "<string>aoe-launcher</string>"
assert_contains "Info.plist version" "$APP/Contents/Info.plist" "<string>$(cat "$ROOT/VERSION")</string>"
if command -v plutil >/dev/null 2>&1; then
  check "Info.plist lint" plutil -lint "$APP/Contents/Info.plist"
fi
check "embedded toolkit sees the install" "$APP/Contents/Resources/toolkit/aoe-mac" status --quiet
check "launcher syntax" bash -n "$APP/Contents/MacOS/aoe-launcher"

echo "== launcher menu (fake osascript)"
export FAKE_OSA_LOG="$WORK/osa.log" FAKE_OSA_REPLIES="$WORK/osa.replies"
launch() { : > "$FAKE_OSA_LOG"; : > "$FAKE_OSA_LOG.scripts"; printf '%s\n' "$@" > "$FAKE_OSA_REPLIES"
  PATH="$ROOT/tests/fake-osascript:$PATH" "$APP/Contents/MacOS/aoe-launcher" >/dev/null 2>&1; }
launch 3 2; assert_eq "menu > balance > de switches profile" "de" "$(cat "$GAME/data/empires.dat")"
assert_contains "Vietnamese menu text passed intact as an argument" "$FAKE_OSA_LOG" "arg:Đổi bản cân bằng..."
assert_contains "Vietnamese prompt passed intact" "$FAKE_OSA_LOG" "arg:Chọn chế độ"
assert_contains "confirmation dialog text intact" "$FAKE_OSA_LOG" "arg:Đã chuyển sang bản cân bằng: de"
assert_eq "AppleScript sources are ASCII-only" "0" "$(LC_ALL=C tr -d '\000-\177' < "$FAKE_OSA_LOG.scripts" | wc -c | tr -d ' ')"
check_not "launcher never passes text through 'system attribute'" grep -q "(system attribute" "$APP/Contents/MacOS/aoe-launcher"
before="$(wc -l < "$PREFIX/launches.log")"
launch 0; assert_eq "cancelling the menu launches nothing" "$before" "$(wc -l < "$PREFIX/launches.log")"
FAKE_WINE_EXIT=5 launch 1 no; assert_contains "crash dialog shows the exit code" "$FAKE_OSA_LOG" "arg:Game thoát bất thường (mã 5). Mở file log để gửi bộ phận kỹ thuật?"
launch 1; assert_eq "menu > single player launches empires.exe" "$GAME|C:\\Games\\AoE\\empires.exe" "$(tail -n 1 "$PREFIX/launches.log")"

echo "== uninstall"
AOE_PREFIX="/tmp/not-aoe-$$" run uninstall -y; assert_eq "uninstall refuses prefix outside AOE_HOME" "1" "$?"
run uninstall -y; assert_eq "uninstall succeeds" "0" "$?"
check_not "prefix removed" test -e "$PREFIX"
run uninstall --all -y; check_not "uninstall --all removes data root" test -e "$AOE_HOME"

if [ "${AOE_TEST_REAL_WINE:-0}" = "1" ]; then
  echo "== integration: real Wine"
  unset AOE_WINE
  export AOE_HOME="$WORK/real"
  run install --source "${AOE_TEST_GAME_SOURCE:-$WORK/src}"; rc=$?
  assert_eq "real Wine install" "0" "$rc"
  [ "$rc" -eq 0 ] || cat "$WORK/out"
  run doctor; rc=$?
  assert_eq "real Wine registry visible to 32-bit apps" "0" "$rc"
  [ "$rc" -eq 0 ] || cat "$WORK/out"
fi

echo
echo "Kết quả: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
