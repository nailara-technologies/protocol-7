#!/usr/bin/env bash
## run_gens_lora.sh <condition-label> -- the SECOND, never-before-used
## held-out prompt set [ P_D/P_E/P_F, defined in build_sft_dataset.py and
## excluded from training there ] x the same 3 fixed seeds as run_gens.sh.
## same server, same request shape ; saves under results-lora/<label>/.
set -u
LABEL=$1
OUT=/data/projects/protocol-7/data/control-vectors/results-lora/$LABEL
mkdir -p "$OUT"

gen() { ## gen <prompt-id> <seed> <prompt text>
    local pid=$1 seed=$2 text=$3
    curl -s --noproxy '*' -m 600 http://127.0.0.1:8000/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d "{\"messages\":[{\"role\":\"system\",\"content\":\"You are a protocol-7 developer.\"},{\"role\":\"user\",\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$text")}],\"max_tokens\":700,\"temperature\":0.7,\"seed\":$seed}" \
        -o "$OUT/${pid}.seed${seed}.json" -w "$LABEL $pid seed=$seed http=%{http_code} t=%{time_total}s\n"
}

P_D="Write a protocol-7 module coding.helper.enforce_quota that reads a per-job byte quota from config [ default 4096 ] and logs a warning when a job's usage exceeds it, returning FALSE in that case."
P_E="Show the p7c command to rebuild the cube session table index as a dry run with forced locking, and explain what each flag does."
P_F="Explain in one paragraph why handlers in this codebase return a mode/data reply hash instead of a bare status string."

for seed in 13 42 7777; do
    gen D "$seed" "$P_D"
    gen E "$seed" "$P_E"
    gen F "$seed" "$P_F"
done
echo "condition $LABEL done"

#,,.,,,,,,.,,,.,.,.,,,.,.,.,,,.,,,,..,,..,...,..,,...,...,...,,..,.,,,,,,,.,.,
#2DFPNEO6RLJLWPPTUU2WZH6EKSRQAPXJJSI4PV6WO3PXMKA5UQEFYXFCQIQ32XDKXJTOKIZ2QI5RG
#\\\|DDSAPDJQYJS7VI5GZPVWLAXJIE74NH2U5HKBTTZSWKNG454SZBC \ / AMOS7 \ YOURUM ::
#\[7]EYAYE7VDVUZCPOOS7PFRHGDE2EZPGRR5SYBEEEOJET42NCXB3OBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
