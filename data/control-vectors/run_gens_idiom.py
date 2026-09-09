#!/usr/bin/env python3
## run_gens_idiom.py -- arm runner behind run_gens_idiom.sh.
## see that script's header for the experiment design and why the system
## prompt is the real production one rather than the stub.

import os, sys, json, time, subprocess, urllib.request, random

ROOT = os.environ.get('ROOT', '/data/projects/protocol-7')
OUT_BASE = os.environ['OUT_BASE']
SYS = open(os.environ['SYS_FILE']).read()
SEEDS = [int(s) for s in os.environ.get('SEEDS', '13 42 7777').split()]
PROMPTS = {k: os.environ['P_' + k] for k in ('A', 'B', 'C')}
URL = 'http://127.0.0.1:8000/v1/chat/completions'

## this host has http_proxy set ; an unproxied opener is required or every
## request to the local inference server comes back 502 Bad Gateway
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
MAXTOK = 700
TEMP = 0.7


def complete(messages, seed):
    body = json.dumps({
        'messages': messages, 'max_tokens': MAXTOK,
        'temperature': TEMP, 'seed': seed,
    }).encode()
    req = urllib.request.Request(
        URL, data=body, headers={'Content-Type': 'application/json'})
    for attempt in range(3):
        try:
            with OPENER.open(req, timeout=900) as fh:
                return json.load(fh)
        except Exception as e:
            if attempt == 2:
                return {'error': str(e), 'choices':
                        [{'message': {'content': ''}}]}
            time.sleep(5)


def content_of(doc):
    try:
        return doc['choices'][0]['message'].get('content') or ''
    except Exception:
        return ''


def save(arm, pid, seed, doc):
    d = os.path.join(OUT_BASE, arm)
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, f'{pid}.seed{seed}.json')
    json.dump(doc, open(p, 'w'), indent=1)
    print(f'  {arm} {pid} seed={seed} chars={len(content_of(doc))}')
    return p


def p7c(args):
    """call a coding-zenka command, returning its stdout text."""
    r = subprocess.run(['p7c', 'coding.idiom-check', args],
                       capture_output=True, text=True, timeout=180)
    return r.stdout


def unescape(s):
    ## p7c renders the reply string with literal \n escapes
    return s.replace('\\n', '\n')


def arm_A0():
    print('== A0 : baseline, production system prompt, gate off')
    for pid, text in PROMPTS.items():
        for seed in SEEDS:
            msgs = [{'role': 'system', 'content': SYS},
                    {'role': 'user', 'content': text}]
            save('A0', pid, seed, complete(msgs, seed))


def arm_A1():
    """deterministic: auto-repair over A0's own generations, no inference."""
    print('== A1 : auto-repair applied to A0 [ paired, no re-inference ]')
    src = os.path.join(OUT_BASE, 'A0')
    tmp = os.path.join(ROOT, 'data', 'idioms', '.a1-scratch.txt')
    for name in sorted(os.listdir(src)):
        if not name.endswith('.json'):
            continue
        doc = json.load(open(os.path.join(src, name)))
        text = content_of(doc)
        if not text.strip():
            json.dump(doc, open(os.path.join(
                _mk('A1'), name), 'w'), indent=1)
            continue
        open(tmp, 'w').write(text)
        out = unescape(p7c(':repair: data/idioms/.a1-scratch.txt')).strip()
        if out and 'not readable' not in out:
            doc['choices'][0]['message']['content'] = out
        json.dump(doc, open(os.path.join(_mk('A1'), name), 'w'), indent=1)
        print(f'  A1 {name} chars={len(out)}')
    if os.path.exists(tmp):
        os.remove(tmp)


def _mk(arm):
    d = os.path.join(OUT_BASE, arm)
    os.makedirs(d, exist_ok=True)
    return d


def arm_A2():
    """one corrective turn per A0 generation that has gate-class violations."""
    print('== A2 : one corrective turn for gate-class violations')
    src = os.path.join(OUT_BASE, 'A0')
    tmp = os.path.join(ROOT, 'data', 'idioms', '.a2-scratch.txt')
    for name in sorted(os.listdir(src)):
        if not name.endswith('.json'):
            continue
        pid = name.split('.')[0]
        seed = int(name.split('seed')[1].split('.')[0])
        doc = json.load(open(os.path.join(src, name)))
        text = content_of(doc)
        if not text.strip():
            json.dump(doc, open(os.path.join(_mk('A2'), name), 'w'), indent=1)
            continue
        open(tmp, 'w').write(text)
        msg = unescape(p7c(':correct: data/idioms/.a2-scratch.txt')).strip()
        if not msg or 'no gate-class violations' in msg:
            ## nothing to correct : A2 == A0 for this generation
            json.dump(doc, open(os.path.join(_mk('A2'), name), 'w'), indent=1)
            print(f'  A2 {name} [ no gate violations, carried over ]')
            continue
        msgs = [{'role': 'system', 'content': SYS},
                {'role': 'user', 'content': PROMPTS[pid]},
                {'role': 'assistant', 'content': text},
                {'role': 'user', 'content': msg}]
        save('A2', pid, seed, complete(msgs, seed))
    if os.path.exists(tmp):
        os.remove(tmp)


def load_fewshot(k=6):
    """k demonstrations from the 403-example sft.jsonl, category-balanced."""
    path = os.path.join(ROOT, 'data', 'control-vectors', 'lora',
                        'dataset', 'sft.jsonl')
    rows = [json.loads(l) for l in open(path)]
    want = {
        'invoke': lambda r: '<[' in r['content'] and ']>->(' in r['content'],
        'cfgaccess': lambda r: '<' in r['content'] and '>' in r['content']
        and '<[' not in r['content'],
        'truefalse': lambda r: 'TRUE' in r['content'] or 'FALSE' in r['content'],
        'modedata': lambda r: 'mode' in r['content'] and 'data' in r['content'],
    }
    rnd = random.Random(13)          ## fixed : the exemplar set is not a
    picked, seen = [], set()         ## free variable between arms
    for _round in range(k):
        for cat, test in want.items():
            if len(picked) >= k:
                break
            cands = [r for r in rows
                     if test(r) and r['user'] not in seen]
            if not cands:
                continue
            r = rnd.choice(cands)
            seen.add(r['user'])
            picked.append(r)
    return picked[:k]


def arm_A3():
    print('== A3 : few-shot demonstrations in the assistant position')
    shots = load_fewshot()
    print(f'  [ {len(shots)} exemplars, fixed seed 13 for selection ]')
    prefix = []
    for r in shots:
        prefix.append({'role': 'user', 'content': r['user']})
        prefix.append({'role': 'assistant', 'content': r['content']})
    for pid, text in PROMPTS.items():
        for seed in SEEDS:
            msgs = ([{'role': 'system', 'content': SYS}] + prefix
                    + [{'role': 'user', 'content': text}])
            save('A3', pid, seed, complete(msgs, seed))


if __name__ == '__main__':
    arms = sys.argv[1:] or ['A0']
    table = {'A0': arm_A0, 'A1': arm_A1, 'A2': arm_A2, 'A3': arm_A3}
    for a in arms:
        if a not in table:
            print(f'unknown arm {a}')
            continue
        table[a]()

#,,,,,...,..,,...,,..,,,.,,..,,,.,..,,...,,..,..,,...,...,,.,,.,,,...,...,,,.,
#D2JY7FKQCPVKFE5POPN7TV4INDZHFKIXU56AZNHH6VKBQX334ATWW6ZH2IE3XBFHE2GO6W53W4NOE
#\\\|VGCY4JJRLSBVZHHNPJ72OZQMHB3E3M6QQMMMNCJDV5V4SGKTQIK \ / AMOS7 \ YOURUM ::
#\[7]42QCSMKYQJH642NAOGP7DWQXXPAKZZDMX7RJMZMLGLSDW3AOUWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
