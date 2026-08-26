---
name: multiply-in-place-timeout-looks-like-ntime-bug
description: "v7's verbosity-scaled timeouts (verify_instance etc.) use *= not //= reset, so any bug that makes v7.init_code run more than once accumulates them exponentially and LOOKS like an ntime/timestamp bug but isn't"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e81d6781-e404-4cb2-9bd8-c1b6d0c366ef
  modified: 2026-08-21T00:21:47.489Z
---

`v7.init_code` (`src/v7.init_code:56-64`) does
`<v7.timeout.verify_instance> *= $verbosity_factor` — multiplies the
existing value, no reset guard. Under normal operation this runs once
per zenka start and produces sane numbers (e.g. 70.8s at `-vv`, 141.6s
at `-vvv`). But if something makes `v7.init_code` run repeatedly (in
the observed case: [[zenka-naming-cleanup]]'s `zenka.v7`/`start.cfg`
rename left `v7.load_zenka_startup_cfgs` grepping for the wrong
filename, which zero'd out the config load and put v7 into a retry
loop), each pass re-multiplies the already-multiplied value — the
observed symptom was a nonsensical `298893936.643 s` timeout, which
*looked* exactly like an ntime/epoch-scale timestamp bug and cost a
detour chasing that theory before the real cause (the rename bug
causing repeated init) was found and fixed.

**how to apply:** if a `v7.timeout.*` value looks absurdly large,
first ask "did `v7.init_code` run more than once?" (check for a retry
loop / repeated init elsewhere) before suspecting the timestamp/ntime
system itself. Fixing the repeat-cause resets these back to normal
automatically — no separate fix needed for the timeout values
themselves.

**don't confuse with:** `v7.handler.zenka_status:153`
(`$instance->{'restart_delay'} * 1.2`) — v7's per-instance restart
delay IS intentionally designed to grow by a 1.2x factor on each
successive restart attempt (exponential backoff). A growing
`restart_delay` in logs is working as designed, not this bug.

#,,.,,...,,,.,,..,.,.,,,,,,,.,,,.,,,.,..,,.,,,..,,...,...,.,,,,,,,,,,,,.,,,,.,
#IIHK2IRKBXZSIRYQVDQGDCFCCTQS4GZA73OCRY24ROOLQ4ZZDD2RAO3GYGEMDJ56W6CEBYTD5TXV2
#\\\|P6ICU2K5SC76XE2SPIQ7HLIGXAWLIYMOG72SPP7KTDF7ULGDJXL \ / AMOS7 \ YOURUM ::
#\[7]AYUFP7WDR6XFXTIB73AOTT3GD4L4IKHP3Q3N4VZC5MEBCKWSPKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
