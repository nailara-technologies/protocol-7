---
name: feedback-check-console-zenka-precedent-before-cross-zenka-keystroke-relay
description: before designing any per-keystroke/modal interactive UI that spans two zenka processes, check for a self-contained console-zenka precedent (user-edit) first — routing keystrokes through cube's async command/reply protocol is a structural dead end, not a bug to patch
metadata:
  type: feedback
---

Built (then reverted, see [[project-cred-mesh-console-ui-architecture]])
an nshell-side single-key dispatch that routed `j/k/r/x/g/a/?` as cube
commands to a different zenka (`cred-mesh`), with a reply-triggered flag
to hand off free-text prompt input. It worked for a one-shot render
(`ui-show`) but the modal/stateful part had a genuine, unfixable-from-the-
client-side race: the "a prompt is now open" flag is armed by an async
cube reply arriving on its own timing, while the client's own keystroke
loop fires independently on STDIN readability — two uncoordinated async
event sources over the same modal state, no ordering guarantee between
them. Separately, it also meant credential payloads crossed cube as plain
command arguments, hitting `p7-log`/terminal-history — a real security
regression for a credential-handling feature, not just a UX rough edge.

**Why:** the user pointed out this codebase already has a working answer
to "how does an interactive terminal UI talk to a zenka that holds the
real data" — `user-edit`, which owns its OWN terminal (`term_init`/
`setup_stdin_watcher`/`handler.stdin_key`) and routes only individual DATA
operations to the separately-named `users` zenka, never keystrokes
themselves. The fix that actually works isn't "own the terminal" alone —
it's `user-edit.console.start`'s HYBRID LOOP MODE: send one routed
command, then block (`[base.init-done:TRUE]` + `[base.zenka.loop]`) for
THAT SPECIFIC reply before reading the next keystroke, serializing
keystroke → call → reply → repaint into one sequential turn instead of
two independent event streams racing.

**How to apply:** before proposing (let alone building) an interactive,
modal, per-keystroke UI where the terminal-owning process and the
data-owning process are different zenki, check `cfg/zenki/*/zenka.v7` for
an existing console-zenka pattern first (grep for `[base.call.
console_command]`, or zenka names ending in a role like `-edit`). If one
exists, mirror its terminal-ownership + hybrid-loop shape rather than
routing individual keystrokes as commands through cube — that structural
mismatch (independent async event sources coordinating shared modal
state across a process boundary) is not something a client-side patch can
fix, no matter how carefully the flag-arming logic is written.

Secondary, smaller lesson from the same session, worth its own note: this
codebase's internal module/file name is never automatically the wire
command name a zenka actually registers — always check the target
zenka's own `<base.cmd>` alias table (or its `commands` console output)
before assuming one. Bit twice in the same session: `cred-mesh.ui.show`
vs the registered `cred-mesh.ui-show`, then `cred-mesh.ui.interactive.
down` vs the registered `cred-mesh.interactive-down`.

#,,,,,,,.,.,,,.,.,,,.,,,,,,..,,,,,.,.,,,,,...,..,,...,...,,,.,.,,,,.,,...,.,.,
#26BF5RAOIFSDEIQJTGIANN3OT4BRW5EKGA6IVGM7KO3APP5BAQGF37EJHS6VC4RK7X6XZ6WRR4ZH4
#\\\|RUJHPFHKT5HB4JQZDHZMECWWEVUW3A6KCVZVP66KCH2OLWGSOCB \ / AMOS7 \ YOURUM ::
#\[7]IKJMMTT4ISKBF4GHLHV43UWDCGD2C7V4WMA7SSHJ5YO3IVGHA6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
