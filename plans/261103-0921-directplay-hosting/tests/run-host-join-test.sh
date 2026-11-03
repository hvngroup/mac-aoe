#!/bin/bash
# Run the dphost/dpjoin acceptance test under the system Wine with a freshly built
# dpwsockx.dll/dplayx.dll pair placed next to the test executables.
#
# Usage: run-host-join-test.sh <dll-dir> <out-dir> [joiners]
#   <dll-dir>  directory holding dpwsockx.dll and dplayx.dll (i386 PE)
#   <out-dir>  where the logs are written (host.log, join1.log, ...; *.trace = WINEDEBUG output)
#   [joiners]  1 (default) or 2; with 2 the first joiner stays in the session while the second
#              joins, and the two joiners exchange a message directly
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DLL_DIR="$1"
OUT_DIR="$2"
JOINERS="${3:-1}"
RUN_DIR="$OUT_DIR/run"
export WINEPREFIX="${WINEPREFIX:-/home/user/wine-build/prefix}"
export WINEDLLOVERRIDES="dpwsockx,dplayx=n,b"
export WINEDEBUG="${WINEDEBUG:-err+all,fixme-all,+dplay}"

mkdir -p "$RUN_DIR"
for f in dphost dpjoin; do
    i686-w64-mingw32-gcc -O1 -Wall -o "$RUN_DIR/$f.exe" "$TESTS_DIR/$f.c" \
        -ldplayx -ldxguid -lole32 -luuid || exit 2
done
cp "$DLL_DIR/dpwsockx.dll" "$DLL_DIR/dplayx.dll" "$RUN_DIR/"
# Wine replaces a DLL carrying the "Wine builtin DLL" marker by the system builtin of the
# same name, so blank the marker to make the loader use these copies as native DLLs.
for f in dpwsockx.dll dplayx.dll; do
    printf '\0%.0s' $(seq 1 16) | dd of="$RUN_DIR/$f" bs=1 seek=64 conv=notrunc status=none
done

[ -d "$WINEPREFIX" ] || wineboot -i > "$OUT_DIR/wineboot.log" 2>&1
wineserver -p 30

cd "$RUN_DIR"
wine dphost.exe 90 "$JOINERS" > "$OUT_DIR/host.log" 2> "$OUT_DIR/host.trace" &
HOST_PID=$!
for i in $(seq 1 100); do
    grep -q "READY\|FAIL" "$OUT_DIR/host.log" 2>/dev/null && break
    sleep 0.2
done

JOIN_RC=0
if ! grep -q READY "$OUT_DIR/host.log"; then
    echo "host never became ready" > "$OUT_DIR/join1.log"
    JOIN_RC=99
elif [ "$JOINERS" = 2 ]; then
    wine dpjoin.exe JoinPlayer1 20 > "$OUT_DIR/join1.log" 2> "$OUT_DIR/join1.trace" &
    J1_PID=$!
    for i in $(seq 1 150); do
        grep -q "joiner received host reply\|RESULT" "$OUT_DIR/join1.log" 2>/dev/null && break
        sleep 0.2
    done
    wine dpjoin.exe JoinPlayer2 0 > "$OUT_DIR/join2.log" 2> "$OUT_DIR/join2.trace"
    J2_RC=$?
    wait $J1_PID
    J1_RC=$?
    JOIN_RC=$((J1_RC + J2_RC))
else
    wine dpjoin.exe JoinPlayer 0 > "$OUT_DIR/join1.log" 2> "$OUT_DIR/join1.trace"
    JOIN_RC=$?
fi
wait $HOST_PID
HOST_RC=$?
wineserver -k
echo "host rc=$HOST_RC join rc=$JOIN_RC"
for f in host join1 join2; do
    [ -f "$OUT_DIR/$f.log" ] && { echo "===== $f.log"; cat "$OUT_DIR/$f.log"; }
done
[ $HOST_RC -eq 0 ] && [ $JOIN_RC -eq 0 ]
