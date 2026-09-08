#!/usr/bin/env python3
## score.py -- fixed idiom rubric, decided BEFORE any experiment generation :
## count, per response [ content field only, think block excluded ], the
## occurrences of :
##   1. <[module.name]>->(  invocation sugar
##   2. <config.key>        bare config access [ angle brackets, no [ ] ]
##   3. TRUE / FALSE        named constants [ not 1 / 0 ]
##   4. ## lowercase        comment lines starting '## ' + lowercase/[
##   5. [ bracket ]         annotations
##   6. :flag:              colon-bracket flag syntax
##   7. a.b.c               dot-separated module names
##   8. mode/data           reply shape [ 'mode' => ... 'data' => ... ]
## supporting anti-idiom counters [ expected to move the OTHER way ] :
##   --flag options, :: module refs, capitalized '# ' comments, bare
##   'return 1' / 'return 0' booleans, success=>/error=> reply keys
import json, re, sys, glob, os

RUBRIC = {
    'invoke':    re.compile(r'<\[[\w.]+\]>->\('),
    'cfgaccess': re.compile(r'<(?!\[)[a-z][\w.]+>'),
    'truefalse': re.compile(r'\b(?:TRUE|FALSE)\b'),
    'comment':   re.compile(r'## [a-z\[]'),
    'bracket':   re.compile(r'\[ [\w][^\]\n]{0,60}? \]'),
    'colonflag': re.compile(r':[a-z][a-z0-9-]*:'),
    'dotmodule': re.compile(r'\b[a-z][a-z0-9_]*(?:\.[a-z0-9_]+){2,}\b'),
    'modedata':  None,  ## presence-based, handled below
}
ANTI = {
    'dashflag':  re.compile(r'--[a-z][a-z-]+'),
    'coloncolon': re.compile(r'\b[A-Z][\w]*(?:::[\w]+)+'),
    'capcomment': re.compile(r'(?m)^\s*# [A-Z]'),
    'barebool':  re.compile(r'\breturn [01]\b'),
    'successkey': re.compile(r'\b(?:success|error)\s*=>'),
}

def score_text(text):
    s = {k: len(rx.findall(text)) for k, rx in RUBRIC.items() if rx}
    s['modedata'] = 1 if ("'mode'" in text and "'data'" in text) else 0
    a = {k: len(rx.findall(text)) for k, rx in ANTI.items()}
    return s, a

def score_dir(d):
    rows = []
    for f in sorted(glob.glob(os.path.join(d, '*.json'))):
        try:
            data = json.load(open(f))
            msg = data['choices'][0]['message']
            text = msg.get('content') or ''
        except Exception as e:
            print(f"{os.path.basename(f)}: UNREADABLE {e}")
            continue
        s, a = score_text(text)
        prompt = os.path.basename(f).split('.')[0]
        rows.append((prompt, os.path.basename(f), s, a, len(text)))
    return rows

if __name__ == '__main__':
    for d in sys.argv[1:]:
        rows = score_dir(d)
        tot = {}
        ant = {}
        print(f"== {d} [{len(rows)} generations]")
        for prompt, name, s, a, ln in rows:
            score = sum(s.values())
            ascore = sum(a.values())
            print(f"  {name:18s} idiom={score:3d} anti={ascore:3d} "
                  + " ".join(f"{k[:4]}={v}" for k, v in s.items()))
            for k, v in s.items(): tot[k] = tot.get(k, 0) + v
            for k, v in a.items(): ant[k] = ant.get(k, 0) + v
        if rows:
            n = len(rows)
            print(f"  TOTAL idiom={sum(tot.values())}  anti={sum(ant.values())}")
            print(f"  per-category totals: " + ", ".join(f"{k}={v}" for k, v in tot.items()))
            print(f"  anti-category totals: " + ", ".join(f"{k}={v}" for k, v in ant.items()))

#,,..,.,,,,..,.,,,,.,,,,.,,,.,,,,,,.,,,.,,...,..,,...,.,.,.,,,,.,,,..,...,,,.,
#2LUY3YTVXTEKYQXTKWS32DRXHSA6F5ODIXXPOLQCGSKA276GJ2E5M32R4P2CKM5AIJWXEPTPZGPQO
#\\\|CKLNXW5E6XWXC4DXV2QR5P666AUFQJBZOR6URQGGE7CP44H3DN6 \ / AMOS7 \ YOURUM ::
#\[7]MSRZ2D7PIGNK56ZV3I5GVACKSRO6THBO3ND4IBSS4RMI277W46DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
