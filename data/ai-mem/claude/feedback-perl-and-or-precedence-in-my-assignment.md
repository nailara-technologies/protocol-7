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

**same trap with `not` in a ternary [ 2026-09-29 ]** : `A ? x : not $d ? y : z`
parses as `not( $d ? y : z )` -- `not` binds looser than `?:`, the branch is
always '' [ both y and z true ]. in `invoke-web.parse_output_line` every
successful render got result '' : logged at level 0 as `render  [ item N ]`
and the silent-failure image check never ran. use `!$d`, or invert the branches [ `$d ? z : y` ].

#,,..,.,,,...,,.,,,.,,..,,,,,,..,,,,,,...,,.,,..,,...,...,.,,,.,.,...,...,.,.,
#2GB6RBJC7VP55TK3NQ6IHUC7SUCEZBT42AMS4G4Y4WRSOSHFUNSIV6HU7W2CAEEAPY22IX2BTRAUI
#\\\|PMUBTMQM2A7463EV7V6HFTTWGZLYDJUKJM7TJJS4ZKLAKEJ2ZI6 \ / AMOS7 \ YOURUM ::
#\[7]RCIAJDVJ4SLJ5SYDAB4XTRLLX72I2S6S3GFT5DKJT65IXROS2EBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
