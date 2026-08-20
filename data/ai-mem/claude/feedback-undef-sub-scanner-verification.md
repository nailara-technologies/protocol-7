---
name: undef-sub-scanner-verification
description: methodology for safely evaluating scanner-flagged "undefined subroutine" references; also covers the separate subroutines.load-early lazy-load-gate failure mode and console_report's default-off visibility gap
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

**6. A sub missing from `%code` at runtime has two distinct possible
causes — don't conflate them.** This scanner/`clear_from_disk` path is one
(a genuine compile-time gap). The other, separate mechanism:
`bin/Protocol-7`'s `p7_early_whitelist_load` (~line 374) loads each
zenka's own `cfg/zenki/<name>/subroutines.load-early` *before*
base modules even compile, and uses it to gate which subs get fully
compiled at all vs. deferred/skipped (lazy-load, not a reporting/
suppression list — confirmed live 2026-07-22: a new cross-namespace sub
that compiles perfectly cleanly still resolved to "Can't use an undefined
value as a subroutine reference" at its call site because it wasn't yet
listed in the *calling* zenka's own whitelist file, so the loader deferred
it and the hash key was never populated at all). Symptom difference: a
whitelist-gated-out sub produces "undefined **value**" (bare `$code{name}`
key never set); a genuine compile failure produces the `bin/Protocol-7`
stub's "called broken/undefined **routine**" message instead (see the
stub-installation code around line ~2050 — only fires when compilation is
*attempted*, so it never fires for a whitelist-skipped sub). When a newly
added cross-namespace call dies at a fresh zenka boot: check both — does
it compile at all (search `undef-subs` buffer / compile-time warnings),
**and** is it actually present in the calling zenka's own
`subroutines.load-early` (regenerated via `bin/dev/gen-sub-whitelist`, not
hand-edited).

Also worth knowing: `ae6b1f79b` (2026-07-20) gated `undef-subs` buffer
console/log visibility behind `base.referenced_subroutines.console_report`,
**default off** for every zenka including `v7` — so a genuine scanner
finding is now silent by default unless a zenka explicitly opts in. For
`v7` specifically (a boot-time failure there takes down the whole fleet's
ability to start anything, categorically worse than for any other zenka),
turning `console_report` on via `v7`'s own config is worth doing
deliberately rather than leaving it at the same default as everything else.

See also [[topic-auth-client-namespace-split]] for the concrete namespace-
split case this methodology was built around, and [[feedback-ncode-tools]]
for a caveat on `ncode replace` hit during the same session.

#,,.,,,.,,,,.,,.,,.,,,,,,,..,,,..,,,.,,,,,..,,..,,...,...,,.,,,.,,,,,,,..,..,,
#Y5LAIP2DSQK6B7KAIDL6LAAR6BS2GOG3HAKXQCVMECAM4IVMH4SKV2LYAELMTHHAVSEYLZ5JPQOY4
#\\\|V2QCJG5IY4RZOE6SJK7UEJ2VXYGAYMTORZT5GH7QCR2JLBDXMMZ \ / AMOS7 \ YOURUM ::
#\[7]IAKR5VTFYYSBA4FICASIJAFG55C3YQYQ5RIFKFBX7CEBAXELIMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
