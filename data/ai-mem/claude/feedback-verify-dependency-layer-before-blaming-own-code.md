---
name: feedback-verify-dependency-layer-before-blaming-own-code
description: when new client code keeps failing against an "already tested" backend, verify the backend directly and independently (bypass the new code entirely) before continuing to patch the new code — the cred-mesh/vault-edit "no active ui focus" chase found two real bugs in shared framework code, not in vault-edit at all
metadata:
  type: feedback
---

Spent several fix-test-fail rounds patching `vault-edit` (session_id
regex shape, argument composition, etc.) for a "no active ui focus"
symptom, each fix plausible and each one failing to change the outcome.
The actual bugs were two real, pre-existing defects in *shared framework
code* `vault-edit` merely happened to be the first caller to exercise:
`src/ui.unfold` silently dropped all arguments when delegating to a
zenka-specific `<namespace>.cmd.ui-show` override (`$code{$cmd}->()`,
zero args — found by calling `p7c cred-mesh.ui-show overview` directly,
bypassing vault-edit/cube-routing/self-loopback entirely, and seeing
`$call->{'args'}` arrive `undef` regardless), and `cred-mesh.cmd.ui-show`
itself had a classic Perl auto-vivification bug (`my $ui = $data{...}
{'ui'};` copies undef instead of aliasing the slot, so a later
`$ui->{'focus'} = ...` write never reached `%data` — found by `cred-mesh
.dump session.<id>` immediately after a real call, showing genuinely
empty state despite the calling code visibly running).

**Why:** each round's fix theory was tested only by re-running the SAME
end-to-end path (vault-edit → cube → cred-mesh) and watching for the same
symptom — which cannot distinguish "my new code is still wrong" from
"the thing my new code depends on is broken," since both produce
identical-looking failures from the caller's side. `cred-mesh.cmd.ui-
show`'s render even LOOKED successful throughout (rendered real content,
no errors) because the overview view doesn't depend on session-specific
state to render — masking the bug for every prior round.

**How to apply:** when a plausible, carefully-reasoned fix to new client
code doesn't change a persistent symptom, stop iterating on the client
and test the DEPENDENCY LAYER directly and in isolation — call the
backend command straight (`p7c <zenka>.<cmd> ...`), inspect its actual
stored state (`<zenka>.dump`/`.get`), independent of anything the new
code does. If the dependency fails or misbehaves even when called
perfectly correctly by hand, the bug was never in the new code at all.
This class of bug is easy to miss specifically because a default/no-op
code path (a default view, an empty registry) can render successfully
and hide a broken argument-passing or persistence layer indefinitely
until something finally needs the missing state.

**Also worth its own note**: building a headless self-test entry point
(`vault-edit.cmd.char-add`, mirroring `user-edit.cmd.char-add` — gated on
a `-no-tty` debug flag, injects keys into the same buffer a real
keystroke would, drives the event loop, returns the current render) is
what actually made this investigation tractable — it turned "ask the
user to run a test and paste the result" (slow, one round-trip per
hypothesis) into "run the test myself" (fast, several rounds per minute).
Worth building this kind of capability EARLY in any interactive-zenka
work expected to need more than one or two live-test rounds, not as an
afterthought once debugging has already dragged on.

#,,,,,,,,,,,.,.,,,,,.,.,,,.,,,,.,,.,.,,..,,,,,..,,...,...,..,,,..,,.,,...,..,,
#VZBGWGUVKR357YOFHVGQQUJPARWYUGB46ORKHNWEDDVCINBGLMXTKMRHJVZQDMTNF3F6YUFPBFULE
#\\\|V4JFKYCH542GNEYKKDH22V2ZLVRR2LCOZPODQ5ZF5EQWWLPTSPN \ / AMOS7 \ YOURUM ::
#\[7]I76A7L6L5OPKJYKNKPV4PHJ2VZJUNJ7MMXNM4YFPMBROXF3GO2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
