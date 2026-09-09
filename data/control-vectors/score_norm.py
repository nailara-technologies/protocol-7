#!/usr/bin/env python3
## score_norm.py -- length-normalized reporting wrapper around score.py
##
## score.py is the PRE-REGISTERED instrument and stays byte-for-byte
## unchanged. it happens to compute len(text) into its rows but never
## prints it, so this wrapper imports score_dir / score_text and does the
## normalization here instead of editing the instrument.
##
## reporting rules this enforces, from the two prior tasks' hazards:
##
##   * the four STRUCTURAL categories are reported separately and are
##     NEVER summed. `modedata` is presence-based [ 0 or 1 per response,
##     so it caps at n ] while invoke / cfgaccess / truefalse are unbounded
##     counts -- a sum would be dominated by whichever is countable.
##   * `comment` and `bracket` are shown apart from the rest : the
##     2026-09-09 addendum found both confounded by the production
##     prompt's own '## header ##' style being echoed back.
##   * a supplementary UNQUOTED modedata count is shown beside the frozen
##     rubric's quoted-only one. score.py tests "'mode'" and "'data'" with
##     literal quotes; real src/ uses the bare form 122 times and the model
##     emits the bare form too, so the frozen number understates this
##     category. the frozen number is still the one of record.
##
## usage:  score_norm.py <results-dir> [...]

import os, re, sys, glob, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from score import score_dir, score_text          # noqa: E402  [ frozen ]

STRUCTURAL = ['invoke', 'cfgaccess', 'truefalse', 'modedata']
SURFACE = ['comment', 'bracket', 'colonflag', 'dotmodule']

## supplementary only -- NOT part of the frozen rubric
RX_BARE_MODEDATA = re.compile(r'(?<![\w\'"])mode\s*=>')
RX_BARE_DATA = re.compile(r'(?<![\w\'"])data\s*=>')
RX_ANY_MODE = re.compile(r'[\'"]?mode[\'"]?\s*=>')
RX_ANY_DATA = re.compile(r'[\'"]?data[\'"]?\s*=>')


def supplementary(d):
    """counts the frozen rubric cannot see. reported separately, labelled."""
    n_bare = n_any = 0
    for f in sorted(glob.glob(os.path.join(d, '*.json'))):
        try:
            text = json.load(open(f))['choices'][0]['message'].get('content') or ''
        except Exception:
            continue
        if RX_BARE_MODEDATA.search(text) and RX_BARE_DATA.search(text):
            n_bare += 1
        if RX_ANY_MODE.search(text) and RX_ANY_DATA.search(text):
            n_any += 1
    return n_bare, n_any


def report(d):
    rows = score_dir(d)
    if not rows:
        print(f"== {d} : no generations")
        return
    n = len(rows)
    tot, chars = {}, 0
    for _prompt, _name, s, _a, ln in rows:
        chars += ln
        for k, v in s.items():
            tot[k] = tot.get(k, 0) + v

    print(f"== {d}  [ n={n}, {chars} chars total, "
          f"{chars/n:.0f} mean ]")

    print("   -- STRUCTURAL [ the number that answers whether this worked ] --")
    for k in STRUCTURAL:
        v = tot.get(k, 0)
        if k == 'modedata':
            ## presence-based : a rate, never a per-1000-chars figure
            print(f"     {k:10s} raw={v:4d}   rate={v}/{n}"
                  f"   [ presence-based, caps at {n} ]")
        else:
            per1k = (1000.0 * v / chars) if chars else 0.0
            print(f"     {k:10s} raw={v:4d}   per1k={per1k:6.3f}")

    print("   -- surface [ confounded by the prompt's own style, do not "
          "read as idiom adherence ] --")
    for k in SURFACE:
        v = tot.get(k, 0)
        per1k = (1000.0 * v / chars) if chars else 0.0
        print(f"     {k:10s} raw={v:4d}   per1k={per1k:6.3f}")

    bare, any_form = supplementary(d)
    print("   -- supplementary [ NOT the frozen rubric ] --")
    print(f"     modedata_BARE_only    rate={bare}/{n}"
          f"   [ `mode =>` unquoted -- score.py scores this ZERO ]")
    print(f"     modedata_ANY_form     rate={any_form}/{n}"
          f"   [ quoted OR bare : actual reply-shape usage. compare this,"
          f" not the frozen number, when judging whether the model used"
          f" the idiom more ]")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("usage: score_norm.py <results-dir> [...]")
        sys.exit(2)
    for d in sys.argv[1:]:
        report(d)
        print()

#,,.,,,,.,..,,.,,,,,,,..,,,.,,,,.,.,,,.,,,.,,,..,,...,...,.,,,,.,,,..,.,,,...,
#L6ZRI572TBIMN4UEXTSSKLOL24QDNQ45BTVLNOE76LEWJKLCBT6YL72XG3GBKJQTDTN7DR36I5CPU
#\\\|KTCQ3FQYKWNV2CZS5T2TFIQCUI6IXWE64D5LDYXSF2AA2EF6UFJ \ / AMOS7 \ YOURUM ::
#\[7]MXUHXVFV2ZFOTUSPTEUCAIFYHZO4B3VP3SBQM7HX7ZZ5TFRQJ4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
