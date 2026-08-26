# task: suggest design templates from recent session

## what to do

read the following files to understand what was built in the most recent
design session, then suggest 5-7 concrete design templates in the format
defined by `data/yaml/design-templates/claude-design-seed.yaml`.

## files to read first

1. `data/md/design/ZERO.md` — the overarching birdview document
2. `git log --oneline -7` — the recent commits to understand session scope
3. `data/md/design/ROUTING-CRYSTAL-HARMONIC-INFERENCE.md`
4. `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md`
5. `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md`
6. `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md`
7. `data/md/design/TREE-PROTOCOL.md`
8. `data/yaml/design-templates/claude-design-seed.yaml` — the template format

## what a good design template does

- orients a model toward one specific design lens or perspective
- is short enough to load at bandwidth 1 (one paragraph)
- has a clear `name`, `description`, and 3-5 `design lenses`
- connects to the p7 geometric vocabulary (darksun, 01/10, 1001, crystal, etc.)
- applies to a wide range of design questions, not just one specific case
- the template IS a simplest possible statement about how to see design

## suggested template categories (starting points, not constraints)

consider templates for:
- routing and route selection decisions
- protocol layer design (when to use TREE vs DATA vs oscillating)
- observer positioning (where to place the darksun in a new subsystem)
- bandwidth/bandwidth tradeoffs in display and serialization
- security boundary design (reflection vs transmission, harmonic conditions)
- address space design (how to assign positions, when to expand)
- formation design (how to structure a 5+2=7 or similar worker group)
- emergent topology (when transport should be designed vs when it should emerge)

## output format

for each suggested template, write:
1. the template name (kebab-case)
2. a one-line description
3. the core design lens it applies (2-4 sentences)
4. 3-5 specific lens questions
5. which bandwidth-3 facet docs it would load

then: for the 2 most promising templates, write the full YAML in the
format of `claude-design-seed.yaml`.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

#,,,,,.,,,.,.,...,,,.,,,.,,.,,,,,,,,,,.,.,,.,,..,,...,...,,..,,,.,,.,,,,.,.,,,
#BSHAPDQINMB33PC7XX6Q6H357IQLLPDMBXGWLAOIIKKEXJMGNHQA6MGERYJYXGXA3CPEFL5EXRRXW
#\\\|FPY43XPVXBPNWB6PBFSDPPP6VOH47RRDZWDQ45P45UZQTWHT4OR \ / AMOS7 \ YOURUM ::
#\[7]B66GZYV7FB2PUBRU46ZYMHCIBTRM47Y2Y563OFY7GYCJWU32QSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
