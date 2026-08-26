## [:< ##

# zenka lifecycle — on-demand, heartbeat, and timeout behaviour
# hybrid modes, route-triggered spawn chains, wake permissions, recovery

---

## status [ 2026-08-24 ]

**"hybrid mode — on-demand with heartbeat monitoring" and "unregister
command" (implementation order items 1-2) are LANDED** — see
`data/tasks/completed/v7-ondemand-heartbeat-idle-term.md` and commit
`0f1ba4446`. the shipped design is simpler than proposed below: no opt-in
`heartbeat.on-demand.hybrid` flag, no `pre_stop_window` — exclusion of
`heart` from resetting the idle timer is unconditional/automatic for
every on-demand zenka, and `v7.idle-term` (not `zenka.unregister-heartbeat`)
is the zenka-initiated pre-exit notice, wrapping `v7.zenka.instance.stop`
directly rather than a separate suspend-then-fire sequence. verified live
on a throwaway on-demand+heartbeat test zenka.

"configurable timeout behaviour", "wake permissions", "network priority
levels", and "WoL integration" below are all still open, unimplemented.

---

## route-triggered spawn chain (already partially working)

on-demand startup already chains naturally through the routing system:

- each route hop waits until the target zenka is fully initialized
  before the command is forwarded and the history stripped
- if the next hop has on-demand startup configured, it is started
  and waited for before routing continues
- this chains to arbitrary depth — a route into a sleeping home network
  works even when intermediate systems are down:

```
p7c home.media.play                    ## home is sleeping
  → cube routes to home-gateway
  → home-gateway: next hop is 'home' — sends WoL packet, waits for boot
  → home comes up, cube connects, routes to media
  → media zenka starts on-demand
  → command arrives
```

no special handling needed beyond on-demand + WoL integration at each hop.
the waiting-until-initialized guarantee already provides the sequencing.

---

## who can wake what — permission-based on-demand startup

on-demand startup is currently binary: enabled or not.
next step: configure which zenki/users are permitted to trigger a wake:

```
## cfg/zenki/media/start.cfg
start.on-demand              = 1
start.on-demand.permitted    = httpd system taeki
start.on-demand.deny         = *         ## default deny all others
```

unpermitted sources attempting to route to a sleeping zenka receive:
`{ mode: false, data: 'zenka unavailable — insufficient wake permission' }`
rather than triggering startup.

**network priority levels** (generic):
```
start.on-demand.priority     = normal    ## normal / high / critical
```
- critical: always starts, preempts resource limits
- high: starts unless system is in maintenance mode
- normal: default on-demand behaviour
- low: starts only when system load is below threshold

priority can also apply to routing — high priority commands bypass
on-demand queuing and get dedicated startup resources.

---

## hybrid mode — on-demand with heartbeat monitoring

problem: a zenka configured with on-demand startup + idle timeout cannot
also have heartbeat monitoring, because heartbeat traffic resets the idle
timer and prevents timeout.

but without heartbeat: a blocking/crashed on-demand zenka goes undetected
until the next command attempt — which may never come.

solution: hybrid mode coordinates heartbeat and on-demand timeout:

```
## cfg/zenki/media/start.cfg
start.on-demand              = 1
start.on-demand.timeout      = 4200       ## 70 minutes idle timeout
heartbeat.disabled           = 0          ## heartbeating enabled
heartbeat.on-demand.hybrid   = 1          ## enable hybrid coordination
```

**hybrid coordination sequence**:

```
1. zenka starts on-demand → v7 registers heartbeat timer
2. zenka is active → heartbeat runs normally (detects blocking)
3. idle timer approaches timeout:
     at (timeout - heartbeat.pre_stop_window): v7 stops heartbeat
     pre_stop_window default: 2× heartbeat interval
4. idle timer fires → zenka shuts down cleanly
5. heartbeat not re-registered until next on-demand startup
6. on next on-demand startup: heartbeat re-enabled after initialized
```

**v7 correlation**:
v7 needs to correlate on-demand timeout with heartbeat suspension.
check if v7 already tracks the relationship between a zenka's on-demand
config and its heartbeat timer — likely it does via the zenka registry.
the key is adding `heartbeat.suspend_at_idle_pct` or a pre-stop window.

**unregister command**:
zenka exposes `zenka.unregister-heartbeat` (or v7 calls it directly).
v7 calls this before the idle timeout fires, giving the zenka a chance
to acknowledge the upcoming shutdown. v7 then suppresses heartbeat failure
alerts for that zenka for the shutdown window.

result: blocking zenki are always detected while running, but on-demand
timeout still works cleanly. no false-positive "zenka blocked" alerts
during clean shutdown.

---

## configurable timeout behaviour — beyond brutal restart

currently: zenka fails heartbeat → v7 restarts it immediately.

this loses all diagnostic information and may restart a zenka that could
recover on its own. configurable recovery modes:

```
## cfg/zenki/media/start.cfg
timeout.mode                 = forensic-first   ## see modes below
timeout.forensic.duration    = 30               ## seconds of data capture
timeout.recovery.attempts    = 2                ## soft recovery attempts first
timeout.recovery.delay       = 5                ## seconds between attempts
```

**timeout modes**:

```
restart          ## current behaviour — immediate brutal restart

forensic-first   ## capture state before restart:
                 ##   - dump zenka %data tree snapshot
                 ##   - capture last N log lines
                 ##   - send to forensics zenka for analysis
                 ##   - then restart

recovery-first   ## attempt soft recovery before restart:
                 ##   - send zenka.recover command (zenka-defined handler)
                 ##   - wait recovery.delay, re-check heartbeat
                 ##   - if still blocked: escalate to restart
                 ##   - configurable retry count

observe          ## data capture window only, no restart:
                 ##   - N seconds of continued monitoring
                 ##   - capture everything, send to forensics zenka
                 ##   - restart after window expires
                 ##   - use for rare/complex failure modes

notify-only      ## alert without restart:
                 ##   - send notification (system.report, log, etc.)
                 ##   - human decides next action
                 ##   - use for critical zenki where restart is dangerous

cascade          ## coordinated shutdown of dependent zenki first:
                 ##   - identify zenki that depend on this one
                 ##   - shut them down cleanly before restarting this one
                 ##   - prevents cascading failures from mid-flight commands
```

**forensics zenka integration**:
```
## forensics zenka receives:
{
  zenka:          'media',
  failure_mode:   'heartbeat_timeout',
  data_snapshot:  { ... },     ## %data tree at time of failure
  log_tail:       [ ... ],     ## last N log lines
  active_cmds:    [ ... ],     ## commands in flight at timeout
  uptime:         12847,       ## seconds since last start
  restart_count:  3,           ## how many times this has happened
}
```

forensics zenka can: classify the failure, check for patterns across
restarts, suggest config changes, alert humans, or trigger automated
remediation via the task zenka.

---

## implementation order

1. **[ LANDED ] hybrid on-demand + heartbeat** — simple coordination change in v7,
   high value immediately. check v7 zenka registry for existing correlation.

2. **[ LANDED ] unregister command** — small addition, needed for hybrid mode.
   verify v7 can call it or v7 handles internally.

3. **configurable timeout modes** — forensic-first first (most useful),
   then recovery-first, then the rest.

4. **wake permissions** — access control extension for on-demand startup.
   builds on base-has-access-source-sid-matching.md work.

5. **network priority levels** — after wake permissions are working.

6. **WoL integration** — gateway zenka sends WoL before waiting for
   next hop. depends on nested cube / gateway zenka being implemented.

---

## connections

- [[base-has-access-source-sid-matching]] — wake permissions use the same
  source SID matching for who-can-wake-what
- [[NESTED-CUBE-NETWORK-SEGMENTATION]] — route spawn chains work through
  gateway zenki; WoL is a gateway responsibility
- `data/md/development/CHILD-PROCESS-LIFECYCLE-POLICY.md` — existing
  lifecycle categories (disposable/decoupled/monitored)
- `data/tasks/v7-teardown-whitelist.md` — v7 access control, related work

#,,,.,.,.,,,.,,.,,,.,,...,..,,,.,,,,.,,,,,,..,..,,...,...,..,,.,.,,,,,..,,.,.,
#B34DGZIEMVX4PRZ3NKEXN3TVNALPDBWVDJCPW2L5JTYFKVUHWSOG5DXWT4IMRASE33PB3LCHCL74E
#\\\|6Y6OG23ZC42XNSFJVWLY2KOGFR7FRYKZB77CNVVAO5OCLQB5RSV \ / AMOS7 \ YOURUM ::
#\[7]4JV7PEKXFY7ADQLPM65FG74P2VUKR4NVLXKV7H34DQC5WLUSIGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
