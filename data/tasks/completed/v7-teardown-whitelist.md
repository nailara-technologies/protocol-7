## [:< ##

# name  = task: v7 — restrict teardown command to system zenka only
# descr = access.cmd.usr.cube = * allows any zenka to trigger full system
#         shutdown — restrict teardown to system zenka only
#
# note  = blocked on base-has-access-source-sid-matching.md
#         correct fix: access.cmd.usr.cube.system = teardown syntax
#         current access system cannot deny a specific command behind a wildcard
#         security is correct by omission in cube/access.zenki for now

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

`cfg/zenki/v7/zenka.v7` has:
```
access.cmd.usr.cube = *
```

this wildcard allows any authorized zenka to call ANY v7 command, including
`v7.teardown` which terminates all zenki and v7 itself. the `source_zenka`
alias in cube/command_aliases provides forensic logging (who called it) but
no access gate.

`v7.teardown` has a `reason` parameter and is intended to be called only by
the `system` zenka for controlled shutdown sequences.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## fix: add teardown-specific access restriction

file: `cfg/zenki/v7/zenka.v7`

read the current file first. find the `access.cmd.usr.cube = *` line.

add a specific restriction for teardown before or after the wildcard line:

```
access.cmd.usr.cube          = *
access.cmd.teardown.usr.cube = system
```

check the P7 access control syntax by reading how other zenki restrict
specific commands — look at `cfg/zenki/X-11/zenka.v7` access lines
or `cfg/zenki/cube/access.zenki` for the correct format.

if the correct syntax is `access.cmd.<command>.usr.cube = <zenka>` then use
that. if it is a different format, adapt accordingly — the goal is: only the
`system` zenka can call `v7.teardown`.

## verification

```bash
## check the access line is present
grep -n 'teardown\|access.cmd' cfg/zenki/v7/zenka.v7

## verify format matches other zenka access restrictions
grep -n 'access.cmd' cfg/zenki/X-11/zenka.v7 | head -5
```

## success criteria

- [ ] `v7.teardown` restricted to `system` zenka only
- [ ] wildcard `*` for all other v7 commands unchanged
- [ ] access restriction syntax matches existing P7 patterns
- [ ] no signature stubs added, no whitelist changes

## dispatch

model: kimi
reasoning: low

prompt: |
  Implement the task at data/tasks/v7-teardown-whitelist.md

  Read cfg/zenki/v7/zenka.v7 and the access control modules first.
  Note: the correct P7 syntax is user-centric (access.cmd.usr.<zenka> = <commands>),
  not command-centric. Add a line granting teardown only to system zenka while
  leaving the wildcard * for all other commands unchanged. No signature stubs,
  no whitelist changes.

#,,.,,,,,,.,.,.,.,..,,,.,,,,,,...,,,.,,,.,,,,,..,,...,..,,,.,,.,,,.,.,..,,..,,
#Q734H55PUKKWRAOHYXF2LO2TQHLB7ZI4M6UU3C5EDQ7442DW7UVZVYMFBIJRHHMNGY2UIMRZK7ZTO
#\\\|FES5NDIIYQTPMS2CRFTDKOKK72AFCCTXQ6SAKWD2ESIKOTVZSBG \ / AMOS7 \ YOURUM ::
#\[7]I5N4ZTOWXAVVJ3HCJ55S7ZN4SYDZNXH4M2KAFVF425X6XYLCQMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
