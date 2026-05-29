# task: memory maintenance — 2026-05-29

## purpose

read both ai memory systems and propose a clean, structured set of edits
to reduce index bloat, retire stale entries, and correct outdated facts.
produce a diff-style proposal only — do not write any files yourself.
the human + claude will review and apply.

## your memory first

before anything else, read your own memory to calibrate tone and style:

- `data/ai-mem/kimi/MEMORY.md`
- `data/ai-mem/kimi/coding-style.md`
- `data/ai-mem/kimi/handover-orientation.md`

then read the canonical style references:

- `data/yaml/code-style/CONVENTIONS.yaml`
- `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`

## what to read

### claude memory (symlinked — both paths are the same files)

index: `data/ai-mem/claude/MEMORY.md`  
files: everything in `data/ai-mem/claude/`

the index currently has 277+ lines and produces a truncation warning —
that is the primary problem to fix. read the actual topic files to
understand what is still load-bearing vs. safe to archive.

### codebase reference

for any topic file that claims something is "COMPLETE" or references a
specific module/branch, verify against the current codebase:
- check if referenced modules still exist under the same path
- check if referenced branches are active (`git branch --list`)
- check if CLAUDE.md sections are still accurate

current active branch: `base`

## what to assess

### claude MEMORY.md index

the index should stay well under 200 lines. for each section:

- is it a one-liner that fits the index? keep
- does it repeat detail already in the topic file? trim to one line
- is the topic marked complete with no forward references? candidate for archive
- is the session note old enough that its facts are in the codebase? candidate for archive
- are there duplicate entries covering the same ground? merge

session notes currently in index: sessions 55, 56, 57, 58, 60, 61.
check each topic file to decide what remains load-bearing.

### topic files

flag any topic file where:
- the feature is fully shipped and the file adds nothing beyond the codebase
- the module paths or branch names it references no longer exist
- it contradicts current code or CLAUDE.md

### kimi MEMORY.md index

apply the same assessment to `data/ai-mem/kimi/MEMORY.md` — look for
stale session entries, completed features, and index bloat.

### CLAUDE.md

check if any sections of CLAUDE.md are outdated relative to the current
codebase. flag specific lines/sections with the correction needed.

**do not assess or touch CLAUDE.yaml** — it references the
workspace-transfer workflow which is currently not in use. out of scope.

## output format

produce a structured proposal with four sections:

### 1. claude MEMORY.md — index changes
for each proposed change, one entry:
```
[ archive ] session-55 entry — all facts now in codebase; topic file is load-bearing but index line is not
[ trim ]    session-57 entry — reduce to: "session-57.md — JHash cube, prev_chk_packed perf fix"
[ keep ]    critical-patterns.md entry — still load-bearing
[ new ]     <if something is missing from the index that should be there>
```

### 2. topic files — archive candidates
list files that can be moved to an archive directory, with one-line reasoning each.

### 3. kimi MEMORY.md — index changes
same format as section 1 but for kimi's own index.

### 4. CLAUDE.md — corrections
specific section + line reference, current text vs. proposed replacement.
if nothing needs changing, say so explicitly.

## constraints

- do not propose removing anything you cannot confirm is actually stale
- if a topic file is referenced from active code or recent commits, keep it
- if uncertain about a topic, flag it as [ uncertain ] with your reasoning
- do not propose style changes to memory files — content accuracy only
- write your proposal in the same lowercase narrative style used in the memory files

#,,..,.,.,,.,,,..,..,,,.,,..,,.,.,,,,,,,.,...,..,,...,...,.,.,,.,,,,.,...,,,.,
#2LJ3ZIZ24UQHFHJFQRJQB4C76URCVWUZWAUJ6RTTFYUCKHT6TJ35BQW45HC5NTUQZYPULDFUTNFAU
#\\\|SD4YRGRCPQB3JU3T55CWFR3OXUJB4RBGDR2RURN5AAXFQPP5F5B \ / AMOS7 \ YOURUM ::
#\[7]HH2COQP4QVYTX56ABFTCGDYNMZHFXPHSIZXZ5NJLU2V2EARSJKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
