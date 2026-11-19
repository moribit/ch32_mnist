# Frozen model provenance

Zinn revision: 6e9a53fb314ff2bf6ff8b4e3860255fcd7003307.
Source checkpoint: examples/mnist-desktop/assets/model.zinn, schema/checkpoint v1,
MLP 256 -> 32 ReLU -> 10. Seed 42; fitting 55,000 and validation 5,000 from official
MNIST training data; split seed 24301; SGD/Cross Entropy, batch 32, lr 0.1,
20-epoch maximum with 10-epoch x0.3 decay; best epoch 13. See the upstream
[provenance](https://github.com/moribit/zinn/blob/6e9a53fb314ff2bf6ff8b4e3860255fcd7003307/examples/mnist-desktop/assets/PROVENANCE.md).

Original int8: model ID 2368000046; parameters 8,680B, workspace 32B;
input_scale 1/127, input_zero 0. Original export validation int8 4757/5000
(95.14%), not a physical rotary handwriting accuracy measurement.

Bundled packed int4: model ID 3905268145; parameters 4,424B; workspace 32B;
input_scale 1/127, input_zero 0. Same float checkpoint, Zinn QuantizedFormat
calibration on the 16 existing dequantized validation fixtures. This deliberately
small calibration set supports offline reproduction, not an accuracy claim.
Output/hidden scales and requantization coefficients remain in generated source.
No packed weight nibble, bias or expected logit is hand-edited.

```sh
zig build export-model
cmp models/mnist-int4.zig zig-out/models/regenerated-int4.zig
zig build -Dregenerate-model=true
# Only if deliberately updating committed generated source:
zig build refresh-model
```

Normal builds use models/mnist-int4.zig directly and require no training, dataset
fetch or exporter execution. Int8 builds import the original generated source
from Zinn. Two firmware samples are original validation indices 0 and 7; host tests
check all 16. No ground-truth labels are supplied, so UI displays reference PASS
rather than claiming label accuracy. MNIST originated with Yann LeCun, Corinna
Cortes and Christopher Burges; source mirror: https://github.com/cvdfoundation/mnist.

Artifact SHA-256 hashes are in the verification report. The checkpoint is not
copied into firmware or duplicated in this repository; obtain it with the exact
Zinn revision above. Project code and Zinn/ch32fun_zig have separate MIT notices.
