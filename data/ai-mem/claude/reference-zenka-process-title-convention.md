---
name: reference-zenka-process-title-convention
description: zenka processes rename their own argv/process title to <hostname>.<zenka-name> once the zenka name is known, or <hostname>.<stdin> before it is -- relevant for ps/pkill when hunting a stuck process
metadata:
  type: reference
---

a running zenka process renames its own title (`$0`/argv) to
`<hostname>.<zenka-name>` as soon as its zenka name is resolved -- e.g.
`DESKTOP-FP4OP26.keys`, matching the same prefix format seen in that
zenka's own log lines. before the name is known (very early startup,
still reading initial input) it shows as `<hostname>.<stdin>` instead.

**why this matters**: the original invocation string (e.g.
`./bin/Protocol-7 keys create test-remove-guard`, or a `timeout N ...`
wrapper) stops matching `pgrep`/`pkill` once the rename happens -- a PID
captured from the launch command can go stale if the process forks/execs
before you go back to kill it. `pkill -f <zenka-name>` (name-based, not
PID-based) reliably reaches it regardless of the rename; killing a
`timeout` wrapper's PID directly does not guarantee the wrapped process
underneath actually dies.

confirmed 2026-07-30 chasing a runaway `keys create` process stuck in an
infinite passphrase re-prompt loop (piped through non-interactive stdin
with no input available) -- `kill -9` on the captured `timeout` PID left
the actual `DESKTOP-FP4OP26.keys` process spinning at ~99% CPU for
several minutes; `pkill -f keys` cleared it immediately.

#,,..,.,.,.,.,...,,..,.,,,.,.,,..,,..,...,.,.,..,,...,...,.,.,,,,,.,.,,,.,,,,,
#AFUD2IFHP2ZJ3NRD4GDFHEK5AWF6GY6TIB2HYZTJ2YL4EVD3BLPEJ63JMWPHEAU7ITDH46QA6NJQE
#\\\|VCIH7QWQNSFOTTJ7TT5YV2ZSOF5WQNWMNQQJHPCMWKOGWXLXBBF \ / AMOS7 \ YOURUM ::
#\[7]TTGJPAOHJWEU4RBPLX6DNZKKAQA7HMPOVUMPHLNHHRWR3YHS6MCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
