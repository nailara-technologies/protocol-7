#!/usr/bin/env python3
"""single bounded HF-side activation probe, matched against
data/control-vectors's eval-callback CPU run for "The quick brown fox"
(4 tokens, no BOS, ids [760, 3841, 13477, 37550]).

captures: input embedding for token 0 ("The"), and hidden state at
position 0 after layer 0 (SSM/delta-net layer) and after layer 3
(dense full-attention layer, full_attention_interval=4) -- position 0
only, since causal masking means position 0's value through pure
attention is independent of later tokens, minimizing alignment risk
between the two implementations. no adapter -- base model only.

loads 4-bit on GPU (device_map={"": 0}, bnb nf4 + bf16 compute), the
SAME pattern every other HF probe in this thread uses -- an earlier
attempt at this loaded fp32 on CPU (~36GB for a 9B model) on a 15GB-RAM
host and very plausibly contributed to a real host-stability incident.
never repeat that: always match lora_invoke_probe.py's loading pattern.
"""
import torch
from transformers import AutoTokenizer, AutoConfig, Qwen3_5ForCausalLM, BitsAndBytesConfig

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"

tok = AutoTokenizer.from_pretrained(BASE)
ids = tok("The quick brown fox", add_special_tokens=False)["input_ids"]
print("token ids:", ids)
assert ids == [760, 3841, 13477, 37550], "tokenization drifted from the eval-callback reference"

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
cfg = AutoConfig.from_pretrained(BASE)
text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

print("[probe] loading base checkpoint in 4-bit on GPU ...")
model = Qwen3_5ForCausalLM.from_pretrained(
    BASE, config=text_cfg, quantization_config=bnb, device_map={"": 0}, dtype=torch.bfloat16
)
model.eval()
model.config.use_cache = False

captured = {}

def make_hook(name):
    def hook(module, inp, out):
        hs = out[0] if isinstance(out, tuple) else out
        captured[name] = hs[0, 0, :8].detach().float().cpu().tolist()  # position 0, first 8 dims
    return hook

layers = model.model.layers
h0 = layers[0].register_forward_hook(make_hook("layer0_out"))
h3 = layers[3].register_forward_hook(make_hook("layer3_out"))

embed = model.get_input_embeddings()
emb_vec = embed(torch.tensor([ids], device=model.device))[0, 0, :8].detach().float().cpu().tolist()
print("input embedding (token 760, first 8 dims):", [round(v, 4) for v in emb_vec])

with torch.no_grad():
    model(input_ids=torch.tensor([ids], device=model.device))

h0.remove()
h3.remove()

for name in ("layer0_out", "layer3_out"):
    print(f"{name} (position 0, first 8 dims):", [round(v, 4) for v in captured[name]])

#,,.,,,,,,,,,,...,,,.,,,.,.,.,.,.,.,,,..,,,..,..,,...,...,,.,,.,,,,..,..,,,..,
#YVAVEAU6W7NPVSM6ZJMBB7ZPCTA5G4BUUHGW36FJL7BYPB3UP5TC67DFIJQ7THCL67BPUUWSVSV4O
#\\\|LAGNNDV6B7F2R4DCTLPHEADZJ3UGYVMRVNTPAHLJOV3Y6PS4Q2Q \ / AMOS7 \ YOURUM ::
#\[7]R254NSWAVMOC42O5WFBCJRQP4DZQTVBYRXG25S73AGC7GAQ7IUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
