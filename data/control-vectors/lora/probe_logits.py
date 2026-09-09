#!/usr/bin/env python3
## probe_logits.py -- compare HF-loaded model top-token logits against    ##
## the production llama.cpp server for the SAME prompt [ ground truth :   ##
## 'Thinking' 0.53, 'The' 0.42 ]. also dumps embedding cosine sanity and  ##
## per-layer hidden-state norms to localize any breakage.                 ##

import sys

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"
tok = AutoTokenizer.from_pretrained(BASE)
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_use_double_quant=True,
                         bnb_4bit_compute_dtype=torch.bfloat16)
model = AutoModelForCausalLM.from_pretrained(
    BASE, quantization_config=bnb, device_map="cuda", dtype=torch.bfloat16)
model.eval()

prompt = ("<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"
          "<|im_start|>user\nExplain in one sentence what a hash map is."
          "<|im_end|>\n<|im_start|>assistant\n<think>\n")
ids = tok(prompt, return_tensors="pt", add_special_tokens=False).to("cuda")

with torch.no_grad():
    out = model(**ids, output_hidden_states=True)
logits = out.logits[0, -1].float()
probs = torch.softmax(logits, -1)
top = probs.topk(8)
print("HF top-8 next token:")
for p, i in zip(top.values, top.indices):
    print(f"  {p.item():.4f}  {repr(tok.convert_ids_to_tokens(i.item()))}")

print("\nper-layer hidden norms [ layer 0 = embeddings ]:")
for li, h in enumerate(out.hidden_states):
    print(f"  {li:3d} norm={h.float().norm(dim=-1).mean().item():10.2f} "
          f"std={h.float().std().item():.4f}")

## embedding cosine sanity
emb = model.get_input_embeddings().weight
def tid(s):
    return tok(s, add_special_tokens=False)["input_ids"][0]
pairs = [("cat", "dog"), ("cat", "xylophone"), ("king", "queen"),
         ("king", "bicycle")]
print("\nembedding cosines:")
for a, b in pairs:
    va, vb = emb[tid(a)].float(), emb[tid(b)].float()
    c = torch.cosine_similarity(va, vb, dim=0).item()
    print(f"  cos({a},{b}) = {c:.3f}")
