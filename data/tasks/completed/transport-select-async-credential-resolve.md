# transport.select async credential resolution

## Background

`modules/transport.handle.quic-hysteria` and `modules/transport.handle.udt-tunnel`
both call `<[cred-mesh.resolve]>->({ slot => ..., context => $ctx })` as if it
were a local subroutine call. `cred-mesh` is a separate zenka — `transport`'s
`%code` does not contain `cred-mesh.resolve`, and even if the module were
co-loaded, `<cred-mesh.registry>` (the actual credential store) is per-zenka
isolated data, so the call would still be against the wrong (empty) registry.
This is the cross-zenka call pattern violation described in
[[feedback-cross-zenka-deferred-reply]] — cross-zenka calls must go through
`protocol-7.route-send` + a deferred reply handler.

Confirmed live: `p7c transport.eval-code 'return exists $code{"cred-mesh.resolve"}
? "yes" : "no"'` returns `no`.

Symptom: cred-mesh integration harness scenario 2
(`bin/dev/cred-mesh-test --scenario 2`) — `transport.select` returns `undef`
for a `quic-hysteria` profile because `transport.handle.quic-hysteria`'s
credential resolution silently fails (undef sub call), the entry gets
demoted, and the loop falls through to the `direct-tcp` fallback, which then
fails to connect to the test's fake hostname (a separate, expected failure —
not part of this task).

Reference pattern already in the codebase for this exact kind of cross-zenka
resolve:
- `modules/proxy.auth.lookup` — issues
  `protocol-7.route-send` with `command => 'cred-mesh.resolve'`,
  `call_args => { args => $slot }` (positional/string form — see
  `modules/cred-mesh.resolve`'s `$as_size_reply = TRUE` branch, which returns
  `{ mode => 'size', data => YAML::XS::Dump($result) }`), and a
  `reply => { handler => ..., params => {...} }`.
- `modules/proxy.handler.auth_lookup_reply` — the corresponding reply
  handler: checks `$reply->{'cmd'} eq 'size'`, `YAML::XS::Load`s
  `$reply->{'data'}`, checks `mode eq 'true'`, then continues the chain by
  calling `proxy.handler.post_auth`.

## Scope

This task converts `transport.select` (and the transport-handle modules that
need credential resolution) from synchronous return-value style to
async/deferred-reply style, matching the route-send + reply-handler
convention used elsewhere.

### 1. `transport.handle.quic-hysteria` and `transport.handle.udt-tunnel`

Both currently:
```perl
my ( $entry, $ctx ) = @ARG;
...
if ( exists $entry->{'credential'} and defined $entry->{'credential'} ) {
    $cred = <[cred-mesh.resolve]>->({ slot => $entry->{'credential'}, context => $ctx });
    ... return undef if resolution failed ...
}
... build and return $handle synchronously ...
```

These need to become callback-style: `(entry, ctx, continue)` where
`continue->($handle_or_undef)` is invoked once (either synchronously, if no
credential is needed, or after the `cred-mesh.resolve` reply arrives). Use
`protocol-7.route-send` with `command => 'cred-mesh.resolve'`,
`call_args => { args => $entry->{'credential'} }`, and a new reply handler
(e.g. `transport.handler.credential_resolved`) that:
- `YAML::XS::Load`s the SIZE reply,
- checks `mode eq 'true'`,
- on success, builds the same `$handle` hashref as today (including
  `'credential' => $resolved_result`) and calls the stashed continuation,
- on failure, calls the continuation with `undef`.

You'll need a way to stash the continuation + entry/ctx across the async
gap — follow the existing convention of passing identifying info through
`reply => { params => {...} }` and looking up any larger state from a
registry hash (see how `proxy.handler.auth_lookup_reply` looks up
`$data{'proxy'}{'clients'}{$client_id}` via `client_id` in `params`). For
transport, you may need a small `<transport.registry>{'pending_resolve'}{$id}`
table keyed by a generated request id, storing `{ entry, ctx, continue }`.

`transport.handle.direct-tcp` and `transport.handle.socks5` need NO change to
their internal logic (no credential resolution), but must be called through
the same callback-style interface from `transport.select` — i.e. wrap their
synchronous `return $handle` in an immediate `$continue->($handle)` call from
`transport.select`'s dispatch loop.

### 2. `transport.select`

Currently iterates `@$transports` synchronously, trying each handler in turn
and returning the first defined `$handle`, falling back to
`transport.handle.<fallback>` if all fail.

Convert to: `transport.select($ctx, $reply)` where `$reply` is the
route-send-style `{ handler => ..., params => {...} }` convention (or, since
this is intra-zenka, can just be a coderef + params if that's simpler and
still consistent — use your judgement, but document the choice). The
function must:
- try each transport entry in `@$transports` in order, via the new
  callback-style handler interface,
- on success (`$handle` defined), record `<transport.registry>{'active'}`
  etc. as today, then invoke the reply with the handle,
- on exhaustion, try the fallback handler the same way, set
  `$ctx->{'transport'}{'degraded'} = TRUE` on success,
- on total failure, invoke the reply with `undef`.

All the demote/quality-check/active-recording logic in the current
`transport.select` should be preserved — only the control flow (sequential
sync loop -> sequential async chain) changes.

### 3. `proxy.transport.select` / `proxy.handler.post_auth`

`proxy.transport.select` currently does
`return <[transport.select]>->($ctx)` synchronously, and
`proxy.handler.post_auth` uses the return value immediately, then calls
`proxy.handler.request`.

Update `proxy.handler.post_auth` to call the new async `transport.select`
with a reply/continuation that sets `$context->{'transport'}{'handle'} =
$transport_result` (if defined) and THEN calls
`<[proxy.handler.request]>->($client_id)` — i.e. move the
`proxy.handler.request` call into the continuation. `proxy.transport.select`
should be updated to pass through the new calling convention (or removed if
it no longer adds value — your judgement, but if removed, update
`configuration/zenki/proxy/subroutine.white-list` and
`configuration/zenki/cred-mesh/subroutine.white-list` accordingly since both
currently list it).

Note: in the current live config, `proxy`'s `modules.load` does NOT include
`transport`, so `exists $code{'transport.select'}` is false in proxy today —
this path is effectively dead in production right now. Keep the
`exists $code{...}` guard so this remains a no-op until/unless `transport` is
co-loaded into `proxy`. Do not add `transport` to proxy's `modules.load` as
part of this task.

### 4. Test harness updates

`bin/dev/cred-mesh-test.d/scenario-2-hysteria-bearer.pl` and
`bin/dev/cred-mesh-test.d/scenario-3-transport-degradation.pl` currently call
`transport.select` synchronously via `transport.eval-code` and expect an
immediate `YAML::XS::Dump($h)` return:

```perl
my $select_code = '... my $h = $code{"transport.select"}->($ctx); return defined $h ? YAML::XS::Dump($h) : "undef";';
my $handle_yaml = p7c_eval( 'transport', $select_code );
```

Since `transport.select` is now async, this needs to change. Simplest
approach: have the `eval-code` snippet itself call `transport.select` with a
reply coderef that stashes the result into a package-level/registry variable
(e.g. `<transport.registry>{'test_last_result'}`), then have the harness poll
for it with a short timeout loop (re-issuing `transport.eval-code 'return
<transport.registry>{"test_last_result"} // "pending"'` every ~0.1s up to a
~5s deadline). Add a small helper to `CredMeshTest.pm` (e.g.
`call_async_transport_select`) if useful — `@EXPORT_OK` already lists several
similar helpers (`wait_for_log`, `proxy_port_ready`) as a pattern reference.

## Acceptance criteria

- `ptd -c` clean on all modified modules
- `p7c transport.eval-code 'return exists $code{"cred-mesh.resolve"} ? "yes" : "no"'`
  is allowed to still say `no` (that's fine/expected — the point is
  `transport.handle.quic-hysteria`/`udt-tunnel` no longer call it directly)
- `bin/dev/cred-mesh-test --scenario 2 --verbose`:
  - `transport handle returned` and `handle type is quic-hysteria` assertions
    PASS (the mock socks5 server in the scenario should let
    `transport.handle.quic-hysteria`'s `test_sock` connect succeed)
  - `handle carries authorization header` assertion PASSes
    (`Bearer test-bearer-token-67890`)
  - `no credential leak in logs` still PASSes
- `bin/dev/cred-mesh-test --scenario 3 --verbose`: re-run and report current
  pass/fail state (scenario 3 was 0/2 before this fix per
  [[topic-credential-fabric-proxy-transport]] — investigate whether the same
  root cause applies and fix if so, otherwise document what's still failing
  and why, without scope-creeping into unrelated fixes)
- `bin/dev/cred-mesh-test --scenario 1 --verbose` still passes at its current
  rate (4/5 — do not regress)
- No change to `proxy`'s `modules.load` (transport stays not-co-loaded in
  production)

## Out of scope

- The pre-existing "no relay pending" scenario-1 assertion failure (stale
  `relay_pending.yaml`, unrelated)
- Adding `transport` to `proxy`'s `modules.load` / making the proxy live
  transport-select path actually active in production — that's a separate,
  bigger decision (would also need the `cred-mesh` route-send pattern from
  this task to actually work end-to-end through proxy, plus testing)
- `transport.handle.socks5`'s own internal protocol logic (no credential
  resolution there, no changes needed beyond the calling convention)

#,,..,,.,,,.,,,,,,..,,,..,,,.,.,.,...,.,,,,.,,..,,...,...,...,.,,,,..,.,,,,.,,
#DFMOCT3MZLYHIBMH3NHQJMMU72NMCNK3G36HPSW3XOXMXRMPRFZRSMTTW7N4XYIVSKFVQWB2CS6JK
#\\\|QT6PG7X57QE6XWZBLXGO5ECOQLRO2QQT2SCP6NUIN3E7Q2ACQR6 \ / AMOS7 \ YOURUM ::
#\[7]7Q4RSBXYFZNOIOPS4BYTU2LKSBINYKSIMURQ3FAEPCO5WL7SOCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
