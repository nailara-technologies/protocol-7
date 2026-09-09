#!/usr/bin/env python3
## fix_a_log.py -- repair the linear_attn.A_log tensors in the dequantized ##
## checkpoint. found via a catastrophic first training loss [ 14.49, above ##
## random-chance ln(248320)=12.4 ] : the GGUF stores ssm_a PRECOMPUTED as  ##
## -exp(A_log) [ this fork's llama-delta-net.cpp:282 uses it raw : gate =  ##
## softplus(alpha+dt) * ssm_a ], while transformers' Qwen3_5GatedDeltaNet  ##
## computes g = -exp(A_log) * softplus(a+dt). storing the raw GGUF value   ##
## as A_log made every linear-attn decay gate wrong. confirmed from the    ##
## values themselves : all 32 ssm_a values strictly negative on every      ##
## layer [ -exp(x) < 0 always ; a raw A_log would go positive ].           ##
## fix : A_log = log(-ssm_a), patched into the shards in place.            ##

import json
import os
import sys

import numpy as np
import torch
from safetensors import safe_open
from safetensors.torch import save_file

sys.path.insert(0, "/data/source/ik_llama.cpp/gguf-py")
from gguf import GGUFReader

GGUF_PATH = ("/mnt/ext-xfs-data/models-lmstudio/mradermacher/"
             "Qwen3.8-9B-heretic-uncensored-i1-GGUF/"
             "Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf")
BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"

## 1. read the true A_log values from the GGUF
reader = GGUFReader(GGUF_PATH)
fix = {}
for t in reader.tensors:
    if t.name.endswith(".ssm_a"):
        layer = t.name.split(".")[1]
        arr = np.array(t.data, dtype=np.float32)
        assert (arr < 0).all(), f"{t.name} has non-negative values"
        fix[f"model.layers.{layer}.linear_attn.A_log"] = torch.from_numpy(
            np.log(-arr)).to(torch.bfloat16)
print(f"{len(fix)} A_log tensors to patch [ expect 24 ]")
assert len(fix) == 24

## 2. rewrite the shards that hold them
index = json.load(open(f"{BASE}/model.safetensors.index.json"))
wm = index["weight_map"]
by_shard = {}
for name in fix:
    by_shard.setdefault(wm[name], []).append(name)
for fname, names in sorted(by_shard.items()):
    with safe_open(f"{BASE}/{fname}", framework="pt") as f:
        tensors = {k: f.get_tensor(k) for k in f.keys()}
    for name in names:
        old = tensors[name].float()
        new = fix[name].float()
        print(f"  {name}: old mean {old.mean():+.4f} -> new mean "
              f"{new.mean():+.4f}")
        tensors[name] = fix[name]
    save_file(tensors, f"{BASE}/{fname}", metadata={"format": "pt"})
    print(f"  rewrote {fname}")
print("A_log patch complete")
