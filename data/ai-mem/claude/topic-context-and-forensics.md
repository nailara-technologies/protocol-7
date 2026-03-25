---
name: context namespace and forensics zenka vision
description: context.* module namespace design, forensics zenka for nightly security audits using NIST/security models
type: project
---

## context.* namespace — unified context management

Design doc: `data/md/coding-tasks/context-namespace-design.md`
Consolidated from: initial design + kimi task LBULHXQ + nist-coder-v1.1 input

**Why:** every zenka that talks to LLMs needs budget-aware context assembly.
existing `context.file`, `context.task.active`, `context.git.recent_changes`,
`context.modules.list` already follow the pattern. new modules extend it.

**How to apply:** all 5 phases (A-E) implemented Mar 25 2026 — 32 modules total.
Phase E (cache/share) committed last. Next: runtime testing in a test zenka,
then dep-graph modules for batch review pipeline, then wire delegation into task system.

## forensics zenka vision

- full concept doc: `data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md`
- already has `is-present` entry in events timetable → 04:07 nightly slot
- security zenki patrol actively, callable by any zenka for incident escalation
- core-dump capture of suspicious processes, forensics pipeline for analysis
- layered reachability: p7 → channels → multicast (each layer independent)
- wake-on-lan via nodes zenka: P0-P3 priority levels, MAC from discover packets
- LLM rule-synthesis loop: detect anomaly → analyze → generate detection rule
- compressed log buffers as input (CONCEPT-CONTEXT-AWARE-LOG-MANAGEMENT.md)
- context.* modules provide model communication layer for forensics analysis
- model routing: security review → NIST coder, pattern analysis → other models

## model capabilities mapping

- **nist-coder-v1.1** — security review, network code audit, input validation
- **qwen models** — newer, general purpose coding (multiple sizes available)
- **kimi** — tool access, file I/O, complex multi-step tasks
- **coding zenka local models** — fast inference, no file access, good for review/generation

#,,..,..,,.,.,,.,,.,.,,.,,...,,,,,..,,...,...,..,,...,...,..,,,,.,...,..,,.,.,
#GBFJM3G3KKULSLVPDIORK5HQ2HRY3RDCPDGCM64KDBF575AYAQVGT32Y2H5NWERMTNAYS5SKNYQ6I
#\\\|YUE6XLMIPPJ6QFZH2DNLQW5XXNEJW6BFHSN5V5UFRGOTDADDC7I \ / AMOS7 \ YOURUM ::
#\[7]MD4777D5BWT3T7O5VMF4YBKBI6PREJSS4K7WNFT5AOUQFFA6BWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
