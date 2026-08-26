---
name: feedback-cmd-segment-stripped
description: ".cmd. in a module's on-disk name is stripped from the callable command — register access grants and call it as <zenka>.<name>, not <zenka>.cmd.<name> (live-confirming 2026-06-08)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 34aa7d51-70a7-457f-a1f9-f1ad06e0dd7b
---

A module file named `<zenka>.cmd.<name>` (e.g. `credential_fabric.cmd.
approve`) is invoked/granted-access-to as `<zenka>.<name>` (e.g.
`credential_fabric.approve`), NOT `<zenka>.cmd.<name>`. `.cmd.` is an
on-disk naming convention marking "this is a console-callable command
module" — it does not survive into the routed command name. This
mirrors [[feedback-base-prefix-stripped]] (the `base.` prefix is
likewise stripped at registration).

**Why:** `credential_fabric.cmd.approve:34` itself carries the comment
`## [ note: cube strips '.cmd.' segment for cross-zenka routing ] ##`.
Confirmed live during session 2026-06-08 (`f870d68f...`, dispatched to
test new `.cmd.resolve`/`.cmd.rotate`/`.cmd.list-slots` wrappers): the
session initially probed with `p7c credential_fabric.cmd.resolve <slot>`
(the on-disk name) and got `no perm [ cmd|usr 'cmd.resolve' ]` —
cube stripped only the `credential_fabric.` zenka prefix, leaving
`cmd.resolve` as the checked command name, which legitimately has no
grant (because the *real* callable name is `resolve`, not `cmd.resolve`).
The access.zenki grants added for this task already used the correct
stripped form (`credential_fabric.resolve`/`.rotate`/`.approve`/
`.list-slots`) — it was the *test invocation* that was wrong, not the
grant.

**How to apply:**
- on-disk module name: `<zenka>.cmd.<name>`
- access.zenki grant / `p7c` invocation: `<zenka>.<name>` (no `.cmd.`)
- if you see "no perm" or "command not known" for a `cmd.<name>`-shaped
  string in cube logs, the caller used the on-disk name instead of the
  routed name — fix the *invocation*, not the access grant
- **status: VERIFIED 2026-06-13** — `credential_fabric.resolve`/`.rotate`/
  `.list-slots`/`.ui-show` all called live via console (`.cmd.` stripped),
  routed correctly, returned real data (not "no perm"/"not known"). Closed.

#,,,,,.,,,...,,..,,,.,..,,..,,.,.,,..,..,,,..,..,,...,...,,.,,,.,,,..,,,.,.,.,
#3Q5DYJOIONFH5YCGLF3BQ6IQ75AOO34QDAS3DUR4TSUNAN77QYACBS36BQ5J2JRMJBLNADWY4EXFI
#\\\|3UJ64CBR5R3BWTTAYSVHVSHXSWIGC5SZXFWN2HFXUJ2A4MFAPDU \ / AMOS7 \ YOURUM ::
#\[7]VZ44ATU2CSHF44YIE7LEPMJAR6D2EELL6NHTGI3627F446IZ56CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
