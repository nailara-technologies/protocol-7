#!/usr/bin/env bash
## run_activation_delta_sweep.sh [prompt] [layer ...]
##
## GGUF-side half of the eleventh pass's delta-vs-delta activation
## comparison (data/tasks/coding-lora-p7-idioms.md). Runs eval-callback
## twice against the same prompt -- adapter off, adapter on -- and prints
## each target layer's l_out whole-tensor `sum` for both conditions, so
## the deltas can be compared against hf_activation_delta_probe.py's HF-
## side numbers. CPU-only (build-cpu), no production GPU contention.
##
## ALWAYS pass --flash-attn off when a lora adapter is loaded -- this
## fork's LoRA silently no-ops under flash-attn (`llama_lora_adapter_set:
## flash_attn is not compatible with LoRA`, visible only on stderr, no
## error/warning on the numeric output itself). eval-callback has no
## automatic guard for this the way coding.spawn_inference_server does
## for the live server -- caught this the hard way in the eleventh pass
## (byte-identical off/on sums until this flag was added).
set -u

BIN=/data/source/ik_llama.cpp/build-cpu/bin/llama-eval-callback
MODEL=/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-uncensored-heretic-GGUF/Qwen3.8-9B-Distill-Heretic-Uncensored-Q8_0.gguf
LORA=/data/projects/protocol-7/data/control-vectors/lora/p7-idioms-real-attempt5-lora.LR7NW7A-XT57X3Y.gguf

PROMPT=${1:-"The quick brown fox"}
shift || true
LAYERS=("$@")
[ ${#LAYERS[@]} -eq 0 ] && LAYERS=(0 16 3 19)  # 2 ssm, 2 dense by default

OFF_OUT=$(mktemp)
ON_OUT=$(mktemp)

"$BIN" -m "$MODEL" --flash-attn off -p "$PROMPT" -n 1 -ngl 0 -t 8 -c 128 --no-warmup 2>/dev/null > "$OFF_OUT"
"$BIN" -m "$MODEL" --lora-scaled "$LORA" 1.0 --flash-attn off -p "$PROMPT" -n 1 -ngl 0 -t 8 -c 128 --no-warmup 2>/dev/null > "$ON_OUT"

printf "%-8s%-8s%14s%14s%14s\n" "layer" "type" "sum_off" "sum_on" "delta(rel%)"
for layer in "${LAYERS[@]}"; do
    kind="ssm"
    [ $(( layer % 4 )) -eq 3 ] && kind="dense"
    off=$(grep -A20 "ggml_debug:.*l_out-${layer} " "$OFF_OUT" | grep "sum = " | head -1 | grep -oE "[-0-9.]+$")
    on=$(grep -A20 "ggml_debug:.*l_out-${layer} " "$ON_OUT" | grep "sum = " | head -1 | grep -oE "[-0-9.]+$")
    rel=$(awk -v off="$off" -v on="$on" 'BEGIN { printf "%.2f", (on - off) / (off < 0 ? -off : off) * 100 }')
    printf "%-8s%-8s%14s%14s%13s%%\n" "$layer" "$kind" "$off" "$on" "$rel"
done

rm -f "$OFF_OUT" "$ON_OUT"

#,,,,,,.,,.,,,.,,,...,...,.,,,..,,,.,,,,,,,..,..,,...,...,...,,..,,..,...,,..,
#3AL3JZ2Z74BKJHROG5ZISZOVWBPNIJ4J33HPBEX4XM7S2ORRUY74DDK4YXJ2LL7IUUGTNZKCHDYJS
#\\\|DBIIAUT6CHCBQX5DFFEJWJ5TZLU3T6G5D3DUHWG2UW6I7ZYFVKO \ / AMOS7 \ YOURUM ::
#\[7]4KPVJMLWUPQJKUQRIOBDCOSUMAYTTQ734NHCCVKIFM5F2JD232AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
