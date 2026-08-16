---
name: reference-bracket-call-trailing-comment-misparse
description: "codebase-wide gotcha: a <[module.name]> bracket followed by a trailing same-line comment, with its ->(...) args on the NEXT line, silently misparses as a zero-arg call whose return value then gets invoked as the real subroutine -- found live 2026-08-16 in a pre-existing crash in crypt.C25519.del_keys_hash_entry, first exercised by the key-delete task"
metadata:
  type: reference
---

`<[module.name]>` with no args is meant to auto-expand to `$code{'module.
name'}->()` (CLAUDE.md's own documented rule: "`->()` implicit when no
args"). Splitting a call across multiple lines is normal, established style
in this codebase — the args land on a later line, e.g.:

```perl
<[editor.control.prompt.open]>->(
    $editor_state,
    { ... }
);
```

This works fine because the translator's "does `->(` follow" lookahead sees
`->(` as the very next non-whitespace token after the closing `]>`.

**The trap**: a trailing `## comment ##` on the SAME line as the closing
`]>`, with the real `->( args )` pushed to the line below it:

```perl
<[base.erase_buffer_content]>    ##  erasing key chksum from memory  ##
    ->( \$key_name_table->{$name}->{'checksum'} );
```

The lookahead does not skip past the comment, sees no `->(` immediately
following, and auto-inserts the zero-arg form — producing, in effect:

```perl
$code{'base.erase_buffer_content'}->()->( \$key_name_table->{...} );
```

The bracketed sub then runs with NO argument, hits whatever guard it has for
a missing/wrong-shaped first arg, and returns whatever that guard returns.
If that return value is truthy-but-not-a-coderef (a bare `1` from `return
warn(...)`, `TRUE`/5, etc.), the outer `->( real args )` then tries to
invoke THAT value as a subroutine — under `use strict 'refs'` this dies with
`Can't use string ("1") as a subroutine ref`, which is the exact signature
this bug produces. If the guard instead just `return`s undef, the failure
mode is "Can't use an undefined value as a subroutine reference" instead —
same root cause, different wording.

**Found live**: `crypt.C25519.del_keys_hash_entry` had exactly this shape on
its `<[base.erase_buffer_content]>` call inside the "not in `%keys` but in
the loaded-keys table" branch — a branch nothing had exercised live before
[[topic-rename-empty-target-stuck-state-investigation-2026-08-16]]'s sibling
delete-key task called `crypt.C25519.unload_key` for the first time in a
real scenario that reached it. The SAME file's other `<[base.
erase_buffer_content]>` call two lines earlier used the safe one-line shape
(`->(...)` immediately after the bracket, comment elsewhere) and never had
the bug — direct proof this is purely about call-site shape, not the callee.
Fixed by moving the comment above the statement and keeping `->(...)` on the
same line as the bracket.

**How to apply**: when writing OR reviewing a `<[module.name]>` call, if a
comment sits between the closing `]>` and the `->(` that supplies its args
— on the same line as the bracket, or immediately after it before the args
line — move the comment elsewhere first. A comment ABOVE the whole statement
is always safe; a comment trailing the bracket itself is not, whenever the
args live on a following line. Grep pattern to spot existing instances:
`<\[[a-zA-Z0-9._-]+\]>\s*##.*##\s*$` followed by a line starting with
`->(`. Worth a sweep of `modules/` at some point — this was found by
accident during live testing, not a deliberate search, so more instances
likely exist unnoticed.

#,,.,,.,,,..,,,.,,,..,.,.,,.,,.,,,,..,...,.,,,..,,...,...,.,,,,..,.,,,..,,,.,,
#XSEFBGS2CITS6XGKYQC5NTHD4DYA6LDORT5GHJEEJWEOT6KAKMPHBD5UHTTPKAQ677X42KABDUTSW
#\\\|QYD2WKQDOLT5J3U55QEBNORSP2O35EIGIGNC2OTSSN4JUE2F7P2 \ / AMOS7 \ YOURUM ::
#\[7]AOVHTSTII7S2D4WCJ57IGS4CJ7EDQMVGGIS25QR6V5PDR2MFL4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
