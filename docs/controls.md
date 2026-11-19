# Controls

Default: DRAW, cursor (7,7), NORTH, PEN DOWN, normalized preprocessing.

- One detent rotates direction 45 degrees: N NE E SE S SW W NW.
- Click advances one cell, clamped to 0..15. PEN DOWN draws; PEN UP only moves.
- Hold 700ms opens the menu once. Rotate selects; click confirms.
- RESUME returns to the retained drawing; PEN UP-DOWN toggles pen state.
- UNDO restores the previous bitmap and cursor once (32-byte bitmap history).
- PREDICT requests inference immediately. Changed drawings also predict after
  600ms idle; rotation/cursor overlays never become input pixels.
- CLEAR resets drawing, undo and result. No double click or continuous drawing.
- SAMPLE loads either bundled validation vector (original indices 0 and 7).
  Rotate changes sample; click opens INSPECT; hold opens menu. PASS means every
  logit matched the model's host reference, not that a ground-truth label is known.
- INSPECT shows ten raw logits, min/max relative bars, prediction, margin and
  inference microseconds. Rotate selects an output, click returns to DRAW.
  Equal logits make empty bars; logits and margins are not probabilities.
- -Dtrace=true adds the actual 32 hidden activations (8x4); the default omits them.
  -Ddiagnostic=true disables encoder acquisition, preserves SWIO and boots SAMPLE.

No results are shown for an empty canvas. Sample browsing preserves the drawing,
but returning to DRAW invalidates the SAMPLE prediction and schedules the retained
drawing as appropriate. Inference timing is displayed as -- until hardware supplies
it; a host PBM has no fabricated device timing.
