# Final-ELF memory budget

Measured by the existing Zinn addMemoryCheck on the final linked ELF, Zig 0.17.0
`.small`, CH32V003 RV32EC. Flash capacity 16,384B; 64B reserved by the HAL
linker, usable limit 16,320B. SRAM capacity 2,048B.

| Configuration | Flash B | Static SRAM B | Main + ISR allowance B | RAM margin B |
|---|---:|---:|---:|---:|
| ssd1306 | 16,060 | 668 | 512 + 128 | 740 |
| ssd1309 | 15,760 | 668 | 512 + 128 | 740 |
| ssd1315 | 16,060 | 668 | 512 + 128 | 740 |
| sh1106 | 15,736 | 668 | 512 + 128 | 740 |
| trace | 16,316 | 712 | 512 + 128 | 696 |
| diagnostic | 15,896 | 756 | 512 + 128 | 652 |
| antialiased | 16,152 | 668 | 512 + 128 | 740 |

Current DRAW revision: [cross-build-sizes.json](cross-build-sizes.json).
Initial milestone sizes are preserved in [cross-build-sizes-initial.json](cross-build-sizes-initial.json).
The immediate input-polling baseline was 14,208B Flash / 620B static SRAM.
Current default is 16,060B / 668B: +1,852B / +48B. The 1KB Flash growth target was
not met; the model remains MLP32 int4. Both physical limits and the 64B Flash
reservation remain enforced. There are 260B of usable Flash left in the default
and only 4B with Trace; these are tight budgets, not spare capacity guarantees.

Full DRAW + Trace + benchmark exceeds Flash and is rejected. For nine-run timing
and stack-watermark preparation, use `-Ddiagnostic=true -Dtrace=true -Dbenchmark=true`.
This retains SAMPLE/INSPECT, disables input and preserves SWIO. This combined-option
restriction is a regression relative to the smaller UI and remains a limitation.
No budget was increased and no smaller model was substituted. Int8 whole-app
linking remains rejected; host int8 golden verification still passes.

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
is main.main at 224B; text rendering uses 76B, page transfer 72B, and the Dense
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
