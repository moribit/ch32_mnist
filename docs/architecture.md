# Architecture and source audit

The original repositories were read without modification. Local Mopping_rotaly
has an uncommitted main.zig change; this project deliberately does not overwrite
or copy its game. Only its hardware choices and standard Gray-code decoder design
were used as references. Its old Build script uses an application-owned reset;
this project uses the current ch32fun_zig public addFirmware API with the complete
memory-init / compact EXTI-only runtime.

| Dependency / reference | Revision reviewed |
|---|---|
| Zinn | 6e9a53fb314ff2bf6ff8b4e3860255fcd7003307 |
| ch32fun_zig | d6524ff375684e127b0d4ae68c0e47b0a8c7823b |
| Mopping_rotaly | 2f3080211436afd896703b71e79eb44657f41859 |
| mimoc-ui | 5486c9cc4d7a67eeb3c385dee836a2081d112322 |

These match the public main revisions inspected on 2026-11-19. Dependencies use
local sibling packages; checkout these revisions for reproduction. There is no
remote repository creation, push or modification of an upstream project.

## Separation

- input.zig: deterministic quadrature and debounced button state machines.
- canvas.zig: 32-byte bitmap, bounds, brush/lines, eight-way Turtle.
- preprocess.zig: integer direct/centering/normalization/4x4 coverage sampling;
  quantization endpoints computed at compile time from model scale/zero point.
- app.zig: host-testable DRAW/SAMPLE/INSPECT and menu/undo/dirty state.
- ui.zig: independent tiny 3x5 font and pure pixel drawing to a generic sink.
- main.zig: HAL, IRQ collection, clocks, picture loop and cycle measurements.
- simulate.zig + sim_surface.zig: host-only 1024-byte framebuffer, PBM and CSV.
- models/mnist-int4.zig: unedited output of the Zinn exporter. No kernel copies.

Zinn is consumed through addInferenceModule, Sequential.infer/inferTraced and
addMemoryCheck. addModel was reviewed but is unnecessary for a frozen checkpoint;
tools/export.zig uses the public Trainer/QuantizedFormat export API instead.
Normal builds use the committed int4 source and do not run training or export.
The int8 model is imported directly from the pinned Zinn example. Host tools are
compiled for the host; firmware model/core modules use the CH32 target.

mimoc-ui was considered and not included: a full widget runtime is unnecessary on
128x64, and the existing HAL supplies the page transfer/drawPixel API. The font
and renderer here are original small application code, not a second ML runtime.

## Scheduling / ownership

Encoder PA2/PD5 is polled from main, matching Mopping_rotaly. Two valid
Gray-code edges produce a rotation event; bounce/reversal cancels pending phase
and invalid transitions reset it. Events are accumulated with a saturating
counter and applied outside the OLED picture loop. No encoder IRQ is enabled.
After each 128-byte page transfer, a 6ms fast polling window captures input while
App remains immutable. There are still gaps during rendering, I2C and inference;
fast rotation can lose edges and requires hardware evaluation. Electrical
direction and events per physical detent depend on the encoder and A/B wiring.

Button polling uses main, 20ms debounce and 700ms long press. A long press is
emitted once, with no release click. Its maximum sampling gap includes the OLED
picture loop and inference; very short presses can be missed. This remains a
physical validation item rather than a claimed loss-free design.

The OLED driver really supports .page, firstPage/nextPage/writePage. Exactly one
128-byte hardware-page buffer is used. Eight pages are redrawn from the same
immutable App state. Polling windows do not mutate App. Dirty updates only; no cursor blink,
idle bus traffic or per-frame inference. I2C is configured to 400kHz. SSD1315 uses
the SSD1306-compatible command path; SH1106 uses its actual +2-column/page handling.
SSD1309 uses its native initialization plus oscillator/VCOM adjustments.

SysTick is a free-running 48MHz counter, not a periodic sampling ISR. Main extends
wrapping cycle deltas into a wrapping millisecond clock, requiring at least one
main iteration per 2^32 cycles (~89s). Button and dirty timers use wrapping subtraction.
IRQ nesting/HPE are disabled by the supplied compact runtime; software entry saves
64 bytes before the EXTI handler. No heap, recursion, float inference, UART, HTTP,
training state or full grayscale canvas exists in firmware.
