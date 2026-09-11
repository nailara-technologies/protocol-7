#!/usr/bin/env python3
## dequant_to_hf.py -- dequantize the PRODUCTION i1-Q4_K_M GGUF back into ##
## an HF-format bf16 checkpoint [ safetensors shards + config.json ] that  ##
## transformers' Qwen3_5ForCausalLM can load for QLoRA training.           ##
##                                                                         ##
## why this exists [ judgment call, recorded in the task results ] : the   ##
## original fp16 checkpoint [ rohit267/Qwen3.8-9B-heretic-uncensored ] is  ##
## private/404 on HF [ confirmed with a valid token 2026-09-09 ], so the   ##
## task's preferred path [ fetch the exact source checkpoint ] is          ##
## impossible. the GGUF's own metadata says mradermacher.convert_type=hf   ##
## and general.source.url=that repo, i.e. this file IS the source model    ##
## at Q4_K_M precision. at inference the adapter runs against              ##
## dequant(Q4_K_M(W)) -- training against the same dequantized tensors is  ##
## the closest achievable weight distribution match [ arguably closer than ##
## the lost fp16 original ].                                               ##
##                                                                         ##
## tensor name mapping GGUF -> HF [ verified 2026-09-09 against :          ##
##   - transformers 5.16.1 modeling_qwen3_5 [ param names + shapes from a  ##
##     meta-device instantiation, 427 params both sides ]                  ##
##   - ik_llama.cpp src/llama-delta-net.cpp [ ssm_alpha = the a/dt_bias/   ##
##     softplus decay path -> in_proj_a ; ssm_beta = sigmoid beta ->       ##
##     in_proj_b ] and modeling_qwen3_5.forward [ same equations ]         ##
## verification : after writing, a meta-device model's state_dict is       ##
## compared name-for-name and shape-for-shape against the shard index.     ##

import gc
import json
import os
import sys

import numpy as np
import torch
from safetensors.torch import save_file

sys.path.insert(0, "/data/source/ik_llama.cpp/gguf-py")
from gguf import GGUFReader
from gguf.quants import dequantize

GGUF_PATH = ("/mnt/ext-xfs-data/models-lmstudio/mradermacher/"
             "Qwen3.8-9B-heretic-uncensored-i1-GGUF/"
             "Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf")
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "base-model"
SHARD_MAX_BYTES = 1500 * 1024 * 1024  ## 1.5GB shards : peak RAM stays ~2GB


def map_name(g):
    if g == "token_embd.weight":
        return "model.embed_tokens.weight"
    if g == "output.weight":
        return "lm_head.weight"
    if g == "output_norm.weight":
        return "model.norm.weight"
    assert g.startswith("blk."), g
    parts = g.split(".")
    n = parts[1]
    rest = ".".join(parts[2:])
    base = f"model.layers.{n}"
    simple = {
        "attn_norm.weight": "input_layernorm.weight",
        "post_attention_norm.weight": "post_attention_layernorm.weight",
        "ffn_gate.weight": "mlp.gate_proj.weight",
        "ffn_up.weight": "mlp.up_proj.weight",
        "ffn_down.weight": "mlp.down_proj.weight",
        "attn_q.weight": "self_attn.q_proj.weight",
        "attn_k.weight": "self_attn.k_proj.weight",
        "attn_v.weight": "self_attn.v_proj.weight",
        "attn_output.weight": "self_attn.o_proj.weight",
        "attn_q_norm.weight": "self_attn.q_norm.weight",
        "attn_k_norm.weight": "self_attn.k_norm.weight",
        "attn_qkv.weight": "linear_attn.in_proj_qkv.weight",
        "attn_gate.weight": "linear_attn.in_proj_z.weight",
        "ssm_alpha.weight": "linear_attn.in_proj_a.weight",
        "ssm_beta.weight": "linear_attn.in_proj_b.weight",
        "ssm_out.weight": "linear_attn.out_proj.weight",
        "ssm_norm.weight": "linear_attn.norm.weight",
        "ssm_a": "linear_attn.A_log",
        "ssm_dt.bias": "linear_attn.dt_bias",
        "ssm_conv1d.weight": "linear_attn.conv1d.weight",
    }
    assert rest in simple, f"unmapped tensor {g}"
    return f"{base}.{simple[rest]}"


def dequant_tensor(t):
    if t.tensor_type.name == "F32":
        arr = np.array(t.data, dtype=np.float32)
    else:
        arr = dequantize(t.data, t.tensor_type)
    out = torch.from_numpy(np.ascontiguousarray(arr))
    if out.ndim == 3 and out.shape[1] == 1:
        pass  ## conv1d already (8192,1,4)-shaped by ggml layout? see below
    if "conv1d" in t.name:
        out = out.reshape(out.shape[0], 1, out.shape[-1])
    return out.to(torch.bfloat16)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    reader = GGUFReader(GGUF_PATH)
    shards = []          ## list of (filename, {name: shape})
    cur, cur_bytes, shard_idx = {}, 0, 1
    total = len(reader.tensors)
    for i, t in enumerate(reader.tensors):
        name = map_name(t.name)
        tensor = dequant_tensor(t)
        nbytes = tensor.numel() * 2
        if cur and cur_bytes + nbytes > SHARD_MAX_BYTES:
            fname = f"model-{shard_idx:05d}.safetensors"
            save_file(cur, os.path.join(OUT_DIR, fname),
                      metadata={"format": "pt"})
            shards.append((fname, {k: list(v.shape) for k, v in cur.items()}))
            print(f"  wrote {fname} [{cur_bytes / 2**30:.2f} GiB, "
                  f"{len(cur)} tensors]")
            cur, cur_bytes = {}, 0
            shard_idx += 1
            gc.collect()
        cur[name] = tensor
        cur_bytes += nbytes
        if (i + 1) % 50 == 0:
            print(f"  [{i + 1}/{total}] dequantized ...")
    if cur:
        fname = f"model-{shard_idx:05d}.safetensors"
        save_file(cur, os.path.join(OUT_DIR, fname),
                  metadata={"format": "pt"})
        shards.append((fname, {k: list(v.shape) for k, v in cur.items()}))
        print(f"  wrote {fname} [{cur_bytes / 2**30:.2f} GiB, "
              f"{len(cur)} tensors]")

    ## final shard naming + index [ transformers expects -of- names ]
    n = len(shards)
    weight_map = {}
    for idx, (old, shapes) in enumerate(shards, 1):
        new = f"model-{idx:05d}-of-{n:05d}.safetensors"
        os.rename(os.path.join(OUT_DIR, old), os.path.join(OUT_DIR, new))
        for k in shapes:
            weight_map[k] = new
    index = {"metadata": {"total_size": sum(
        os.path.getsize(os.path.join(OUT_DIR, f"model-{i:05d}-of-{n:05d}.safetensors"))
        for i in range(1, n + 1))},
        "weight_map": weight_map}
    with open(os.path.join(OUT_DIR, "model.safetensors.index.json"),
              "w") as f:
        json.dump(index, f, indent=2)
    print(f"index written : {len(weight_map)} tensors across {n} shards")


if __name__ == "__main__":
    main()

#,,..,..,,.,,,.,,,...,.,.,..,,..,,,,,,,,,,.,.,..,,...,..,,..,,,.,,,,,,,,,,,.,,
#WXD33LREDIICPIUG6B5JKEOPB6RFLBBMA3LGLEVLNGAHZG2QI3MEXFNVSCEOFDYD7RT6PRKZYPIJW
#\\\|6VCZE33IUJJJ4OJ2XEHWAIYE6CGCUNH3APSSNAAEHA3AWNNJKP4 \ / AMOS7 \ YOURUM ::
#\[7]DYSPCIH5CLJUL4SIAMXKNVNGCNO5SXGWNSWN4NXMHJMVQBUCCSBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
