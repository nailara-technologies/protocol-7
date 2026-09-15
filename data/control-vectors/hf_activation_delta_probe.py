#!/usr/bin/env python3
"""HF-side adapter DELTA probe -- companion to eval-callback's GGUF-side
delta (see run_activation_delta_sweep.sh). NOT an absolute-activation
comparison: HF loads nf4 4-bit, GGUF loads Q8_0, and those are different
quantizations of the same weights -- the ninth pass already proved
quantization alone shifts activations (58.99% -> 64.60% baseline top1,
zero adapter involved). Absolute values are not comparable across the
two sides at any sample size. What IS comparable: each side's own
adapter-on minus adapter-off delta, since quantization noise is largely
common-mode within a side's own pair and cancels in the difference.

captures per-layer whole-tensor SUM of the l_out tensor (matches
eval-callback's own printed `sum = ` reduction line, no patching needed
on the GGUF side) at SSM layers {0, 16} and dense/full-attention layers
{3, 19} (full_attention_interval=4, dense = index % 4 == 3), adapter off
then on, same "The quick brown fox" prompt used in the tenth pass's
absolute-value comparison (kept for continuity, not because this specific
sentence matters -- this is a coarse structural check, not a replication
of the real invoke-idiom decision point).

loads 4-bit on GPU, same pattern as lora_invoke_probe.py -- NEVER fp32 on
CPU on this host, see the tenth pass's postmortem in
data/tasks/coding-lora-p7-idioms.md before touching this loading block.
"""
import sys
import torch
from transformers import AutoTokenizer, AutoConfig, Qwen3_5ForCausalLM, BitsAndBytesConfig
from peft import PeftModel

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"
ADAPTER = "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-real-attempt5/adapter"
LAYERS = [0, 16, 3, 19]  # SSM, SSM, dense, dense

PROMPT = sys.argv[1] if len(sys.argv) > 1 else "The quick brown fox"

tok = AutoTokenizer.from_pretrained(BASE)
ids = tok(PROMPT, add_special_tokens=False)["input_ids"]
print(f"prompt: {PROMPT!r} -> {len(ids)} tokens: {ids}")

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
cfg = AutoConfig.from_pretrained(BASE)
text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

print("[probe] loading base checkpoint in 4-bit on GPU ...")
base_model = Qwen3_5ForCausalLM.from_pretrained(
    BASE, config=text_cfg, quantization_config=bnb, device_map={"": 0}, dtype=torch.bfloat16
)
base_model.eval()
base_model.config.use_cache = False

print("[probe] attaching attempt5 adapter ...")
model = PeftModel.from_pretrained(base_model, ADAPTER)
model.eval()

captured = {}

def make_hook(name):
    def hook(module, inp, out):
        hs = out[0] if isinstance(out, tuple) else out
        captured[name] = hs.detach().float().sum().item()  # whole-tensor sum, all positions
    return hook

layers = model.base_model.model.model.layers
handles = [layers[i].register_forward_hook(make_hook(f"layer{i}")) for i in LAYERS]

input_ids = torch.tensor([ids], device=model.device)

results = {}
with torch.no_grad():
    with model.disable_adapter():
        model(input_ids=input_ids)
        for i in LAYERS:
            results[f"layer{i}_off"] = captured[f"layer{i}"]

    model(input_ids=input_ids)
    for i in LAYERS:
        results[f"layer{i}_on"] = captured[f"layer{i}"]

for h in handles:
    h.remove()

print()
print(f"{'layer':<8}{'type':<8}{'sum_off':>14}{'sum_on':>14}{'delta':>14}")
for i in LAYERS:
    kind = "dense" if i % 4 == 3 else "ssm"
    off = results[f"layer{i}_off"]
    on = results[f"layer{i}_on"]
    print(f"{i:<8}{kind:<8}{off:>14.4f}{on:>14.4f}{on - off:>14.4f}")

#,,..,,.,,...,,.,,,,.,,,.,,,,,.,,,,,,,..,,...,..,,...,...,..,,.,.,.,,,.,,,.,,,
#VEWZ7MM7WF2BS5GBTDG34YG7KS4LVVU3X6OWSDDL47DL4XAS63DX5HB4EEUXFT3MN7WALV36MJJWE
#\\\|UA4YSHWZ4XMQPZAUFDXFNDSGYYTIBQTCACILHAL2VT5S5BLCX2X \ / AMOS7 \ YOURUM ::
#\[7]UFLCEB5S57AN7ZBIOSU55SWSK2QFV55N2GKNIZYCR5VBMVTBP4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
