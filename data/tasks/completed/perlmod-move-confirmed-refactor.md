# perlmod load/autoload — move 11 confirmed-hot loads into init_code

**Priority:** Medium
**Type:** Refactor, small/mechanical per file — real code edits
**Model:** kimi K3

## Before you start

Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
first — both now include notes from the categorization/re-verification
work this task follows on from.

## Background

`data/tasks/perlmod-move-reverification-results.md` re-verified 59
candidate `MOVE` recommendations down to **11 confirmed**. Everything below
is already independently verified (real callers traced, `.cmd`/`.handler`
frequency corroborated via `access.zenki` grants or timer registrations,
false positives excluded) — this task is the actual code change, not
another verification pass.

**Important context for the edit itself**: `base.perlmod.load` short-
circuits via a single hash lookup in `<base.perlmod.loaded>` once a module
is loaded — a redundant per-call load is not a real CPU cost. The reason
each of these 11 is still worth moving is either (a) first-call latency
(avoiding the load happening lazily on the first real request instead of at
boot) or (b) removing genuinely dead-weight inline load code once the
module is already guaranteed loaded by `init_code`. Don't add any
performance-motivated reasoning to commit messages/comments beyond that —
it would misstate why this matters.

## The 11 files

For each: remove the per-call `<[base.perlmod.load]>->(...)` /
`<[base.perlmod.autoload]>->(...)` call (and its guard, if any, e.g.
`if not <[base.perlmod.loaded]>->(...)`) from the listed file, and add the
equivalent call to the target `init_code` file instead (matching that
file's existing style — most `init_code` files call
`<[base.perlmod.load]>->('Module::Name');` as a bare statement near their
other preload calls).

1. **`src/base.file.temp`** — `File::Path` → `src/base.init_code`.
   Real path: `<[file.temp]>` called by `base.file.zenka_dir.write:126` on
   every atomic `>`-mode write; that helper has 60+ callers.

2. **`src/base.handler.read.encryption-wrapper`** —
   `Crypt::AuthEnc::ChaCha20Poly1305` → `src/base.init_code`. Installed
   as the state-3 session input handler by
   `protocol.protocol-7.init_code:91` / `encryption.init:106` — per-message
   read path of every encrypted session.

3. **`src/base.handler.write.encryption-wrapper`** — same module,
   `Crypt::AuthEnc::ChaCha20Poly1305` → `src/base.init_code`. Factory
   for the per-session output encryption handler
   (`protocol.protocol-7.encryption.init:115-127`), installed on every
   encrypted link. (Since both #2 and #3 need the same module in
   `base.init_code`, add it once, not twice.)

4. **`src/channels.util.yaml_decode`** — `YAML::XS` →
   `src/channels.init_code`. Single YAML entry point for
   `channels.cmd.update:34`, the central write path for every channel
   publication; `channels` runs `start.on-demand = 1`, so this loads on
   virtually every activation.

5. **`src/coding.tools.handler.git_diff_output`** — `Git::Wrapper` →
   `src/coding.init_code`. Called by `git_diff_staged:17` /
   `git_diff_unstaged:17` on every git-diff tool call in the coding-agent
   loop. `coding.init_code` already preloads other tool-path deps — this
   one was missing.

6. **`src/jobsite.dispatch.assessments`** — `Encode`, `HTML::Entities`
   → `src/jobsite.init_code`. Every completed fetch batch funnels into
   this via several handler paths; `jobsite.init_code` already preloads
   `YAML::XS`+`JSON::XS` but not these two.

7. **`src/jobsite.util.build_prompt`** — `HTML::Entities`, `Encode` →
   `src/jobsite.init_code`. Same two modules as #6 — add once. Called
   per-job inside every assessment batch by
   `jobsite.dispatch.assessments:132` and per-repair by `dispatch.repair`.

8. **`src/context.git.recent_changes`** — `Git::Wrapper` →
   `src/context.init_code`. Rendered via
   `<[context.git.recent_changes:budget=N]>` in `coding-assistant.tmpl` on
   every coding-backend model request, plus per tool call and per
   context-compose build.

9. **`src/models.backend.kimi_web`** — `Crypt::Misc` →
   `src/models.init_code`. Reached via
   `models.cmd.chat → models.chat.invoke_model → models.backend.kimi_web`
   on every kimi/kimi-code chat request; `models.init_code` doesn't
   currently preload this.

10. **`src/screen.setup.ensure-display`** — `Cairo`, `Glib` →
    `src/screen.setup.init_code`. `screen.setup.init_code` already
    loads `Gtk3` and calls `Gtk3->init` — only `Cairo`/`Glib` need adding
    alongside it. Called by `screen.setup.open_window:15` and
    `enumerate-monitors:8` in this already-GUI-only zenka (no boot-cost
    concern here — the whole zenka is GUI-only).

11. **`src/zulum.cmd.export-streams`** — `JSON` →
    `src/zulum.init_code`. `zulum.init_code:55-62` itself schedules
    this on a 200ms repeating timer for the entire zulum zenka lifetime —
    it always runs, so eager-loading at boot is strictly correct.

## status [ 2026-07-26 ] — DONE, landed in `33e58f17b`. all 11 files
## confirmed re-verified 2026-08-25: no `perlmod.load`/`perlmod.autoload`
## calls remain in any of the 11 source files, and each target `init_code`
## carries the corresponding load.

## Verification per file

- `bin/dev/ptd -c <file>` on both the edited source file and the target
  `init_code` file after each change.
- Confirm the removed per-call load's guard (if present) is fully deleted,
  not left as dead code.
- Do not touch any file not listed above, even if it looks similar (e.g.
  don't go move unrelated loads in the same `init_code` file you're
  already editing — stay scoped to these 11).

## Constraints

- Real edits this time, not a read-only pass — but keep changes minimal:
  remove the per-call load, add the init_code load, nothing else.
- Leave signing to the system, no stub lines — do not attempt to fix or
  regenerate AMOS7 signature footers yourself.
- If anything about a file doesn't match its description above once you
  actually open it (line numbers drifted, module already preloaded, etc.),
  stop and report rather than guessing — this list was hand-verified, but
  re-confirm before editing since time has passed since the trace.

## Notes

- signatures_note: leave signing to the system, no stub lines

#,,..,..,,..,,,..,,.,,..,,...,,..,.,,,...,,..,..,,...,..,,.,.,,..,,..,,..,,..,
#JM7ZQHUI4GYYLNQSQ2GRJLGRH3S6WGY2HDR22H6ZZILTFEKZZ53NI7NB2N33R57QK5CWNFA4B2F4W
#\\\|4J2C37M7ECA4PXIXWGA3BAW23SUM442YIDF5MW5BIMRLZ54GV73 \ / AMOS7 \ YOURUM ::
#\[7]HSPVI2JPFUHPTP6KPHEO7WYIXGN7TPPLZMMRH5B46YKOLC457OCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
