## [:< ##

# name  = task: write P7-LLM-REFERENCE.md — management and debugging commands
# descr = concise flat reference of P7 commands for LLM sessions working with
#         running zenki — lifecycle, status, testing, logs, source management

## context

LLM sessions (kimi, coding zenka) repeatedly need the same set of P7 management
commands during implementation and testing tasks. these are currently scattered
across CLAUDE.md, task files, and memory entries. a single short reference doc
that can be cat'd into any task file context reduces per-session friction.

this is a **write-only task** — produce the document, no code changes.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat CLAUDE.md                              ## existing scattered mentions to consolidate
cat data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md  ## example of good doc style
## also skim a few recent task files for patterns used in context sections
ls data/tasks/*.md | head -5 | xargs head -20
```

---

## document to produce

file: `data/md/development/P7-LLM-REFERENCE.md`

style: flat, minimal prose, command-first. one-line descriptions. no headers
beyond the main sections. the goal is fast scanning, not reading. use the
project's lowercase comment style throughout.

the document should cover these sections:

### 1. running commands

```
p7c <zenka>.<command> [args]   — call any zenka command (low-latency, no shell overhead)
p7 <command>                   — alias for p7c, same thing
p7c <zenka>.commands           — list all commands the zenka exposes
p7c <zenka>.heart              — check if zenka is alive (returns 'BEAT')
```

### 2. zenka lifecycle

```
p7c v7.start <zenka>           — start a zenka
p7c v7.stop <zenka>            — stop a running zenka
p7c v7.restart <zenka>         — stop and restart
p7c v7.start_once <zenka>      — start only if not already running
p7c v7.list zenki              — list all zenki and their status
```

### 3. session and network status

```
p7 list sessions               — all currently connected sessions with ids
p7 list users                  — authorized user sessions
p7 list zenki                  — connected zenki (cube-level view)
```

### 4. live testing

```
p7c <zenka>.<command> 'arg'           — string argument
p7c <zenka>.<command> '{ "k": "v" }' — json argument
p7c <zenka>.reload                    — hot-reload zenka source modules
p7c <zenka>.show-buffer               — show zenka's recent log output
                                        (not all zenki support this)
```

### 5. log access

```
p7c p7-log.cmd.tail            — stream live log output
p7c p7-log.cmd.list-logs       — list available log files
p7c p7-log.cmd.append '<msg>'  — write a marker into the log
```

### 6. source and signatures

```
p7c sourcecode.recently-modified          — modules changed recently
p7c sourcecode.update-signatures          — resign all modified modules
                                            (requires signing key passphrase —
                                             run by human, not LLM)
p7c sourcecode.verify                     — verify all module signatures
```

### 7. inter-zenka routing

```
p7c <zenka>.<command>                     — routed via cube to named zenka
p7c <zenka>[<subname>].<command>          — target zenka with specific subname
## example: p7c web-browser.cmd.get_uri
## example: p7c X-11.cmd.get_display
```

### 8. common debugging sequence

```
## is the zenka running?
p7c v7.list zenki | grep <name>

## if offline, start it:
p7c v7.start_once <zenka>

## call a command and see what it returns:
p7c <zenka>.<command> '<args>'

## check recent log output:
p7c <zenka>.show-buffer

## hot-reload after editing modules:
p7c <zenka>.reload

## if something is very wrong, restart:
p7c v7.restart <zenka>
```

### 9. notes for LLM sessions

```
## p7c works without a running P7 session being active — it connects directly
## to the unix socket. use it freely for testing during tasks.

## 'list sessions' shows numerical session ids — these are also valid targets:
## p7c 1234567.command  (targets session directly, bypasses name routing)

## zenka subnames appear as <zenka>[<subname>] in session lists
## and are targeted as: p7c <zenka>[<subname>].<command>

## when a zenka is 'starting' and looping (v7 restart loop), stop it with:
## p7c v7.stop <zenka>  — then fix the config before restarting
```

---

## success criteria

- [ ] `data/md/development/P7-LLM-REFERENCE.md` written
- [ ] all 9 sections present with accurate commands
- [ ] commands verified against actual running system where possible
- [ ] style is flat, lowercase, command-first throughout
- [ ] fits comfortably in one terminal screenful per section
- [ ] no code changes, no signature stubs, no whitelist changes

#,,,,,,,,,.,,,...,,,.,,,.,...,.,,,,,.,,,,,.,,,..,,...,...,,,.,.,,,,,,,,.,,,..,
#D6AGOA2UHIMVG77U6O2GVQFPWVDDGW5P2YSBYLGWEOVO7LN2KLLFYUM74AY5ABO5RBNFCMZWDXLQ2
#\\\|HEFMY7Q5LF4INIEN4H3B6ISXO6COLKUJRPSYGRY46MJGZHX26AC \ / AMOS7 \ YOURUM ::
#\[7]DMFF3NAVPDZQUHV42PVJ7NGEEK3YWBC7WK4HCHFKKJGBNRXTGMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
