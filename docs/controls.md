# Controls

[日本語](controls_ja.md) · [DRAW screenshots and verification](draw-ui.md)

Default: DRAW, cursor (7,7), NORTH, PEN DOWN, normalized preprocessing.

| Input | DRAW action |
|---|---|
| Rotate, button released | Turn the direction by 45 degrees |
| Short click | Advance one cell |
| Hold and rotate positive / negative | Advance / move backwards without turning |
| Hold 700ms without rotation | Open or close MENU |

The decoder reports one event per complete four-edge quadrature cycle. Physical direction and
steps per detent depend on wiring/encoder type and require device verification.
With PEN DOWN the path is drawn; PEN UP moves only the cursor. Coordinates clamp
at the canvas edge. A click is one UNDO operation; all moves in one held gesture
share one UNDO snapshot. Opposite rotations are processed in order, not cancelled.

Held rotation consumes the click and long press. Release never adds an extra
step. Once a long press opens MENU, further rotation during that press selects
menu items; it cannot draw. Debounce is 20ms: uncertain boundary rotations and
partial quadrature steps are discarded instead of assigned to the wrong gesture.

MENU keeps RESUME, PEN UP/DOWN, UNDO, PREDICT, CLEAR, SAMPLE and INSPECT. The selected
row is inverted. The PEN item names the next action. Long press closes MENU without
changing the retained mode/canvas/result. CLEAR remains immediate, with no new
confirmation workflow. RESUME explicitly returns to DRAW.

The left 48×48 image is the 16×16 bitmap at 3× scale. The square cursor and 8-way
arrow are display overlays, never model input. At an outward boundary, the arrow
finishes at the cursor, retaining its head within the canvas area. A filled/hollow
circle indicates PEN DOWN/UP. The right side contains only prediction information:
`--` for empty, three dots for pending input, or a 5×7 digit enlarged to 20×28px.

Only changes to bitmap pixels invalidate prediction. Direction, pen toggling,
PEN UP motion, blocked edge motion and redrawing existing ink keep the result.
Automatic inference waits 100ms after the last bitmap change and until a held
stroke is released. PREDICT still requests an immediate inference outside MENU.
SAMPLE inputs remain the two bundled validation vectors (original indices 0 and
7): rotate browses, click opens INSPECT. INSPECT rotates its selected output and
click returns to the retained drawing. PASS means all reference logits match,
not ground-truth classification accuracy. Logits and margins are not probabilities.
`-Dtrace=true` adds actual hidden activations; no fake timing is shown in host PBMs.

## Input scheduling and limits

The current firmware polls GPIO; it does not use encoder EXTI. Main and each 6ms
window after a page transfer sample the encoder and button together. A four-record
queue stores semantic events and 32-bit acquisition times. App changes are applied
only after the immutable eight-page picture loop. No framebuffer/history is added.

If the queue fills, queued events are discarded and the gesture is ended; `lost`
in the metrics increments. A held gesture is suppressed until release. Unheld
rotation recovers after the queue drains. This intentionally loses excessive input
rather than inventing clicks, reordering direction changes or leaving inference
permanently blocked. Gaps during I2C/render/inference and very fast motion can still
lose physical edges. This is not a loss-free input claim.
