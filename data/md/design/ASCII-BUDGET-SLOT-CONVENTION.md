## [:< ##

# ascii budget-slot convention
# a fixed-width bracket in a static template as a generic, resource-agnostic state register

[ origin: 2026-07-21 — user observation while watching `coding.round-progress`
  live during the file-io-fix test task, generalized here into a named,
  cross-cutting convention. ]

related prior art [ this document names the principle those already embody ]:
- `bin/dev/ptd` `show_progress` — simplest existing instance
- `ascii.frame.bar` / `ascii.frame.slot.select` (see `topic-frame-plugin-slots.md`,
  `data/md/design/PLUGIN-SLOT-SELECTOR.md`) — closest existing implementation to
  the generalized form below: provider-based, interest-max selection, already
  resource-agnostic (`PROGRESS`/`STATUS` slots fed by arbitrary providers)
- `src/coding.cmd.round-progress` — bespoke, hand-rolled, the instance that
  prompted this note

---

## the observation

```
:::[:::::        ]::[ task-7GCYT2Q | R:01 | http: 156s of 384s [%040] | tools: -- ]:.
```

the bracketed region isn't decoration — it's a **budget window**: a fixed total
capacity, a consumed portion, a remaining portion. what's consumed and what
remains doesn't have to be time. it could be tokens against a context ceiling,
disk space against a quota, GPU thermal headroom, retry attempts against a max,
or wall-clock time against a stall timeout — the *shape* of the representation
doesn't change with the resource type. a progress bar is just a budget with a
1-D fill.

## why this matters beyond "it looks nice"

the region is a **fixed-width character range at known positions inside an
otherwise-static template**. that has a consequence past human readability:
anything that knows the contract — total width, fill/empty characters, label
position — can read *or write* the state without understanding anything about
what's being measured. no parsing, no NLP, no model needed to advance it. a
five-line shell script that increments a counter and re-renders the bracket is
a fully competent participant. this is the same "template stays static, only
the addressed slot varies" idea `ANTI-ENTROPIC-TEMPLATE-PRINCIPLES.md` already
argues for at the language level ("templates as portable, validated logic" —
code stays put, logic/state moves through defined slots) — this document is
that principle applied to the visual/state-encoding layer specifically.

## the contract, made explicit

a budget slot needs exactly:
- **total width** (fixed, part of the static template)
- **fill / empty characters** (e.g. `:` / ` `, or `#` / `-` — convention, not
  fixed universally, but fixed *per rendering context*)
- **fraction source** — consumed/total, expressed however the caller likes
  (elapsed/ceiling seconds, bytes/quota, rounds/max) — the slot renderer
  doesn't need to know which
- **label position** (inside or outside the bracket — `[%040]` style inline
  percentage in the example above, or a separate `STATUS` slot as
  `ascii.frame.slot.select` already does)

this is already exactly what `ascii.frame.bar` + `ascii.frame.slot.select`
implement — a provider returns `{value, label, interest}`, the selector picks,
the renderer fills a slot at a known position. `coding.round-progress` reimplements
the same shape by hand, independently, with its own ANSI/bracket logic.
`bin/dev/ptd`'s `show_progress` is a third, simpler independent instance.

## consequence, not urgent

no immediate migration proposed — this is a naming/documentation pass, not a
refactor plan. but if a fourth budget-slot need comes up (disk quota under a
zenka's `var_P7` dir, context-window consumption during a coding task, retry
budget in the http_error recovery path we fixed earlier this session), it's
worth reaching for `ascii.frame.bar`/`ascii.frame.slot.select` first rather
than hand-rolling a fourth bespoke bar — the provider-based version already is
the generalized form this document is naming, it just hasn't been pointed at
from outside the frame-system's own docs before.

## connections

- `data/md/philosophy/ANTI-ENTROPIC-TEMPLATE-PRINCIPLES.md` — the language-level
  version of "static template, addressed variable slot"
- `data/ai-mem/claude/topic-frame-plugin-slots.md` — the existing generalized
  implementation this document names the principle of
- `data/md/design/PLUGIN-SLOT-SELECTOR.md`, `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
  — the wider ascii-frame/console design family this sits alongside
- `src/coding.cmd.round-progress`, `bin/dev/ptd` (`show_progress`) — independent
  existing instances of the pattern named here

#,,,,,,.,,.,,,,,.,,,,,,..,.,,,.,.,,..,,,,,,,.,..,,...,...,.,.,,.,,..,,...,,,.,
#V3NY2JXMTSFOVE4QI5VTX2JJ3XH7S3BDUBX2XVRYARONWYAGSPRTML7KYTJSTBF5PQXQFAYY6PNBY
#\\\|GYRDEPOYZ4ZJIEFOVVKKGQOBRJCLJRJQQLC5FBGSYKPMLTYWWJO \ / AMOS7 \ YOURUM ::
#\[7]DZGWAMZBVOLUTIWBGGYGNNVWJZAEY4MPLGOEN6WLC5K35EEHCICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
