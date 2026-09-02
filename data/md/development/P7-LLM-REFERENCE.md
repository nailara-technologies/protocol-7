# p7 command reference for LLM sessions

flat reference of common protocol-7 management and debugging commands.
use `p7c` for low-latency direct socket access. `p7` is the retired name
— it is now a stub that only prints a rename notice and exits, so always
call `p7c`.

the management zenka is named `v7-zenki` [ formerly `v7` ]. its stop
command is `terminate` [ formerly `stop` ].

---

## 1. running commands

```
p7c <zenka>.<command> [args]   — call any zenka command (low-latency, no shell overhead)
p7c <zenka>.commands           — list all commands the zenka exposes
p7c <zenka>.heart              — check if zenka is alive (returns 'BEAT')
```

## 2. zenka lifecycle

```
p7c v7-zenki.start <zenka>       — start a zenka
p7c v7-zenki.terminate <zenka>   — stop a running zenka [ marks it 'manually stopped' ]
p7c v7-zenki.restart <zenka>     — stop and restart
p7c v7-zenki.start_once <zenka>  — start only if not already running
p7c v7-zenki.list zenki          — list all zenki and their status
p7c v7-zenki.list                — show which lists are available
```

## 3. session and network status

```
p7c list sessions                — all currently connected sessions with ids
p7c list users                   — authorized user sessions
p7c v7-zenki.list zenki          — connected zenki and their status
```

## 4. live testing

```
p7c <zenka>.<command> 'arg'           — string argument
p7c <zenka>.<command> '{ "k": "v" }' — json argument
p7c <zenka>.reload                    — hot-reload zenka source modules
p7c <zenka>.show-buffer <name>        — show buffer content
                                        (use 'list buffers' to see names;
                                         not all zenki support this)
```

## 5. log access

```
p7c p7-log.show-buffer <name>  — return buffer content
p7c p7-log.list-logs [pattern] — list available log files
p7c p7-log.append <zenka> <id> <buffer> <time> <level> <msg>
                                 — write a log line
```

## 6. source and signatures

```
p7c sourcecode.update-signatures          — resign all modified modules
                                            (requires signing key passphrase —
                                             run by human, not LLM)
p7c sourcecode.verify-p7-signatures       — verify all module signatures
p7c sourcecode.verify-dev-signatures      — verify developer signatures
```

## 7. inter-zenka routing

```
p7c <zenka>.<command>                     — routed via cube to named zenka
p7c <zenka>[<subname>].<command>          — target zenka with specific subname
## example: p7c web-browser.get_uri
## example: p7c X-11.get_display
```

## 8. common debugging sequence

```
## is the zenka running?
p7c v7-zenki.list zenki | grep <name>

## if offline, start it:
p7c v7-zenki.start_once <zenka>

## call a command and see what it returns:
p7c <zenka>.<command> '<args>'

## check recent log output:
p7c <zenka>.show-buffer <name>

## hot-reload after editing modules:
p7c <zenka>.reload

## if something is very wrong, restart:
p7c v7-zenki.restart <zenka>
```

## 9. notes for LLM sessions

```
## p7c works without a running P7 session being active — it connects directly
## to the unix socket. use it freely for testing during tasks.

## 'list sessions' shows numerical session ids — these are also valid targets:
## p7c 1234567.command  (targets session directly, bypasses name routing)

## zenka subnames appear as <zenka>[<subname>] in session lists
## and are targeted as: p7c <zenka>[<subname>].<command>

## when a zenka is 'starting' and looping (v7-zenki restart loop), stop it with:
## p7c v7-zenki.terminate <zenka>  — then fix the config before restarting
## clear the 'manually stopped' mark again with: p7c v7-zenki.clear-manual <zenka>
```

---

#,,,,,,.,,,..,,..,.,,,...,...,.,.,...,.,,,,,,,..,,...,...,.,,,..,,,..,..,,,,,,
#OHZFFT64QUI34ONUWR7MSBJFSPBWTSQQHL4LB6RAKRNOUCRZETWUSFW6YBX4SC24RDH7WVBC37NO2
#\\\|R7HLYLBAVWHCU2QZJTK6JKEAPW7WU5FTRUMMT6LOVHBRALSVTJO \ / AMOS7 \ YOURUM ::
#\[7]6W2ECCCGBGHP2EENQDK4EHS2DYRXXDLPZDGX7XQ77SVV6PCO3MCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
