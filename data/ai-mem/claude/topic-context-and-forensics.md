---
name: context namespace and forensics zenka vision
description: context.* module namespace design, forensics zenka for nightly security audits using NIST/security models
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
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

## task tree integration

Forensics/security tasks fit natively into the task tree + watcher architecture:
- pattern-based subtasks: fast, no inference, resolve immediately
- inference subtasks: `requires: worker: nist-coder` active dep for security review
- pattern synthesis: recursive subtask chain — anomaly → analyze → write pattern →
  `await-event: pattern_registered` watcher confirms registry write before continuing
- external status slots: `core_dump_captured`, `incident_escalated`, `pattern_registered`
- nightly 04:07 slot: timer watcher seeds a forensics task tree that fans out autonomously
- LLM rule-synthesis loop = declarative task chain with depends_on + await-event, no
  custom orchestration code needed

## task-group note namespace integrity

Autonomous task loops (e.g. job assessment, coding iterations) get scoped
note namespaces for cross-iteration memory. forensics zenka audits these
periodically — reads accumulated notes cold against the declared task logic
to detect prompt injection artifacts, behavioral drift, or dark zones that
develop silently. a model with no stake in the notes reviews them as a third
party. prevents maliciously crafted external input (e.g. job listings) from
shaping model behavior invisibly across iterations.

## model capabilities mapping

- **nist-coder-v1.1** — security review, network code audit, input validation
- **qwen models** — newer, general purpose coding (multiple sizes available)
- **kimi** — tool access, file I/O, complex multi-step tasks
- **coding zenka local models** — fast inference, no file access, good for review/generation

#,,,.,,.,,.,.,,..,.,,,,..,,..,...,,.,,.,,,,,.,..,,...,...,..,,.,.,.,.,...,,,.,
#QJMAGFQLW6XOAUJDLVLCJIWMGVNTV3ABRBBCFJSA6CPB2SRG3LUZW7425KCR3V6V5SMLTJYZF74RK
#\\\|57652QAMJVH3MEQWNE34B64OH7MGYVYKIRITWNZBF5CNUJAEMNM \ / AMOS7 \ YOURUM ::
#\[7]RZOMVMOBRGNAR6QHTG43MUWSJZYSKBXQQEBLOS5ZNP37V3OZWICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
