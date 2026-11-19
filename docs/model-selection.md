# Model selection

The desktop MLP32 int8 was tried first. The complete application currently exceeds
the HAL linker Flash region by about 2.4KB; it remains available for host golden
checks and fails clearly on an oversized firmware build. Page buffering and
removal of unused preprocessing paths were applied before choosing int4.

Default: 256 -> 32 ReLU -> 10, packed int4 weights, int8 activations, int32 sums.
The same frozen MLP32 checkpoint is used; no training or hand-edited weights.
MLP16 variants were not added because MLP32 int4 fits. Unsupported names are errors.

The int4 calibration uses the 16 quantized validation fixtures already distributed
with Zinn, dequantized using the original scale. Targets are unused for calibration.
This tiny demo calibration is reproducible and does not require MNIST download,
but it is NOT the earlier 1024-training-sample calibration and must not inherit
its official benchmark accuracy. No final-test set was evaluated or used here.
The original int8 snapshot records 95.14% validation accuracy; the benchmark's
96.59% official-test figure belongs to a separately frozen export.

Two reference inputs (original indices 0,7) and their matching expected logits are
retained in firmware; other verification fixtures are eliminated by dead-code
removal. All 16 are checked by host tests. No ground-truth label is claimed for
the two bundled images. Model metadata, hashes and commands are in
[PROVENANCE](../models/PROVENANCE.md).

## Preprocessing comparison

Four methods are built from the same integer code:

- direct: original 16x16 position; binary zero/white endpoints.
- centered: translate bounding box to center, no resizing.
- normalized (default): preserve aspect ratio, fit inside 12x12, center; nearest.
- antialiased: the same fit, with deterministic 4x4 subpixel coverage sampling.

No 112x112 canvas or 28x28 float array is allocated. Desktop preprocessing instead
fits 20x20 inside 28x28 and centers by mass, followed by area resize to 16x16.
This firmware approximation is not numerically identical to that pipeline.

CSV reproduction: zig build simulate; choose -Dmodel=mlp32-int8 for the baseline.
The simulator replays seven-segment strokes through the actual Turtle, including
pen-up travel, and evaluates ten digits in base/shifted/thick variants. These are
30 deterministic synthetic styles, not a human handwriting accuracy study.
The comparison tables and raw CSV are in [verification](verification-report.md).
Small/real handwritten digits and a physical encoder dataset still need collection;
no fine-tuning is performed and no general accuracy claim follows from these fixtures.
