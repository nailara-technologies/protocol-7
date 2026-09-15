#!/usr/bin/env python3
"""position-matched teacher-forced probe, HF/PEFT half (diagnostic, no training).

the EXACT methodology of coding-lora-p7-idioms.md's sixth-pass serve+revalidate
step, made repeatable: the prompt is cut at the precise token boundary right
before the invoke idiom's leading ' <' token, and the prompt is fed as RAW
TOKEN-IDS (never re-stringified -- string prompts can retokenize differently at
the cut, which invalidated two earlier attempts at this comparison). prints the
top-15 next-token distribution at that position for the intact base vs the
adapter, so the result is directly comparable token-for-token with a live
llama-server /completion query using the same token-id array.

reference (poisoned attempt4 adapter, sixth pass): HF/PEFT gave ' <' 60.4%
top1 at this position; live ge525 gave ' my' ~59-60% WITH and WITHOUT the
adapter -- zero measurable transfer.
"""

import json
import sys

import torch
from transformers import AutoConfig, AutoTokenizer, BitsAndBytesConfig, Qwen3_5ForCausalLM
from peft import PeftModel

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"
ADAPTER = (
    "/data/projects/protocol-7/data/control-vectors/lora-out/"
    "p7-idioms-real-attempt5/adapter"
)
# raw token-id prompt copied verbatim from the sixth-pass scratchpad
# (probs_req_tokenized.json) -- ends at the token before the ' <' of
# `            <[file.zenka_dir.write]>->(` ; DO NOT retokenize from string.
TOK_PROMPT = json.load(open("/tmp/attempt5_posmatch_tokenized.json"))["prompt"]

tok = AutoTokenizer.from_pretrained(BASE)
print(f"[posmatch] prompt tail tokens: {tok.decode(TOK_PROMPT[-6:])!r}")
print(f"[posmatch] next expected token if invoke idiom: ' <' id={tok.convert_tokens_to_ids(' <')}")

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
cfg = AutoConfig.from_pretrained(BASE)
text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

base_model = Qwen3_5ForCausalLM.from_pretrained(
    BASE, config=text_cfg, quantization_config=bnb, device_map={"": 0}, dtype=torch.bfloat16
)
base_model.eval()
base_model.config.use_cache = False


@torch.no_grad()
def next_token_topk(model, k=15):
    ids = torch.tensor([TOK_PROMPT], device=model.device)
    logits = model(input_ids=ids).logits[0, -1].float()
    probs = torch.softmax(logits, dim=-1)
    top_p, top_i = torch.topk(probs, k)
    return [(tok.decode([int(i)]), float(p)) for p, i in zip(top_p, top_i)]


def report(label, model):
    print(f"\n=== {label} ===")
    for text, p in next_token_topk(model):
        marker = " <== INVOKE-IDIOM START" if text == " <" else ""
        print(f"  {p * 100:6.2f}%  {text!r}{marker}")


report("baseline (intact petruhonk checkpoint, no adapter)", base_model)

peft_model = PeftModel.from_pretrained(base_model, ADAPTER)
peft_model.eval()
report("attempt5 adapter on intact checkpoint", peft_model)

#,,,,,.,,,..,,,,,,...,.,.,..,,,,.,,,.,...,,,,,..,,...,..,,.,.,,.,,...,..,,,..,
#A3KHT6PEBB3UXD2P7KMNSBUMORDL7I4S267FM4BTWNIFJFPW2CCAYP57UMYFVCYUE4XT7SMAKJDLE
#\\\|XR6PASD6ZWP65EIEQHHR36KVY244RI27VWMDWRYIKBNJXJB4M4B \ / AMOS7 \ YOURUM ::
#\[7]NQFSVUBCOEJSHXODURXUYUO2EZHV3T23CLLBLZT53QKXVFJVMKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
