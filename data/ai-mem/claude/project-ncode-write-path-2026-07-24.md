---
name: project-ncode-write-path-2026-07-24
description: ncode.cmd.suggest/apply's syntax-gate + write path landed and live-verified end-to-end; chmod-child gained a ported create command; bin/ptd -c and bin/format-code temp-file handling fixed along the way
metadata:
  type: project
---

**Landed 2026-07-24, one extended session (Claude Code / Sonnet 5).** Started
as "wire a `ptd -c` syntax gate into `ncode.cmd.apply`" and expanded into a
full live shakeout of `ncode`'s never-before-tested write path. See
[[feedback-posix-group-write-precedence]] for the core diagnostic finding.

## what shipped

- **`bin/ptd -c`** — was decorative: always `exit(0)` regardless of real
  syntax errors, and only ran the `perl -c` fallback when perltidy itself
  failed (perltidy silently accepts plenty of broken perl — verified with a
  missing-semicolon file that perltidy passed clean but `perl -c` caught).
  Now: `perl -c` always runs in `-c` mode, exit code reflects real pass/fail,
  and the p7-macro false-positive filter (`Can't modify glob in ...
  assignment`) broadened to catch the `defined or assignment (//=)` variant
  that `<data.key> //= {}` produces — the old regex only matched plain
  scalar assignment and was silently failing real modules.
- **`bin/format-code`** — temp files were `File::Temp`-random
  (`format-code.XXXXXX.tmp`), invisible to the module loader only by luck of
  not matching dot-naming. Now `.tmp.<basename>`, same directory,
  dot-prefixed (loader-invisible on principle, not luck), deterministic —
  and a pre-existing `.tmp.*` file aborts the run with a collision warning
  instead of being silently clobbered.
- **`ncode.cmd.suggest`/`ncode.cmd.apply`** — were unreachable via `p7c`/cube
  dispatch entirely: both expected a ready hashref via `shift`, but cube
  dispatch always passes a `$call_args` object with `args` as a raw string.
  Added a JSON-args adapter (`suggest`) and a plain-text `<fix_id> |
  --session <root>` adapter (`apply`), matching the usage hints `suggest`
  already printed. `ncode.init_code` now preloads `JSON::PP` for this.
  `suggest`'s session-seed also called `<[base.time]>->(4)` — no such module
  exists anywhere in the codebase (same dead call found independently in
  `coding.cmd.call-tool`) — replaced with `$$`/`time`, not chased further.
- **`ncode.cmd.apply`'s syntax gate** — builds the proposed content, writes
  it to a scratch file via `<[file.temp]>` (zenka's own writable dir,
  collision-safe naming, auto-cleanup — far simpler than the same-directory
  `.tmp.<name>` + chmod-child dance that was tried and abandoned first, see
  below), runs `ptd -c` on it, and only proceeds to the real write if clean;
  reverts otherwise.
- **`ncode.cmd.apply`'s real write** — now uses `chmod_child`'s `restore`
  command for a temporary permission grant (write, then restore original
  mode), mirroring `coding.tools.handler.replace_in_file`'s pattern, with
  the group-write-not-other-write fix from
  [[feedback-posix-group-write-precedence]].
- **`ncode.start.chmod_child`** gained a `create <path>` command, ported
  from `coding.start.chmod_child` (which already had it) — creates a new
  file as the admin user (taeki) when the target's own directory isn't
  group-writable, sidestepping a create/unlink-needs-directory-write problem
  that the file-level `restore` grant can't solve on its own. Confirmed:
  `ncode`'s original port of `coding`'s chmod-child had **silently dropped
  file-level write-grant support** when adapting it — coding's `"gw"`
  (file, group-write) became ncode's `"gwd"` (directory only), and `create`/
  `mkdir` were never ported at all. User's framing: "it was only ported,
  never used."
- **`configuration/zenki/ncode/{start,subroutine.white-list}`** — `suggest`/
  `apply` opened on `ncode`'s cube command whitelist (previously withheld
  pending the signature-gated approval system, see
  [[topic-write-access-security-infrastructure]]) explicitly for this
  testing pass; `subroutine.white-list` regenerated via the canonical
  `bin/dev/gen-sub-whitelist` tool throughout, never hand-edited.

## live-verification path (why this took so long)

1. First write attempt: bare `open '>', $file` → `Permission denied` on a
   taeki-owned `644` file. Assumed "needs chmod-child, not wired in" — true,
   but not sufficient.
2. Granted with `restore (mode|0002)` (other-write, copying
   `write_with_perms`) → still `Permission denied`, even after confirming
   via `stat` that the mode really did change to `646`. Chased a false trail
   through mount namespaces, AppArmor, Landlock (`dmesg` showed the LSM is
   *compiled in*, which is not the same as *anything using it* — a
   reasoning error caught by the user: "if it were, the coding zenka could
   not write either").
3. **Direct A/B test against `coding`** (same uid/gid/groups, live process)
   writing the identical taeki-owned file — succeeded immediately. Reading
   `coding.tools.handler.replace_in_file`'s actual grant command (`"gw"` →
   `0020`) vs `write_with_perms`'s (`"restore" | 0002`) is what surfaced the
   POSIX group-match-precedence bug — see
   [[feedback-posix-group-write-precedence]] for the mechanism.
4. Fixed the file-write grant → real content mutation confirmed live
   (`$_` → `$ARG` via the `p7-arg-regression` pattern), mode correctly
   restored to `644` after.
5. Hit a **second**, distinct permission wall: the syntax-check scratch file
   needs to be *created* next to the target (e.g. inside `modules/`, `755`,
   no group-write) — creating a new file needs directory-write, not
   file-write, so the just-fixed grant didn't cover it. First fix attempt
   (chmod-child `create` + `gwd`/`restore` around `unlink`) worked but was
   objectively over-complicated; user pointed at `base.file.temp`
   (aliased `<[file.temp]>`) as the already-existing, already-correct tool
   — zenka's own writable scratch dir, no directory-permission problem to
   solve at all. Replaced the whole dance with one call.
6. Full pipeline re-verified clean end-to-end after the simplification: no
   leftover temp files anywhere, target mode restored, real content change
   confirmed.

## update, same session: ncode.cmd.assess wired up (regex.assess pipeline)

`ncode.regex.assess` (extracts a confidence-scored candidate regex pattern
from an old/new diff) plus its five dependency modules
(`context.diff.find_line_changes`/`.lines_similar`/`.find_resync`,
`context.pattern.extract_from_change`/`.assess_generalizability`/
`.calculate_confidence`/`.generate_name`/`.generate_description`,
`context.string.common_prefix_len`/`.common_suffix_len`) all already
existed, fully built, completely unexercised — no `ncode.cmd.*` entry point
ever called any of it. Added `ncode.cmd.assess` (same JSON-args adapter
shape as `suggest`) to expose it via `p7c`.

**Root cause of why it silently failed at first** (`"subroutine
context.diff.find_line_changes not defined"` despite the whitelist looking
right): `context` is its own zenka namespace
(`configuration/zenki/context/`), and `ncode`'s `modules.load` never
included it — same class of incomplete port as the `chmod_child` gap above;
`coding` already loads `context` for the same reason, `ncode` never got it
added. `bin/dev/gen-sub-whitelist`'s namespace-leak-prevention filter
(designed to stop dead call edges from *other* zenki polluting a
whitelist — see `get_zenka_namespaces()` in `bin/dev/dep-graph`) was
correctly stripping `context.*` from ncode's reachable set as an
unintended side effect of the real bug, not a whitelist-generation bug
itself. Fixed by adding `context` to `ncode`'s `modules.load`; a plain
`ncode.reload` was sufficient to pick it up, no zenka restart needed.

**Live test result — honestly mixed, and informative.** Assessed
`open my $fh, '<', $path or die $!;` → `my $fh = <[file.open]>->($path);`.
Got back a technically-valid but low-quality candidate: `0.65` confidence,
`partial` coverage, 6 capture groups from the generic fallback branch of
`context.pattern.extract_from_change`, but the `replace` value is the
literal new text unchanged — it does **not** reconstruct from the captured
groups, so this candidate would emit the wrong variable names if applied
anywhere else. This is exactly the tier-A/tier-B boundary discussed in the
same-session design conversation ([[topic-ncode-pattern-learning-loop]]):
naive line-diffing handles simple substitutions well but can't safely
auto-generalize a structural rewrite — the honest result here is "flag for
human/LLM authoring," not "auto-apply," and the low confidence score
correctly reflects that rather than over-claiming.

## known gaps, not yet fixed

- **Pattern schema mismatch, now traced further than `apply`**: patterns
  loaded from `data/yaml/ncode-patterns/*.yaml` that only define top-level
  `pattern`/`replace` (used by `suggest`'s detection scan and by
  `ncode.regex.assess`'s candidate format) silently no-op in `apply`, which
  only reads the `steps` array. Confirmed live: `single-quote-to-qw-scalar`
  (no `steps` defined) reported "1 fixes applied" but left the file
  byte-identical. Only patterns with an explicit `steps: [{tool: ncode,
  search:, replace:}]` block (e.g. `p7-arg-regression`) actually mutate
  content. **Traced the same gap into `ncode.regex.save`** (persists
  `<ncode.patterns>` to YAML): it only exports `pattern`/`replace`, never
  `steps` — so even a pattern that goes all the way through
  assess→expand→save still wouldn't be usable by `apply` without a
  `pattern`→`steps` synthesis step somewhere in that chain. Needs either
  that synthesis, or an explicit YAML-authoring convention that `steps` is
  required for patterns intended to be auto-applied.
- **`apply`'s revert path never got the chmod-child treatment.** The
  success-path write (`if ($verify_pass and $step_ok and $syntax_ok)`) is
  fixed; the `else` branch a few lines down, which tries to write
  `$original` back to `$file` when a check fails, is still a bare `open
  '>', $file`. In practice this hasn't bitten because failures caught so
  far never got as far as writing the real file in the first place (the
  syntax-check/verify gates catch problems before that point), but it's the
  same latent bug, unfixed.
- **Security posture is still "opened for testing."** `suggest`/`apply` are
  live on `ncode`'s cube whitelist now, gated only by the `ptd -c` syntax
  check + checksum-addressed fix IDs — not by anything resembling the
  signature-gated approval system [[topic-write-access-security-infrastructure]]
  describes as the eventual real gate. Whether this stays open, gets pattern-
  or reviewer-gated, or gets folded into that bigger design is an open
  decision, not yet made.

#,,,.,,.,,,,,,.,,,.,.,,,.,,,,,...,..,,..,,.,,,..,,...,...,..,,...,,,.,,..,.,.,
#6YDDGU6NTMOYXQQRESROOTO2N3KJIW775KRNBLIBSXH46GZP7SZHOSAW7KGALWLMRN7P6DNKBMSNK
#\\\|G57MM5N7CLPJZXRGK3V3WQXHEQASVLVO4NGDW5JSKF3FLZDFHTD \ / AMOS7 \ YOURUM ::
#\[7]7WDE3YJ3YGA3NCW72RL6TPNUKOEM7KMTMMYQALQUNDUI4IFFGMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
