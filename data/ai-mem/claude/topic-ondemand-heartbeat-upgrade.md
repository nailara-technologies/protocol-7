---
name: ondemand-heartbeat-upgrade
description: "future v7 upgrade to let on-demand zenki keep heartbeat enabled without heartbeats resetting the idle timeout, plus pre-exit termination notification"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

Currently on-demand zenki (`calc`, `image2html`, etc.) conventionally set
`restart.disabled = 1` and `heartbeat.disabled = 1` alongside
`start.on-demand = 1` + `[base.zenki.set_ondemand_timeout:N]` — so v7
neither monitors nor restarts them, and they self-terminate after idle.

**2026-06-15 — tile zenka set up as a test case:** `tile` (renamed from
`tile-groups`, see [[zenka-naming-cleanup]]) was configured as
`start.on-demand = 1` with `dependencies = cube X-11 openbox set-up` and
heartbeat/restart left at default (enabled), and *no* idle-timeout call.
Rationale: tile holds live window-group/layout state used by many
always-on desktop zenki — losing heartbeat protection (crash detection +
restart) wasn't worth the idle-timeout savings, and a non-zero idle
timeout would currently be pointless anyway since the on-demand timeout
logic treats heartbeat requests like regular requests (i.e. as long as
v7 heartbeats it, it never goes idle).

**Two follow-up upgrades identified (not yet implemented):**
1. Add a "exclude heartbeat requests from resetting the on-demand idle
   timer" mode, so on-demand zenki *can* have a real idle timeout even
   with heartbeat enabled.
2. Add a pre-exit termination notification from a self-terminating
   on-demand zenka to v7, which immediately disables auto-restart +
   heartbeat for that instance *before* the zenka exits — avoiding a
   false "unresponsive" detection race. Once implemented, this would let
   *all* on-demand zenki safely run with heartbeat enabled by default
   (protected against unplanned unresponsiveness, while planned
   idle/manual shutdown still works cleanly).

**2026-08-24 — LANDED, both #1 and #2.** Implemented as: (1) `heart` is
excluded from resetting `<base.ondemand.last_activity>`
(`base.handler.command`), and `base.event.callback.io-idle-restart` arms
the idle timer with the *remaining* time since last real activity instead
of the full window every time — unconditional/automatic, no opt-in flag.
(2) `v7.idle-term` (new `src/v7.zenka.cmd.idle-term`, cloned from
`v7.zenka.cmd.restart_own-zenka`'s cube_sid→instance resolution) — an
idling zenka asks v7 to terminate it via `v7.zenka.instance.stop`, which
sets `<zenka.instance.shutdown>` *before* killing the process so
`v7.handler.zenka_status`'s override forces `shutdown` status regardless
of what was computed, meaning no restart-on-idle-exit — race-proof by
construction, no separate "unregister"/pre-stop-window step needed. v7
replies `'deferred'` and deliberately never completes it on the accept
path (the caller's about to die anyway) and explicitly deletes its own
`<base.cmd_reply>` entry, since nothing else does — see
[[p7-local-command-route-and-deferred-reply-mechanics]] for why that's
safe and what it isn't the same as. Full design writeup + verification:
`data/tasks/completed/v7-ondemand-heartbeat-idle-term.md`, commit
`0f1ba4446`. Design doc `data/md/design/ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md`
updated with a status note; its "configurable timeout modes" / wake
permissions / priority / WoL sections remain open, unimplemented.

**2026-08-24 — first real rollout, zenka-by-zenka (commit `70a2e4013`).**
Went through every on-demand zenka and actually read its command-handler
code for blocking calls rather than flipping `heartbeat.disabled` in
bulk — see [[heartbeat-probe-backlog-mechanics]] for why a blind bulk
flip would have been wrong (a big `heartbeat.timeout` does not make a
long single blocking call safe; it just delays the same probe-backlog
problem).

- 28 zenki with zero blocking code found: heartbeat re-enabled at the
  internal 17s default — `audio`, `calc`, `channels`, `fetch-files`,
  `forensics`, `geoloc`, `graphics-matrix`, `image2html`, `index`,
  `index-mem`, `invoke-web`, `jobsite`, `mediainfo`, `menu-commands`,
  `opencv`, `pdf2html`, `povray`, `reasoning`, `screenshot`, `set-up`,
  `smtpd`, `sys-deps`, `task`, `test-link-upgrade`, `transport`,
  `users`, `vision-batch`, `X-11-pointer`.
- Bounded blocking calls, `heartbeat.timeout` sized to the largest
  internal call bound + margin: `kimi` = 30s (LWP calls capped at 10s),
  `invoke` = 60s (max internal 30s), `letsencr` = 45s (max internal
  15s, excluding `letsencr.child.*` which runs in a forked child),
  `site-yaml` = 60s (LWP timeout=30s).
- `tile`, `mpv`, `external`, `screen-setup`, `select-region`, `weather`,
  `window-place`, `content` — these were already heartbeat-monitored by
  default (no `heartbeat.disabled` line ever set, the `tile`-style
  pattern above). Confirmed clean on inspection (`mpv.open_player`'s
  `waitpid` is explicitly `WNOHANG`; the X-11 UI zenki load only
  generic modules, no zenka-specific code to block on), so given an
  explicit `heartbeat.timeout = 47` — WSL can add real jitter, so a
  value comfortably above the 17s internal default was wanted even
  though nothing here actually blocks.
- Left heartbeat disabled where a single command handler can
  legitimately block for an unbounded or very long duration, since no
  `heartbeat.timeout` value fixes the probe-backlog problem there (see
  [[heartbeat-probe-backlog-mechanics]]): `ffmpeg` (rescale — hours,
  known design limitation, needs a full refactor), `fs` (mount/umount —
  can legitimately take minutes on sequential-spin-up disk arrays),
  `melt` (frame extraction via blocking `waitpid`, no I/O-event
  pattern), `powershell` (`.exec` blocks on WSL-interop `getlines`; a
  false-positive kill mid-script could interrupt something on the
  Windows host that doesn't tolerate interruption well), `build`,
  `nessus`, `openvas`, `ncode` (all bare `waitpid($pid,0)`, no internal
  cap — build-recipe/scan/generic-subprocess duration is open-ended),
  `download` (LWP `timeout` is a stall timeout, not a total-duration
  cap — a large slow-but-active transfer could run long), `ext-pkg`,
  `memory`, `notify` (no internal bound at all, not resolved this
  session), `kimi-web` (mixed: several paths bounded at 10-30s, but
  `cmd.dispatch`'s synchronous branch takes a caller-supplied timeout
  defaulting to 300s with no cap), `lm-vision` (`handler.http_analyze`
  has an internal 300s LWP timeout — same backlog magnitude as the
  `fs`/`melt` case, so held), `models` (LLM/model management — sync
  LWP with no timeout at all in `backend.api.invoke`, unbounded
  `sha256sum`/install/local-server-start calls), `coding` (LLM
  orchestration zenka — its own code comments reference a past
  "waitpid incident," too complex/sensitive to certify from a
  read-through alone), `debian` (`apt_child` — same package-install
  duration uncertainty as `ext-pkg`).

**Still open:** `git`, `session`, `sessions`, `work`,
`workspace-transfer`, `zenki`, `branch`, `os-pkg` (no idle timeout, some
already heartbeat-monitored) weren't reached this session. `tile`'s
`start.cfg` still has *no* idle timeout — that specific "still open"
item from the original design remains unresolved; only its
`heartbeat.timeout` was addressed this round. `kimi-web`, `lm-vision`,
`models`, `coding`, `debian`, and the open-ended-duration group above
all need either a real bound discovered/added in code, or a genuine
async refactor, before heartbeat can be safely turned on for them.

#,,.,,,,,,,,.,...,,.,,..,,,..,,,.,...,,..,..,,..,,...,...,,..,.,,,...,.,.,,,.,
#M4CMAW2IYM4WKCD7DANPACCOFNRKVPIGE7ZGSQ5SQ3AK32SLOLEDIYJGVUQYTVZ7J2UBWE42PCRNM
#\\\|5CKUDDCH647LUI2E5F3DRVJ3ANN24YHJNAORRO5VR6GR6JTUKBW \ / AMOS7 \ YOURUM ::
#\[7]KSEOJ5DGTJUAEC4B2CFOHIZRD3ZVXHKCDN643TNQHIFGFEIAP2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
