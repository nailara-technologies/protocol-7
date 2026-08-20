# topic — duck.ai transcript extraction → security task tree (2026-07-29)

session: split a 66-prompt duck.ai claude-haiku design conversation
(6.6k lines, originally `INCOMING/duck.ai_2026-07-29_01-27-33.txt`, now in
user's backup) into repo artifacts. committed as `737836d5d`.

## what was created

- **7 task files** (`data/tasks/`): openvas-agent (FIRST), nessus-agent
  (later licensed variant), forensics-agent, forensic-report-pipeline,
  security-intel-embedding-domains, dep-graph-semantic-embeddings,
  real-estate-agent-port
- **2 design docs** (`data/md/design/`): HYBRID-LLM-GOVERNANCE (5-layer
  local/external isolation, offline invariant, template refinement waves),
  NETWORK-SNAPSHOT-AND-IDEA-POOL (snapshot/resume/idea-pool on memory tree)
- **3 reasoning templates** (`data/yaml/reasoning-templates/`):
  network-as-institutional-memory, template-wave-refinement,
  models-as-pattern-generators
- **interview strand** → `/data/interview/` (OUTSIDE repo, 6 files:
  salary/positioning/evidence/interview-prep/private-relocation)

## the workflow that worked (reusable)

1. read the whole transcript, build a topic-cluster map with prompt ranges
2. propose the split to the user BEFORE writing (they redirected personal
   content to /data/interview/ — always confirm destination of personal data)
3. **exists-vs-gap scan per topic cluster via parallel explore agents**
   (3 agents × ~5 topics) before writing any task file. this prevented
   real duplication — see coverage map below
4. write files, cross-reference with [[wiki-links]], keep task files in
   house format (## context + phases + ```## dispatch + prompt``` blocks)

## exists-vs-gap map (verified 2026-07-29, trust this over assumptions)

- **fasttext pipeline**: EXISTS — `data/tasks/FASTTEXT-MEMORY-PIPELINE.md`
  (open, phased), `data/md/design/EMBEDDING-INFRASTRUCTURE-TRACK.md` (master
  index). no `bin/dev/train-embedding` yet. new embedding work EXTENDS these.
- **pattern DB + applicability classifier**: IMPLEMENTED — `ncode.regex.*` +
  `ncode.cmd.*` + `data/yaml/ncode-patterns/`; definitive memory at
  `data/ai-mem/claude/topic-ncode-pattern-learning-loop.md`. phase-2 scope
  stack task open. "regex-only agent" = tier-A + ptd gate, not a named agent.
- **dep-graph → embeddings**: GREENFIELD — only a one-bullet mention in
  INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS. `.asc` is already word-neighbor
  format; module name = filepath under src/ (no registry).
- **memory tree**: IMPLEMENTED — 52 `src/memory.*` modules.
  ⚠️ `MEMORY-TREE-SYSTEM.md` header still claims "nothing built yet" — STALE.
  `memory.tree.checkpoint`/`memory.tree.diff` still unimplemented.
- **forensics agent**: rich design (`CONCEPT-SECURITY-AND-FORENSICS-
  ARCHITECTURE.md`), zero code. live nightly slot `event-setup.base`:
  `zenka-name = forensics`, `at = 04:07` (also in event-setup.letsencr).
  **zenka name must stay `forensics`**. research extraction
  (research-knowledge-base-extraction.md topic 10) still pending.
- **nessus/openvas/CVE/MITRE/CWE/CISA**: total greenfield (were only in
  the transcript). `data/yaml/task-tree/branches.yaml` has a
  `self-improvement` branch id — the report pipeline hooks there.
- **jobsite framework**: fully implemented + maintained
  (jobs-pipeline-2026-06-28.md); real-estate port = greenfield + the
  framework's generalization test case.
- **hybrid LLM governance (cloud)**: greenfield. terminology trap:
  `cfg/external-inference-models` = LOCAL backends (lmstudio/
  ollama on 127.0.0.1), NOT cloud APIs. `coding.sanitize.jinja_messages`
  is jinja-safety, NOT privacy sanitization — a real `sanitize.request`
  module for the layer-2 boundary is still to be built.

## decisions worth remembering

- **openvas first, nessus later** (user's call): open backend matches
  public-domain nature; greenbone NVT feed doubles as the intel domain —
  scanner + knowledge base from one source. nessus only where a license
  exists; shared `scan.result.schema` keeps downstream backend-neutral;
  nvt vs nessus plugin ids stay SEPARATE embedding domains, bridged by
  cross-domain nearest-neighbor.
- **personal data rule**: `/data/interview/` is outside the repo; the
  relocation/baseline file is flagged never-dispatch, never-external-model.
- the transcript's "nessus agent" named the capability, not the brand.

## style notes for future extraction sessions

- reasoning templates: yaml frontmatter (name/category/version/description)
  + lowercase sections + ```ascii blocks``` + "the test" checklist +
  [[related]] footer
- design docs: status header naming source + exists/gap statement +
  relationship-to-existing-systems table when overlapping implemented areas
- user signs + bumps version afterwards; commit only after their go

#,,,.,..,,,..,..,,,,,,..,,.,,,...,.,,,..,,.,,,..,,...,...,,..,...,.,,,,,,,..,,
#7UK4UK7SP3BXRFX7BT2PFISYUI2FN7KZGOVN6ZT5ULUQNLLXLI4K7YHOU62223J56OCTT2PPHMJCC
#\\\|RLPZJG74EF772BYKKU5FC6W7ESI3RJDSN2PHNHISAZD6TVYLEYI \ / AMOS7 \ YOURUM ::
#\[7]2UUOEFEDJC5HAFQSDPAIP5D6CNWNTAYQ6E7XOVBI7T6EFZ435QAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
