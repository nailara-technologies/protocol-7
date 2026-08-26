---
name: feedback-amos-chksum-listcontext-gotcha
description: AMOS7::CHKSUM::amos_chksum returns a 2-element list under wantarray -- calling it inline in a hash literal silently corrupts the hash
metadata:
  type: feedback
---

`AMOS7::CHKSUM::amos_chksum($data)` returns `($checksum_encoded, $num_amos_csum)`
in list context, `$checksum_encoded` alone in scalar context (see
`data/lib-path/pm/AMOS7/CHKSUM.pm` ~line 318: `return (...) if wantarray;`).

Perl's `return EXPR` propagates the *caller's* context through the sub that
calls it. So a thin wrapper like:

```perl
sub chk3 { my $id = shift; local $AMOS7::CHKSUM::str_length = 3; return AMOS7::CHKSUM::amos_chksum("$id"); }
```

called as `chk => chk3($id)` inside a hash-literal `(...)` is itself in LIST
context (hash literals evaluate their contents in list context) — so `chk3`
silently returns 2 values instead of 1, and the hash literal shifts every
key/value pair after it by one. Symptom: `Odd number of elements in
anonymous hash`, but only where the checksum call happens to fall inside a
literal — a direct `my $x = chk3($id)` (scalar assignment) never shows it,
which makes this easy to miss in ad-hoc testing.

**Why:** `wantarray`-sensitive return isn't visible from the call site or
from reading `chk3` in isolation — it only bites when the *caller's*
context is list, which callers rarely think about for what looks like a
single-value helper.

**How to apply:** any wrapper around `amos_chksum` (or anything else that
branches on `wantarray`) should force `return scalar EXPR` explicitly,
never bare `return EXPR`, unless the wrapper is deliberately meant to be
context-transparent. Caught live in [[project-bin-todo-random-id-scheme]]
while building `bin/todo`'s id generator.

#,,..,...,.,,,,.,,...,.,,,.,,,,,,,..,,..,,,,,,..,,...,...,,.,,..,,,.,,,,,,,.,,
#OOQGYHSKPWU7G7UH7GK7AK4AAQLP5BWT3SPXZQSEGZEAJXJT3LILPTF23U4TLBJLUMDI4OPOBBNR2
#\\\|JCARMGKG5DEJX3PAC2KT2TN5PMPGOPI66VEKXEE6H3UMATJ4BPC \ / AMOS7 \ YOURUM ::
#\[7]DBJQRI2XMWBT4HPHXSUYYBTRUCSRF5FOLRGE7ABSVQZW643JICDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
