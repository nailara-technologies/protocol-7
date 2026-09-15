#!/usr/bin/env python3
## qwen35_hf_to_gguf.py -- full-model HF -> GGUF converter for the qwen35  ##
## hybrid architecture [ Qwen3_5ForConditionalGeneration, text tower only ] ##
## written for the coding-lora-p7-idioms-checkpoint-quantize task : this    ##
## fork's gguf-py has NO qwen35 registration in convert_hf_to_gguf.py       ##
## [ confirmed 2026-09-14 ], so the vendored converter refuses this         ##
## checkpoint outright.                                                     ##
##                                                                          ##
## every transform below was verified NUMERICALLY against ge525's           ##
## pre-existing Q4_K_M GGUF of the SAME petruhonk checkpoint [ F32 tensors  ##
## match exactly, quantized tensors at per-row cosine ~0.997 = quant        ##
## error ] -- not derived from name similarity :                            ##
##   1. zero-centered RMSNorms [ input/post_attention/final/q/k norm ] are  ##
##      stored as (1 + w) F32 -- HF applies (1+w), ggml rms_norm multiplies ##
##      by the stored value directly. linear_attn.norm [ ssm_norm ] is      ##
##      ones-centered and stored as-is.                                     ##
##   2. ssm_a = -exp(A_log), F32 -- the fork's delta-net computes           ##
##      softplus(alpha + dt_bias) * ssm_a directly [ llama-delta-net.cpp    ##
##      build_beta_gate ].                                                  ##
##   3. v-head permutation P = [0,2,4,...,30,1,3,...,31] [ evens then       ##
##      odds ] applied to EVERY 32-v-head-indexed dimension : ssm_a,        ##
##      ssm_dt.bias, in_proj_b/a rows, in_proj_z rows, v-rows of            ##
##      in_proj_qkv [ blocks of head_dim=128 ], conv1d v-channels,          ##
##      out_proj input columns. the fork pairs 2 CONSECUTIVE v-heads per    ##
##      k-group; HF pairs group g with heads {2g, 2g+1}. q/k head order     ##
##      [ 16 heads ] is unchanged.                                          ##
##   4. full-attention q_proj is copied DIRECTLY -- HF already stores the   ##
##      output gate per-head interleaved [ head0_q(256), head0_gate(256),   ##
##      head1_q, ... ], which is exactly the layout the fork's              ##
##      llm_build_mul_mat_qkv_gated view-stride expects.                    ##
##   5. conv1d.weight [ 8192, 1, 4 ] is squeezed to (8192, 4) F32.          ##
##   6. vision tower [ model.visual.* ] and MTP [ mtp.* ] tensors are       ##
##      skipped -- production GGUF ships neither and the fork treats        ##
##      nextn tensors as optional.                                          ##
##                                                                          ##
## metadata + tokenizer KV mirror the working production GGUF [ mradermacher##
## i1-Q4_K_M ] key-for-key, with petruhonk provenance recorded in           ##
## general.url / general.source.url. tokenizer arrays are copied verbatim   ##
## from the production GGUF after verifying all 33 added/special tokens     ##
## match petruhonk's tokenizer.json by id+content [ they do ].              ##
##                                                                          ##
## memory-bounded : tensor infos are declared first, then each tensor is    ##
## loaded, transformed and streamed to file one at a time [ peak ~ one      ##
## tensor, embed/lm_head ~2GB bf16 + f16 copy ]. produce F16, then run the  ##
## already-installed /usr/bin/llama-quantize for the final quant -- do NOT  ##
## hand-roll K-quants here.                                                 ##

import json
import sys

import numpy as np
import torch
from safetensors import safe_open

sys.path.insert(0, "/data/source/ik_llama.cpp/gguf-py")
import gguf

## v-head permutation verified against ge525's GGUF [ see header note 3 ]   ##
V_HEADS = 32
V_PERM = list(range(0, V_HEADS, 2)) + list(range(1, V_HEADS, 2))

PROD_GGUF = (
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/"
    "Qwen3.8-9B-heretic-uncensored-i1-GGUF/"
    "Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf"
)


def permute_v_heads(arr, head_dim, axis=0):
    ## permute blocks of head_dim along the given axis by V_PERM             ##
    a = np.moveaxis(arr, axis, 0)
    rest = a.shape[1:]
    a = a.reshape(V_HEADS, head_dim, *rest)[V_PERM]
    return np.moveaxis(
        a.reshape(V_HEADS * head_dim, *rest), 0, axis
    )


class Checkpoint:
    ## lazy per-tensor access across the safetensors shards                  ##

    def __init__(self, ckpt_dir):
        self.dir = ckpt_dir
        idx = json.load(open(f"{ckpt_dir}/model.safetensors.index.json"))
        self.weight_map = idx["weight_map"]
        self.config = json.load(open(f"{ckpt_dir}/config.json"))

    def get(self, name):
        shard = self.weight_map[name]
        with safe_open(f"{self.dir}/{shard}", framework="pt") as f:
            return f.get_tensor(name)

    def shape(self, name):
        shard = self.weight_map[name]
        with safe_open(f"{self.dir}/{shard}", framework="pt") as f:
            return list(f.get_slice(name).get_shape())

    def layer_types(self):
        return self.config["text_config"]["layer_types"]


def build_tensor_plan(ck):
    ## ordered list of (ggml_name, hf_name_or_None, kind, transform)         ##
    ## kind : "f16" | "f32" ; transform : callable(torch.Tensor)->np.ndarray ##
    plan = [("token_embd.weight",
             "model.language_model.embed_tokens.weight", "f16",
             lambda t: t.to(torch.float16).numpy())]

    for i, lt in enumerate(ck.layer_types()):
        p = f"model.language_model.layers.{i}."
        b = f"blk.{i}."
        plan.append((b + "attn_norm.weight", p + "input_layernorm.weight",
                     "f32", lambda t: t.float().numpy() + 1.0))
        if lt == "full_attention":
            for hf, gg in (("self_attn.q_proj", "attn_q"),
                           ("self_attn.k_proj", "attn_k"),
                           ("self_attn.v_proj", "attn_v"),
                           ("self_attn.o_proj", "attn_output")):
                plan.append((b + gg + ".weight", p + hf + ".weight", "f16",
                             lambda t: t.to(torch.float16).numpy()))
            plan.append((b + "attn_q_norm.weight", p + "self_attn.q_norm.weight",
                         "f32", lambda t: t.float().numpy() + 1.0))
            plan.append((b + "attn_k_norm.weight", p + "self_attn.k_norm.weight",
                         "f32", lambda t: t.float().numpy() + 1.0))
        else:
            assert lt == "linear_attention", lt
            la = p + "linear_attn."

            def qkv(t):
                a = t.float().numpy()
                q, k, v = a[:2048], a[2048:4096], a[4096:]
                v = permute_v_heads(v, 128, axis=0)
                return np.concatenate([q, k, v], 0).astype(np.float16)

            plan.append((b + "attn_qkv.weight", la + "in_proj_qkv.weight",
                         "f16", qkv))
            plan.append((b + "attn_gate.weight", la + "in_proj_z.weight",
                         "f16", lambda t: permute_v_heads(
                             t.float().numpy(), 128, axis=0
                         ).astype(np.float16)))
            plan.append((b + "ssm_alpha.weight", la + "in_proj_a.weight",
                         "f16", lambda t: t.to(torch.float16).numpy()[V_PERM]))
            plan.append((b + "ssm_beta.weight", la + "in_proj_b.weight",
                         "f16", lambda t: t.to(torch.float16).numpy()[V_PERM]))

            def conv1d(t):
                a = t.float().numpy().squeeze(1)          ## (8192, 4)      ##
                q, k, v = a[:2048], a[2048:4096], a[4096:]
                v = permute_v_heads(v, 128, axis=0)
                return np.concatenate([q, k, v], 0)

            plan.append((b + "ssm_conv1d.weight", la + "conv1d.weight",
                         "f32", conv1d))
            plan.append((b + "ssm_dt.bias", la + "dt_bias",
                         "f32", lambda t: t.float().numpy()[V_PERM]))
            plan.append((b + "ssm_a", la + "A_log",
                         "f32", lambda t: (-t.float().exp()).numpy()[V_PERM]))
            plan.append((b + "ssm_norm.weight", la + "norm.weight",
                         "f32", lambda t: t.float().numpy()))
            plan.append((b + "ssm_out.weight", la + "out_proj.weight",
                         "f16", lambda t: permute_v_heads(
                             t.float().numpy(), 128, axis=1
                         ).astype(np.float16)))
        plan.append((b + "post_attention_norm.weight",
                     p + "post_attention_layernorm.weight",
                     "f32", lambda t: t.float().numpy() + 1.0))
        for hf, gg in (("mlp.gate_proj", "ffn_gate"),
                       ("mlp.up_proj", "ffn_up"),
                       ("mlp.down_proj", "ffn_down")):
            plan.append((b + gg + ".weight", p + hf + ".weight", "f16",
                         lambda t: t.to(torch.float16).numpy()))

    plan.append(("output_norm.weight", "model.language_model.norm.weight",
                 "f32", lambda t: t.float().numpy() + 1.0))
    plan.append(("output.weight", "lm_head.weight", "f16",
                 lambda t: t.to(torch.float16).numpy()))
    return plan


def copy_tokenizer_kv(writer):
    ## verbatim from the production GGUF [ verified identical vocab, see    ##
    ## header ] -- guarantees the exact tokenizer section the live fork     ##
    ## already serves correctly today.                                      ##
    r = gguf.GGUFReader(PROD_GGUF)
    tokens = r.get_field("tokenizer.ggml.tokens").contents()
    types = r.get_field("tokenizer.ggml.token_type").contents()
    merges = r.get_field("tokenizer.ggml.merges").contents()
    assert len(tokens) == 248320 and len(types) == 248320
    assert len(merges) == 247587
    writer.add_tokenizer_model("gpt2")
    writer.add_tokenizer_pre("qwen35")
    writer.add_token_list(tokens)
    writer.add_token_types([int(x) for x in types])
    writer.add_token_merges(merges)
    writer.add_eos_token_id(248046)
    writer.add_pad_token_id(248044)


def main(ckpt_dir, out_path):
    ck = Checkpoint(ckpt_dir)
    tc = ck.config["text_config"]
    plan = build_tensor_plan(ck)

    writer = gguf.GGUFWriter(out_path, arch="qwen35")
    writer.add_string("general.type", "model")
    writer.add_name("Qwen3.8 9B Distill Uncensored Heretic")
    writer.add_finetune("distill-uncensored-heretic")
    writer.add_basename("Qwen3.8")
    writer.add_size_label("9.2B")
    writer.add_license("apache-2.0")
    writer.add_base_model_count(1)
    writer.add_base_model_name(0, "Qwen3.5 9B")
    writer.add_base_model_organization(0, "Qwen")
    writer.add_base_model_repo_url(0, "https://huggingface.co/Qwen/Qwen3.5-9B")
    writer.add_tags(["empero-ai", "qwen3.5", "qwen3.8", "distill",
                     "uncensored", "heretic", "text-generation"])
    writer.add_languages(["en"])

    writer.add_block_count(int(tc["num_hidden_layers"]))
    writer.add_context_length(int(tc["max_position_embeddings"]))
    writer.add_embedding_length(int(tc["hidden_size"]))
    writer.add_feed_forward_length(int(tc["intermediate_size"]))
    writer.add_head_count(int(tc["num_attention_heads"]))
    writer.add_head_count_kv(int(tc["num_key_value_heads"]))
    mrope = list(tc["rope_parameters"]["mrope_section"])
    writer.add_rope_dimension_sections(mrope + [0] * (4 - len(mrope)))
    writer.add_rope_freq_base(float(tc["rope_parameters"]["rope_theta"]))
    writer.add_layer_norm_rms_eps(float(tc["rms_norm_eps"]))
    writer.add_key_length(int(tc["head_dim"]))
    writer.add_value_length(int(tc["head_dim"]))
    writer.add_ssm_conv_kernel(int(tc["linear_conv_kernel_dim"]))
    writer.add_ssm_state_size(int(tc["linear_key_head_dim"]))
    writer.add_uint32("qwen35.ssm.group_count",
                      int(tc["linear_num_key_heads"]))
    writer.add_ssm_time_step_rank(int(tc["linear_num_value_heads"]))
    writer.add_ssm_inner_size(int(tc["linear_num_value_heads"])
                              * int(tc["linear_value_head_dim"]))
    writer.add_uint32("qwen35.full_attention_interval",
                      int(tc["full_attention_interval"]))
    writer.add_rope_dimension_count(
        int(int(tc["head_dim"]) * float(tc["partial_rotary_factor"])))

    copy_tokenizer_kv(writer)
    with open(f"{ckpt_dir}/chat_template.jinja") as f:
        writer.add_chat_template(f.read())

    writer.add_quantization_version(getattr(gguf, "GGML_QUANT_VERSION", 2))
    writer.add_file_type(1)    ## mostly F16                                 ##
    writer.add_url("https://huggingface.co/petruhonk/"
                   "Qwen3.8-9B-Distill-uncensored-heretic")
    writer.add_source_url("https://huggingface.co/petruhonk/"
                          "Qwen3.8-9B-Distill-uncensored-heretic")

    ## declare all tensor infos first [ metadata pass, no data held ]        ##
    for gg_name, hf_name, kind, _xf in plan:
        shape = ck.shape(hf_name)
        if gg_name.endswith("ssm_conv1d.weight"):
            shape = [shape[0], shape[2]]          ## squeeze singleton dim   ##
        dtype = np.float16 if kind == "f16" else np.float32
        esz = 2 if kind == "f16" else 4
        nbytes = int(np.prod(shape)) * esz
        writer.add_tensor_info(gg_name, shape, np.dtype(dtype), nbytes)

    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_ti_data_to_file()

    ## stream tensor data one at a time                                      ##
    total = len(plan)
    for n, (gg_name, hf_name, _kind, xf) in enumerate(plan):
        arr = xf(ck.get(hf_name))
        writer.write_tensor_data(np.ascontiguousarray(arr))
        del arr
        if (n + 1) % 25 == 0 or n + 1 == total:
            print(f"  [{n + 1}/{total}] {gg_name}", file=sys.stderr, flush=True)

    writer.close()
    print(f"wrote {out_path} : {total} tensors")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

#,,,.,...,.,.,...,.,,,,..,.,.,.,.,,,,,...,.,.,..,,...,...,.,.,.,,,.,.,.,.,.,.,
#LVJSQPOUCBN2RPAJTQ2KSUFZUNR7U5XTUY5IWEIII7VFHLJXYJYNQ6LFIXGYGNN724SWCFMMY7RZU
#\\\|AFLEAMMSPQQDZQT6DDCJCHHEE5F7WV7C2GGV2AY57T2EPPTLQOA \ / AMOS7 \ YOURUM ::
#\[7]2243NCS7WSCEGV5ULSJ6P2D5LMIDYDYNR5QOTUIDZ3H3CCYGU4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
