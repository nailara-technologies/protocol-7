---
name: topic-smtpd-actionable-mail-channels-notify
description: smtpd.route's actionable-mail notify call was hardwired to a legacy send.local path (fixed, use route-send); still routes to a desktop notify-osd zenka that can't run on a headless smtpd host -- proposal is to publish to channels.* instead, syncing cross-host to wherever a desktop session exists
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

**problem 2 -- separate, NOT fixed, still real**: once the crash was gone,
the notify actually attempted to fire and surfaced a genuine environment gap:
`notify` is an on-demand zenka whose startup depends on `dbus` (`access.cmd.
usr.notify = dbus.socket_address`), and `dbus`'s own on-demand start timed out
(`instance ... ['dbus'] start timed out after 64.7s`), so cube's ondemand
watchdog fired and failed the 7 queued `notify.message` commands back. This is
exactly the headless-deployment mismatch below, now confirmed empirically
rather than just theorized.

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

**why capture rather than fix now**: this needs its own scoped task (channel
shape/payload, confirming `channels` reaches smtpd's host and the desktop
host, cross-host sync mechanism, then swapping the `notify.message` call for
a publish). Decided (2026-08-24) not to scope-creep this into the
pattern-registry commit, which is already done and merged.

**how to apply**: when picking this up, start from `channels.memory-sync.*`
for the cross-host sync precedent, design the channel path/payload (probably
at least `message_id`, `intent`, `subject`, `from`), confirm `channels` is
reachable from smtpd's host and from wherever notify-osd actually runs, then
replace the `notify.message` call in `src/smtpd.route` with a channel
publish. The `dbus` on-demand startup timeout is a separate, still-open
environment issue on this host -- check whether it's specific to this dev
box or a real dbus zenka problem before assuming it'll resolve itself once
notify-osd is only reached from a proper desktop-hosted channels subscriber.

related: [[pattern-registry-engine]]

#,,..,,,,,.,,,...,..,,..,,...,,,,,..,,,.,,.,,,..,,...,...,.,.,,,,,.,.,.,.,,,,,
#SEZLWOCKMHEK5B4HWXNP6KGPJG3LBRF7KANTCOFWC5WHJ2AY24MOOQUBP7P37QYHJMQB2LBSVVPKA
#\\\|OV4NJ6DEBJSDT6CWV2QME4J6YHYPWNPAUP3GQURXGSUDIVCLAIA \ / AMOS7 \ YOURUM ::
#\[7]Q3IGJWDSGFW7VZLGKFKWOX2SCXH4UFW5Z7HXPBVUNLPOR5O3RSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
