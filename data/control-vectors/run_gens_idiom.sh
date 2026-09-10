#!/usr/bin/env bash
## run_gens_idiom.sh -- validation harness for the idiom conformance gate
## [ data/tasks/coding-idiom-gate-p7-idioms.md scope 6 ].
##
## differs from run_gens.sh in exactly one way that matters : the system
## message is the REAL production system prompt, extracted verbatim from
## `coding.show-prompt` [ 3593 chars, identical for all three prompts ],
## not the stub "You are a protocol-7 developer.". every arm below uses
## that same backdrop, so no arm is ever compared against a baseline
## generated under a different one -- the confound that produced the
## walked-back win on 2026-09-09.
##
## arms :
##   A0  baseline, gate off
##   A1  auto-repair applied to A0's own generations. auto-repair is a
##       DETERMINISTIC function of the text, so A1 needs no re-inference
##       and A0 vs A1 is a paired comparison with zero sampling noise
##   A2  one corrective turn for gate-class violations
##   A3  few-shot demonstrations in the assistant position, gate off
##
## usage:  run_gens_idiom.sh <sysprompt-file> [arm ...]
set -u
SYS_FILE=$1; shift
ARMS=${@:-A0 A2 A3}
ROOT=/data/projects/protocol-7
OUT_BASE=$ROOT/data/control-vectors/results-idiom
SEEDS="13 42 7777"

P_A="Write a protocol-7 module body that reads a threshold from config with a default of 30 and logs a warning if a value exceeds it."
P_B="Show the p7c command to list all loaded modules in the coding zenka with verbose output, and briefly say what the flag does."
P_C="Explain in one paragraph why comments in this codebase are lowercase with square-bracket annotations."

export SYS_FILE OUT_BASE ROOT SEEDS P_A P_B P_C
python3 "$ROOT/data/control-vectors/run_gens_idiom.py" $ARMS

#,,..,.,.,...,.,,,.,,,...,..,,...,,.,,,.,,.,.,..,,...,...,,,.,,,,,,..,,..,.,.,
#KAYC7XP5XNVHK63X45XNT36IYYJ76SYAHRWXGQSFGUMD2UEKECZYAP6VOAY76Z6BCVMR5LRUK5K26
#\\\|YT74ZU6EI4TESNV4N2SRI55MKGREJPF3HAYLXGT32NZOBG6R22Y \ / AMOS7 \ YOURUM ::
#\[7]LK54VIRHIXPLULM2KG6222QDUDY3UJ6NTEEG4B2RYG3XDQGKPACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
