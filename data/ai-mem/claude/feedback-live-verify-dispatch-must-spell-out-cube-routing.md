---
name: feedback-live-verify-dispatch-must-spell-out-cube-routing
description: "a k3-256k live-verification dispatch for storage.9p.* burned ~85% of its session budget failing to grasp cube's .cmd.-stripping routing convention because the dispatch prompt assumed it as inherited knowledge instead of spelling it out"
metadata:
  type: feedback
---

## what happened

Dispatched a k3-256k task to bring up the real `storage` zenka and
live-exercise its `storage.cmd.9p-connect`/`storage.cmd.9p-scan`
commands end-to-end through cube (see
[[topic-storage-9p-server-buildout]] /
`data/tasks/completed/plan-9-server-event-loop-wiring.md` for the
broader arc this sat inside). The dispatch prompt described the goal
and pointed at the relevant files, but never explained P7's own
command-routing convention: a cube-routable command file named
`storage.cmd.9p-connect` is invoked over the wire as `storage.9p-connect`
— cube strips the `.cmd.` segment, it is not part of the routable name.

kimi spent the large majority of its session budget (reported at 85%+
used) trying combinations like `storage.cmd.9p-connect`,
`cmd.9p-connect`, and other guesses, because nothing in the task told
it cube does this stripping. It never independently rediscovered the
convention from reading `base.regex`/cube's dispatch code in the time
it had. The user had to attach to the live kimi terminal and explain
the routing rule directly; I then took over live verification myself
in the same conversation rather than re-prompting an already-exhausted
context window.

## why this is a distinct failure from the "narrow scoping" success pattern

[[feedback-narrow-scoped-kimi-task-file-pattern]] documents scoping
that worked well for **execution-free, static** dispatches (syntax
checks, hand-tracing). This incident was a **live-verification**
dispatch — the task explicitly required starting a real zenka and
routing real commands through cube. That category has an extra
implicit-knowledge surface a static task doesn't: the actual wire
conventions of the system being exercised (command naming/stripping,
auth requirements, socket paths, v7 start-set-up state). I treated
"kimi already has repo access and can read CLAUDE.md" as equivalent to
"kimi already knows how cube routes commands" — it is not; CLAUDE.md's
own routing section doesn't mention the `.cmd.` stripping detail
either, so this wasn't even discoverable by re-reading project docs.

## how to apply

For any dispatch (kimi or otherwise) whose task is to **live-exercise**
a zenka/command through cube, explicitly spell out in the task prompt,
every time, regardless of how "obvious" it seems from inside this
session's own accumulated context:
- the exact routable command string to type (already stripped of any
  `.cmd.`/`.handler.`-style file-naming segment), with one full worked
  example command + expected reply shape
- which zenki need to be running first and how to start them
  (`v7.start <name>`, dependencies)
- any auth/access-grant requirement that must already exist
  (`cfg/zenki/cube/access.zenki`, `auth.zenki`)
- how to tell a genuine "command doesn't exist" apart from a "command
  syntax rejected by cube's regex" failure (both can look like a
  generic error) — see [[bug-forensics-dotted-command-names]] for the
  diagnostic

Treat this as a mandatory checklist item before sending any
live-verification-style dispatch, not just for cube routing but for
any P7-specific wire convention the dispatched task depends on being
right the first time — a wasted 85%-of-budget session on a single
missing sentence is a much worse trade than a slightly longer prompt.

#,,,.,.,.,..,,,,.,,..,,,.,,,.,.,.,...,...,.,.,..,,...,...,..,,.,.,,.,,,,.,,..,
#XVW55F3AHUSIHZY5DTU63LF3PWBTJ5LSVQSUI2R6VWEXKNMTEUQZ37JXJIHNW6PAEL62JZMM2PZFK
#\\\|O7F7SGNAIBVRIDB7NZHN4TKD2CV565QRLRMUUAPQMYESZH62J2X \ / AMOS7 \ YOURUM ::
#\[7]FG7BR4R443O7FSPJVGCPJPQPCB76NOOMNYEMSGT3ZKBBNEXJKKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
