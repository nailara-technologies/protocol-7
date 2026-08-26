---
name: project-disk-edit-host-edit-zenki-planned
description: "2026-08-14 user direction: two more console zenki likely to emerge soon in the same style as user-edit -- disk-edit and host-edit -- no scope defined yet, but expect them to reuse the user-edit/users pattern rather than starting from scratch"
metadata:
  type: project
---

**Per user, 2026-08-14** (stated while the `user-edit` key-details-tab
dispatch was in flight): two more zenki will likely emerge soon, in the
same style as `user-edit` — **`disk-edit`** and **`host-edit`**. No scope,
field list, or timeline given yet; this is a heads-up for when they do
surface, not a task to start now.

**How to apply**, based on what "same style" means for `user-edit` today
(see [[topic-user-edit-console-zenka-status]] for the full build history):

- standalone console zenka shape, cloned from `keys`' pattern originally
  (no crypt.C25519/network at first, network added back in later when
  needed — `user-edit` hit this exact gap at `43d22a1f8`)
- `editor.control.*` field editing (buffer/cursor/masked/readonly
  primitives), `ascii.frame.*`/`editor.ui.ascii_frame.*` rendering
- event-driven form loop (`event.add_io` on stdin, `event.add_var` on a
  dirty flag triggering re-render) once past a one-shot console-command
  phase
- the `plugin.<zenka>.<name>.*` detail-tab mechanism (`registry.post_init`
  discovery, `display_override` hook, pinned-field vs. synthesized-field
  distinction — see [[reference-editor-list-field-and-render-contract]]
  and the key-details tab work for the synthesized-field shape) is
  reusable machinery, not `user-edit`-specific, and should very likely be
  the starting point for whatever `disk-edit`/`host-edit` need rather than
  reinventing tab discovery per zenka
- `users.record.*`'s directory-per-record storage shape
  (`[NAMESPACE_HOST]/<key>/details.yaml`, single-source-of-truth path
  module) is worth checking as a precedent too if either of these turns
  out to need its own record store, though neither is confirmed to need
  one yet

**Not yet known**: what "disk" and "host" actually mean here — likely
either two more `users`-style authority zenki for different record
namespaces (parallel to `host-system`), or two more `user-edit`-style thin
editing front-ends over an existing/future authority zenka. Ask when they
actually come up rather than guessing further now.

[[topic-user-edit-console-zenka-status]]
[[project-keys-zenka-integration-direction]]

#,,.,,,.,,,.,,..,,,,.,..,,...,,..,..,,..,,.,.,..,,...,...,..,,,..,,.,,.,.,..,,
#AZS2CDRZHM6MHZC7QRM45DIPI73763Y4NDROAD4P5YMT22T4B74RH3LH7543Y5IC4CXLVEDZEWYPS
#\\\|DLVUCAC7FWIXBNBBXAW7VGOLDEZLOJHTBDBC6BUWIJ5L3XFB6YO \ / AMOS7 \ YOURUM ::
#\[7]UIQU2NL5ARVTTXPDMN7A3LWCUOWU556C66WNQWXCLZDMNH6LPWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
