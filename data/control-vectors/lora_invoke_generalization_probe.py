#!/usr/bin/env python3
"""generalization test (advisor-recommended follow-up to lora_invoke_probe.py):
does the trained lora's confidence boost on the invoke idiom transfer to
NOVEL module-name/call-site strings never seen verbatim in the training
corpus, or is it memorization of the 6 example lines the first probe used?
same teacher-forced-logprob method, same THINK_OPEN/CLOSER scaffold, same
training-style instruction prefixes -- only the held-out CONTENT differs.
"""

import glob
import re
import torch
from transformers import AutoTokenizer, AutoConfig, Qwen3_5ForCausalLM, BitsAndBytesConfig
from peft import PeftModel

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"
CORPUS = "/data/projects/protocol-7/data/idioms/corpus/mined.curated.sft.txt"
ADAPTERS = {
    "attempt2-real": "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-real/adapter",
    "attempt4-invoke-oversampled": "/data/projects/protocol-7/data/control-vectors/lora-out/p7-idioms-invoke-oversampled/adapter",
}

THINK_OPEN = "<think>\n"
THINK_CLOSER = "\n</think>\n\n"
ASSISTANT_MARKER = "<|im_start|>assistant\\n"
INVOKE_RE = re.compile(r"<\[[\w.\-]+\]>->\(")

## same training-style instruction prefixes, reused verbatim (this is the   ##
## exact scaffold trained on) -- only the CONTENT after them is genuinely   ##
## novel, never-seen-verbatim held-out code from src/*, not from the corpus ##
PREFIX_TEMPLATES = [
    "<|im_start|>system\\nYou are a protocol-7 developer.<|im_end|>\\n<|im_start|>user\\nUpdate this Perl fragment to match how the rest of protocol-7 writes this kind of code.\\n\\n{snippet}<|im_end|>\\n" + ASSISTANT_MARKER,
    "<|im_start|>system\\nYou are a protocol-7 developer.<|im_end|>\\n<|im_start|>user\\nBring this piece of protocol-7 code in line with the codebase's established style.\\n\\n{snippet}<|im_end|>\\n" + ASSISTANT_MARKER,
]


def unescape(t):
    return t.replace("\\n", "\n")


## build the set of idiom strings already seen verbatim in training ##
corpus_text = open(CORPUS, encoding="utf-8").read()
seen_idioms = set(m.group(0) for m in INVOKE_RE.finditer(corpus_text))

## mine genuinely novel (idiom, surrounding-context) pairs from src/* ##
novel = []
for path in sorted(glob.glob("/data/projects/protocol-7/src/*")):
    try:
        text = open(path, encoding="utf-8", errors="ignore").read()
    except Exception:
        continue
    if text in corpus_text:
        continue
    lines = text.split("\n")
    for i, line in enumerate(lines):
        for m in INVOKE_RE.finditer(line):
            idiom = m.group(0)
            if idiom in seen_idioms or idiom in corpus_text:
                continue
            ## a couple lines of naive "before" context = the target line   ##
            ## itself minus the invoke call, framed as ordinary perl -- we  ##
            ## don't have a genuine naive/pre-p7-style "before" for these   ##
            ## (they're already p7 code), so use the actual surrounding     ##
            ## lines as the "fragment to bring in line with style" prompt.  ##
            ## this still tests transfer of the scaffold -> idiom trigger   ##
            ## to unseen module names, which is exactly what's in question  ##
            context_lines = lines[max(0, i - 1) : i + 2]
            snippet = "\n".join(l.rstrip() for l in context_lines if l.strip())
            if len(snippet) > 400:
                continue
            novel.append((path, idiom, snippet, "\n".join(context_lines)))
            break
    if len(novel) >= 40:
        break

## dedupe by idiom's module name to get variety, cap at 6 ##
picked = []
seen_mods = set()
for path, idiom, snippet, full_line in novel:
    mod = idiom.split("]>")[0].lstrip("<[")
    if mod in seen_mods:
        continue
    seen_mods.add(mod)
    picked.append((path, idiom, snippet, full_line))
    if len(picked) >= 6:
        break

print(f"[gen-probe] {len(picked)} novel held-out invoke call sites picked, none of these exact idiom strings appear anywhere in the training corpus")
for path, idiom, snippet, full_line in picked:
    print(f"  {path}  idiom={idiom!r}")

examples = []
for idx, (path, idiom, snippet, full_line) in enumerate(picked):
    prefix_text = PREFIX_TEMPLATES[idx % len(PREFIX_TEMPLATES)].format(snippet=snippet)
    prefix_text = unescape(prefix_text)
    content_text = full_line  ## teacher-force on the REAL held-out line containing the novel idiom ##
    matches = list(INVOKE_RE.finditer(content_text))
    if matches:
        examples.append((prefix_text, content_text, matches))

print(f"[gen-probe] {len(examples)} usable examples after assembly")

tok = AutoTokenizer.from_pretrained(BASE)

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
cfg = AutoConfig.from_pretrained(BASE)
text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

print("[gen-probe] loading base checkpoint in 4-bit ...")
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
                per_token.append({"tok": tok.decode([true_tok]), "logprob": lp, "is_top1": top1 == true_tok})
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
    if not results:
        print(f"\n=== {label} === NO MATCHES")
        return {"label": label, "mean_avg_logprob": float("nan"), "top1_rate": float("nan")}
    avg = sum(r["avg_logprob"] for r in results) / len(results)
    top1_rate = sum(sum(1 for t in r["per_token"] if t["is_top1"]) for r in results) / sum(r["n_tokens"] for r in results)
    print(f"\n=== {label} ===")
    print(f"  n_matches={len(results)}  mean(avg_logprob/token)={avg:.4f}  top1_rate={top1_rate:.3f}")
    for r in results:
        print(f"    [{r['match']!r}] avg_lp={r['avg_logprob']:.4f}  " + " ".join(f"{t['tok']!r}:{t['logprob']:.2f}{'*' if t['is_top1'] else ''}" for t in r["per_token"]))
    return {"label": label, "mean_avg_logprob": avg, "top1_rate": top1_rate}


summary_rows = []
print("\n[gen-probe] === condition: baseline (no adapter) ===")
summary_rows.append(summarize("baseline", eval_condition(base_model)))

import os

for name, path in ADAPTERS.items():
    if not os.path.exists(os.path.join(path, "adapter_model.safetensors")):
        print(f"\n[gen-probe] === condition: {name} === SKIPPED (safetensors missing)")
        continue
    print(f"\n[gen-probe] === condition: {name} ===")
    peft_model = PeftModel.from_pretrained(base_model, path)
    peft_model.eval()
    summary_rows.append(summarize(name, eval_condition(peft_model)))
    base_model = peft_model.unload()
    base_model.eval()
    torch.cuda.empty_cache()

print("\n\n================ GENERALIZATION SUMMARY (held-out, never-seen-verbatim idioms) ================")
print(f"{'condition':30s} {'mean_avg_logprob':>18s} {'top1_rate':>10s}")
for row in summary_rows:
    print(f"{row['label']:30s} {row['mean_avg_logprob']:18.4f} {row['top1_rate']:10.3f}")
print("=====================================================================================")

#,,.,,,..,.,,,,,.,..,,,,.,.,.,..,,.,,,.,,,,,.,..,,...,...,...,,.,,,..,..,,,..,
#UYY3ZUDJYS5MF7YS5XG3XALGTR2RZRBG5TDSRWYIK53VA3HFJXXMXHHWGO5EID5EDVVWIRPXPLDJI
#\\\|AP4JSLQA4ZT45HCBIIABPQWNQRJKEWOYZEBM2PV6WHV2KNHTIP7 \ / AMOS7 \ YOURUM ::
#\[7]UNAMPFKOKBBRMXZNYBFDRE7X3BD54Y7LSCJZIC5IHK5Y5CO33QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
