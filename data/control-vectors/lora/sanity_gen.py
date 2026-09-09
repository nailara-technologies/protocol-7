#!/usr/bin/env python3
## sanity_gen.py -- post-patch base-model check BEFORE retraining :       ##
## generate short continuations [ coherence test ] and compute label      ##
## loss over a handful of dataset examples [ expect ~1.5-3.5 for a        ##
## working 9B on in-domain data ; the broken mapping gave 14.49 ].        ##

import json
import sys

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"
DATA = sys.argv[2] if len(sys.argv) > 2 else "dataset/sft.jsonl"

tok = AutoTokenizer.from_pretrained(BASE)
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_use_double_quant=True,
                         bnb_4bit_compute_dtype=torch.bfloat16)
model = AutoModelForCausalLM.from_pretrained(
    BASE, quantization_config=bnb, device_map="cuda", dtype=torch.bfloat16)
model.eval()

PROMPTS = [
    ("You are a protocol-7 developer.",
     "Write one line that logs a warning when a module fails to load."),
    ("You are a helpful assistant.",
     "Explain in one sentence what a hash map is."),
]
for sys_p, user_p in PROMPTS:
    text = (f"<|im_start|>system\n{sys_p}<|im_end|>\n"
            f"<|im_start|>user\n{user_p}<|im_end|>\n"
            f"<|im_start|>assistant\n<think>\n")
    ids = tok(text, return_tensors="pt", add_special_tokens=False).to("cuda")
    with torch.no_grad():
        out = model.generate(**ids, max_new_tokens=90, do_sample=False,
                             pad_token_id=tok.pad_token_id)
    gen = tok.decode(out[0][ids["input_ids"].shape[1]:],
                     skip_special_tokens=False)
    print("=" * 70)
    print("PROMPT:", user_p)
    print(gen[:600].replace("\n", "\\n"))

## loss over 8 dataset examples [ same masking as training ]
rows = [json.loads(l) for l in open(DATA)][:8]
losses = []
for ex in rows:
    prompt = (f"<|im_start|>system\n{ex['system']}<|im_end|>\n"
              f"<|im_start|>user\n{ex['user']}<|im_end|>\n"
              f"<|im_start|>assistant\n<think>\n")
    target = f"{ex['think']}\n</think>\n\n{ex['content']}<|im_end|>"
    p = tok(prompt, add_special_tokens=False)["input_ids"]
    t = tok(target, add_special_tokens=False)["input_ids"]
    ids = torch.tensor([p + t]).cuda()
    labels = torch.tensor([[-100] * len(p) + t]).cuda()
    with torch.no_grad():
        loss = model(input_ids=ids, labels=labels).loss
    losses.append(loss.item())
print("=" * 70)
print("per-example loss:", [round(l, 2) for l in losses])
print(f"mean loss {sum(losses) / len(losses):.3f}")
