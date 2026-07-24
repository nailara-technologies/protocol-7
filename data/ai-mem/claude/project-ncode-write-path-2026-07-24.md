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

## known gaps, not yet fixed

- **Pattern schema mismatch**: patterns loaded from
  `data/yaml/ncode-patterns/*.yaml` that only define top-level
  `pattern`/`replace` (used by `suggest`'s detection scan and by
  `ncode.regex.assess`'s candidate format) silently no-op in `apply`, which
  only reads the `steps` array. Confirmed live: `single-quote-to-qw-scalar`
  (no `steps` defined) reported "1 fixes applied" but left the file
  byte-identical. Only patterns with an explicit `steps: [{tool: ncode,
  search:, replace:}]` block (e.g. `p7-arg-regression`) actually mutate
  content. Needs either a `pattern`→`steps` synthesis fallback in `apply`,
  or an explicit YAML-authoring convention that `steps` is required for
  patterns intended to be auto-applied.
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

#,,,.,.,,,,,,,,,,,..,,,..,...,,.,,,,.,.,,,,.,,..,,...,...,,..,...,..,,,.,,,.,,
#QLUSGMQADKIOUKJ47XW3RS4RFX4PDU7WOR7AFALIY32C5THZRUJSMXGTMS2CB4MJERVRCM5UQSERY
#\\\|AVHAGXMTGQWKKWDC3FDEJQPWDT4XCHLXH36L3XS2X2AKM6YQOM7 \ / AMOS7 \ YOURUM ::
#\[7]S7RM54X4WUV5LKPOJEB72MAZSP3MKWQQOTCZZI262UO2MM37CYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
