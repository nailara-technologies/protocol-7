---
name: topic-anyevent-bridge-vs-replace
description: "event.anyevent.init_code's real history: a stalled full drop-in-replacement attempt (blocked by AnyEvent missing variable watchers), distinct from a separate, still-viable 'bridge' design that would let AnyEvent-dependent third-party modules interoperate with the existing base.event.*/Event.pm loop without replacing anything"
metadata:
  type: project
---

**2026-07-25**, surfaced while diagnosing a `dep-graph`/`gen-sub-whitelist`
false-positive on `httpsd` (full mechanical detail in
[[feedback-base-prefix-stripped]]'s "two families colliding" entry — this
file is the design/history side, not the bug fix).

## the actual history of `event.anyevent.init_code`

Not abandoned-for-no-reason: it was a genuine attempt at a **drop-in
replacement** for `base.event.*`/`Event.pm` — meant to be flexible, hence
starting with `swap_subs('event.anyevent', 'event')` the same way
`base.event.pre_init` does, so a full parallel implementation
(`event.anyevent.add_io`, `.del_io`, etc.) would eventually promote to
become the actual `event.*` namespace. It stalled at just the init file
because **AnyEvent doesn't have variable watchers** — a capability the
drop-in-replacement approach needed and couldn't work around, so the
implementation was never completed. Kept on disk rather than deleted, in
case that gap ever gets resolved and the attempt is worth finishing
properly. User's explicit framing on priority: **the replacement path had
no urgency** — the existing `Event.pm`/`base.event.*` implementation is
already stable and performant, so there was never real pressure to finish
it. That's also why the bridge idea (below) is the thread actually worth
tracking going forward — it's not motivated by dissatisfaction with the
current loop, only by third-party interop need.

## a separate, still-viable idea: bridge, not replace

User's own framing: the real incentive to use AnyEvent isn't necessarily
to replace `Event.pm` — it's that **AnyEvent itself has an `Event.pm`
backend**. Some third-party Perl modules only know how to speak AnyEvent
(`AnyEvent->io`, `AnyEvent->condvar`, etc.), not raw `Event.pm`. If
AnyEvent is configured to use its own `Event.pm` backend, those modules'
AnyEvent calls would register against the *same* underlying `Event`
instance `base.event.add_io`/etc. already drive — no competing namespace,
no `swap_subs` needed at all, no variable-watcher gap to solve since
nothing is being replaced.

This is architecturally closer to how `base.gtk.main_loop`/
`base.gtk.attempt_load.glib_event` already treat `Glib::Event`: not a
rival implementation of `event.*`, just an optional low-level hook (or a
manual polling fallback via `<[event.once]>`) that lets `Gtk3->main`
drive the *same* `Event` watchers alongside its own loop. A concrete
bridge implementation would likely be something like setting
`$AnyEvent::MODEL = 'AnyEvent::Impl::Event'` (or relying on AnyEvent's own
backend autodetection finding the already-loaded `Event` module) rather
than anything resembling the current stub's `swap_subs` approach.

**A third, separate motivation, explicitly not to be conflated with the
above:** AnyEvent can also select an `evlib`/libev backend instead of
`Event.pm` — a distinct incentive (different performance/capability
profile), which would need its own, different integration shape than the
bridge idea above. Don't merge these two into one design; they solve
different problems.

## status

Design-only, not scoped into a task. Three genuinely distinct threads
now on record, not to be conflated with each other:
1. The stalled full-replacement attempt (`event.anyevent.init_code` as it
   exists today) — blocked on missing variable watchers, kept as a stub
   for possible future completion.
2. The bridge idea (Event.pm-backed AnyEvent, for third-party
   AnyEvent-only module interop) — architecturally simpler, doesn't hit
   the variable-watcher gap since nothing is being replaced.
3. The evlib/libev-backend motivation — separate performance-driven
   reason to touch AnyEvent, needs its own integration shape.

**What would actually unblock thread 1, if ever revisited:** an
equivalent to `Event.pm`'s variable watchers — or an elegant, even if
slower, fallback for them — implemented independently of AnyEvent itself.
User's framing: this isn't just about finishing the stalled replacement,
it's a real capability gap whose value stands on its own — "there would
be benefits to a more flexible event core" regardless of whether AnyEvent
interop ever happens. So this is a fourth, even more separable thread:
variable-watcher support (or a fallback) as its own capability to build,
which would *incidentally* reopen thread 1 as a side effect rather than
being motivated by it. Nothing scoped or designed yet — just the
observation that solving it has independent value.

**Why this would be tractable, not just desirable — user's point**:
`base.event.add_var` is the single, central gate every variable-watcher
registration goes through — confirmed live, exactly 15 real call sites
codebase-wide (`grep -rl "event\.add_var\b" modules/`: `v7.init_code`,
`protocol-7-menu.menu-structure-init`, `v7.setup_stdout_redir`,
`jobqueue.event.register_job_queues`, `httpd.http_post`,
`base.log.send-buffer.init`, `coding.cmd.complete-analysis`,
`vision-batch.parent.process`, `httpd.handler.input.body_remainder`,
`nshell.init_code`, `base.session.init`, `coding.vision-parser.init_code`,
`kimi.init_code`, `jobsite.init_code`, plus `base.event.add_var` itself).
No scattered ad-hoc variable-watching logic to hunt down elsewhere —
every affected variable, call site, and scope is already fully
enumerable from this one grep. That's what makes experimenting with a
replacement/fallback mechanism low-risk: the blast radius is exactly
these 15 files, known in advance, not something to discover mid-migration.

**Caveat, user's follow-up — the 15 sites aren't all low-stakes, and the
scope is broader than "core"**: several are session input/output buffers
with the full network I/O layer attached (e.g. `base.session.init`,
`httpd.handler.input.body_remainder`, `base.log.send-buffer.init`,
`nshell.init_code`) — but this isn't scoped to some narrow "core"
subsystem. It's the **protocol-7 link itself, on both sides of the
connection, for any zenka** — not just a few privileged always-on zenki.
And it extends beyond the primary protocol-7 wire protocol too: other
protocols the system speaks (HTTP/HTTPS, SSH, plan-9, etc. — see the
various `protocol.*`/`*.protocol-7.*`/`io.*` namespaces) sit on the same
variable-watcher foundation. So "15 enumerable call sites" understates the
real reach — it's 15 *registration* sites, but what flows through them is
every zenka's live network link, across every protocol this system speaks,
on both ends. "Enumerable and low-risk to *locate*" is not the same claim
as "low-risk to *change*" — the small, known blast radius makes
experimenting safe to scope and reason about, but this is exactly the
kind of thing that needs careful, real-traffic verification (not just
`perl -c`/syntax checks) before trusting a replacement mechanism, given
what they're actually watching.

**What the watched variables actually decouple — user's mechanism
explanation**: the input/output buffers sit *between*
`base.handler.command` and the IO event layers. The variable watcher
fires when a packet gets stripped off an input buffer scalar (parsed/
consumed) or when network output gets appended to an output buffer
scalar (queued to send). The whole point is that `base.handler.command`
never touches an actual IO handle/socket directly — it only reads/writes
plain scalar variables, and the variable-watcher mechanism is what
bridges "this scalar changed" into the real IO action (or the reverse:
"IO layer wrote new bytes into the input buffer" → command handler gets
notified data arrived). That's the actual architectural role
`base.event.add_var` plays: the decoupling seam between command
processing and the network layer, for every zenka, on both ends of the
link, across every protocol. Any replacement/fallback mechanism has to
preserve exactly this seam, not just "watch a variable" in the abstract.

## related

[[feedback-base-prefix-stripped]] (the swap_subs mechanism + the scanner
false-positive this stub currently causes), [[feedback-swap-subs-not-fragile]]

#,,,.,,,,,,.,,...,.,.,,,.,,,.,,,,,.,.,...,.,.,..,,...,...,.,.,,.,,.,,,,..,.,,,
#CUWV5N53N3XM66MHTFTYU67CLNZCVC5L55N6WOPKLC6KT3CNTVJFU4L57LQ5SWWSYWRR2NUTBE5W6
#\\\|XLZ4ZUBZTNOO6SGQYX6PPC54IVXTDJ45RSFSCNFMHE4QIGUTX4W \ / AMOS7 \ YOURUM ::
#\[7]Q5GAOIVPPUR3GGJB7EY6TFFAR3L7LX4LYDLCKPESALGVJZQQBWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
