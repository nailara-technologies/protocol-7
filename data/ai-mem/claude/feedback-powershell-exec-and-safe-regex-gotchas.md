---
name: feedback-powershell-exec-and-safe-regex-gotchas
description: "two subtle, reusable bugs found building powershell.cmd.get-event-log: (1) a multi-line script passed to powershell.exec's open3 array-form exec fails silently over WSL-to-Windows interop, single-line semicolon-joined works; (2) base.eval.comp_regex's Safe-compiled qr// doesn't compose with an outer m//i flag, must embed (?i) in the pattern text itself"
metadata:
  type: feedback
---

Found 2026-08-28 while building/fixing `src/powershell.cmd.get-event-log`
(`data/tasks/powershell-get-event-log-command.md`). Both are general, not specific to
that one command.

**1. `powershell.exec` (`src/powershell.exec`) and multi-line scripts.** It calls
`open3(..., $exe, '-NoProfile', '-NonInteractive', '-Command', $ps_script)` — array
form, no shell. If `$ps_script` contains embedded newlines (e.g. built from a normal
multi-line heredoc), the call reliably fails: exit code 1, completely empty stdout AND
stderr, nothing to diagnose from inside Perl. Confirmed via isolated reproduction
(bypassing the zenka entirely, calling `open3` + `powershell.exe` directly from a
throwaway script) that the IDENTICAL script logic works perfectly when joined into one
line with `;` instead of `\n`. Root cause is presumably the WSL-to-Windows interop
layer's argv-to-command-line marshaling not surviving embedded newlines inside a single
argument — not confirmed at that depth, but the workaround is solid either way.
**How to apply**: any future `powershell.exec` caller must build its script as ONE LINE
(semicolon-joined statements), never a multi-line heredoc, regardless of how the source
file formats it for readability.

**2. `base.eval.comp_regex` (`src/base.eval.comp_regex`) and case-insensitive matching.**
It compiles a caller-supplied pattern string inside a `Safe` compartment for sandboxing
(`$parse->reval("qr'...'", 1)`), returning a blessed `Safe::RootN::Regexp` object rather
than a plain `Regexp`. This object stringifies normally (looks like `(?^:pattern)`) and
matches correctly using whatever flags were baked into the ORIGINAL pattern text, but an
ADDITIONAL flag applied on the outer match (`$str =~ m|$compiled_pattern|i`) is silently
ignored — confirmed via isolated reproduction: an exact-case match against the
Safe-compiled object works, the same match with an outer `i` added does not, and the
identical pattern with `(?i)` embedded in the pattern TEXT before compilation does work.
**How to apply**: any caller of `base.eval.comp_regex` wanting case-insensitive (or any
other flag-based) matching must prepend the flag group to the pattern STRING itself
before calling it (e.g. `"(?i)$pattern"`), never rely on flags added to the outer match
operator afterward. Also: the function's own second parameter (an error-message scalar
ref) is easy to forget passing — without it, a genuine compile failure returns `undef`
for the error slot too, and naively dereferencing that (`$err->$*`) crashes instead of
producing a clean error message. Always pass `\$err_str` as the second argument.

**3. `Get-WinEvent -FilterHashtable` throws TERMINATING errors liberally.** Both for a
genuinely unknown log name AND for the entirely legitimate "zero matching events in this
window" case — `$ErrorActionPreference = 'SilentlyContinue'` does not suppress either.
First attempted a targeted pre-check (`-ListLog` existence test) for the unknown-log
case specifically; that fixed unknown-log but NOT the empty-result case, which hit the
exact same undiagnosable exit-1-empty-output symptom for a different reason. **The
general lesson, per the user's own correction**: don't pre-empt PowerShell failure modes
one at a time as they're discovered — wrap the whole query in
`try { ... } catch { Write-Output ('P7ERR:' + $_.Exception.Message) }` and parse the
sentinel generically (`if $raw_out =~ m|^P7ERR:(.+)|`) rather than matching specific
known error strings. This surfaces PowerShell's own real exception text (more accurate
than a guessed message) and covers every current AND future failure shape uniformly.
**How to apply**: any `powershell.exec`-based command should default to this generic
try/catch-and-sentinel shape from the start, not add specific pre-checks per failure
mode discovered through testing.

#,,,.,,.,,,..,,,.,..,,.,.,,.,,,.,,.,,,,.,,,..,..,,...,...,...,,.,,,.,,.,,,,,,,
#EWLEC772ERVWLIJPAOYOKRB2HAZGF3FC2TFCCTZHY7JJP2UBRRFUGRH2RWGBBJS7N2UTPJU36GDDA
#\\\|2O2MOXRNDHCKLMT4ZJF6N2CNFPIS7RFWG44CGAOAYZ5XCOTWFDI \ / AMOS7 \ YOURUM ::
#\[7]QOWVK7NYBTQ6OJYCYQMPH36OHKDDGHAVLKTUBVAQ45L5OW3XXIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
