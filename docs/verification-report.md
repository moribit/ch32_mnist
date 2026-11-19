# Verification report — 2026-11-19

## Completed and checked

- External Zinn inference and ch32fun_zig addFirmware/page OLED/EXTI integration.
- DRAW, two-reference SAMPLE, INSPECT, menu, one-level undo and dirty inference.
- 16x16 one-bit canvas, eight-way clamped Turtle, integer preprocessing A-D.
- Every one of the 16 generated sample logits matches the compiled inference
  for int8 and int4; ordinary and traced outputs also match exactly.
- Nine grouped host tests pass for each model in Debug and ReleaseSafe (macOS).
  Tests cover phase decoding/bounce/invalid edges, debounce/long-press/wrap,
  canvas/brush/bounds/lines, Turtle edges, translation/coverage/blank input,
  menu/source/undo transitions, references, idle scheduling and UI buffer bounds.
- All four OLED controller paths, optional Trace/benchmark/diagnostic and AA
  preprocessing cross-build. Final ELF passes the budgets in memory-budget.md.
- Deliberate Flash/RAM over-budget and invalid model/display options are rejected.
- Re-exporting int4 produces byte-identical generated source; no training occurs.
- Host simulator writes PBM snapshots and deterministic preprocessing CSV.

Re-run the full local suite with ZIG=zig sh tools/verify.sh. Firmware is always
ReleaseSmall by default; host test safety is selected with -Dtest-optimize.
Linux runtime testing is not performed here; hardware-free code uses portable
Zig standard APIs and is structured for the same test commands on Linux.
No GitHub remote, repository creation, push or CI run is part of this project.

## Sample / MCU comparison mechanism

zig build simulate -- golden prints all ten expected host logits. Model ID
3905268145, firmware sample indices 0 and 1 (upstream validation indices 0,7):

```text
0: -41,29,-17,123,-58,48,-103,-10,39,-4        prediction 3
1: -20,-39,17,60,-62,-11,-112,114,-12,30     prediction 7
```

Firmware compares every output to these frozen expected values and displays
PASS/FAIL. In -Ddiagnostic=true -Dbenchmark=true -Dtrace=true, Encoder B must be
isolated, SWIO remains enabled, encoder IRQs are disabled and SAMPLE 0 runs.
The exported mnist_metrics contains model ID, logits, reference_ok, timer overhead,
min/median/max cycles, preprocessing/render/transfer cycles, invalid/lost input
counts and conservative stack watermark. Compare this block through a debugger
with the host golden output. No runtime communication service is required.

Only the cross-compilation of this mechanism is verified. MCU execution and
Host/MCU observed logit equality are **not yet verified**. Normal firmware also
works without a debugger and releases SWIO after its startup grace interval.

## Timing protocol (not yet measured)

Single inference timing excludes preprocessing and OLED transfer. Optional
benchmark reuses Zinn benchmark.measure: timer-read overhead, one untimed warm-up,
nine samples, sorted min/median/max after overhead subtraction. Encoder IRQs may
run during normal benchmark samples: this is real application latency, not an
interrupt-free kernel measurement. Diagnostic mode measures with encoder off.
At the configured 48MHz, microseconds are cycles/48. Results remain -- in host
snapshots instead of fabricated device timings.

Preprocessing and UI rendering / I2C transfers are measured separately. OLED
page rendering sums eight page-generation intervals; transfer sums the eight
nextPage calls. Full page-loop latency and button sampling gaps must also be
measured on hardware. Blank input skips inference. No frame-loop repeated NN calls.

| Physical observation | Status |
|---|---|
| OLED SSD1306/1309/1315/SH1106 | Not tested |
| PA2/PD5 encoder and PC4 button | Not tested |
| Inference min/median/max | Unmeasured |
| Preprocessing / display render / transfer time | Unmeasured |
| Stack high-water including encoder IRQ | Unmeasured |
| Encoder input loss / button minimum press length | Unmeasured |
| Actual rotary-drawn recognition | Not evaluated |

USB inventory found Espressif JTAG/serial hardware (303a:1001), not a CH32 probe.
No flash/write was attempted; the existing device and other repositories were
left untouched. See wiring.md for the shared PD5/PD1/SWIO package lead.

## Recognition-quality limits

Seven-segment synthetic digits 0-9 were replayed through the actual Turtle and
App events, in base / translated / thick-stroke variants. They are a small
regression set with known intended digit, not representative handwritten MNIST.

| Preprocessing | int8 intended-digit matches /30 | int4 /30 |
|---|---:|---:|
| Direct | 7 | 7 |
| Centered | 10 | 7 |
| Normalized | 6 | 6 |
| 4x4 coverage AA | 8 | 9 |

Raw data: [int8](preprocessing-int8.csv), [int4](preprocessing-int4.csv).
Performance is poor on these stylized inputs; successful deployment/Golden matching
must not be presented as good handwriting accuracy. Normalized remains a simple
provisional scaling baseline; AA is selectable, but 30 artificial cases are not
sufficient to tune a production recognizer. Small/real handwriting, line-width
and physical Turtle datasets need broader collection before calibration changes
or fine-tuning. The earlier official MNIST benchmark accuracy does not apply to
this new int4 calibration or rotary input distribution.

## Artifact identity

```text
Zinn checkpoint model.zinn SHA256:
1b3e3746e02191bdeed9f0d8c80dcc97d5813d283eaa9d687ee3589905d4a2df
models/mnist-int4.zig SHA256:
ad49fcf46ea226e7727ff4b912001cb24ba12efc7f458b1a7ffb9a19e7b7bfa1
```

## Remaining work

Connect the specified J4M6/OLED/encoder with a removable B jumper and CH32 probe;
first run the SWIO-preserving diagnostic SAMPLE, record every logit and all
measurements, then test the normal encoder firmware and controller variants.
Verify stack/IRQ margin and input capture at worst-case rotation. Collect actual
drawn digits, compare preprocessing on held-out device inputs, then consider a
larger representative calibration set. MLP16 fallback, continuous drawing, a GUI
simulator and physical Linux test execution were not added.
