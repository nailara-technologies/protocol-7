#!/usr/bin/env python3
## verify_checkpoint.py -- structural verification of the dequantized     ##
## checkpoint : every param of a meta-device Qwen3_5ForCausalLM must      ##
## exist in the shard index with the exact shape, and vice versa ; plus   ##
## value sanity on a sample of real tensors [ finite, non-degenerate ].   ##

import json
import sys

import torch
from safetensors import safe_open
from transformers.models.qwen3_5 import Qwen3_5ForCausalLM, Qwen3_5TextConfig

BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"

index = json.load(open(f"{BASE}/model.safetensors.index.json"))
wm = index["weight_map"]

cfg = Qwen3_5TextConfig.from_pretrained(BASE)
with torch.device("meta"):
    model = Qwen3_5ForCausalLM(cfg)
sd = model.state_dict()

missing = [k for k in sd if k not in wm]
extra = [k for k in wm if k not in sd]
print(f"model params {len(sd)}, index tensors {len(wm)}")
assert not missing, f"missing from checkpoint: {missing[:5]}"
assert not extra, f"unexpected in checkpoint: {extra[:5]}"

bad = []
for fname in sorted(set(wm.values())):
    with safe_open(f"{BASE}/{fname}", framework="pt") as f:
        for key in f.keys():
            sl = f.get_slice(key)
            if list(sl.get_shape()) != list(sd[key].shape):
                bad.append((key, list(sl.get_shape()), list(sd[key].shape)))
assert not bad, f"shape mismatches: {bad[:5]}"
print("names + shapes : exact match")

## value sanity on a handful of tensors across layer types
probes = ["model.embed_tokens.weight", "model.layers.0.linear_attn.A_log",
          "model.layers.0.mlp.gate_proj.weight",
          "model.layers.3.self_attn.q_proj.weight",
          "model.layers.31.mlp.down_proj.weight", "model.norm.weight",
          "lm_head.weight"]
for key in probes:
    fname = wm[key]
    with safe_open(f"{BASE}/{fname}", framework="pt") as f:
        t = f.get_tensor(key).float()
        assert torch.isfinite(t).all(), f"non-finite in {key}"
        print(f"  {key:50s} mean={t.mean():+.5f} std={t.std():.5f} "
              f"absmax={t.abs().max():.4f}")
print("checkpoint verification OK")
