## usage.kimi first-request "did not report back in time" — FIXED (2026-09-16)

symptom: first usage.kimi query after a kimi token expiry always answered
"provider did not report back in time" (35s guard); the second query worked
immediately. 67 refresh cycles in the log, zero retries, zero "refresh
already in progress" (so refresh_cleanup always ran, single slot always
freed).

root cause [NOT a race, NOT event-loop starvation] : interface mismatch in
plugin.usage.kimi.refresh_token. caller plugin.usage.kimi.handler.response
passes (undef, { on_done => { handler => 'plugin.usage.kimi.refresh_retry',
params => {...} } }) — matching refresh_token's own documented param line —
but refresh_token read $on_done->{'handler'} on the OUTER hash, where only
the 'on_done' key exists. the length() test failed on every call, so
refresh_state->{'on_done'} was always undef, refresh_cleanup silently
skipped the retry dispatch, and the retried /usages fetch was never
scheduled. the detached kimi child DID rewrite the credential file, which is
why query #2 always worked.

fix: refresh_token now unwraps $args->{'on_done'} (accepts both the
documented wrapped shape and a bare {handler,params}). verified live with a
fixture credential dir (garbage token, cfg override
usage.provider.kimi.cred_rel_dir): full chain 401 -> refresh -> cleanup ->
refresh_retry -> add_idle -> retry fetch -> honest 401 report, 'query
complete in 22s', guard never fired.

debug-method notes (reusable):
- anum log timestamps decode: perl -MCrypt::Misc=decode_b32r -e 'unpack
  "w*"' then unix = ntime/4200 + 1023228000 (see base.ntime.B32_2_unix).
- base.event.add_timer 'handler' branch does NOT forward 'params' — the
  callback gets the event object; only base.event.add_idle forwards
  'params'. a timer variant of refresh_retry died with 'not a HASH
  reference [plugin.usage.kimi.fetch:12]' live.
- forcing a real 401 without waiting for expiry: point cred_rel_dir at a
  fixture dir with a kimi-code*.json containing a garbage access_token;
  NOTE the provider hash persists across reloads (init_code only //=s), so
  removing the cfg override needs an explicit correct value pushed once
  before reverting the cfg line.
- base.event.add_timer supports interval/repeat fine; Event->io does NOT
  set O_NONBLOCK (pipe stayed blocking, flags=0x0); a perpetually-readable
  fd (EOF pipe) io watcher DOES starve Event->idle one-shots, but that
  scenario was NOT the bug here.

verified: fixture run complete in 22s with delivery; config restored
pristine.

#,,,.,,.,,..,,.,,,,.,,.,,,,..,...,,..,,.,,,.,,...,...,..,,.,.,.,,,,..,.,,,.,,,
#XJP5AIDUQEAF3KPXR4TPXNY3LZ3VAB6AWEWJBJUCFT33CW3IL62VAAJFIVXLJHJP26CZ7YYILZYLA
#\\\|DHZDU4C36IHAQR4MFG3P7FSK5YQ7RPICER7WXYRBCJXRKZ4P7IX \ / AMOS7 \ YOURUM ::
#\[7]KB25TEV42VJOFZATOQTLQPL2OALSIVV3I62P3NOVW5SBCNPLVMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
