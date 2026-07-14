---
name: topic-x11-bare-name-routing-ambiguity
description: "bare-name command routing (X-11.foo, no [subname]) fans out to every session under that user name, not just the subname-less one — live-breaking once a second X-11 session (xvfb) registers"
metadata: 
  node_type: memory
  type: project
  originSessionId: f4339d87-d62c-4af2-bd7a-8532f2169b22
---

## the actual gap (corrected 2026-07-14)

An earlier note in this file (now retired) framed the upcoming
concurrent-X-11-zenki problem as an *identity/addressing* gap needing a
cube-13-style secondary cube to sidestep. That framing was wrong per
taeki's correction: instance addressing is not the problem — xvfb
instances already get their own cube session id plus their own subname
(`xvfb-0000`, `xvfb-0001`, ...), and explicit subname-qualified addressing
already works today via the `usr[subname].cmd` bracket syntax (regex
`usr_subn_str` in `modules/base.regex`, handled in
`modules/base.handler.command.route_to_target`).

The real gap is in the **bare-name** branch of that same routing logic —
when a caller sends `X-11.get_display` / `X-11.heart` with no `[subname]`
qualifier at all. In `modules/base.handler.command.route_to_target`
(~line 80-96), the loop over all sessions belonging to user `X-11` only
filters by subname when the caller specified one:

```perl
foreach my $target_sid ( keys $data{'user'}{$target_name}{'session'}->%* ) {
    next if $data{'session'}{$target_sid}{'mode'} ne qw| client |;
    next
        if defined $target_subname
        and ( not defined $data{'session'}{$target_sid}{'subname'}
        or $data{'session'}{$target_sid}{'subname'} ne $target_subname );
    push @send_sids, $target_sid;
}
```

When `$target_subname` is undef (the bare-name case), nothing excludes
sessions that *do* have a subname — every session registered under user
name `X-11` gets pushed to `@send_sids`, subname-less "desktop" instance
and every `xvfb-000N` instance alike. This only works correctly today by
accident: exactly one `X-11` session currently exists (the desktop/host
one, registered with no subname). The moment a second `X-11` session
comes online with an xvfb subname, every existing bare-name caller
(`X-11.get_display`, `X-11.get_screensize`, `X-11.heart`, etc. — the
current, universal calling convention, none of it subname-qualified) will
fan out to both the primary and every xvfb instance simultaneously,
producing multiple/duplicate replies where exactly one was expected. This
is a live-breaking routing bug waiting on a second X-11 session to exist,
not a future design project.

## what's needed

Per taeki: "making the zenka selection logic more intelligent instead of
knowing just one global X-11 zenka." Concretely, the bare-name branch of
`route_to_target` needs a rule for what "no subname specified" should
resolve to, replacing today's implicit "all of them." The natural
candidate: bare name = the subname-less session specifically (i.e. add
`next if defined $data{'session'}{$target_sid}{'subname'}` when
`$target_subname` is undef, mirroring the existing subname-match branch
but for the *absence* of a subname) — so bare `X-11.foo` always means "the
one true desktop X-11," and reaching an xvfb instance always requires the
explicit `X-11[xvfb-0002].foo` form. This is a small, scoped fix inside
existing routing logic, not a new addressing scheme.

Not yet checked: whether any existing caller *relies* on the current
fan-out-to-all behavior (e.g. a legitimate "ping every X-11 instance"
use case) — that would need auditing existing bare-name `X-11.*` callers
across `modules/` before changing the filter, though none surfaced in
what's been read so far and the calling convention throughout this
project favors singular, non-broadcast replies.

## status

Diagnosed, not yet fixed. No task file yet. Blocking trigger: whenever an
xvfb-mode X-11 zenka is first brought up concurrently with the host-mode
one under the same user name (see [[topic-x11-multi-server]],
[[topic-x11-resolution-profiles]]).

## related

[[topic-x11-multi-server]] · [[topic-x11-resolution-profiles]] ·
[[topic-window-canvas-addressing]] (unrelated identity question, already
solved differently — canvases, not zenka instances) ·
[[topic-hybrid-namespace-routing]]

#,,.,,.,.,,,.,...,,..,..,,..,,..,,,,.,,.,,.,.,..,,...,...,...,,,,,,..,.,,,,,,,
#JDCAN6FYMPEEDMZKSEKHSRTI7T4EOUG2HO6WDW6WMG5M5AJ2GMFUHDUQ6U7NNDYW56OX6RFIBCR7U
#\\\|JOU2AKSJXJRDRHYIU2OAGCJRVHLQVSE2WUFGX7UWVAGBGAZEQHH \ / AMOS7 \ YOURUM ::
#\[7]GICU77ZSLZOD4KXTMEZZJKZL5I73QKS6VCIMAWKFHFZVVLESXCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
