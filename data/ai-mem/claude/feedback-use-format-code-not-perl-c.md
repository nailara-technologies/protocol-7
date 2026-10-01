---
name: feedback-use-format-code-not-perl-c
description: use bin/format-code -c for syntax-checking P7 module files, not plain perl -c
metadata:
  type: feedback
---

`bin/format-code -c <file>...` is the project's own syntax checker, built specifically for this
codebase's module dialect (`<[module.name]>` calls, `<data.path>` tree-variables, `qw||` etc). It
runs `perl -c` internally but **strips the P7-specific false positives** those constructs trigger
in a raw `perl -c` (e.g. `<coding.task.queue>` parses as Perl's own diamond/readline operator,
`//=` after one reads as "modify glob", `state %hash` misparses) before reporting real errors.

**Why:** spent a large chunk of a session (round-chain/rewind-redo feature work) manually running
plain `perl -c` on every edited file, hitting the same handful of false positives repeatedly, and
proving each one harmless only by diffing the edited file against `git show HEAD:<path>` to show
the identical error existed pre-edit at the same offset. `bin/format-code -c` does this
discrimination automatically and reports a clean `syntax valid` / real-error verdict directly —
no manual diffing needed. It also flags real perltidy formatting drift (`would reflow`) separate
from syntax errors, and the same binary without `-c` applies that reflow in place.

**How to apply:** after any edit to a `src/*` module file in this project, run
`bin/format-code -c <file1> <file2> ...` (accepts multiple files, and stdin via `-` per its
pipe-friendly design) as the syntax-check step, instead of bare `perl -c`. If it reports
`would reflow`, running `bin/format-code <file>` (no `-c`) applies the fix in place. Reserve
manual `perl -c` + HEAD-diffing for the rare case format-code itself is unavailable or suspect.

**This was already known, not new** — see [[feedback-ptd-vs-format-code-two-reasons-to-keep]]
from an earlier session (2026-07-26), which covers `format-code` vs its sibling `bin/dev/ptd` in
depth. That memory just didn't get surfaced/re-applied during a later, long session doing heavy
src/* editing (this one) — it reads as "which of these two tools to keep," not "reach for this
instead of perl -c," so it didn't come to mind as the fix for repeated `perl -c` false positives.
This entry exists to make the *when to use it* trigger more discoverable than that one alone was.

**Recurrence, 2026-09-14, SAME session this entry describes**: despite this memory already
existing, reached for `bin/test-scripts/p7-module-syntax-check` all session instead (a DIFFERENT
tool — see [[reference-p7-module-syntax-check-tool]] — with its own, larger set of false positives:
`%colors`/other `our`-in-bin/Protocol-7 globals, `$call` on `.cmd.` files, and now `uniq @array`
bareword-list form misparsed as "Array found where operator expected"). Proved each one harmless
the slow way (HEAD-diffing) every single time, exactly what this memory says to stop doing. User
had to point at `bin/format-code -c` directly, live, before it got used. **Two established,
overlapping syntax-check tools in this codebase, both with their own false-positive classes, is
itself the likely reason neither memory reliably surfaces** — `p7-module-syntax-check`'s own
reference memory doesn't mention `format-code` as the better default, and vice versa. If both
memories keep getting missed, consider: always run `bin/format-code -c` FIRST for any `src/*` edit
in this project, full stop, before considering `p7-module-syntax-check` at all.

**strict since 2026-09-29 [ 8722cf792 ].** format-code -c used to skip
`use strict` and passed two modules the zenka compiler rejected [ `stat(_)`,
a `my $fh` declared inside an `if` condition ]. it now compiles P7 modules
the way the loader does : `use strict`, the loader's imports [ File::stat
overrides stat \ lstat -- list-context `stat()` returns ONE object there,
use `CORE::stat` for `( stat $f )[9]` ], `$call` \ `$reply` in `.cmd.`,
`$zenkaname`, and runtime-loaded modules [ Encode, Socket, Symbol, POSIX
WNOHANG, Gtk3 ] only for files that use them. across all of src/ it then
reported 12 real errors in dormant legacy zenki [ ssl, power, keys,
weather css, download ] and no noise.
`bin/dev/ptd -c` stays the simple, fast precursor : syntax only, its ok line
reads `syntax ok [ no strict ]` -- never treat it as the final check.

**never keyword-filter format-code's output** [ 2026-10-01 ] : I grepped it
for `syntax\|error\|warn\|strict` and saw nothing -- the real compile error
[ `Experimental keys on scalar is now forbidden` ] contains none of those
words, a broken init_code went live and the user had to paste it from the
console. check instead that EVERY per-file verdict line reads `syntax
valid` : strip ANSI, `grep "^::\[\|^    " | grep -v "syntax valid"` must
print nothing. format-code itself caught it fine [ same perl 5.42.3 as
bin/Protocol-7 ].

#,,..,,,.,,,,,.,,,...,,..,,..,,..,.,,,,.,,,,,,..,,...,...,...,,.,,,.,,,,.,.,,,
#S7HVSQ2K5XXTWLGX2QJV2HUVOCTX3QQTIOLDPBOZZJRGINAZZGI2LCZUS6KZOYOQJS2VXRGSMBUQ6
#\\\|M4CC23FXPNZ4UG6GL6AF4XIGZE3BTOMWCLRX7R7GTHQHFALGGNC \ / AMOS7 \ YOURUM ::
#\[7]2FB4N7WO4N4RKWT5EHK7FTBQ3G4USBCTS5GLA2TFV4MVJ4KQSQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
