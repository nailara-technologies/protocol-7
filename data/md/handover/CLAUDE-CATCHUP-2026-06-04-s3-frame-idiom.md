# Claude Catchup — 2026-06-04 (session 3) — frame idiom convergence + corner-pinning spring

resuming the ascii-frame work. continues from session 2 (`CLAUDE-CATCHUP-2026-06-04.md`,
git `7f2c04a03`) and the session-3a commit `e8eedf1de` (# purge + color-routing fix).
this file = the idiom-convergence pass: new base features + the corner-pinning model.

## one-line state

the memory-tree-root frame now renders the new idiom **exactly matching the
reference `/tmp/frame.asc`** — `.:[ value ]::[ memory tree ]:.` corners pinned,
single `:` sides, dotted `:….:` bottom, outer margin + top padding. four new
reusable frame features landed + verified. `feedback` converted as the second proof.
**5 remaining frames still need conversion** (REQUIRED — see warning below). nothing
re-signed yet; user signs the whole batch together.

## what shipped (all verified live on the memory zenka)

### 1. four new ascii.frame base features

- **outer margin** — `margin: {left: N, right: N}` in frame yaml → space OUTSIDE the
  border (the parent-plane's breathing room; 0 when nested). applied in
  `ascii.frame.render` as a final wrap; `ascii.frame.render.color` preserves it by
  splitting off per-line leading whitespace before classifying (so the margin never
  poisons side/corner detection). read into the descriptor by `ascii.frame.load`.
- **vertical padding** — `padding: {top: N, bottom: N}` → blank content rows inside
  the border, above/below the content block (the top/bottom analogue of lpad/rpad).
  `ascii.frame.render` inserts them; `ascii.frame.load` now copies top/bottom too.
- **self-invalidating frame cache** — NEW module `ascii.frame.init_code` does
  `<ascii.frame.cache> = {};`. `base.init_modules` re-runs every `*.init_code` on each
  source reload, so edited frame yaml now takes effect on `reload` (was: required a
  COLD zenka restart — the cache was never invalidated). **creating the file IS the
  whole registration** — no wiring. do NOT put frame specifics in generic
  `base.cmd.reload` (tried it; user corrected — frame system owns its own lifecycle).
- **corner-pinning spring model** — rewrote `ascii.frame.render.border_line`. a border
  line stretches at exactly ONE spring:
  - **slot present → the slot is the spring**: its value is padded (on the right) to
    fill the line while every fill stays rigid at its minimum. pins `.:` `::` `:.` and
    widens the bracketed content — matches the reference's wide-bracket layout. the
    status provider's width-23 is now just a FLOOR; border_line pads beyond it.
  - **no slot → the largest fill is the spring** (e.g. the dotted bottom rule: dots
    stretch, `:` corners pin).

### 2. two frames converted to the new idiom

- `memory-tree-root.yaml` → `.:[ {{PROGRESS}} ]::[ memory tree ]:.` / single `:` /
  `:….:` bottom / `margin {left:1}` / `padding {top:1}`. renders width-rigid 56,
  matching `/tmp/frame.asc`.
- `feedback.yaml` → headline-promotion: the `{{RULE}}` slot moved INTO the top bracket
  (`.:[ {{RULE}} ]::[ feedback ]:.`) so it becomes the slot-spring. renders clean at 46.

## ⚠ REQUIRED next: convert the remaining 5 frames

the border_line spring change is global. any frame whose TOP is slot-less / decorative
now **blows out its leading corner** (slack lands on the largest fill; an all-min-1 or
decorative top → leading `..` explodes, e.g. `............[ … ]`). confirmed on
`feedback` BEFORE its conversion. so these MUST be converted or they regress:

| frame | plan |
|---|---|
| `project` | promote `{{FACT}}` into top bracket (same as feedback) |
| `user-profile` | promote `{{ROLE}}`, or a plain `[ user profile ]` title |
| `task-queue` | block-only, NO headline → **open Q**: separator-stretch vs a count headline |
| `session-catchup` | block-only, NO headline → **open Q**: separator-stretch vs "Ns ago" |
| `memory-tree-node` | already has top slots `{{N}}/{{TOTAL}}`,`{{TITLE}}` — idiom cleanup only (single `:`, dotted bottom); note slot-spring pads the FIRST slot |
| `memory-composite` | already has `PROGRESS`/`STATUS` top — idiom cleanup |
| `memory-tree-compact` | borderless single line — SKIP |

**open design Qs for the user (asked, not yet answered):**
1. `task-queue` / `session-catchup`: separator-stretch (`::` grows, corners pin) OR
   invent a headline (task-count / session-age)?
2. the `==[ why & apply ]==` content-separator row doesn't stretch full-width (it's a
   fixed `=` run in a content row, not a border) — leave it, or make it elastic?

## how to drive / verify

- memory frame: `p7c memory.reload && p7c memory.show 1 | bin/dev/strip-ansi-colors`
- width uniformity: pipe to `| awk '{print length}' | sort -u` → single number.
- **other frames** (`context.provider.frame` is NOT loaded in the memory zenka) — render
  via the frame primitives in eval-code (one line):
  `p7c memory.eval-code 'my $f=$code{"ascii.frame.load"}->("feedback"); return $code{"ascii.frame.render"}->({descriptor=>$f->{descriptor},values=>{RULE=>"x",WHY=>"y",APPLY=>"z"}});' | bin/dev/strip-ansi-colors`
- after ANY frame yaml edit: `p7c memory.reload` (clears the frame cache via init_code).

## gotchas banked this session

- **File::stat** is imported project-wide and overrides built-in `stat` to return an
  OBJECT. use `File::stat::stat($path)->mtime`, never `(stat $path)[9]`. (we ended up
  dropping mtime entirely — see next.)
- `stat _` (the `_` filehandle) trips P7's `strict subs` at compile — bareword error.
- mtime caching has 1-second resolution → two edits in the same second poison the
  cache permanently. that's WHY we use reload-clear (`init_code`), not mtime.
- `memory.startup` has an idempotent `return TRUE if <memory.ready>` guard at the top —
  cannot hang cache-clears off it (short-circuits on reload).
- no-slot border tops with all-min-1 fills: largest-fill tie → FIRST → leading corner
  stretches. give such a top a slot OR a uniquely-largest non-corner fill (`::`).

## uncommitted batch (sign together, then commit)

```
src/ascii.frame.load               src/ascii.frame.render
src/ascii.frame.render.border_line src/ascii.frame.render.color
src/ascii.frame.init_code                         (NEW)
cfg/zenki/memory/source/ascii.frame.init_code  (NEW source marker)
data/yaml/ascii-frames/memory-tree-root.yaml
data/yaml/ascii-frames/feedback.yaml
data/md/handover/CLAUDE-CATCHUP-2026-06-04-s3-frame-idiom.md   (this file)
```
plus auto-generated whitelist / src-ver / dep-graph as usual.

## pointers

- reference render: `/tmp/frame.asc`
- design doc: `data/md/design/PLUGIN-SLOT-SELECTOR.md`
- vision: `data/ai-mem/claude/topic-ascii-desktop-domains.md` (role-vs-glyph / windowing —
  the NEXT layer after convergence; genuinely kimi-shaped work, unlike this taste-laden pass)
- prior: git `e8eedf1de` (s3a), `7f2c04a03` (s2)

#,,,,,,.,,,,.,...,...,.,,,,..,,,.,,..,..,,..,,..,,...,...,...,...,,,,,...,,,.,
#JKRQTEEQBMJHEB2KZDWO7ZWVXDS5T2OXWME3CPY7ANTNCMWXYNX55IFIWZXZ3B6KXMWHKY2OZJGB4
#\\\|32E5U3CFJHBAFOQVVPO67UIU7TBAKDE5N4TZTZG4JKY7PK5WFUK \ / AMOS7 \ YOURUM ::
#\[7]A6WJA3E7O5TGOKD5XQ4TAXPZOTTB5GAYFW7432FFRD4NO2E3ZMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
