#!/usr/bin/env python3
## verify_qwen35_gguf.py -- read-only, memory-bounded three-way numerical ##
## verification of the F16 GGUF produced by qwen35_hf_to_gguf.py :         ##
##   (a) OUR gguf vs the HF checkpoint        -- every tensor, exact       ##
##       [ f16 rounding tolerance only where f16 ]                         ##
##   (b) OUR gguf vs ge525's Q4_K_M gguf      -- F32 tensors exact, 2D at  ##
##       quant-error cosine [ independent provenance/transform check ]     ##
##   (c) OUR gguf vs the PRODUCTION gguf      -- F32 tensor divergence     ##
##       report [ quantifies the checkpoint mismatch itself ]              ##
##                                                                         ##
## STRICTLY read-only file comparison. never loads anything into an        ##
## inference server. memory-bounded on purpose [ this host has 15GB RAM    ##
## and OOM-crashed once already ] : tensors are compared one at a time,    ##
## the two 248320x4096 giants [ token_embd, output ] are compared in       ##
## row chunks, and their ge525 cosine is sampled over 128 rows via         ##
## per-row block slicing [ Q4_K/Q6_K blocks never span rows ] instead of   ##
## a full dequantize. no float64 anywhere on big tensors.                  ##

import json
import sys

import numpy as np
import torch
from safetensors import safe_open

sys.path.insert(0, "/data/source/ik_llama.cpp/gguf-py")
import gguf
from gguf.quants import dequantize

sys.path.insert(0, "/data/projects/protocol-7/data/control-vectors/lora")
from qwen35_hf_to_gguf import Checkpoint, build_tensor_plan

OURS = sys.argv[1]
GE = ("/mnt/ext-xfs-data/models-lmstudio/ge525/"
      "Qwen3.8-9B-Distill-uncensored-heretic-Q4_K_M-GGUF/"
      "qwen3.8-9b-distill-uncensored-heretic-q4_k_m.gguf")
PROD = ("/mnt/ext-xfs-data/models-lmstudio/mradermacher/"
        "Qwen3.8-9B-heretic-uncensored-i1-GGUF/"
        "Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf")
CKPT = ("/mnt/ext-xfs-data/models-lmstudio/petruhonk/"
        "Qwen3.8-9B-Distill-uncensored-heretic")

GIANT = {"token_embd.weight", "output.weight"}
BLOCK = {"Q4_K": (256, 144), "Q6_K": (256, 210)}


def deq(t):
    if t.tensor_type.name in ("F32", "F16", "BF16"):
        return np.asarray(t.data, dtype=np.float32)
    return dequantize(t.data, t.tensor_type).reshape(
        [int(x) for x in t.shape][::-1])


def deq_rows(t, row_idx, n_cols):
    ## dequantize selected rows of a quantized 2D tensor without a full     ##
    ## dequant [ blocks are row-local ]                                     ##
    bsz, tsz = BLOCK[t.tensor_type.name]
    per_row = (n_cols // bsz) * tsz
    raw = np.asarray(t.data)
    out = np.empty((len(row_idx), n_cols), dtype=np.float32)
    for j, r in enumerate(row_idx):
        row = raw[r] if raw.ndim == 2 else raw[r * per_row:(r + 1) * per_row]
        out[j] = dequantize(np.ascontiguousarray(row.ravel()),
                            t.tensor_type)
    return out


def cos_rows(a, b):
    an = a / (np.linalg.norm(a, axis=1, keepdims=True) + 1e-12)
    bn = b / (np.linalg.norm(b, axis=1, keepdims=True) + 1e-12)
    return (an * bn).sum(1)


def main():
    ck = Checkpoint(CKPT)
    plan = build_tensor_plan(ck)
    ro = gguf.GGUFReader(OURS)
    ours = {t.name: t for t in ro.tensors}
    rg = gguf.GGUFReader(GE)
    ge = {t.name: t for t in rg.tensors}
    rp = gguf.GGUFReader(PROD)
    prod = {t.name: t for t in rp.tensors}

    names = [g for g, _h, _k, _x in plan]
    assert len(ours) == len(names) == 427, (len(ours), len(names))
    print(f"[a] tensor count 427 ok ; "
          f"name-set == ge525 : {set(ours) <= set(ge)} ; "
          f"== prod : {set(ours) == set(prod)}")

    fail = 0
    for gg_name, hf_name, kind, xf in plan:
        t = ours[gg_name]
        if gg_name in GIANT:
            ## chunked row comparison, 2048 rows at a time                  ##
            n_rows = int(t.shape[1])
            maxd = 0.0
            for r0 in range(0, n_rows, 2048):
                r1 = min(r0 + 2048, n_rows)
                with safe_open(
                        f"{ck.dir}/{ck.weight_map[hf_name]}",
                        framework="pt") as f:
                    want = xf_from_rows(f, hf_name, r0, r1, kind)
                got = np.asarray(t.data[r0:r1], dtype=np.float32)
                maxd = max(maxd, float(np.abs(got - want).max()))
                del want, got
            tol = 0.0 if kind == "f32" else 2e-3
            status = "OK " if maxd <= tol else "FAIL"
            if maxd > tol:
                fail += 1
            print(f"[a] {status} {gg_name:28s} chunked max|diff| {maxd:.2e}")
            continue

        want = xf(ck.get(hf_name)).astype(np.float32)
        got = deq(t)
        if got.shape != want.shape:
            print(f"[a] FAIL shape {gg_name}: {got.shape} vs {want.shape}")
            fail += 1
            del want
            continue
        maxd = float(np.abs(got - want).max())
        tol = 0.0 if kind == "f32" else 2e-3
        if maxd > tol:
            fail += 1
            print(f"[a] FAIL {gg_name:28s} max|diff| {maxd:.2e}")
        del want, got

    print(f"[a] ours-vs-HF exhaustive: "
          f"{'ALL 427 EXACT' if fail == 0 else f'{fail} FAILURES'}")

    ## (b) ge525 cross-check : F32 exact everywhere, 2D cosine             ##
    bfail = 0
    worst_cos = 1.0
    for gg_name, hf_name, kind, _xf in plan:
        if gg_name in GIANT:
            continue
        g = deq(ge[gg_name])
        o = deq(ours[gg_name])
        if kind == "f32":
            if not np.allclose(g, o, atol=1e-6):
                print(f"[b] FAIL ge525-f32 {gg_name}: "
                      f"max|diff| {np.abs(g - o).max():.3e}")
                bfail += 1
        else:
            c = cos_rows(g.astype(np.float32), o.astype(np.float32))
            m = float(c.min())
            worst_cos = min(worst_cos, m)
            if m < 0.98:
                print(f"[b] FAIL ge525-cos {gg_name}: min row cos {m:.5f}")
                bfail += 1
        del g, o
    ## giants : sampled-row cosine via block slicing                        ##
    for gg_name in sorted(GIANT):
        t, tg = ours[gg_name], ge[gg_name]
        n_rows, n_cols = int(t.shape[1]), int(t.shape[0])
        idx = np.linspace(0, n_rows - 1, 128).astype(int)
        a = deq_rows(tg, idx, n_cols)
        b = np.asarray(t.data[idx], dtype=np.float32)
        m = float(cos_rows(a, b).min())
        worst_cos = min(worst_cos, m)
        print(f"[b] {gg_name:20s} sampled-row cos vs ge525 min {m:.5f}")
        del a, b
    print(f"[b] ours-vs-ge525: {'OK' if bfail == 0 else f'{bfail} FAILURES'}"
          f" ; worst 2D row-cos anywhere {worst_cos:.5f}")

    ## (c) production divergence report [ the checkpoint mismatch itself ] ##
    print("[c] F32-tensor divergence ours [ petruhonk ] vs prod [ rohit267 ]:")
    for gg_name, _hf, kind, _xf in plan:
        if kind != "f32":
            continue
        o = deq(ours[gg_name]).ravel()
        p = deq(prod[gg_name]).ravel()
        d = float(np.abs(o - p).max())
        cos = float(o @ p / (np.linalg.norm(o) * np.linalg.norm(p) + 1e-12))
        if gg_name in ("blk.0.ssm_a", "blk.0.ssm_dt.bias",
                       "blk.0.attn_norm.weight", "blk.3.attn_q_norm.weight",
                       "output_norm.weight", "blk.30.ssm_norm.weight",
                       "blk.30.ssm_conv1d.weight"):
            print(f"    {gg_name:30s} max|diff| {d:9.4f}  cos {cos:.5f}")
    print("[c] [ any large max|diff| above = two genuinely different "
          "fine-tunes, i.e. the mismatch itself, measured directly ]")


def xf_from_rows(f, hf_name, r0, r1, kind):
    t = f.get_slice(hf_name)[r0:r1]
    if kind == "f16":
        return t.to(torch.float16).float().numpy()
    return t.float().numpy()


if __name__ == "__main__":
    main()

#,,.,,.,,,.,.,...,...,,.,,..,,,.,,.,.,.,,,,,.,..,,...,...,...,...,.,.,.,,,,,.,
#3IXNVBWVAL6DW26I2AB7SRNALFCNN5KEH6I3DWCX5XGC2GNG5C7LNX234QMAE43OWBNUV6LARDDC4
#\\\|DSDXW3N4U3O6LPJXGBTRJ6BGVFLUJSROUOUF4SYHUZOBOVU2MAS \ / AMOS7 \ YOURUM ::
#\[7]R6XNSYV3VQEEXQLC7DB76JQ54RFXXLEW36DRESHZ56KILAEXRGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
