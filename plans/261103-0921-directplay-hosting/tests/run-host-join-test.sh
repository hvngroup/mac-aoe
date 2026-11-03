#!/bin/bash
# Run the dphost/dpjoin acceptance test under the system Wine with a freshly built
# dpwsockx.dll/dplayx.dll pair placed next to the test executables.
#
# Usage: run-host-join-test.sh <dll-dir> <out-dir> [joiner-ip]
#   <dll-dir>  directory holding dpwsockx.dll and dplayx.dll (i386 PE)
#   <out-dir>  where the logs are written (host.log, join.log)
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DLL_DIR="$1"
OUT_DIR="$2"
JOIN_IP="${3:-}"
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

[ -d "$WINEPREFIX" ] || wineboot -i > "$OUT_DIR/wineboot.log" 2>&1
wineserver -p 30

cd "$RUN_DIR"
wine dphost.exe 40 > "$OUT_DIR/host.log" 2> "$OUT_DIR/host.trace" &
HOST_PID=$!
for i in $(seq 1 100); do
    grep -q "READY\|FAIL" "$OUT_DIR/host.log" 2>/dev/null && break
    sleep 0.2
done
if grep -q READY "$OUT_DIR/host.log"; then
    wine dpjoin.exe $JOIN_IP > "$OUT_DIR/join.log" 2> "$OUT_DIR/join.trace"
    JOIN_RC=$?
else
    echo "host never became ready" > "$OUT_DIR/join.log"
    JOIN_RC=99
fi
wait $HOST_PID
HOST_RC=$?
wineserver -k
echo "host rc=$HOST_RC join rc=$JOIN_RC"
echo "===== host.log"; cat "$OUT_DIR/host.log"
echo "===== join.log"; cat "$OUT_DIR/join.log"
[ $HOST_RC -eq 0 ] && [ $JOIN_RC -eq 0 ]
