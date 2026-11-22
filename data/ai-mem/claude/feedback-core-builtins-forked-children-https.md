---
name: core-builtins-forked-children-https
description: three traps found live 2026-11-22 -- overridden builtins need CORE::, forked children compile stubs per request, and http tests do not cover httpsd
metadata:
  type: feedback
---

1. **CORE:: where the list form is used.** a zenka that loads File::stat, User::pwent or
   Time::localtime gets OBJECTS from stat \ lstat \ getpw* \ localtime ; `(stat $f)[4]`
   is then undef. write `CORE::stat`, `CORE::getpwnam` etc. for list use [ sweep in
   c87a047be7 ].
2. **forked children and on-demand subs.** a sub that is only a deferred stub in the
   parent gets compiled INSIDE each forked child and is lost when the child exits --
   seen as dozens of identical 'loading p7-code' lines. fix by listing the namespaces in
   the zenka's modules.load and regenerating its whitelist [ bin/dev/gen-sub-whitelist
   <zenka> ], never by a manual load in pre_init.
3. **test the TLS path.** httpd and httpsd differ in their module sets ; a live test over
   plain http passed while httpsd returned an empty reply and took a live page down twice.
   run the live tests over https through httpsd before any deploy that touches serving.

**Why:** each cost a live outage or a long hunt this session.
**How to apply:** before signing a change in a serving path, run the https live test ;
when a feature runs in a child, check the parent's module list ; grep new code for
list-form builtins.

#,,,.,.,,,,..,,.,,,.,,..,,..,,,,,,...,,.,,.,.,..,,...,...,...,,.,,,.,,,,.,,.,,
#XXSTXLQHNGMIV3R3XT7G3UXNQFD7WXBV5J7UOPDSNVLDWCHLV7RUJMDN3X7RUJHRH4T6LICLDWMHC
#\\\|D5DLYPK7LSHDHDAZD7AWSK7BOTWIJ3AO6EONFQQBXVYK5Q6H2IA \ / AMOS7 \ YOURUM ::
#\[7]QMNUUSSPNWIINLNHML6T5I27VDLANUHUIOQZGU25UA46DIL33CBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
