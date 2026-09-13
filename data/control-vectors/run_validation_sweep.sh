#!/usr/bin/env bash
## run_validation_sweep.sh <label> [lora-gguf-path]
##
## baseline vs lora-on validation sweep against the coding zenka's live
## gpu inference server: run_gens.sh + run_gens_lora.sh (3 seeds each,
## P_A-F) under both conditions, then score.py + a finish_reason/
## completion_tokens confound check. same discipline as every attempt in
## data/tasks/coding-lora-p7-idioms.md.
##
## with no gguf path, only runs the baseline condition (useful to refresh
## baseline numbers alone). pass a gguf path to also run lora-on and the
## full compare.
##
## REQUIRES a health-CONFIRMED wait before firing any generation request
## -- caught live 2026-09-13 (coding-lora-p7-idioms.md's fourth-attempt
## addendum): an earlier version of this script used a fixed self-test
## wait timeout that "proceeded anyway" on expiry, right as a seed-retry
## respawn was mid-flight. 16 of 18 lora-on requests landed on a dead
## server (http=000, sub-20ms connection failures) and the run had to be
## redone. never relax wait_confirmed_healthy back to a fixed timeout.
set -u

LABEL=${1:?usage: run_validation_sweep.sh <label> [lora-gguf-path]}
LORA_GGUF=${2:-}

CV=/data/projects/protocol-7/data/control-vectors
LOG=/var/log/protocol-7/DESKTOP-FP4OP26.coding.zenka.log
MODEL_ID="OFSQC4I:QDBKEXY"

ts() { date '+%H:%M:%S'; }

## confirmed healthy = /health returns valid json with slots_idle:1 --   ##
## polled with NO fixed give-up timeout other than a generous overall    ##
## ceiling (20min), since the real failure mode is giving up too early,  ##
## not waiting too long. never replace this with a short fixed-count     ##
## retry loop that proceeds regardless on expiry.                        ##
wait_confirmed_healthy() {
    local max_minutes=20
    local deadline=$(( $(date +%s) + max_minutes * 60 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        local h
        h=$(curl -s -m 5 --noproxy '*' http://127.0.0.1:8000/health 2>/dev/null)
        if echo "$h" | grep -q '"status":"ok"' && echo "$h" | grep -q '"slots_idle":1'; then
            echo "$(ts) confirmed healthy: $h"
            return 0
        fi
        sleep 5
    done
    echo "$(ts) FATAL: server never reported confirmed-healthy within ${max_minutes}min"
    return 1
}

## respawn, then require the server to sit confirmed-healthy for several ##
## consecutive quiet windows with no new self-test/seed-retry activity   ##
## logged in between, before ever firing a generation request            ##
respawn_and_wait() {
    echo "$(ts) issuing switch-model respawn..."
    p7c "coding.switch-model $MODEL_ID backend=gpu"
    sleep 5
    ps aux | grep llama-server-cuda-fa | grep -v grep

    wait_confirmed_healthy || return 1

    for check in 1 2 3; do
        local quiet_check_ln
        quiet_check_ln=$(wc -l < "$LOG")
        sleep 15
        local new_activity
        new_activity=$(tail -n +"$((quiet_check_ln + 1))" "$LOG" | grep '\[self_test\] starting\|seed-retry respawn')
        if [ -z "$new_activity" ]; then
            echo "$(ts) no new self-test activity in the last 15s, proceeding"
            return 0
        fi
        echo "$(ts) new self-test activity detected mid-quiet-check, re-confirming health..."
        wait_confirmed_healthy || return 1
    done
    echo "$(ts) WARNING: self-test activity never fully quieted after 3 checks, proceeding with caution"
}

score_condition() {
    local label=$1
    echo "-- $label --"
    python3 "$CV/score.py" "$CV/results/$label" "$CV/results-lora/$label"
}

finish_reason_stats() {
    python3 - "$@" <<'PYEOF'
import json, glob, sys
for label in sys.argv[1:]:
    total = 0
    stop = 0
    chars = 0
    for pattern_dir in ("results", "results-lora"):
        for f in sorted(glob.glob(f"/data/projects/protocol-7/data/control-vectors/{pattern_dir}/{label}/*.json")):
            try:
                d = json.load(open(f))
            except Exception as e:
                print(f"{f}: UNREADABLE {e}")
                continue
            ch = d['choices'][0]
            total += 1
            if ch.get('finish_reason') == 'stop':
                stop += 1
            chars += len(ch['message'].get('content') or '')
    print(f"{label}: {stop}/{total} finish_reason=stop, total content chars={chars}")
PYEOF
}

echo "$(ts) === STAGE 1: baseline (no lora) ==="
p7c "coding.eval-code <coding.cfg.lora_adapter> = ''; <coding.cfg.lora_adapter_scale> = 1.0; 'cleared'"
respawn_and_wait || { echo "$(ts) ABORTING baseline stage"; exit 1; }

echo "$(ts) --- baseline generations: run_gens.sh (P_A/B/C) ---"
bash "$CV/run_gens.sh" "baseline-$LABEL" 2>&1
echo "$(ts) --- baseline generations: run_gens_lora.sh (P_D/E/F) ---"
bash "$CV/run_gens_lora.sh" "baseline-$LABEL" 2>&1

if [ -n "$LORA_GGUF" ]; then
    echo "$(ts) === STAGE 2: lora-on ($LORA_GGUF, scale 1.0) ==="
    p7c "coding.eval-code <coding.cfg.lora_adapter> = '$LORA_GGUF'; <coding.cfg.lora_adapter_scale> = 1.0; 'set'"
    respawn_and_wait || { echo "$(ts) ABORTING lora-on stage"; exit 1; }

    echo "$(ts) --- lora-on generations: run_gens.sh (P_A/B/C) ---"
    bash "$CV/run_gens.sh" "lora-on-$LABEL" 2>&1
    echo "$(ts) --- lora-on generations: run_gens_lora.sh (P_D/E/F) ---"
    bash "$CV/run_gens_lora.sh" "lora-on-$LABEL" 2>&1

    echo "$(ts) === STAGE 3: restore state (no lora, flash-attn back on) ==="
    p7c "coding.eval-code <coding.cfg.lora_adapter> = ''; <coding.cfg.lora_adapter_scale> = 1.0; 'cleared'"
    respawn_and_wait || echo "$(ts) WARNING: restore did not confirm healthy, verify manually"
fi

echo "$(ts) === SCORING ==="
score_condition "baseline-$LABEL"
[ -n "$LORA_GGUF" ] && score_condition "lora-on-$LABEL"

echo "$(ts) === finish_reason / completion_tokens per condition ==="
if [ -n "$LORA_GGUF" ]; then
    finish_reason_stats "baseline-$LABEL" "lora-on-$LABEL"
else
    finish_reason_stats "baseline-$LABEL"
fi

echo "$(ts) === DONE ==="

#,,.,,,..,.,,,..,,..,,..,,.,,,,..,,.,,,,,,,.,,..,,...,...,,.,,,.,,...,.,,,..,,
#4E7TUX2IZYH2BBHBOACMCDI5HFROQI3GZ3NONY2273SLGHKLEJLPQTENBWTTQKPE2WBDGQNHWJKYO
#\\\|LONPWPZ2UXW5BI6F45CPMVBZW5ZZYJK4XEXLPV4VGXJQSKID2UN \ / AMOS7 \ YOURUM ::
#\[7]FI6PORRU3CM4TRDVJXXJO2DL2CPBVYV7RBKBOJZ2SKFRXZ3TJSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
