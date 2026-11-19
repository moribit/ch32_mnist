# Final-ELF memory budget

Measured by the existing Zinn addMemoryCheck on the final linked ELF, Zig 0.17.0
ReleaseSmall, CH32V003 RV32EC. Flash capacity 16,384B; 64B reserved by the HAL
linker, usable limit 16,320B. SRAM capacity 2,048B.

| Configuration | Flash B | Static SRAM B | Main + ISR allowance B | RAM margin B |
|---|---:|---:|---:|---:|
| SSD1306 / default | 14,480 | 652 | 512 + 128 | 756 |
| SSD1309 | 14,284 | 652 | 512 + 128 | 756 |
| SSD1315 | 14,480 | 652 | 512 + 128 | 756 |
| SH1106 | 14,296 | 652 | 512 + 128 | 756 |
| Trace + nine-run benchmark / encoder active | 15,096 | 740 | 512 + 128 | 668 |
| SWIO diagnostic + Trace + benchmark / encoder off | 14,392 | 704 | 512 + 128 | 704 |
| Antialiased preprocessing | 14,572 | 652 | 512 + 128 | 756 |

Machine-readable evidence: [cross-build-sizes.json](cross-build-sizes.json).
These are cross-built sizes, not hardware measurements. Int8 whole-app linking
is rejected (about 2.4KB above available Flash); no silent int4 fallback occurs
when explicitly requesting int8. The normal default is explicitly int4.

The budget checker covers every load segment, Flash load addresses for .data,
RAM placement and initialized/BSS statics, and rejects out-of-region placement.
A 1,024B Flash or SRAM override must fail; tools/verify.sh tests both.

## Static ownership

- One 128B OLED page buffer; no 1024B framebuffer in firmware.
- 32B drawing bitmap + 32B one-operation undo bitmap.
- 256B quantized input, 32B workspace, 10B output.
- App/input/HAL state and an exported hardware-metrics block, counted in the ELF.
- Optional Trace 42B (32 hidden + 10 final) and 9-sample benchmark buffer.
- No training checkpoint, host dataset, dynamic graph or allocator.

Two firmware fixture inputs occupy 512B of read-only Flash, with 20B expected
logits; the other verification fixtures are not emitted. Assembly confirms one
512B fixture constant and one 4096B packed first-layer weight constant.
The 1024B host PBM buffer lives only in the simulator executable.

## Stack caveat

512B main and 128B ISR are separate allowances. The compact EXTI entry explicitly
saves 64B; handler/callee usage must fit the remaining ISR allowance. It does not
use nested interrupts or HPE. The largest emitted default single function frame
is main.main at 192B; text rendering/page transfer use 72B frames and the Dense
kernel has a 64B frame. No observed single emitted frame exceeds 256B. This is
NOT a proven whole call-chain bound, and no stack high-water has been measured.

Reproduce assembly with zig build assembly (zig-out/reports/firmware.s). In
-Dbenchmark=true, the optional watermark fills only unused SRAM below the current
SP minus a 128B live-stack guard, after BSS and before starting encoder polling.
The exported stack_upper is a conservative watermark observation including that
guard. Scanning briefly masks IRQs; timing/overflow testing must acknowledge this
benchmark-only perturbation. Neither the code nor these reservations establish
physical memory safety without worst-case hardware high-water testing.

## Rotary polling revision

The default SSD1306 build after matching Mopping_rotaly input polling uses
14,208 B Flash and 620 B static SRAM. The unchanged 512 B main + 128 B ISR
allowance leaves 788 B RAM margin. The encoder no longer enables EXTI interrupts;
the conservative ISR allowance is retained. Older assembly sizes above are
historical observations, not a new whole-stack bound. Hardware rotation response
and stack high-water remain unverified for this revision.
