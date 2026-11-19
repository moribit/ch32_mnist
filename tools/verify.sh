#!/bin/sh
set -eu
z=${ZIG:-zig}
"$z" fmt --check build.zig build.zig.zon src tools/export.zig
for model in mlp32-int4 mlp32-int8; do
 for optimize in debug safe; do "$z" build test -Dmodel="$model" -Dtest-optimize="$optimize"; done
done
"$z" build
"$z" build size
for controller in ssd1306 ssd1309 ssd1315 sh1106; do "$z" build -Ddisplay="$controller" --prefix "zig-out/$controller"; done
"$z" build -Dtrace=true -Dbenchmark=true --prefix zig-out/benchmark
"$z" build -Dtrace=true -Dbenchmark=true -Ddiagnostic=true --prefix zig-out/diagnostic
"$z" build -Dpreprocess=antialiased --prefix zig-out/antialiased
"$z" build export-model
cmp models/mnist-int4.zig zig-out/models/regenerated-int4.zig
"$z" build simulate -- sample zig-out/sample.pbm
"$z" build simulate -- inspect zig-out/inspect.pbm
if "$z" build -Dflash-bytes=1024 > zig-out/rejected-flash.log 2>&1; then echo "Flash limit was not enforced" >&2; exit 1; fi
if "$z" build -Dram-bytes=1024 > zig-out/rejected-ram.log 2>&1; then echo "RAM limit was not enforced" >&2; exit 1; fi
if "$z" build -Dmodel=unknown > zig-out/rejected-option.log 2>&1; then echo "Bad model was not rejected" >&2; exit 1; fi
if "$z" build -Ddisplay=unknown > zig-out/rejected-display.log 2>&1; then echo "Bad display was not rejected" >&2; exit 1; fi
# Restore the default installed firmware after alternative configurations.
"$z" build
printf '%s\n' 'Verified host tests, OLED variants, diagnostic/benchmark builds, reproducible export, snapshots and budget rejection.'
