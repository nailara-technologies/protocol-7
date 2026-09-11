#!/usr/bin/env python3
## offline_check.py -- the two pre-build calibration checks for the idiom
## conformance gate, per data/tasks/coding-idiom-gate-p7-idioms.md scope 2.
##
##   fp   : run the rule table over real human-written src/coding.* .
##          anything flagged there is a LINTER BUG, not a finding.
##   recall : run it over stored model generations and classify every
##          structural-idiom opportunity into auto / normalize / gate.
##
## reads data/idioms/rules.yaml -- the same table the perl modules use, so
## the calibration measures the shipped rules and not a separate copy.
##
## usage:  offline_check.py fp [src-glob]
##         offline_check.py recall <results-dir> [...]

import json, re, sys, os, glob, collections
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RULES_PATH = os.path.join(ROOT, 'data', 'idioms', 'rules.yaml')


def load_rules():
    with open(RULES_PATH) as fh:
        doc = yaml.safe_load(fh)
    out = []
    for r in doc['rules']:
        pat = r['detect']
        try:
            rx = re.compile(pat)
        except re.error as e:
            print(f"  !! rule {r['id']}: uncompilable regex: {e}", file=sys.stderr)
            continue
        out.append({**r, 'rx': rx})
    return out


_MODCACHE = None


def known_modules():
    """the resolver's offline stand-in: real module names from src/."""
    global _MODCACHE
    if _MODCACHE is None:
        _MODCACHE = {os.path.basename(f) for f in glob.glob(os.path.join(ROOT, 'src', '*'))}
    return _MODCACHE


def resolves(kind, name):
    if kind == 'module':
        return name in known_modules()
    if kind == 'config':
        ## offline stand-in: config keys cannot be resolved without a live
        ## zenka, so treat every one as unresolved [ the conservative side ]
        return False
    return True


def scan(text, rules):
    """return list of violations; `skip` rules mask overlapping matches."""
    masked = []
    for r in rules:
        if r['class'] == 'skip':
            masked.extend((m.start(), m.end()) for m in r['rx'].finditer(text))

    def is_masked(a, b):
        return any(a >= s and b <= e for s, e in masked)

    viols = []
    for r in rules:
        if r['class'] == 'skip':
            continue
        for m in r['rx'].finditer(text):
            if is_masked(m.start(), m.end()):
                continue
            line = text.count('\n', 0, m.start()) + 1
            cls = r['class']
            ## a rewrite is only ever applied when its target resolves.
            ## unresolved -> demoted to gate [ the hazard-2 discipline:
            ## a rubric hit that does not resolve is a regression ].
            target = None
            if r.get('resolve') and m.groups():
                target = m.group(int(r.get('target_group', 1)))
                if r.get('target_transform') == 'perl_package':
                    target = m.group(0).rstrip('( \t').lower().replace('::', '.')
                if not resolves(r['resolve'], target):
                    if r.get('on_unresolved') == 'drop':
                        continue          ## not a violation at all
                    cls = 'gate-unresolved' if cls == 'gate' else 'gate'
            viols.append({
                'id': r['id'], 'category': r.get('category', '?'),
                'class': cls, 'line': line,
                'found': m.group(0)[:80],
                'resolve': r.get('resolve'), 'target': target,
            })
    return viols


def strip_fences(text):
    """model replies wrap code in ``` fences; prose outside them is not code."""
    blocks = re.findall(r'```[a-z]*\n(.*?)```', text, re.S)
    return '\n'.join(blocks) if blocks else text


def cmd_fp(args):
    pattern = args[0] if args else os.path.join(ROOT, 'src', 'coding.*')
    rules = load_rules()
    files = [f for f in glob.glob(pattern) if os.path.isfile(f)]
    print(f"== false-positive calibration over {len(files)} real P7 files")
    per_rule = collections.Counter()
    hits = []
    for f in files:
        try:
            text = open(f, encoding='utf-8', errors='replace').read()
        except Exception:
            continue
        for v in scan(text, rules):
            if v['class'] in ('report', 'gate-unresolved'):
                continue   ## report-only rules and unresolvable refs are
                           ## not rewrites, so they cannot corrupt code
            per_rule[v['id']] += 1
            hits.append((os.path.basename(f), v))
    print(f"   total flags on known-good code: {len(hits)}  [ target: 0 ]")
    for rid, n in per_rule.most_common():
        print(f"     {rid:32s} {n}")
    for fname, v in hits[:40]:
        print(f"       {fname}:{v['line']} [{v['id']}] {v['found']!r}")
    if len(hits) > 40:
        print(f"       ... and {len(hits)-40} more")
    return len(hits)


def cmd_recall(dirs):
    rules = load_rules()
    print("== detection recall over stored generations")
    grand = collections.Counter()
    catcls = collections.defaultdict(collections.Counter)
    for d in dirs:
        files = sorted(glob.glob(os.path.join(d, '*.json')))
        n_code = 0
        local = collections.Counter()
        for f in files:
            try:
                text = json.load(open(f))['choices'][0]['message'].get('content') or ''
            except Exception:
                continue
            if not text.strip():
                continue
            code = strip_fences(text)
            if '```' in text:
                n_code += 1
            for v in scan(code, rules):
                local[v['class']] += 1
                grand[v['class']] += 1
                catcls[v['category']][v['class']] += 1
        print(f"  {d:48s} files={len(files):3d} code={n_code:3d}  "
              + " ".join(f"{k}={v}" for k, v in sorted(local.items())))
    print("\n  -- by class --")
    for k, v in sorted(grand.items()):
        print(f"     {k:10s} {v}")
    print("\n  -- by category x class --")
    for cat in sorted(catcls):
        row = catcls[cat]
        print(f"     {cat:10s} " + " ".join(f"{k}={v}" for k, v in sorted(row.items())))
    ## go/no-go : of REAL violations [ excluding cosmetic normalize ],
    ## what share is mechanically actionable [ auto or gate ] ?
    real = grand['auto'] + grand['gate'] + grand['assist']
    actionable = grand['auto'] + grand['gate']
    if real:
        print(f"\n  actionable (auto+gate) / real violations = "
              f"{actionable}/{real} = {100.0*actionable/real:.0f}%")
        print(f"  auto-only share                          = "
              f"{grand['auto']}/{real} = {100.0*grand['auto']/real:.0f}%")
    print(f"  cosmetic 'normalize' matches (reported separately) = {grand['normalize']}")
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__ or 'usage: offline_check.py fp|recall ...')
        sys.exit(2)
    mode, rest = sys.argv[1], sys.argv[2:]
    if mode == 'fp':
        sys.exit(0 if cmd_fp(rest) == 0 else 1)
    elif mode == 'recall':
        sys.exit(cmd_recall(rest or [os.path.join(ROOT, 'data/control-vectors/results/real-system-prompt-v2')]))
    else:
        print(f"unknown mode {mode}")
        sys.exit(2)

#,,,,,,,,,.,.,,.,,,,,,,..,.,,,...,,,.,,.,,,,,,..,,...,...,,.,,...,...,.,.,...,
#2OZIYI5ZCWX5AVNBNXQDBJPRENN3A7EO4YTQFEO4RP7WJD4ZJLCGNHYSVVSWPPIDBGJGTRS32QDDU
#\\\|FOBRCDZCOG7QXJ4RMATC2EKRNPUW4LGDF7LIYPNMG57WWH5L4F3 \ / AMOS7 \ YOURUM ::
#\[7]B7H7AOKHBEIJ5VUAULL4I4EARUX33O3VTR57NY7QMCEWVWWSAOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
