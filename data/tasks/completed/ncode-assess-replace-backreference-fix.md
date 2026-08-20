## [:< ##

# name  = task: ncode assess replace-backreference fix
# descr = make ncode.regex.assess's generic-token branch reconstruct
#         replace from its own capture group, so extracted patterns
#         actually generalize instead of overfitting to one line

## background

`data/ai-mem/claude/bug-ncode-assess-replace-not-backreferenced.md` has
the full write-up; read it first. Short version:
`src/context.pattern.extract_from_change` (called by
`ncode.regex.assess`, which `ncode.cmd.assess` wraps for `p7c`) builds a
regex `pattern` with a real capture group, but every branch builds
`replace` by splicing in the literal training-example value instead of a
backreference. Confirmed live via `p7c`, no changes made:

```
p7c ncode.assess '{"old":"## offset for 3D effect (parallax) ##","new":"## offset for 3D effect [ parallax ] ##","file_type":"module","namespace":"amos-term"}'
-> pattern: ## offset for 3D effect \(([\w\-]+)\) ##
-> replace: ## offset for 3D effect [ parallax ] ##      <- literal "parallax", not $1

p7c ncode.assess '{"old":"## default probe interval (seconds) ##","new":"## default probe interval [ seconds ] ##","file_type":"module","namespace":"transport"}'
-> pattern: ## default probe interval \(([\w\-]+)\) ##
-> replace: ## default probe interval [ seconds ] ##     <- literal "seconds", not $1
```

Concrete motivating case, don't lose sight of it: CLAUDE.md's own
convention is `[ word ]` for comment annotations, never `( word )`. Real,
unfixed occurrences exist today, e.g.
`src/amos-term.render.draw_buffer:41` and
`src/transport.init_code:27` (also `base.zenka.push.reply-handler.
offline:19`, `work.calculate_suggestion_relevance:83`, and others — grep
`^\s*##.*([a-z_]\+)\s*##\s*$` in `src/` excluding lines that already
use `[`). This whole class is currently un-sweepable via `ncode.cmd.
assess` because every extracted pattern only matches the one line it came
from.

## the fix — scope it to the generic/token branch only

`src/context.pattern.extract_from_change` has 5 branches (lines
51-111): numeric, identifier, quoted-string, value-assignment, and the
generic/multi-word "token" fallback (lines 92-103, the one that fired in
both repro cases above). **Only fix the token branch.** The other four
branches deliberately implement "replace every match with this one fixed
new value" semantics (batch-rename an identifier, force a specific
number/string everywhere a shape matches) — that's a legitimate, distinct
use case from "reconstruct a structural wrapper around whatever was
captured," and changing their behavior isn't in scope here. If you find
evidence one of those four is *also* hit by real callers expecting
generalization (check `data/yaml/ncode-patterns/*.yaml` for existing
patterns whose `vars` marks them `number`/`identifier`/`string`/`value`,
and check whether any caller's test/usage assumes reconstruction), flag
it in your report — don't silently change it without confirming first.

**What "fix the token branch" means:** right now (lines 92-103) it does:

```perl
$escaped_old =~ s|\w+|([\\w\\-]+)|g;
...
$pattern = $prefix . $escaped_old . $suffix;
$replace = $new;   ## <-- bug: always the literal full new-line text ##
```

Detect the case where `$new_middle` is a **structural wrap** of
`$old_middle` — i.e. `$new_middle` contains `$old_middle` as a
contiguous substring (`index($new_middle, $old_middle) >= 0`). In that
case, split `$new_middle` into `$wrap_prefix`/`$wrap_suffix` around that
substring, and build:

```perl
$replace = $prefix . $wrap_prefix . '$1' . $wrap_suffix . $suffix;
```

(escaping `$prefix`/`$suffix`/`$wrap_prefix`/`$wrap_suffix` as needed —
they're going into a **stored replacement string**, not a live `s///`,
so match the escaping/quoting convention `ncode.regex.load`/`ncode.regex.
save`/`ncode.cmd.apply` already use for backreferences post-`cb45d56d0`
— that fix already made the actual substitution engine correctly
interpolate `$1`/`$2` from a YAML `replace` string, so you're only
fixing pattern *generation* here, not consumption; don't touch the
consumption side unless you find it's actually still broken for this
case too).

`$escaped_old` currently collapses **every** run of `\w+`/`\d+`/`\s+`
into its own capture group — for a single-word case like `parallax` this
is one group (`$1`), but a multi-word `old_middle` (e.g. "3D effect")
would produce multiple groups. For this task, it's fine to only handle
the single-capture-group case correctly (use `$1`); if `$old_middle`
produces more than one capture group, keep the current literal-`$new`
behavior for now (same as today, not a regression) and note it in your
report as a follow-up rather than trying to solve positional
multi-group mapping in this pass — that's real design work, out of
scope here.

If `$new_middle` does **not** contain `$old_middle` as a substring (a
genuine content change, not a structural wrap — e.g. rewording rather
than bracket-wrapping), keep today's literal-substitution behavior. That
case isn't reconstructible from a single line of evidence and forcing a
backreference there would be wrong, not just unhelpful.

## acceptance checks

1. `ptd -c` clean on the touched file(s).
2. Re-run both repro commands above. `replace` should now come back as
   `## offset for 3D effect [ $1 ] ##` and
   `## default probe interval [ $1 ] ##` respectively (or equivalent —
   confirm the literal string `$1` appears in place of the captured
   word, not the training-example's literal word).
3. **Persist and apply for real**, against real repo occurrences, not a
   scratch file — this is what the original ask was for. Use
   `ncode.cmd.expand`/`ncode.regex.save` to persist one of the two
   confirmed patterns (or a merged/generalized version covering both —
   your call, but keep the pattern narrow/scoped rather than
   overclaiming), then `ncode.cmd.suggest`/`ncode.cmd.apply` it against
   at least 2-3 of the real occurrences listed above (or found via the
   grep). Confirm via real `p7c` output (quote it in your report, not a
   paraphrase) that a **different** word than the one in the training
   example gets correctly bracket-wrapped — that's the actual proof the
   backreference fix works, not just that the stored string contains
   `$1`.
4. `ptd -c` clean on every file `apply` touches.
5. Leave `<ncode.patterns>`/the touched module files staged for human
   sign-off, but do not stage/sign/commit yourself.

## notes

- Per project convention, live-verify via real `p7c` calls and quote
  actual output in your report — don't trust your own self-summary
  without it, and don't claim something is fixed based on code reading
  alone.
- If `chmod-child Permission denied` recurs on a long-running `ncode`
  zenka mid-task, try `p7c v7.stop ncode` first (on-demand respawn picks
  it back up) before assuming a logic bug — known stale-pipe-state
  issue, see `data/ai-mem/claude/feedback-chmod-child-restore-readline.md`.
- Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
  first per this project's convention.

#,,,,,,.,,..,,,,,,.,,,,,.,..,,.,,,.,.,.,.,.,,,.,.,...,...,.,.,.,,,,.,,..,,,.,,
#O4FIINSFQDTXRQA5X3464JWDKRSZBZMFMW6ARAL4Z574SZFCYCKIMYXQOSVASVBO7EORFKJHLJG3K
#\\\|Q2BU3NWZINLFDX52J4PX5EKTOZN6WXPU23A7T6ZKJXCJZFNGQCR \ / AMOS7 \ YOURUM ::
#\[7]ALFFWKV62TYQE5XQVONJ7EIEWLUWM6FEBP3GGEJOGTLAR5VH52AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
