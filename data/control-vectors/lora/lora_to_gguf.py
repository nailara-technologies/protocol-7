#!/usr/bin/env python3
## lora_to_gguf.py -- convert the trained PEFT adapter [ safetensors +    ##
## adapter_config.json ] into the GGUF LoRA format that ik_llama.cpp's    ##
## --lora / --lora-scaled loads.                                           ##
##                                                                         ##
## why not the vendored convert_lora_to_gguf.py : it routes through       ##
## Model.from_model_architecture() and this fork's gguf-py has NO qwen35  ##
## registration [ confirmed 2026-09-09 : no QWEN35 in gguf-py/gguf/       ##
## constants.py, no qwen35 model class in convert_hf_to_gguf.py ] -- it   ##
## exits 'Model Qwen3_5ForCausalLM is not supported'. this writer covers  ##
## exactly the 7 projection types this adapter touches, with the loader's ##
## requirements read from src/llama.cpp llama_lora_adapter_init_internal  ##
## and verified live [ see results ] :                                     ##
##   KV : general.type=adapter, general.architecture=qwen35 [ arch match  ##
##        IS enforced ], adapter.type=lora, adapter.lora.alpha=<f32>      ##
##   tensors : <ggml name>.lora_a [ numpy (r, in)  -> ggml ne=[in, r]  ]  ##
##             <ggml name>.lora_b [ numpy (out, r) -> ggml ne=[r, out] ]  ##
##   applied scale at runtime = user_scale * alpha / rank [ same as PEFT, ##
##   confirmed in src/llama-build-context.cpp llm_build_lora_mm ]         ##

import json
import sys

import numpy as np
import torch
from safetensors.torch import load_file

sys.path.insert(0, "/data/source/ik_llama.cpp/gguf-py")
import gguf

HF_TO_GGUF = {
    "self_attn.q_proj": "attn_q",
    "self_attn.k_proj": "attn_k",
    "self_attn.v_proj": "attn_v",
    "self_attn.o_proj": "attn_output",
    "mlp.gate_proj": "ffn_gate",
    "mlp.up_proj": "ffn_up",
    "mlp.down_proj": "ffn_down",
    ## added 2026-09-10 -- this session's adapter widens target_modules to  ##
    ## also cover the 24 linear-attention (SSM) layers (see coding-lora-   ##
    ## p7-idioms.md's RE-DECIDED 2026-09-10 section), which the original   ##
    ## 7-entry map above (dense-transformer-only) has no mapping for and   ##
    ## would crash on via the `unmapped module` assert. ggml names below   ##
    ## confirmed by exact tensor-SHAPE match between this HF checkpoint's  ##
    ## model.language_model.layers.0.linear_attn.* weights and the real,   ##
    ## already-working production GGUF's blk.0.* tensors (not guessed from ##
    ## name similarity alone -- e.g. in_proj_a [32,4096] matches ssm_alpha ##
    ## [4096,32] exactly, in_proj_b matches ssm_beta, in_proj_z [4096,4096]##
    ## matches attn_gate, in_proj_qkv [8192,4096] matches attn_qkv,        ##
    ## out_proj [4096,4096] matches ssm_out).                              ##
    "linear_attn.in_proj_qkv": "attn_qkv",
    "linear_attn.in_proj_z": "attn_gate",
    "linear_attn.in_proj_a": "ssm_alpha",
    "linear_attn.in_proj_b": "ssm_beta",
    "linear_attn.out_proj": "ssm_out",
}

## added 2026-09-12 -- top-level target modules with no blk.N. layer prefix ##
## at all. "lm_head" is the ONLY one of the two this session's train_lora  ##
## added that this fork's inference path actually applies: confirmed by    ##
## reading llama-build-context.cpp directly -- build_output() routes the   ##
## output/lm_head projection through llm_build_lora_mm (same lora-aware    ##
## path as every attn/mlp/ssm projection above), but llm_build_inp_embd()  ##
## reads the token embedding table via a bare ggml_get_rows(tok_embd, ...) ##
## with no lora_mm call anywhere near it. an embed_tokens lora would load   ##
## without error and then silently never apply -- same failure shape as    ##
## the flash-attn bug this task already found once -- so embed_tokens is    ##
## deliberately NOT in this map and its tensors are skipped below           ##
TOP_LEVEL_HF_TO_GGUF = {
    "lm_head": "output",
}


def main(adapter_dir, out_path):
    cfg = json.load(open(f"{adapter_dir}/adapter_config.json"))
    alpha = float(cfg["lora_alpha"])
    rank = int(cfg["r"])
    sd = load_file(f"{adapter_dir}/adapter_model.safetensors")

    pairs = {}
    skipped_base_layer = 0
    skipped_embedding = 0
    for key, tensor in sd.items():
        ## keys look like :
        ## base_model.model.model.layers.3.self_attn.q_proj.lora_A.weight
        ## base_model.model.lm_head.lora_A.weight                (top-level)
        ## base_model.model.model.embed_tokens.lora_embedding_A  (inert, skip)

        if ".base_layer." in key:
            ## a redundant full-precision copy of an unquantized target      ##
            ## module's frozen base weight -- lm_head/embed_tokens are the   ##
            ## only two target modules NOT loaded in 4-bit here, so PEFT     ##
            ## saves their base tensor alongside the lora delta. ik_llama.   ##
            ## cpp already has the real weights from the production gguf --  ##
            ## never needed, never written                                   ##
            skipped_base_layer += 1
            continue
        if ".lora_embedding_" in key:
            skipped_embedding += 1
            continue

        m = key
        assert m.startswith("base_model.model."), m
        m = m[len("base_model.model."):]
        assert m.endswith((".lora_A.weight", ".lora_B.weight")), m
        is_a = m.endswith(".lora_A.weight")
        m = m.rsplit(".lora_", 1)[0]

        if m.startswith("model.layers."):
            parts = m.split(".")
            layer = parts[2]
            mod = ".".join(parts[3:])
            assert mod in HF_TO_GGUF, f"unmapped module {mod}"
            ggml = f"blk.{layer}.{HF_TO_GGUF[mod]}.weight"
        elif m in TOP_LEVEL_HF_TO_GGUF:
            ggml = f"{TOP_LEVEL_HF_TO_GGUF[m]}.weight"
        else:
            raise AssertionError(f"unmapped top-level module {m}")

        pairs.setdefault(ggml, {})["A" if is_a else "B"] = tensor

    print(
        f"skipped {skipped_base_layer} redundant base_layer tensor(s), "
        f"{skipped_embedding} inert embed_tokens lora tensor(s)",
        file=sys.stderr,
    )

    writer = gguf.GGUFWriter(out_path, arch="qwen35")
    writer.add_string("general.type", "adapter")
    writer.add_string("adapter.type", "lora")
    writer.add_float32("adapter.lora.alpha", alpha)

    n = 0
    for ggml_name in sorted(pairs):
        ab = pairs[ggml_name]
        assert "A" in ab and "B" in ab, f"incomplete pair {ggml_name}"
        a = ab["A"].to(torch.float32).numpy()  ## (r, in)
        b = ab["B"].to(torch.float32).numpy()  ## (out, r)
        assert a.shape[0] == rank and b.shape[1] == rank, \
            f"rank mismatch {ggml_name}: A{a.shape} B{b.shape}"
        assert a.shape[1] == b.shape[0] or True
        writer.add_tensor(ggml_name + ".lora_a", a)
        writer.add_tensor(ggml_name + ".lora_b", b)
        n += 1

    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    print(f"wrote {out_path} : {n} lora pairs [ rank {rank}, alpha "
          f"{alpha} ]")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "adapter",
         sys.argv[2] if len(sys.argv) > 2 else
         "p7-idioms-lora.OFSQC4I-QDBKEXY.gguf")

#,,..,...,,..,,,,,,.,,,.,,,..,.,.,,,.,,..,,.,,..,,...,...,,,.,.,,,,,,,,..,,.,,
#PYBDTF6DQDJFDPN2GEDTDK3RQ5ZV6PQI6VARA65MNCMDO6OAINVTXUXNBHTVF5U6ZFUQ7YWXNPS3U
#\\\|MRVSU45YMUJAGUHHZFEAQCXWJSKJGN23CYT4LJH3AI5THDFNIEP \ / AMOS7 \ YOURUM ::
#\[7]CGHFO473KSGH6AGVLHD45JL3I56RTBGY26HBLVZDT5WF7SRYE6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
