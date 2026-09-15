#!/usr/bin/env python3
"""live position-matched teacher-forced probe (single decisive position):

reproduces the exact methodology from coding-lora-p7-idioms.md's sixth-pass
serve+revalidate step, previously run inline in a session transcript (now
saved as a standalone tool so the comparison is reproducible):

- context: the same training-style edit prompt + immediate-think-close
  scaffold the HF probes use (prefix_raw + THINK_OPEN + THINK_CLOSER)
- content: the real corpus example whose first invoke call is
  `<[file.zenka_dir.write]>->(` (the "stage to zenka dir" example)
- the prompt is cut at the EXACT token boundary right before the first
  token of the invoke match (scored token = ' <', id 361), and sent to
  the live server's /completion endpoint as RAW TOKEN IDS -- never as a
  string. two earlier attempts at this comparison used string prompts and
  were invalidated by boundary retokenization artifacts (the trailing
  whitespace + ' <' retokenize differently when the server re-tokenizes
  the cut string), giving '# '/'##' ~28%/26% instead of the true ' my'
  ~59.7% baseline top1. do not "simplify" this back to a string prompt.

usage: run against the live server in whatever condition it is currently
in (baseline no-adapter, or lora-on), label the run via argv[1].
reference numbers (sixth pass, poisoned attempt4 adapter, ge525 base):
  live baseline AND live poisoned-lora-on: ' my' ~59.7% top1, ' <' not
  in top-15 -- zero measurable adapter effect.
  HF/PEFT, same position, poisoned attempt4 adapter: ' <' ~62.5% top1.
attempt 5 HF/PEFT reference (this session, intact checkpoint):
  baseline ' <' logprob -11.72 (~0.001%), attempt5 adapter ' <' -0.20
  (81.9% top1) -- see lora_invoke_probe.py's example 3.
"""

import json
import re
import sys
import urllib.request

from transformers import AutoTokenizer

BASE = "/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic"
SERVER = "http://127.0.0.1:8000"

prefix_raw = (
    "<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n"
    "<|im_start|>user\nUpdate this Perl fragment to match how the rest of "
    "protocol-7 writes this kind of code.\n\n"
    "return 'error: cannot write file';<|im_end|>\n"
    "<|im_start|>assistant\n"
)
THINK_OPEN = "<think>\n"
THINK_CLOSER = "\n</think>\n\n"
content_text = (
    "            ## stage to zenka dir when no write access ##\n"
    "            my $stage_name = $path;\n"
    "            $stage_name =~ s|/|__|g;\n"
    "            my $stage_rel = \"staged/$stage_name\";\n"
    "            <[file.zenka_dir.write]>->( $stage_rel, \\$new_content );\n"
    "            <[base.logs]>->(\n"
    "                1, "
)

INVOKE_RE = re.compile(r"<\[[\w.\-]+\]>->\(")


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "unlabeled"
    tok = AutoTokenizer.from_pretrained(BASE)

    context = prefix_raw + THINK_OPEN + THINK_CLOSER
    ctx_ids = tok(context, add_special_tokens=False)["input_ids"]
    enc = tok(content_text, add_special_tokens=False, return_offsets_mapping=True)
    content_ids = enc["input_ids"]
    offsets = enc["offset_mapping"]

    m = list(INVOKE_RE.finditer(content_text))[0]
    start_char, end_char = m.span()
    tok_idx = [i for i, (s, e) in enumerate(offsets) if e > start_char and s < end_char]
    first_tok = tok_idx[0]
    print(f"[{label}] match={m.group(0)!r}")
    print(f"[{label}] token right before match: {tok.decode([content_ids[first_tok-1]])!r}")
    print(f"[{label}] scored token: {tok.decode([content_ids[first_tok]])!r} id={content_ids[first_tok]}")
    assert tok.decode([content_ids[first_tok]]) == " <", "scored token drifted from the reference ' <'"

    full_prefix_ids = ctx_ids + content_ids[:first_tok]
    print(f"[{label}] total prefix token count: {len(full_prefix_ids)} (reference: 105)")

    payload = {
        "prompt": full_prefix_ids,  ## raw token ids, NOT a string -- see docstring
        "n_predict": 1,
        "n_probs": 15,
        "temperature": 0.0,
        "cache_prompt": False,
    }
    req = urllib.request.Request(
        f"{SERVER}/completion",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        d = json.load(resp)
    print(f"[{label}] top-15 at the scored position:")
    for p in d["completion_probabilities"][0]["probs"]:
        print(f"  {p['tok_str']!r:20s} {p['prob']:.4f}")


if __name__ == "__main__":
    main()

#,,,,,,,,,..,,.,,,,.,,.,.,...,,,,,,,.,,.,,.,.,..,,...,...,,,.,,,,,,..,,,.,.,.,
#GMD3HRAFC5BXUXHW5RWK77LEZ6UQDCJJZ3DINCJ7AFIZV6O33BY5CRVMRJGXXEMMYCER6BAY6GJO4
#\\\|466PKN5FEXT43XFBXPFGQZ6E5PZGV76QJST4NORAA4YL6FBSHZC \ / AMOS7 \ YOURUM ::
#\[7]W4PXEBKTF5NTDAPN3K4WV2NI4WOGXDBVN4UBPFJAE3A3U4CL6OBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
