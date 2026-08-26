---
name: feedback-perl-and-or-precedence-in-my-assignment
description: "\"my $x = A and B\" only assigns A — and/or bind looser than =, use && / || instead"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 12e05c8a-5436-4bcc-9de0-47cd73099409
---

`my $landed = defined $actual and abs(...) <= $tol and abs(...) <= $tol;`
parses as `(my $landed = defined $actual) and ...` — `and`/`or` bind LOOSER
than `=` in Perl, so only the first term gets assigned and the rest is
evaluated and discarded. `&&`/`||` bind TIGHTER than `=`, so they're the
correct operator whenever a multi-term boolean expression needs to land in
a `my` (or any) assignment.

**Why:** found in `src/ticker.open_window`'s startup void-recovery
timer (2026-06-25, landed `531aa14db`) — the bug made `$landed` always true
on the first geometry read (`defined $actual` is true almost immediately
after map), so the timer believed it had landed and cancelled on attempt 1,
and `find_safe_position` never ran. The retry loop *looked* complete (10
attempts, 0.2s cadence, proper cleanup) but was dead on arrival. This is
exactly the kind of bug that survives code review because the surrounding
logic is sound — only the single operator choice is wrong. See
[[topic-async-window-startup-transition]] for the full incident.

**How to apply:** when reviewing or generating P7 module code, flag any
`my $x = EXPR1 and EXPR2` / `my $x = EXPR1 or EXPR2` pattern — it is almost
never what was intended. Rewrite as `&&`/`||`, or split into a statement
followed by a separate `and`/`or`-modified statement if the low-precedence
short-circuit control-flow idiom (`open(...) or die`) was actually the
intent.

#,,..,,,.,...,.,.,,,,,.,,,,,,,,,.,,,.,,.,,,.,,..,,...,..,,,..,,,,,,..,,..,..,,
#3TJ257JH5DH44M23KKYBAMM6SHTFBSORJSG4C2WTNDHVGIFBYUOS3N22XRG7BZL4P3Q24QNEUZSSI
#\\\|X7NKQWLGGTUGOX5TXFF2WQU7V6UQMUXRHG2YD774S6FJRV5KYK6 \ / AMOS7 \ YOURUM ::
#\[7]RSMVIAFFPGO7AU7RAFZSOG7NXVT5AWALVDILI4HUOJSZANSTAYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
