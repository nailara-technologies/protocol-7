#!/usr/bin/env bash
## run_gens.sh <condition-label> -- fire the 3 held-out prompts x 3 seeds at
## the server on 127.0.0.1:8000 and save raw json replies under
## results/<label>/. seeds and prompts are FIXED across conditions.
set -u
LABEL=$1
OUT=/data/projects/protocol-7/data/control-vectors/results/$LABEL
mkdir -p "$OUT"

gen() { ## gen <prompt-id> <seed> <prompt text>
    local pid=$1 seed=$2 text=$3
    curl -s --noproxy '*' -m 600 http://127.0.0.1:8000/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d "{\"messages\":[{\"role\":\"system\",\"content\":\"You are a protocol-7 developer.\"},{\"role\":\"user\",\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$text")}],\"max_tokens\":700,\"temperature\":0.7,\"seed\":$seed}" \
        -o "$OUT/${pid}.seed${seed}.json" -w "$LABEL $pid seed=$seed http=%{http_code} t=%{time_total}s\n"
}

P_A="Write a protocol-7 module body that reads a threshold from config with a default of 30 and logs a warning if a value exceeds it."
P_B="Show the p7c command to list all loaded modules in the coding zenka with verbose output, and briefly say what the flag does."
P_C="Explain in one paragraph why comments in this codebase are lowercase with square-bracket annotations."

for seed in 13 42 7777; do
    gen A "$seed" "$P_A"
    gen B "$seed" "$P_B"
    gen C "$seed" "$P_C"
done
echo "condition $LABEL done"

#,,,,,,,,,,.,,,.,,,..,,,.,.,.,.,,,,..,,.,,.,,,..,,...,.,.,..,,,..,,.,,...,..,,
#SMYSHU6D4YFXE4AQIX3J5WPC773GW22UZMQZ2FHSJYXN47VUPJZML4C4YD3BJG3WSGDAQJXZYBCHE
#\\\|V5D3IYE6RJUOZJGVSUVQVKSXQEC5VXJCKZOMG7E3AFBRIVURCIX \ / AMOS7 \ YOURUM ::
#\[7]VUJYBBXYB4I5QUSJSMJXTMNCYDW5YFENJLKSET26XYKD5Y76WICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
