#!/usr/bin/env bash
## run_lora_scale_sweep.sh [scale ...]
##
## fa-held-constant lora scale sweep against the live coding-zenka gpu
## server -- isolates the adapter's live effect from the flash-attn on/
## off confound that affects every baseline-vs-lora-on sweep in this
## thread (coding.spawn_inference_server only pushes --flash-attn off
## when a lora_adapter path is set, so "baseline" and "lora-on" runs in
## run_validation_sweep.sh differ in two variables, not one). here the
## adapter path is SET in every condition -- including scale 0.0, the
## true zero-delta control -- so FA stays off throughout and only
## --lora-scaled varies. uses the single-shot position-matched probe
## (lora_invoke_live_position_probe.py), not a full generation sweep --
## cheap, no training, one respawn per scale point.
##
## default scales: 0.0 1.0 4.0 8.0 16.0 (data/tasks/coding-lora-p7-idioms.md's
## "eighth pass"). pass explicit scales as argv to test others, e.g.:
##   run_lora_scale_sweep.sh 2.0 3.0 6.0
##
## needs .venv-lora (transformers) -- NOT the bare system python3, and
## NO_PROXY='*' -- this host's http_proxy/https_proxy/ALL_PROXY env vars
## make bare urllib.request calls to 127.0.0.1:8000 silently route through
## the proxy and come back as a misleading HTTP 502, not a client-side
## proxy issue. curl already sidesteps this via --noproxy '*'.
set -u

CV=/data/projects/protocol-7/data/control-vectors
LOG=/var/log/protocol-7/DESKTOP-FP4OP26.coding.zenka.log
MODEL_ID=LR7NW7A:XT57X3Y
LORA_GGUF=/data/projects/protocol-7/data/control-vectors/lora/p7-idioms-real-attempt5-lora.LR7NW7A-XT57X3Y.gguf
PROBE=/data/projects/protocol-7/data/control-vectors/lora_invoke_live_position_probe.py
PYTHON=/data/projects/protocol-7/.venv-lora/bin/python3
RESTORE_MODEL_ID=OFSQC4I:QDBKEXY

SCALES=("$@")
[ ${#SCALES[@]} -eq 0 ] && SCALES=(0.0 1.0 4.0 8.0 16.0)

ts() { date '+%H:%M:%S'; }

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

respawn_and_wait() {
    local target_model=$1
    echo "$(ts) issuing switch-model respawn ($target_model)..."
    p7c "coding.switch-model $target_model backend=gpu"
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

run_scale() {
    local scale=$1
    local label="fa-off-scale${scale}"
    echo "$(ts) === scale=$scale ($label) ==="
    p7c "coding.eval-code <coding.cfg.lora_adapter> = '$LORA_GGUF'; <coding.cfg.lora_adapter_scale> = $scale; 'set'"
    respawn_and_wait "$MODEL_ID" || { echo "$(ts) ABORTING scale=$scale"; return 1; }
    ps aux | grep -o -- '--flash-attn [a-z]*' | head -1
    NO_PROXY='*' no_proxy='*' "$PYTHON" "$PROBE" "$label" 2>&1
}

for s in "${SCALES[@]}"; do
    run_scale "$s"
done

echo "$(ts) === restoring production ==="
p7c "coding.eval-code <coding.cfg.lora_adapter> = ''; <coding.cfg.lora_adapter_scale> = 1.0; 'cleared'"
respawn_and_wait "$RESTORE_MODEL_ID"
echo "$(ts) === DONE ==="

#,,..,..,,.,,,.,,,...,,,.,.,.,,.,,,.,,,,.,..,,..,,...,..,,..,,,,,,.,,,,,.,,,.,
#H2EB5TOJBX25WYNO44VJU3VTSCUD7OLNDPD4HAKSAENXTUIHLCSHSLKMIQCXNFWD4INQ43QNPUXP6
#\\\|UDNXVRBRIJ3ZFRXCW4WDRNP624T4W2VZMR2TRE6QW5ZBVSLK2P2 \ / AMOS7 \ YOURUM ::
#\[7]66BXVQNDUWQ3PK2W6XQAYEXG6QJ4J2IRI5PFA4DJYQWFJVDDA6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
