---
name: topic-smtpd-actionable-mail-channels-notify
description: smtpd.route's actionable-mail notify call was hardwired to a legacy send.local path (fixed) and depended on a dbus zenka regex bug (fixed) and a missing notification-daemon (env gap); still routes to a desktop notify-osd zenka that can't run on a headless smtpd host -- proposal is to publish to channels.* instead, syncing cross-host to wherever a desktop session exists
metadata:
  type: project
---

during live verification of [[pattern-registry-engine]] (2026-08-24), found that
`src/smtpd.route`'s "notify on actionable mail" block (the `action_required`
branch, ~line 43) called `<[base.protocol-7.command.send.local]>->({command =>
'cube.notify.message', ...})` directly -- routing to the `notify`/`notify-osd`
zenka family (`cfg/zenki/notify*`, `src/notify.cmd.message`,
`src/notify-osd.*`), which exists to put a popup on an active desktop session
via notify-osd.

**problem 1 -- FIXED (2026-08-24, by user directly, live)**: the call crashed
with `undefined value as subroutine reference` at `smtpd.route:48` on every
`action_required` intent, but only after a FULL `p7c smtpd.reload` (source-only
reload didn't trigger it) -- root cause never fully pinned down (ruled out:
`base.caller`, `event.add_timer`, all whitelisted callees of `send.local`/
`base.route.add`/`base.zenki.resolve_routing_sids`), but empirically the fix
was to stop calling the legacy `base.protocol-7.command.send.local` primitive
directly and use the newer wrapper instead:
```perl
# before (crashed on full reload):
<[base.protocol-7.command.send.local]>->({'command' => qw| cube.notify.message |, ...});
# after (clean across full reloads, verified):
<[protocol-7.route-send]>->({'command' => qw| notify.message |, ...});
```
Note the call target also dropped the `cube.` prefix (`notify.message`, not
`cube.notify.message`) -- `route-send` and `send.local` take the target
differently. `<[protocol-7.route-send]>` textually expands to
`$code{'protocol-7.route-send'}->(...)` (P7's `<[name]>` macro is a pure
string substitution, confirmed at `bin/Protocol-7:1408-1411` -- no namespace-
relative resolution), yet no file in `src/` declares that literal name (only
`src/base.protocol-7.route-send` does, header `# name = base.protocol-7.
route-send`) -- how `$code{'protocol-7.route-send'}` ends up populated at
runtime is still unexplained, but the fix is verified working across
multiple full reloads with all 5 `action_required`-setting intents (interview_
request/offer/document_request/reply), so treat it as the correct call form
going forward rather than re-investigating the resolution mechanism.

**problem 2 -- FIXED (2026-08-24, found+fixed live)**: once the crash was
gone, the notify actually attempted to fire and surfaced a genuine bug:
`notify` is an on-demand zenka whose startup depends on `dbus` (`access.cmd.
usr.notify = dbus.socket_address`), and `dbus`'s own on-demand start timed out
(`instance ... ['dbus'] start timed out after 64.7s`) -- but NOT because
`dbus-daemon` failed to start; it started fine every time (confirmed
standalone: `dbus-daemon --print-address --session --nopidfile --nofork`
prints an address immediately). The real bug: `src/dbus.handler.
process_output` line 35 parsed the printed address with
`m|^(unix:abstract=([^\n,]+),[^\n]+)$|` -- matching ONLY the Linux
abstract-namespace socket form. On this WSL2 host, `dbus-daemon` emits a
path-based address instead (`unix:path=/tmp/dbus-XXXXXXXXXX,guid=...` --
abstract sockets are apparently unavailable/unreliable under WSL2's network
namespace setup), which the regex never matched, so the address line fell
into the generic `else`/log branch and `<[base.async.get_session_id]>` (the
call that reports "online" back to v7/cube) never fired -- `dbus-daemon` ran
fine forever while v7 waited for a signal that would never come, until the
ondemand watchdog gave up. Fixed by broadening the regex to
`m{^(unix:(?:abstract|path)=([^\n,]+),[^\n]+)$}` -- note the switch from
`m| |` to `m{ }` delimiters, required because `(?:abstract|path)`'s literal
`|` collides with a `|`-delimited regex (same class of delimiter footgun as
the `s|^\s+|\s+$| | g` corruption fixed elsewhere in `smtpd.*` this session
-- `{}`/`()` delimiters don't have this ambiguity, prefer them whenever the
pattern itself contains alternation). Verified live: `dbus` reaches `online`
status reliably now (`p7c v7.restart dbus` + `v7.list zenki dbus`), and
`notify`/`notify-osd` both come up online right after (on-demand, chained).

**problem 3 -- new, NOT fixed, environment gap**: with dbus and notify both
online, `p7c notify.loves '...' '...'` still fails: `notify-send exited with
code 1` / `Failed to show notification: GDBus.Error:org.freedesktop.DBus.
Error.ServiceUnknown: The name org.freedesktop.Notifications was not
provided by any .service files`. The D-Bus session bus is now genuinely up
and reachable, but nothing is registered on it that implements the
`org.freedesktop.Notifications` interface -- WSLg provides X11 + audio
passthrough but not a full desktop shell, so there's no notification daemon
(e.g. `dunst`, `notification-daemon`, `xfce4-notifyd`) running to receive
`notify-send` calls. Not a protocol-7 bug -- a missing system package/service
on this dev box. Installing and running a lightweight notification daemon
(e.g. `dunst`) would resolve it here, but this is an environment decision,
not something to silently add as a code fix.

**design smell, still open**: smtpd hardwires *how* a human gets told about
actionable mail (a desktop OSD popup, needing a live X11/dbus session) into
the code that *decides* something is worth flagging. User's framing
(2026-08-24): smtpd is expected to mainly run on a remote/headless server, so
the actionable-mail signal needs a channel that can be synced cross-host to
wherever a desktop session actually exists, which then locally triggers the
notify-osd popup on exit from the LOCAL channels zenka -- not smtpd calling
notify-osd's chain directly at all. The `channels.*` zenka (`cfg/zenki/
channels`, `src/channels.cmd.subscribe`, `<channels.data>`/`<channels.
subscriptions>`) already exists as a lazy pub/sub-by-path layer, used today by
content-discovery/memory-sync/playlist-integration -- memory-sync in
particular already does cross-host data propagation, worth reading first as
the closest existing precedent for the sync leg of this design.

**why capture rather than fix now**: the design-smell fix needs its own
scoped task (channel shape/payload, confirming `channels` reaches smtpd's
host and the desktop host, cross-host sync mechanism, then swapping the
`notify.message` call for a publish). Decided (2026-08-24) not to
scope-creep this into the pattern-registry commit, which is already done
and merged. Problems 1 and 2 (the crash and the dbus regex) turned out to
be quick, concrete fixes and were landed the same session instead of
deferred -- only the channels redesign and the missing notification-daemon
package (problem 3, an environment decision) remain open.

**how to apply**: when picking up the channels redesign, start from
`channels.memory-sync.*` for the cross-host sync precedent, design the
channel path/payload (probably at least `message_id`, `intent`, `subject`,
`from`), confirm `channels` is reachable from smtpd's host and from
wherever notify-osd actually runs, then replace the `notify.message` call
in `src/smtpd.route` with a channel publish.

related: [[pattern-registry-engine]]

#,,.,,..,,...,..,,,..,.,,,.,,,.,,,,.,,,,,,,..,..,,...,...,.,.,.,.,,..,,,.,,..,
#6OGFM6ZMOSHEUXJS4WU7VUL3EV2NK43LZRM7RJWRCVHTSCNAZBNTQLSRVI563BYHLTXPXGZE5CW7A
#\\\|ZZMPYRJFKVTOCRXHT6N2GLYMKLWHZIMNRQWZWHTOR6GJ5VWL2E5 \ / AMOS7 \ YOURUM ::
#\[7]V6BRAG6YN3UCQHOB3NTGEOLS7HBH4ZEUUFUH6E3E3MVOU7GWOQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
