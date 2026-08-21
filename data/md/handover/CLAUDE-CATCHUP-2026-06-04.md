# Claude Catchup — 2026-06-04 (session 2) — frame plugin slots + variable border width

handover for resuming the ascii-frame / memory-status-bar work. READ the design
doc first: `data/md/design/PLUGIN-SLOT-SELECTOR.md` (full design + the deferred
vertical-slot roadmap). this file is the session narrative + gotchas.

continues from session 1 (same day, "memory zenka: from empty shell to useful")
— that handover is in git at `db76d35fb`; the tree foundation (build / flow /
score) lives in `data/ai-mem/claude/topic-memory-tree-zenka.md` and
`data/md/design/MEMORY-TREE-SYSTEM.md`.

## one-line state

the memory zenka's frame now has a context-aware **status bar** (plugin-slot +
selector), and `ascii.frame.parse` handles **variable border width** (`:` vs
`::` first-class). all verified live. ONE batch is pending sign + commit.

## 1. variable-border-width parser fix  [ the original ask ]

`ascii.frame.parse`: after picking the border CHARACTER, detect its WIDTH as the
minimum consistent run across content rows (`::` → width 2). taking the MIN run
never eats content. borders are now true `::` strings. this killed the +1 spacer
drift. also fixed a latent padding bug it exposed: pure-whitespace spacer rows
are now excluded from the padding scan (they had poisoned lpad/rpad to 42).

## 2. plugin-slot + context-aware selector  [ the main feature ]

the top-bar bracket is now a live status region. "most interesting value for the
current page" — a selector ranks candidate providers by interest and surfaces
the winner. inspiration: `read-me/documentation/dev/research-notes/user-interfaces.00007.asc`.

- **foundation (generic, zenka-agnostic):**
  - `ascii.frame.slot.select` — `{providers=>[coderef...], context=>$ctx}` runs
    each, picks max `->{interest}`, earliest-wins tie, broken providers skipped,
    all-fail → empty. verified: max / skip / tie / all-fail.
  - `ascii.frame.bar` — `{frac=>0..1, width=>N, char=>':'}` → ptd-style fill bar
    (`bin/dev/ptd` `show_progress` is the reference), left-justified to width.
- **integration (NO render-path change):** border slots read straight from
  `%values` in `ascii.frame.render.border_line`; `render.color` is a
  POST-PROCESSOR (colorizes already-rendered lines, does not resolve slots). so
  `memory.tree.node.render` (root variant) builds `$ctx`, runs the selector, and
  sets `$values{PROGRESS}` / `$values{STATUS}`. that's the whole hook.
- **providers** `memory.status.provider.*` (each: `$ctx` in, `{value,label,interest}` out; value PADDED to `$ctx->{width}=23` so the border never jitters):
  - `branch_count` — "N of TOTAL branches"; interest 0.05 = resting default.
  - `weight_captured` — frac = visible-slice score / total tree score; interest
    `0.5*frac`. with 164 branches the top slice is ~8% so it only surfaces on a
    SKEWED tree (correct — it's a contextual signal, not the default).
  - `focus_saturation` — 0 when no focus set; else `0.7 + 0.3*frac` (frac = share
    of children with flow_focus>0). spikes above everything when focus is active.
  - `rebuild_age` — `:. rebuilt Ns ago .,` flash; interest 0.6 for <10s, else
    0.04 (yields to the resting default).
- **config:** `memory.cfg.status_providers` in `cfg/zenki/memory/zenka.v7`.
- **yaml:** `memory-tree-root.yaml` top border is now `..[{{PROGRESS}}]..[ memory tree ]:.`
- **VERIFIED 4-state ladder:** <10s rebuilt-flash → branch-count resting →
  focus bar (focus set); width rigid at 57, no jitter.

## how to drive / verify

- `p7c memory.show 1 | bin/dev/strip-ansi-colors`  (strip-ansi for width checks)
- set focus: `p7c memory.eval-code '$data{memory}{focus}={session=>5}; return "ok";'`
  NOTE: `<...>` / `<[...]>` P7 sugar does NOT parse in eval-code (runtime) — use
  `$data{...}` and `$code{"mod"}->()`. keep the perl on ONE line.
- live introspection now enabled in the memory zenka: `memory.list-subs <pat>`
  and `memory.exec-sub <sub> <args...>`.
- width uniformity: `p7c memory.show 1 | bin/dev/strip-ansi-colors | awk '{print length}' | sort -u` → must print a SINGLE number.

## ntime gotcha [ important — cost us a round-trip ]

`base.ntime.b32` does NOT round-trip through `base.ntime_BASE32_to_numerical`
(it is the reverse-order, non-sortable encoder — see `feedback-ntime`). storing
`built_ntime` with it produced garbage ages. FIX: store `<memory.built_ntime>`
as RAW NUMERICAL `<[base.ntime]>`; compute `age = (now - built)/4200` inline.
`base.ntime.delta_seconds` two-arg form works; its single-arg "delta to now"
path is suspect — avoid it. verify any ntime encode/decode empirically.

## deferred / next  [ additive, non-blocking ]

- **vertical slots** (design doc "future: vertical slots"): inverted scrollbar —
  thumb renders at the OPPOSITE border width of the track (`:` vs `::`),
  distinguishable by contrast, costs no column. plus a bottom-right mini
  horizontal echo of the scrollbar value. COST: `ascii.frame.render` uses a
  single `border->{left}/{right}` for the whole frame; a scrollbar needs PER-ROW
  border state. renderer change, not just a provider.
- cleaner double-colon pass on the frame.
- **term-rarity scoring attribute** — the OTHER open roadmap thread (IDF-style
  wordcount table, re-sort by uniqueness). see `topic-memory-tree-zenka.md`.

## working-with-kimi note

kimi built the 4 providers cleanly from a tight spec (extraction-style work it is
good at), BUT chose `base.ntime.b32` for the timestamp — the non-decoding
encoder — so the age came out garbage. claude diagnosed + fixed. lesson holds:
verify kimi's ntime/encoding choices and its API picks empirically (it also
reported test (a) as a "discrepancy" when it was actually correct behavior).

## pending sign + commit batch

```
src/ascii.frame.parse                          (parser fix)
src/ascii.frame.slot.select   src/ascii.frame.bar
src/memory.status.provider.{branch_count,weight_captured,focus_saturation,rebuild_age}
src/memory.tree.node.render   src/memory.startup
cfg/zenki/memory/zenka.v7                   (status_providers + list-subs/exec-sub access)
data/yaml/ascii-frames/memory-tree-root.yaml
data/yaml/ascii-frames/memory-tree-root.example.asc
data/md/design/PLUGIN-SLOT-SELECTOR.md
data/md/handover/CLAUDE-CATCHUP-2026-06-04.md       (this file)
```
plus auto-generated: whitelist / src-ver / dep-graph / source-markers.

## pointers

- example render: `data/yaml/ascii-frames/memory-tree-root.example.asc`
- inspiration: `read-me/documentation/dev/research-notes/user-interfaces.00007.asc`
- prior session: git `db76d35fb`, `data/ai-mem/claude/topic-memory-tree-zenka.md`

#,,..,,..,.,,,.,,,.,.,,..,,,,,,..,.,.,..,,,..,..,,...,...,.,.,..,,.,,,.,,,.,.,
#4LQBEED4OCKE46WM3P4YLDHYRO25RKQDDN3GPSCPUECK22YXBEO7JSP2AAEJRH5XMM6OBXZ4Q5IHQ
#\\\|HRBJP2EMJ73W7VKUKTIEZXMPHK4QJVDBUYD345ZPP4SRBBEZ72I \ / AMOS7 \ YOURUM ::
#\[7]KDEDFR3MEEMRBQAN67ZE5GBVOFMNREDCBJNYIBKRZCWWLIMUWMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
