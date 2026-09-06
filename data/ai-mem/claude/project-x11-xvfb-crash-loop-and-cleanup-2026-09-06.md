---
name: project-x11-xvfb-crash-loop-and-cleanup-2026-09-06
description: "X-11 xvfb-start/status/list/stop went from crash-looping and structurally broken to a fully working, live-verified command cycle; 7 bugs fixed, task file rewritten. Same-day follow-ups: X-11.disp-ctl + X-11.cmd.xvfb-display let the zenka's 39 window-management commands target an xvfb auxiliary display, not just the primary; then xvfb-start dropped its caller-chosen display number entirely in favor of atomic auto-allocation via base.gen_id + a reversible x-<vax-int> reference label"
metadata:
  type: project
---

Started as: check `data/tasks/x11-xvfb-start-async-refactor.md` for
whether it's a clean dispatch-to-kimi candidate. It wasn't (real open
questions, live-testing hazard from prior crash-loops) - ended as a full
live debugging session that fixed everything in the task, plus 3 more
bugs found along the way.

**Why this matters**: the user's actual goal is automatic headless
capture recreation (vision-generic-web-template-hybrid-doc-browser
work) - a prior session had aborted trying xvfb mode for this and used
the non-headless web-browser zenka instead, because xvfb-start was
fundamentally broken. It now works.

## bugs found and fixed, all live-verified

1. Dependency deadlock (pre-existing fix, confirmed still correct)
2. **The actual crash-loop** - `X-11.cmd.xvfb-start` queued a redundant
   second `finalize_server` job on top of the one `X-11.job.start_server`
   already queues itself; both fired on the same dependency resolving,
   double-registering `event.add_io` on Xvfb's output pipe (never set
   non-blocking), so the second watcher's `sysread()` blocked the whole
   event loop and tripped v7's heartbeat watchdog. The task's original
   theory (slow `X11::Protocol->new()` connect) was wrong - live timing
   data showed every stage was fast. See
   [[feedback-audit-shared-state-when-multi-instance-bolted-on]] for how
   a related bug (6, below) was found via git archaeology.
3. Resource guard (pre-existing fix, confirmed still correct)
4. `xvfb-status`/`xvfb-list`/`xvfb-stop` all read `<X-11.xvfb.pid>`,
   which nothing ever wrote to - real state lives in `<X-11.servers>`.
   Fixed to read the right structure, with a `mode eq 'xvfb'` guard so
   these commands can never touch the primary/host display.
5. `server_output` logged every deliberate `xvfb-stop` identically to an
   unexplained crash ("shut down unexpectedly" at error level). Fixed by
   having `xvfb-stop` mark its own pid as an intentional stop before
   signalling it.
6. `output_buffer`/`first_error` were single global scalars (not keyed
   by pid/display) and `"done."` (a zenka-shutdown idiom) logged
   unconditionally even on the non-exiting auxiliary-server path - all
   three predate 2026-06-18's multi-server support and were never
   audited when it landed (see the linked feedback memory for the git
   archaeology that proved it). Fixed: moved onto per-server state
   (`$event->data`, confirmed same hashref for a watcher's lifetime),
   `"done."` now only logs when actually exiting.
7. Ported the `log_whitelist` convention from `openbox.start_wm` /
   `base.handler.child_output.simple`: Xvfb's benign xkbcomp keymap
   warnings now demote to log level 3 instead of 2, per the user's
   clean-logs-for-regular-operation policy (a level-2 diagnostic session
   should show only output that isn't already known-safe, not require
   re-figuring out "is this noise or signal" every time).

## process notes worth remembering

- `v7-zenki` is the zenka name (not `v7` - `p7c v7.list` returns "client
  not present"). Routable commands drop the `.cmd.` infix from the
  filename AND, for `v7-zenki.zenka.cmd.terminate`, also the `zenka.`
  segment - the actual command is `v7-zenki.terminate` (confirmed via
  `p7c v7-zenki.commands`, don't guess from the filename).
- `show-buffer` must be routed to the target zenka
  (`p7c X-11.show-buffer zenka N`) - the bare `show-buffer` command reads
  whatever zenka is p7c's own default target, which is NOT the zenka you
  think you're diagnosing.
- A zenka's own diagnostic-level (2+) log lines can be filtered at the
  source by its own `<system.zenka.verbosity.buffer>` (codebase default:
  1) - bumping it needs either a `devmod.change-log-verbosity` runtime
  call (only works if `devmod` is loaded into that zenka's module set,
  it often isn't) or a `system.zenka.verbosity.buffer = N` line added
  directly to the zenka's own `zenka.v7` config + a restart. Reverted
  back to default after this session's diagnostics were done, per the
  clean-logs policy - re-add it (2 or 3) for any future live session on
  this zenka.
- A restart of a v7-managed zenka after a source or config edit is
  `v7-zenki.restart <instance-id>` (from `v7-zenki.list zenki`, NOT the
  cube session id from `list sessions`/`list subnames` - different id
  spaces). A crash-loop can leave duplicate instances under the same
  zenka name; `v7-zenki.instance_pids <id>` + `ps -o lstart` tells you
  which is newer, `v7-zenki.terminate <older id>` cleans up.

## status

All 7 bugs fixed and live-verified, including a two-concurrent-display
stress test (separate Xvfb output streams stay un-interleaved, both
stop cleanly, no crash). Task file fully rewritten to document the real
root causes; ready to archive. Nothing in the original task remains open.

## same-day follow-up: X-11.disp-ctl + X-11.cmd.xvfb-display

The zenka has 39 existing `X-11.cmd.*` window-management commands
(get-windows, move-window, set_geometry, the dpms-*/keep_above/hide-
window family, etc.), every one of which reads a single global
(`<X-11.obj>`, `<X-11.WM>`, `<X-11.kbd>`, `<X-11.has_randr>`, ...) with
zero display parameter - so none of them could be pointed at an xvfb
auxiliary display, only the primary. Checked: every display (primary or
auxiliary) already gets its own raw `X11::Protocol` connection in
`<X-11.servers>->{$display_str}->{'conn'}` (set in
`X-11.handler.display_poll`) - the actual gap was that
`X-11.job.finalize_server` only builds the higher-level objects (WM,
keyboard, RANDR/DPMS/Composite flags) for the primary, in its
`return unless $is_primary` branch.

**The fix**, three new files + one small addition to `finalize_server`:
- `X-11.helper.setup_display_wm` - builds the minimal per-display bundle
  (WM, keyboard, extension flags) for a non-primary display, reusing
  `X-11.WM.update`'s existing tested WM-scan/WSL-fallback logic
  unchanged by `local`-substituting the same globals it already reads
  for the duration of the call (confirmed `X-11.pool.query` also reads
  `<X-11.obj>`, so this correctly flows through too).
- `X-11.job.finalize_server` - calls that helper for auxiliary displays;
  for the primary, added one small block at the very end (after all its
  existing richer host-mode setup) that mirrors the now-fully-populated
  globals onto `$server` too, so the primary carries the same
  per-server bundle shape as an auxiliary display, zero risk to the
  primary's existing tested logic.
- `X-11.cmd.disp-ctl <display_num> <sub-command> [args...]` - looks up
  the target display's bundle, `local`-substitutes it for the globals
  (auto-restores on return, including early return/die), dispatches to
  the existing `X-11.cmd.<sub-command>` unmodified. Explicitly refuses
  the one command (of 39 checked) that schedules `event.add_timer` work
  beyond its own call (`fade_out`) - `local`'s restore would have
  already unwound by the time a deferred timer fires, silently reading
  the primary's globals again instead of the targeted display's; an
  explicit refusal beats a silent wrong-display bug.
- `X-11.cmd.xvfb-display <server-id>` - simple lookup returning the
  X11 display string (e.g. `:52`) for a live, connected xvfb-mode
  entry, so a client script knows what to point `DISPLAY`/
  `X11::Protocol->new()` at. Deliberately scoped down (user's choice)
  to same-host/same-user addressing only, not a fuller host+auth
  resolution or a named-identifier layer.

None of the 39 existing commands were modified - the new capability is
entirely additive via `disp-ctl`, existing primary-display behavior is
unaffected.

**Live-verified**: `xvfb-display 61` returns `:61` for a live display;
`disp-ctl 61 get-windows` executes for real (empty result, correctly - a
bare Xvfb has no windows); `disp-ctl 62 is-composited` correctly reports
"no composite extension" while querying the primary directly in parallel
still correctly reports "yes, is composited" (proves the per-display
isolation actually works, not just returns the same primary state);
`disp-ctl 62 dpms-status` correctly reports no DPMS support (accurate for
bare Xvfb); a stopped/nonexistent display and the excluded `fade_out`
both correctly refused with clear messages; zenka stayed on the same
instance throughout, no orphaned processes. One real bug caught live
during this: `disp-ctl`'s `join(' ', @args)` produced `''` instead of
`undef` for a zero-extra-args call, which `get-windows` treated as
"filter by empty pattern" instead of "no filter" - every native zero-arg
call elsewhere passes `undef`, fixed to match.

**Naming note**: went through several rounds of the user's own
`bin/is-true`/harmonic-truth naming check (`X-11.get-xvfb-display` -
FALSE, rejected; `X-11.xvfb-display` - TRUE; `X-11.sub-disp-ctl` - TRUE
but `sub-` added no semantic value over plain `X-11.disp-ctl`, also TRUE
and shorter). See `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`
/ `AMOS7::Assert::Truth` for what this check is.

## same-day follow-up 2: auto-allocated display numbers + x-<id> labels

User's concern: callers picking their own `xvfb-start` display number can
collide, and any "reserve an id first, then start" two-step design would
need a round trip plus extra async state just to avoid that. Resolution:
`xvfb-start` no longer takes a display number at all (`<w> <h> [depth]`
only) - it picks one atomically, synchronously, in the same call.

**Mechanism**: `base.gen_id($href, $max_ids)` derives its id length as
`length($max_ids)+2` with a guaranteed non-zero leading digit - passing a
small `$max_ids` (99) naturally produces 4-digit numbers, which sit well
above the low display numbers (:0-:99) a manually configured primary/
xorg/xephyr display uses, with no separate floor arithmetic. `gen_id`
already retries internally until the raw integer passes
`AMOS7::Assert::Truth::is_true` (its default `$want_harmony` behavior).
New `X-11.helper.alloc_xvfb_display` seeds `gen_id`'s collision-tracking
href from every currently-active `<X-11.servers>` key (any mode, not
just xvfb - an auto-picked number must never collide with the primary
either), then wraps a second, OUTER retry loop around it: the raw
integer passing truth doesn't mean `'x-' . base.vax-int.encode($n)` also
does (different bytes, independent check) - same "generate -> transform
-> check truth of the FINAL form -> retry" shape as
`chk-sum.bmw.harmonize_L13`, mirrored rather than reused since that one's
specific to BMW/L13 content checksums.

**Why vax-int specifically** (user's own reasoning, worth keeping): it's
reversible, unlike an AMOS checksum - `base.vax-int.decode` (or
`bin/vax-int` standalone) gets the exact number back from the label, so
the label can be a genuine second reference to the same display, not
just a one-way cosmetic tag.

**The full loop, so the label is actually usable, not just returned**:
new `X-11.helper.resolve_display_id` accepts either a plain digit string
or an `x-<BASE32>` label (decoding it) and returns the plain number or
undef. `xvfb-status`/`xvfb-list`/`xvfb-stop`/`X-11.cmd.disp-ctl`/
`X-11.cmd.xvfb-display` all resolve their display argument through it
now, so a label works everywhere a raw number used to. `xvfb-status`/
`xvfb-list`'s output rows also gained the label as a field
(`<X-11.servers>->{$display_str}->{'label'}`, set by `xvfb-start`).

**Live-verified**: `xvfb-start 800 600` twice in a row returns two
different auto-picked 4-digit numbers with distinct labels (no manual
number ever given); `xvfb-status`/`xvfb-display <label>`/
`disp-ctl <label> get-windows`/`xvfb-stop <label>` all correctly resolve
the label back to the same display and operate on it; `xvfb-stop` via
label actually kills the right OS process; garbage input (`x-garbage!!`,
`notanumber`) is cleanly rejected by both commands; zenka stayed on the
same instance throughout, no crash, no orphaned processes.

**Bug caught live during this**: `X-11.cmd.xvfb-status`'s
`my $is_xvfb = defined $entry and (...) eq 'xvfb';` triggered a real
"useless use of eq in void context" compile warning - `and` binds looser
than `=`, so it was assigning just `defined $entry` and silently
discarding the `eq` result. Caught via the zenka's own live compile-
warning output on restart, NOT by `ptd -c` (known gap, see
[[feedback-ptd-syntax-check]]) - fixed by wrapping the whole condition in
parens. Worth remembering as a fresh instance of the general perl and/or-
precedence pitfall this project's dispatch notes already warn about.

**Explicitly not built this round**: any correlation between an xvfb
display's `x-<id>` label and a subname-style cross-zenki addressing
scheme (`zenka[subname]`) - user named this as the reason the id/label
work needed to happen first, but the correlation itself is separate,
not-yet-scoped work.

## next real step toward the user's stated goal

Not attempted this session: X-11 zenka's `zenka.v7` mode is still `host`
by default. `xvfb-start`/`xvfb-stop`/`disp-ctl`/`xvfb-display` being
reliable is the prerequisite, not the finish line - actually wiring a
headless-capture workflow to use an xvfb display end-to-end (spin one
up, drive it via disp-ctl / a client pointed at xvfb-display's address,
capture, tear down) is still open. Also open: the alternate
`X-11[subname]` mechanism (a separate dedicated zenka instance
configured for xvfb from the start, vs. an auxiliary display on the
primary instance) was noted in the original task as a deployment
pattern worth knowing about, not evaluated against this session's
approach.

#,,,,,...,,..,.,,,,.,,,,.,,,.,...,,.,,...,.,.,..,,...,...,.,.,,,,,,..,.,.,,,,,
#FKYZEMUGY3MJ5437LXK67N6LZHSJ5NBO4KQE7KFWTTHZQHQQ2QYBE7ZIDLA6IOXYKY7DZVWT6WGEA
#\\\|QN4ZRKDFJLBQTGCFP5W73KCYAWNMCRBYPAAFTXQCBJCTIOOT25Q \ / AMOS7 \ YOURUM ::
#\[7]HXAGQDN3RNMPXOIQMCCSAMS6VU7ZWK7H6PECQKNTQ33EDGMNQ4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
