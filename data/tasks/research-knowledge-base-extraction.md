## [:< ##

# name  = task: knowledge base extraction — roadmap topic research
# descr = extract already-defined structures from knowledge base for task briefs

## objective

the implementation roadmap at data/md/development/IMPLEMENTATION-ROADMAP.md
has 11 topic areas. several reference large design documents that contain
already-defined structures. extract these into structured notes that can
become task file briefs.

do NOT implement anything. research and extract only.
write findings to data/tasks/research-findings/ (create dir if needed).

## reasoning level

medium — discovery + extraction, not implementation

## documents to mine

### primary targets (search these first)

1. data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md
   (very large — use search_code and read_file with offset/length)

2. data/ai-mem/claude/topic-orbital-data-space.md

3. data/ai-mem/claude/topic-field-coherence-synthesis.md

4. data/ai-mem/claude/topic-creative-field-behaviour.md

5. data/md/design/ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md

6. data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md

### secondary (if primary insufficient)

7. data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc
   (enormous — use search_code only, targeted keyword searches)

## what to extract per topic

### topic 7.2 — dancing zenki formation

search terms: 'dancing zenki', 'formation', '5 of 7', 'overwatch',
              'shift-change', 'spiral ascent'

extract:
- exact formation geometry (5+2=7, positions, roles)
- shift-change algorithm details
- overwatch rotation direction and rules
- transport layer relationship
- pyramid + apex mapping
- any existing implementation references

output: data/tasks/research-findings/dancing-zenki-formation.md

### topic 7.3 — council of 13

search terms: 'council of 13', 'council', 'forensic', 'containment',
              'perspective closure', 'inversion aware'

extract:
- why 13 (derivation from 5+7 neighborhood)
- session protocol details
- convening conditions
- truth detection threshold mechanics
- any existing implementation references

output: data/tasks/research-findings/council-of-13.md

### topic 9.1 — personal HUD grid

search terms: 'HUD', 'personal grid', 'reference grid', 'observer',
              'waypoint', 'gaussian acceleration', 'force vector'

extract:
- intermediate reference grid definition
- layer cross-reference mechanics
- waypoint crystallization logic
- gaussian approach curve details
- any existing implementation references

output: data/tasks/research-findings/personal-hud-grid.md

### topic 10 — forensics zenka

search terms: 'forensic', 'parasite', 'containment', 'tracer',
              'route tracing', 'inversion', 'council'

extract:
- forensics zenka boot sequence requirements
- tracer activation conditions
- route tracing algorithm
- quarantine cycle protocol
- [NOT RELEVANT] bucket compression details

output: data/tasks/research-findings/forensics-zenka.md

### topic 5 — loves-it tree

search terms: 'loves-it', 'desirable', 'reference count',
              'detection matrix', 'deduplication tree'

extract:
- loves-it reference formation mechanics
- detection matrix precision properties
- group formation from reference clusters
- resource pool structure details

output: data/tasks/research-findings/loves-it-tree.md

## output format for each findings file

```
# research findings: [topic name]

## source locations
  [file]:[line range] — [what was found]

## extracted structure
  [the actual definition/algorithm/geometry found]

## gaps
  [what the documents don't define — needs design work]

## implementation hints
  [any existing code or modules that partially implement this]

## suggested task file sections
  [outline of what the task file should contain]
```

## important notes

- use search_code with specific terms before read_file
- use read_file with offset/length — do not load full large files
- if a search returns nothing, try variant spellings
- note exact file:line for every finding (for traceability)
- the 3O37VUNMMS3UU.asc file is enormous — search_code only
- write findings incrementally — one file per topic
- if context fills, complete current topic and stop cleanly

## signatures note

new files in data/tasks/research-findings/ — leave clean, no stub footer.

#,,,.,..,,,,,,.,.,..,,.,,,.,.,.,.,..,,.,,,...,..,,...,...,..,,,..,,.,,...,..,,
#ZTX3SGHI2VSXE7GVGEK6TA4RB5YOXRBDKU36ZFWBAAXEUVNLHBF5XANGBD7VRTVP3CXVORA4KGEPO
#\\\|ZQPLLTGSU5VJBD5AYEGWM5B3SU3CJVFANEMIPXLBLMWF6M7K2FJ \ / AMOS7 \ YOURUM ::
#\[7]NADMHH26OEYN5PF763EOLVY3F7EFBXTM4WG44NXNJGYNUK3RPEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
