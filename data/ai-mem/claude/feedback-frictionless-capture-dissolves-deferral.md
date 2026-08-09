---
name: frictionless-capture-dissolves-deferral
description: "user built bin/todo's style-cleanup + harmonic id-scheme specifically to remove friction from capture, so a mid-session one-liner reminder gets written to disk immediately instead of joining a pile of mental notes -- recognize this and act same-session"
metadata:
  type: feedback
---

observed 2026-08-09, sourcecode.console.update-signatures `:stage:` switch:
the user described the causal chain explicitly. it took (1) writing `bin/todo`
itself, (2) its style cleanup [[topic-bin-todo-style-refresh]], and (3)
enforcing the harmonic list-item id scheme [[project-bin-todo-random-id-scheme]]
before a "funnel" dissolved -- after which a throwaway mid-session sentence
("add :stage: switch to update-signatures") made it to disk as a real todo
entry immediately, rather than being routed onto the pile of other mid-session
mental notes that typically evaporate or get deferred indefinitely.

the follow-on point [[feedback-design-ideation-capture]] already covers:
don't just discuss a design riff, write it down. this memory covers the
layer underneath that -- WHY capture succeeds or fails at all. it isn't
about willpower or discipline to remember to write things down; it's about
whether the capture mechanism's friction has been engineered low enough
that writing beats not-writing by default.

**Why**: the user named the real bottleneck as friction, not
task-smallness or personal-relevance of the requirement. a task looking
"small and personal" is not itself a reason to defer -- what actually
determines whether it gets built same-session is whether the diagnostic
work is already done (see [[jobsite-export-history-csv-batch-import]]-style
tasks, born from an already-solved incident) and whether the capture path
from thought to durable record is short.

**How to apply**: when the user drops an unprompted one-line implementation
spec mid-task (a `:switch:` name, an exact behavior, a "this would save
copy-pasting" framing), treat that specificity itself as evidence the
diagnostic work already happened in their head -- the same signal
[[feedback-design-ideation-capture]] names for design riffs. Don't ask
"is this worth doing now" as if size were the open question; the open
question is only ever "has the shape already been proven." If yes,
implement same-session rather than parking it as a todo, mirroring how the
user now treats their own mid-session notes since the capture funnel
dissolved.

#,,,,,,.,,,..,...,...,,,.,,,.,...,,,.,...,,.,,..,,...,...,.,,,...,,.,,.,,,...,
#NWW4E4WDFK6BOTUODIHVRMHF2EVV6L6TY2OTAJXIXPHYQIAPCRU7DPFMWE4X46HNN6C6WD6LS4JGY
#\\\|QEJFV5E3553KUQ3LLRNVVRPLNU7KW652SBFTYKNUUD36GIKBVAC \ / AMOS7 \ YOURUM ::
#\[7]PQ463MJFLLZRPCRNRQ2FW7H25FDJH3HSDBEERP43VTKEITE5FGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
