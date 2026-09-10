#!/usr/bin/env bash
## check_tokens.sh -- hazard-4 length matching : tokenize the assistant turn
## of every pair [ both sides ] with the real model's tokenizer and report
## per-pair deltas. exits 1 if any pair exceeds the threshold.
##
## usage: check_tokens.sh <model.gguf> <positive.txt> <negative.txt> [thresh%]

set -u
MODEL=$1; POS=$2; NEG=$3; THRESH=${4:-10}
TOK=/data/source/ik_llama.cpp/build-cpu/bin/llama-tokenize
TMP=$(mktemp -d)

## unescape one line [ mirrors string_process_escapes ] and cut everything ##
## up to the last 'assistant\n' marker, leaving only the assistant turn     ##
python3 - "$POS" "$NEG" "$TMP" <<'EOF'
import sys, re

def unescape(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            c = s[i+1]
            if   c == 'n': out.append('\n'); i += 2
            elif c == 'r': out.append('\r'); i += 2
            elif c == 't': out.append('\t'); i += 2
            elif c in "'\"\\": out.append(c); i += 2
            else: out.append('\\' + c); i += 2      ## default: survives intact
        else:
            out.append(s[i]); i += 1
    return ''.join(out)

pos = open(sys.argv[1]).read().splitlines()
neg = open(sys.argv[2]).read().splitlines()
assert len(pos) == len(neg), "pair count mismatch"
for i, (p, n) in enumerate(zip(pos, neg), 1):
    for side, line in (('pos', p), ('neg', n)):
        text = unescape(line)
        idx = text.rfind('assistant\n')
        assert idx >= 0, f"pair {i} {side}: no assistant marker"
        open(f"{sys.argv[3]}/{i:02d}.{side}.txt", "w").write(text[idx+10:])
print(len(pos))
EOF

NPAIRS=$(ls "$TMP"/*.pos.txt | wc -l)

count_one() {
    ## prints "<file> <ntokens>"
    local f=$1
    local n
    n=$("$TOK" --log-disable --no-bos --show-count -m "$MODEL" -f "$f" 2>/dev/null \
        | grep -oP 'Total number of tokens: \K\d+')
    echo "$(basename "$f") $n"
}
export -f count_one; export TOK MODEL

ls "$TMP"/*.txt | xargs -P 8 -I{} bash -c 'count_one "$@"' _ {} > "$TMP/counts.txt"

python3 - "$TMP" "$NPAIRS" "$THRESH" <<'EOF'
import sys
tmp, npairs, thresh = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
counts = {}
for line in open(f"{tmp}/counts.txt"):
    name, n = line.split()
    counts[name] = int(n)
worst = 0.0
signs = []
print(f"{'pair':>4} {'pos':>5} {'neg':>5} {'delta':>6} {'delta%':>7}")
for i in range(1, npairs + 1):
    p = counts.get(f"{i:02d}.pos.txt", -1)
    n = counts.get(f"{i:02d}.neg.txt", -1)
    d = n - p
    pct = abs(d) / max(p, n) * 100 if max(p, n) > 0 else 0
    worst = max(worst, pct)
    signs.append(1 if d > 0 else (-1 if d < 0 else 0))
    flag = "  <-- OVER" if pct > thresh else ""
    print(f"{i:>4} {p:>5} {n:>5} {d:>+6} {pct:>6.1f}%{flag}")
avg_pos = sum(counts[f"{i:02d}.pos.txt"] for i in range(1, npairs+1)) / npairs
print(f"\navg assistant-turn tokens [pos side]: {avg_pos:.0f}")
print(f"estimated usable rows: {sum(counts[f'{i:02d}.pos.txt'] for i in range(1, npairs+1))}")
print(f"delta sign balance: +{signs.count(1)} / -{signs.count(-1)} / 0={signs.count(0)}")
print(f"worst delta: {worst:.1f}% [ threshold {thresh}% ]")
sys.exit(1 if worst > thresh else 0)
EOF
RC=$?
rm -rf "$TMP"
exit $RC

#,,.,,,,,,,,,,,,.,..,,.,,,,..,,,.,.,.,,.,,,.,,..,,...,...,,.,,,,,,..,,,,,,,,.,
#NT7SYNARU6HC5RBW6XYKZC2YTPDCFC5S7GNGGLFQ2NP7PPSTXARKPXNTTSIZQLAC646EUPMTJBVKO
#\\\|S7PUPZ4JYY5V6OHWHATDOG2XNSMSRXMHVKRCQICSIYXJSRXLAXU \ / AMOS7 \ YOURUM ::
#\[7]UAMKFXMNEJEW727VXP4EX7272ZXT4GMEQNTYFI6KL6CUGDTZ3KAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
