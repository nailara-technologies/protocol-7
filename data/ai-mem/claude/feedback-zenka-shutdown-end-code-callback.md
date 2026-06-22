---
name: zenka-shutdown-end-code-callback
description: "never assign $SIG{'INT'}/$SIG{'TERM'} directly in a zenka module — use the <callbacks.end_code> registry instead"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f389ff82-5ffe-4566-bc0c-7ec2e472fbe6
---

A zenka module must never do `$SIG{'INT'} = sub {...}` / `$SIG{'TERM'} = ...`
directly. Perl only keeps the last assignment per signal, so this silently
clobbers the framework's own `modules/base.sig_int` / `modules/base.sig_term`
handlers — which do v7 teardown, cross-zenka shutdown notification
(`base.net.send_to_all_initialized`), and `<system.kill_list>` child killing.
A module-local direct signal assignment breaks all of that for the whole
zenka, not just adding its own cleanup.

**The correct mechanism**: `bin/Protocol-7` has an `END { ... $code{'base.
handler.end_code'}->(); }` block that fires on every exit path (including
`base.sig_int`/`base.sig_term`'s own `exit()` calls) and runs every callback
registered in `<callbacks.end_code>` (`$data{'callbacks'}{'end_code'}`), in
reverse-registration order, by module name (not coderef — "direct code refs
currently not supported", `bin/Protocol-7` ~line 3768). Register with:

```perl
push <callbacks.end_code>->@*, qw| your.module.name |;
```

Precedent: `modules/v7.setup_stdout_redir` → `push <callbacks.end_code>->@*,
qw| v7.stdout_log.close |`. The callback module itself is plain cleanup logic,
no `exit()` call inside it — the process is already exiting via whatever path
triggered the END block; the callback just does its cleanup and `return TRUE`.

**Why this surfaced**: found while reviewing kimi's AMOS7::SHM phase-4
cleanup-on-exit work — the *original* phase-1 code already had this bug for
SIGINT alone (`modules/data.mount.shm.init_code`); kimi's phase-4 task asked
it to add SIGTERM cleanup too, and it extended the same direct-`$SIG`-assignment
pattern, which would have also clobbered `base.sig_term`. Fixed by replacing
the direct assignment with the `<callbacks.end_code>` push (see
[[topic-amos7-shm-phase1]]).

**How to apply**: any time a module needs cleanup-on-shutdown logic, reach for
`<callbacks.end_code>` first. Only standalone (non-zenka) Perl scripts/packages
— which have no Protocol-7 callback framework at all — legitimately need a
real `$SIG{...}`/`END` block of their own; `AMOS7::SHM.pm`'s standalone-mode
`END` block is the correct counterexample, gated on `not defined
$main::PROTOCOL_SEVEN`.

#,,,,,,.,,,,.,.,,,,..,,,.,,,,,,.,,,,.,.,.,.,.,..,,...,...,...,...,,,,,.,.,,..,
#HMRRCVQL2PQWKL32R3BPOC2ILMZI4AAQZSQZCOJEJT7BLR25MGOV76KVXRWHS6RZZE6E2NGUIRBNG
#\\\|R4EEV76Z7BN35WY6NI6QX3GBEMJ5HY4DD3HQ3GASFQK7OJZ2WBD \ / AMOS7 \ YOURUM ::
#\[7]7GXQ76K5D2ORFRSSEJSBV2ETDMOMVNLSZM3ZG37BBH2VDLCH2OBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
