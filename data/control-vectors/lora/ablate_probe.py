#!/usr/bin/env python3
## ablate_probe.py -- localize the base-model breakage by zeroing out     ##
## components and watching next-token quality :                           ##
##   A: no token mixers at all [ embed -> mlp only ]                      ##
##   B: only full-attn mixers [ linear-attn zeroed ]                      ##
##   C: only linear-attn mixers [ full-attn zeroed ]                      ##
##   D: full model [ control -- known garbage ]                           ##
## ground truth [ llama.cpp, same prompt ] : 'Thinking' 0.53, 'The' 0.42  ##

import sys
import types

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"
MODE = sys.argv[2] if len(sys.argv) > 2 else "A"

tok = AutoTokenizer.from_pretrained(BASE)
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_use_double_quant=True,
                         bnb_4bit_compute_dtype=torch.bfloat16)
model = AutoModelForCausalLM.from_pretrained(
    BASE, quantization_config=bnb, device_map="cuda", dtype=torch.bfloat16)
model.eval()


def zero_mixer(self, hidden_states, **kwargs):
    return torch.zeros_like(hidden_states)


for layer in model.model.layers:
    if MODE == "A" or (MODE == "B" and layer.block_type == "linear_attention"):
        if layer.block_type == "linear_attention":
            layer.linear_attn.forward = types.MethodType(
                zero_mixer, layer.linear_attn)
        else:
            if MODE == "A":
                layer.self_attn.forward = types.MethodType(
                    lambda self, hidden_states, **kw:
                    (torch.zeros_like(hidden_states), None),
                    layer.self_attn)
    if MODE == "C" and layer.block_type == "full_attention":
        layer.self_attn.forward = types.MethodType(
            lambda self, hidden_states, **kw:
            (torch.zeros_like(hidden_states), None), layer.self_attn)

prompt = ("<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"
          "<|im_start|>user\nExplain in one sentence what a hash map is."
          "<|im_end|>\n<|im_start|>assistant\n<think>\n")
ids = tok(prompt, return_tensors="pt", add_special_tokens=False).to("cuda")
with torch.no_grad():
    out = model(**ids)
probs = torch.softmax(out.logits[0, -1].float(), -1)
top = probs.topk(8)
print(f"MODE {MODE} top-8:")
for p, i in zip(top.values, top.indices):
    print(f"  {p.item():.4f}  {repr(tok.convert_ids_to_tokens(i.item()))}")
