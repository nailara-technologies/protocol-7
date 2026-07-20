---
name: undef-sub-scanner-verification
description: methodology for safely evaluating and fixing scanner-flagged "undefined subroutine" references before converting or renaming anything
metadata:
  type: feedback
  originSessionId: 5c95ba04-6293-4ece-a4ae-455aa1095528
  modified: 2026-07-20T09:57:01.683Z
---

`base.referenced_subroutines.clear_from_disk` (called from `base.cmd.reload`
on every `init`/`all` reload) scans compiled source for `$code{'literal'}`
patterns and reports ones with no matching `%code` entry. The scanner does
**zero reachability analysis** — it flags a reference the instant the
containing file is compiled into a zenka, regardless of whether the code
path is ever actually executed there. Before touching any flagged entry:

**1. Check for existing guards first.** Many flagged references are already
safe: `eval { <[name]>->() } // fallback` catches the "undefined subroutine
reference" die and degrades gracefully (found in `ui.cmd.ui-show`'s
`ascii.frame.load` call — this was never a live risk). Also check for
`exists $code{'literal.name'}` guards immediately before the call — these
themselves get flagged by the scanner (same regex match) even though the
call they guard is already safe. Read the actual surrounding code, don't
assume "flagged = broken."

**2. Grep for dynamic (`sprintf`) construction before renaming/moving
anything.** The scanner only matches literal `$code{'quoted.name'}`
patterns — `<[$var]>` (dynamic form) compiles to `$code{$var}->()` and is
*invisible* to the scanner by construction. But this cuts both ways: other
code may resolve a sub name via `sprintf('prefix.%s.suffix', $var)` instead
of a literal call, and grepping for the literal old name won't find it.
Hit this twice in one session: `base.net.connect` had
`sprintf('auth.%s.authenticate', $type_str)` that broke silently after an
`auth.unix.authenticate` → `auth.client.unix.authenticate` rename (nshell
failed to connect to cube until found); `base.handler.auth` constructs
`sprintf('auth.callback.cap-neg.%s-%s', $action, $capability)` and
`sprintf('plugin.auth.%s', $auth_method)` — both would have broken the
same way if those clusters had been renamed. **Always grep the target
name(s) for `sprintf.*<name-fragment>` and `sprintf.*'%s'` constructions
across the whole tree before a rename, not just literal `<[...]>` calls.**

**3. Trace actual callers before assuming a namespace gap is a bug.**
`context.provider.frame` unconditionally called `ascii.frame.load` — real
gap, `coding`/`nshell` didn't load `ascii`. But `ui.render.tree` looked
like a second caller (`grep -o` matched `ascii.frame.render`) — it was
actually a **comment** (`## LLL: integrate with ascii.frame.render once
frame templates exist`), not code. `grep -o "ascii\..*"` matches comments
too; verify with the actual compiled reference, not a raw string grep.

**4. A "missing dependency" zenka-side often traces to one specific,
possibly-dead caller — check reachability before adding the dependency.**
`crypt.C25519.store_remote_key`/`validate_remote_key_checksum` flagged in
`nshell` traced entirely to `nshell.tofu_validate_pubkey`, which has zero
callers anywhere in the codebase (dead/unwired scaffolding, not a live
risk). Don't reflexively add the missing namespace to `modules.load` —
check whether the flagged reference is even reachable first.

**5. Self-reference reload gotcha.** Editing `base.cmd.reload` or
`base.referenced_subroutines.clear_from_disk` themselves only takes effect
on the *next* `reload`/`init` call, not the one that triggers the reload
picking up the new source — the currently-executing invocation is still
running the old compiled closure. If a fix doesn't seem to take effect,
reload again before assuming the fix is wrong.

**How to apply:** work through `undef-subs` buffer entries one at a time —
find the actual call site(s) via targeted grep (not the buffer's own
"found in" line alone, which only shows one instance), read the full
surrounding function, check `modules.load` for both the calling and
target zenka, and only then decide: existing guard (leave alone), genuine
gap needing a `modules.load` addition, needs [[base.code.call_expected]]
(condition holds → truly expected, loud error if still missing) or
`base.code.call_optional` (no expectation either way, silent skip), or a
dead/unwired caller worth flagging back rather than silently fixing.

See also [[topic-auth-client-namespace-split]] for the concrete namespace-
split case this methodology was built around, and [[feedback-ncode-tools]]
for a caveat on `ncode replace` hit during the same session.

#,,..,...,,..,,,.,.,,,,.,,..,,,.,,.,.,,,,,,,,,..,,...,...,..,,.,.,,,,,,,,,.,.,
#GXCWSKWTHMULYNKUMWDTI5UG4PQYPPHH6P7BGBWC3RLRTXY7R3FTY3TCQX3DM3JWFYHBWPPBX7ZSQ
#\\\|C2PJOSYYFSE7YBJ6QI32HLMNEZVAIRMBQO2TLZJRTZOIRVNBCW7 \ / AMOS7 \ YOURUM ::
#\[7]DOZR7ZXRSBGYIMLLGFCNWMT4JDBWSPVYR6XTKV2YE2SIWSYL5EDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
