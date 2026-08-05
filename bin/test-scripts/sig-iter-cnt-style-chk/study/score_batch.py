#!/usr/bin/env python3
## blind quality scoring driver : sends each stripped sample file to the
## local 9B inference server [ same backend the coding zenka uses ] with a
## fixed rubric. the scorer never sees the signature footer / iteration
## count [ stripped in scratch/ copies ]. writes scores.tsv incrementally.

import csv
import json
import os
import re
import subprocess
import time

HERE = os.path.dirname(os.path.abspath(__file__))
URL = "http://127.0.0.1:8000/v1/chat/completions"
MODEL = "ZDMAPAY:AR3OCKQ"

PROMPT = """You are scoring a Perl module from the Protocol-7 codebase for code quality.

Criteria:
- STYLE [ 0-4 ] : project conventions : lowercase comments, [ square bracket ] annotations, 78-column limit, qw| | string style, consistent spacing and alignment.
- COMMENTS [ 0-3 ] : file starts with a header holding name + descr, comments explain why rather than what, concise.
- STRUCTURE [ 0-3 ] : defensive coding [ checks before use, // defaults ], clear control flow, no dead code, minimal complexity.

Reply with ONLY these 4 lines, an integer after each colon, nothing else:
STYLE:
COMMENTS:
STRUCTURE:
TOTAL:

MODULE SOURCE:
"""


def score_file(sid, content):
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": PROMPT + content}],
        "max_tokens": 200,
        "temperature": 0.2,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    r = subprocess.run(
        ["curl", "-s", "--noproxy", "*", "-m", "300", URL,
         "-H", "Content-Type: application/json", "-d", json.dumps(body)],
        capture_output=True, text=True, env={"PATH": "/usr/bin:/bin"})
    try:
        resp = json.loads(r.stdout)
        text = resp["choices"][0]["message"].get("content", "")
    except Exception:
        return None, r.stdout[:200]
    scores = {}
    for key in ("STYLE", "COMMENTS", "STRUCTURE", "TOTAL"):
        m = re.search(key + r":\s*(\d+)", text)
        scores[key] = int(m.group(1)) if m else None
    if any(v is None for v in scores.values()):
        return None, text[:200]
    return scores, text


def main():
    rows = list(csv.DictReader(open(f"{HERE}/sample.tsv"), delimiter="\t"))
    done = set()
    outpath = f"{HERE}/scores.tsv"
    if os.path.exists(outpath):
        for line in open(outpath):
            done.add(line.split("\t")[0])
    out = open(outpath, "a")
    if not done:
        out.write("id\tstyle\tcomments\tstructure\ttotal\traw\n")
    n = 0
    for r in rows:
        sid = r["id"]
        if sid in done:
            continue
        content = open(f"{HERE}/scratch/{sid}").read()[:8000]
        scores, raw = score_file(sid, content)
        if scores is None:  # one retry after a pause
            time.sleep(5)
            scores, raw = score_file(sid, content)
        if scores is None:
            out.write(f"{sid}\t\t\t\t\tPARSE_FAIL:{raw!r}\n")
        else:
            raw_clean = re.sub(r"\s+", " ", raw)[:120]
            out.write(f"{sid}\t{scores['STYLE']}\t{scores['COMMENTS']}\t"
                      f"{scores['STRUCTURE']}\t{scores['TOTAL']}\t{raw_clean}\n")
        out.flush()
        n += 1
        if n % 10 == 0:
            print(f"[score] {n} done, id={sid}", flush=True)
        time.sleep(0.3)
    out.close()
    print(f"[score] complete: {n} files")


if __name__ == "__main__":
    main()

#,,.,,.,,,.,,,,..,.,.,,,.,,,,,.,,,..,,,..,...,..,,...,...,...,,,,,.,,,,.,,,,,,
#2QT3JHA3E2ZRWEE2O652VSVVGSUYX63R7T7YGTMNFWJD3OPLD6ICS5SPJBWMDZYV7KBHDF2DUFATW
#\\\|THCQQUC2HJITCR3V2H45OHSSVHDJMPDVG4AKE2L7GVYWDLKFZNX \ / AMOS7 \ YOURUM ::
#\[7]GUY3K26PRPXKR3NDIVWOUQCFXBJTYQG54GQCVG66K7F2QCBIHGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
