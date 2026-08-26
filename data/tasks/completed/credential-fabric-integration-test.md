# task: credential fabric — end-to-end integration test harness

## dispatch
build a reproducible end-to-end test harness for the
cred-mesh + transport + proxy zenki working together. read first:
`data/md/design/CRED-MESH-INTEGRATION-AND-UI.md` (part 1, "test
scenarios" section);
`data/tasks/cred-mesh-wiring.md` (the wiring this verifies);
`src/proxy.handler.request`, `src/proxy.handler.passthrough_reply`;
`src/transport.select`, `src/transport.demote`,
`src/transport.promote`, `src/transport.probe.timer`;
`src/cred-mesh.resolve`, `src/cred-mesh.rotate`,
`src/cred-mesh.handler.rotation_strm`,
`src/cred-mesh.request-authorization`;
existing test scripts under `bin/dev/` for shape conventions
(`bin/dev/comp-test`, `bin/dev/bit-count` etc.).
do NOT modify zenka modules themselves — this task only adds the harness.
this task assumes the wiring task has landed.

## goal
five test scenarios from the design doc, each runnable from a single
script that:
- prepares a fresh `var/cred-mesh/` and `var/transport/`
- seeds the registry with deterministic slots
- spawns a local upstream listener (echo server on a high port)
- runs the scenario against the proxy at `127.0.0.1:8118`
- verifies the expected behaviour
- prints pass/fail with one-line summary per scenario

a single harness binary `bin/dev/cred-mesh-test` orchestrates
all five and supports running them individually
(`bin/dev/cred-mesh-test --scenario 3`) or all in sequence.

## structure

```
bin/dev/cred-mesh-test          [ orchestrator + helpers ]
bin/dev/cred-mesh-test.d/
    scenario-1-direct-tcp-api-key.pl
    scenario-2-hysteria-bearer.pl
    scenario-3-transport-degradation.pl
    scenario-4-rotation-invalidation.pl
    scenario-5-auth-relay-console.pl
    helper-upstream-echo.pl
    helper-seed-fabric.pl
    helper-spawn-proxy.pl
    helper-curl-via-proxy.pl
```

## helpers

**upstream echo listener** — listens on a free port; for each connection
it reads the request and writes a yaml body containing the request
headers + path. lets the scenario assert that injected credential
headers actually made it upstream.

**seed-fabric** — writes a deterministic `var/cred-mesh/seed.yaml`
with all slots the scenarios need, plus writes plaintext values into the
tier-1 store directly (using the same encryption path the fabric uses,
or by calling `p7c cred-mesh.register` + `cred-mesh.put`
once the fabric is up). prefer the latter — it is the real path.

**spawn-proxy** — starts a clean v7 with cred-mesh, transport,
and proxy zenki. waits for `proxy.handler.accept` to be ready (poll
`127.0.0.1:8118` until connect succeeds, max 10s). tears down on exit.

**curl-via-proxy** — a small lwp client that sends a request through
the proxy and returns the response body, status, and any error. used
by every scenario.

## scenarios

### 1. direct-tcp + low-sensitivity api-key
seeds slot `openweathermap.api-key` (low sens, api-key type, owner =
weather but resolves locally for test). transport profile = default
(direct-tcp). issues GET `http://127.0.0.1:$echo_port/test` through
the proxy. asserts:
- response body shows header `X-API-Key: <seeded value>` in echoed
  request headers
- proxy log shows the chosen transport was `direct-tcp`
- no entry appears in the relay-pending file

### 2. hysteria-socks5 + bearer-token
seeds slot `api.atom-host.bearer` (medium sens, bearer-token, transport
owner). adds `data/yaml/transport/profiles/atom-test.yaml` matching the
test echo host with a hysteria-socks5 entry pointing at a mock socks5
server (use `IO::Socket::Socks` server-side or skip the full hysteria
binary). asserts:
- handle returned by `transport.select` has `type='hysteria-socks5'`
- echoed request shows `Authorization: Bearer ...`
- credential value never appears in proxy logs (no leak)

### 3. transport degradation
patches `transport.handle.direct-tcp` runtime behaviour via the test
hook described in the design (or sets a quality threshold low enough
to fail). triggers a transport.demote, waits for one probe cycle,
clears the hook, verifies `transport.promote` runs. asserts:
- demote fires within 1 probe cycle of injected failure
- `<external.transports>->{'demoted'}` (or wherever transport state
  lives — confirm during wiring task) contains the entry
- promote fires within 1 probe cycle of cleared hook
- all proxy requests during degradation succeeded (graceful)

### 4. rotation invalidation
seeds a slot, issues one proxied request to populate the proxy cache,
calls `p7c cred-mesh.rotate <slot>` with a new value, issues
a second request, asserts:
- before-rotate echo shows old value
- after-rotate echo shows new value
- proxy cache log shows a flush entry for the slot
- transport profile cache (if it had the slot) also logged a flush

### 5. console auth-relay fallback
deliberately do NOT seed a slot for the test domain. issue a GET to
that domain. asserts:
- proxy returns 407 (or whatever the wiring task chose) with a body
  containing the req_id
- `var/cred-mesh/relay_pending.yaml` contains one entry
- `p7c cred-mesh.approve <req_id> <payload>` returns ok
- relay_pending.yaml entry is removed
- retried original request (curl-via-proxy with same url) succeeds
  with injected header

## reusable assertion helpers

`harness_assert($name, $cond, $msg)` — single assertion primitive,
records into the run's result hash, prints `[ OK ]` or `[ FAIL ]`
per assertion.

`wait_for_log($pattern, $timeout)` — tails the v7 log file (the test
fixture knows its path) and returns true if the pattern appears within
the timeout. used by scenarios 3 and 4.

`extract_handle_type($id)` — reads a handle-type marker from a debug
log line. requires the wiring task to emit a single log line at proxy
request start: `proxy: outbound type=<type> dst=<host:port>`.

## run modes

`bin/dev/cred-mesh-test` (no args) — runs all scenarios in
sequence, prints a summary, exits non-zero on any failure.

`--scenario N` — runs one scenario, leaves the fixture alive for
inspection if it failed (`--no-cleanup` to force-keep).

`--keep-running` — runs setup and seeding, leaves the proxy running,
prints `127.0.0.1:8118` and the seeded slots. for manual exploration.

`--verbose` — passes through to v7 log level + dumps echo server
request transcripts.

## test fixture isolation

each run uses a fresh `/tmp/credfab-test-<ntime>/` as the v7 var
directory (override via `PROTOCOL_7_VAR=`). do not pollute the real
`var/`. teardown removes the temp dir on success; preserves it on
failure with a `[ fixture kept: /tmp/credfab-test-... ]` message.

## acceptance
- `bin/dev/cred-mesh-test` runs all five scenarios from a clean
  checkout (after wiring task) and exits 0.
- individual `--scenario N` works for each.
- failed scenarios leave a usable fixture and clear failure message
  pointing at the assertion that failed.
- no scenario leaks state into the real `var/cred-mesh/` or
  `var/transport/` directories.
- harness adds no perl modules to `data/lib-path/pm/` — uses only
  what existing scripts already pull (LWP, IO::Socket::IP, YAML::XS).

## signatures note
do not add the `#,,..` stub to any new file. the signing system writes
it. lowercase comments, `[ word ]` annotations.

#,,.,,,,.,,..,.,,,...,,.,,,.,,,,.,,,,,,.,,.,,,..,,...,...,..,,...,.,.,,,.,,.,,
#4IOTA5QA7IQKBOWA6AB3WNESMGN2WAIRPD65ISTW6IXVSLCF2WZEXBJRG7WTGJY73THQXOMZNUZL2
#\\\|PALMFVGWDTEV4B53CEZ5ZDBFEDEYTCEOB3435BR7BOFSW26JFYJ \ / AMOS7 \ YOURUM ::
#\[7]7BRRXY3IMUSLV43FMMC7H3CEGF5ASPNXLH43TCKQM5RWMWMH6EBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
