#!/bin/sh
set -eu
bin=${1:-zig-out/firmware/firmware.bin}
[ -f "$bin" ] || { echo "Build first: zig build" >&2; exit 1; }
echo "J4M6: disconnect Encoder B from shared PD5/PD1 lead 8 before programming." >&2
if [ -n "${MINICHLINK:-}" ]; then exec "$MINICHLINK" -w "$bin" flash -b; fi
if command -v minichlink >/dev/null 2>&1; then exec minichlink -w "$bin" flash -b; fi
if command -v chzig >/dev/null 2>&1; then exec chzig minichlink -w "$bin" flash -b; fi
echo "Install minichlink/chzig or set MINICHLINK=/path/to/minichlink" >&2
exit 1
