## [:< ##

# name  = task: v7 — restrict teardown command to system zenka only
# descr = access.cmd.usr.cube = * allows any zenka to trigger full system
#         shutdown — restrict teardown to system zenka only

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

`configuration/zenki/v7/start` has:
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

file: `configuration/zenki/v7/start`

read the current file first. find the `access.cmd.usr.cube = *` line.

add a specific restriction for teardown before or after the wildcard line:

```
access.cmd.usr.cube          = *
access.cmd.teardown.usr.cube = system
```

check the P7 access control syntax by reading how other zenki restrict
specific commands — look at `configuration/zenki/X-11/start` access lines
or `configuration/zenki/cube/access.zenki` for the correct format.

if the correct syntax is `access.cmd.<command>.usr.cube = <zenka>` then use
that. if it is a different format, adapt accordingly — the goal is: only the
`system` zenka can call `v7.teardown`.

## verification

```bash
## check the access line is present
grep -n 'teardown\|access.cmd' configuration/zenki/v7/start

## verify format matches other zenka access restrictions
grep -n 'access.cmd' configuration/zenki/X-11/start | head -5
```

## success criteria

- [ ] `v7.teardown` restricted to `system` zenka only
- [ ] wildcard `*` for all other v7 commands unchanged
- [ ] access restriction syntax matches existing P7 patterns
- [ ] no signature stubs added, no whitelist changes

#,,,.,..,,..,,,,,,,..,,,.,,,.,,..,,..,,,,,...,..,,...,...,.,.,.,.,,.,,.,.,,,.,
#CDYTUR5FF5NXZ33O3B6P7G4YC4AY5XQDHAXYWQGVFT7J632L4J7HJUSQWCPRZKZZ7TP52MKDS62LS
#\\\|5JLPGUBLFJUV3MLCE7ES2RSRQXZPUN6XMXA7RL7UMHJO55XAOLN \ / AMOS7 \ YOURUM ::
#\[7]CZWMADOYW2GZQ2OYHQDUQA63LM2WRHWJOACZFVCTZYMW3BBRPWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
