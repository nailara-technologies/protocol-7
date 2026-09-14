#!/usr/bin/env python3
"""diagnostic probe (not training): does the model's actual token-level
probability for the p7 `<[module.name]>->(` invoke idiom move AT ALL across
lora attempts 2/3/4, on real in-distribution training examples, teacher
forced? distinguishes "not learned correctly" from "genuine capacity
ceiling" for data/tasks/coding-lora-p7-idioms.md. no training, forward
passes only.
"""

import re
import torch
from transformers import AutoTokenizer, AutoConfig, Qwen3_5ForCausalLM, BitsAndBytesConfig
from peft import PeftModel

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"
CORPUS = "/data/projects/protocol-7/data/idioms/corpus/mined.curated.sft.txt"
ADAPTERS = {
    "attempt2-real": "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-real/adapter",
    "attempt3-lmhead": "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-real-lmhead/adapter",
    "attempt4-invoke-oversampled": "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-invoke-oversampled/adapter",
}

THINK_OPEN = "<think>\n"
THINK_CLOSER = "\n</think>\n\n"
ASSISTANT_MARKER = "<|im_start|>assistant\\n"

INVOKE_RE = re.compile(r"<\[[\w.\-]+\]>->\(")


def unescape(t):
    return t.replace("\\n", "\n")


def load_examples(path, limit=6):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or ASSISTANT_MARKER not in line:
                continue
            prefix_raw, content_raw = line.split(ASSISTANT_MARKER, 1)
            prefix_text = unescape(prefix_raw) + "<|im_start|>assistant\n"
            content_text = unescape(content_raw)
            matches = list(INVOKE_RE.finditer(content_text))
            if matches:
                out.append((prefix_text, content_text, matches))
            if len(out) >= limit:
                break
    return out


examples = load_examples(CORPUS, limit=6)
print(f"[probe] {len(examples)} examples with an invoke idiom in the target span")

tok = AutoTokenizer.from_pretrained(BASE)

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
cfg = AutoConfig.from_pretrained(BASE)
text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

print("[probe] loading base checkpoint in 4-bit ...")
base_model = Qwen3_5ForCausalLM.from_pretrained(
    BASE, config=text_cfg, quantization_config=bnb, device_map={"": 0}, dtype=torch.bfloat16
)
base_model.eval()
base_model.config.use_cache = False


@torch.no_grad()
def eval_condition(model):
    per_match = []
    for prefix_text, content_text, matches in examples:
        context = prefix_text + THINK_OPEN + THINK_CLOSER
        ctx_ids = tok(context, add_special_tokens=False)["input_ids"]
        enc = tok(content_text, add_special_tokens=False, return_offsets_mapping=True)
        content_ids = enc["input_ids"]
        offsets = enc["offset_mapping"]

        full_ids = ctx_ids + content_ids
        input_ids = torch.tensor([full_ids], device=model.device)
        out = model(input_ids=input_ids)
        logits = out.logits[0].float()
        logprobs = torch.log_softmax(logits, dim=-1)

        offset0 = len(ctx_ids)
        for m in matches:
            start_char, end_char = m.span()
            tok_idx = [i for i, (s, e) in enumerate(offsets) if e > start_char and s < end_char]
            if not tok_idx:
                continue
            per_token = []
            lp_sum = 0.0
            for i in tok_idx:
                pred_pos = offset0 + i - 1
                true_tok = content_ids[i]
                lp = logprobs[pred_pos, true_tok].item()
                top1 = int(torch.argmax(logprobs[pred_pos]).item())
                per_token.append(
                    {
                        "tok": tok.decode([true_tok]),
                        "logprob": lp,
                        "is_top1": top1 == true_tok,
                    }
                )
                lp_sum += lp
            per_match.append(
                {
                    "match": m.group(0),
                    "n_tokens": len(tok_idx),
                    "sum_logprob": lp_sum,
                    "avg_logprob": lp_sum / len(tok_idx),
                    "per_token": per_token,
                }
            )
        del out, logits, logprobs
        torch.cuda.empty_cache()
    return per_match


def summarize(label, results):
    avg = sum(r["avg_logprob"] for r in results) / len(results)
    sum_lp = sum(r["sum_logprob"] for r in results)
    top1_rate = sum(sum(1 for t in r["per_token"] if t["is_top1"]) for r in results) / sum(
        r["n_tokens"] for r in results
    )
    print(f"\n=== {label} ===")
    print(f"  n_matches={len(results)}  mean(avg_logprob/token)={avg:.4f}  sum_logprob(all)={sum_lp:.4f}  top1_rate={top1_rate:.3f}")
    for r in results:
        print(f"    [{r['match']!r}] avg_lp={r['avg_logprob']:.4f}  " + " ".join(f"{t['tok']!r}:{t['logprob']:.2f}{'*' if t['is_top1'] else ''}" for t in r["per_token"]))
    return {"label": label, "mean_avg_logprob": avg, "sum_logprob": sum_lp, "top1_rate": top1_rate}


summary_rows = []

print("\n[probe] === condition: baseline (no adapter) ===")
base_results = eval_condition(base_model)
summary_rows.append(summarize("baseline", base_results))

import os

for name, path in ADAPTERS.items():
    if not os.path.exists(os.path.join(path, "adapter_model.safetensors")):
        print(f"\n[probe] === condition: {name} === SKIPPED (adapter_model.safetensors missing on disk, only gguf remains)")
        continue
    print(f"\n[probe] === condition: {name} ===")
    peft_model = PeftModel.from_pretrained(base_model, path)
    peft_model.eval()
    results = eval_condition(peft_model)
    summary_rows.append(summarize(name, results))
    base_model = peft_model.unload()
    base_model.eval()
    torch.cuda.empty_cache()

print("\n\n================ SUMMARY ================")
print(f"{'condition':30s} {'mean_avg_logprob':>18s} {'sum_logprob':>14s} {'top1_rate':>10s}")
for row in summary_rows:
    print(f"{row['label']:30s} {row['mean_avg_logprob']:18.4f} {row['sum_logprob']:14.4f} {row['top1_rate']:10.3f}")
print("===========================================")
print("higher (less negative) logprob / higher top1_rate = model MORE confident in the")
print("invoke idiom tokens under that condition, teacher-forced on real in-distribution data.")

#,,.,,,..,...,,..,.,.,...,,,.,...,,.,,.,.,...,..,,...,...,,.,,.,.,...,.,,,,,.,
#5ZVEUEKVPJV2PED6J6PKBBLI2EDBNZ363ROM5JDMWV2Z3UHIT7VUUST5ERXTGUIA6HLTHIALBDIS6
#\\\|K7YOJW5RNFDE6H3SBWAJMPVNUQBHRP3YGLSS3SPHOLB5SP3KRRN \ / AMOS7 \ YOURUM ::
#\[7]KWCSGNI5EQP5PNAE2HVV7KOO5UFOXMBFHRN7HNNMFCGNBXFZC4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
