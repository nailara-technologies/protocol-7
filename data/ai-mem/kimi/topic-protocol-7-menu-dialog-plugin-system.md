# protocol-7-menu dialog plugin system [ 2026-08-09 ]

Task: data/yaml/coding-tasks/protocol-7-menu-dialog-plugin-system.yaml
IMPLEMENTED: dialog-types registry, cmd.input-choice, dialog-* wrappers,
pending-question ambient indicator.

## New modules

- `protocol-7-menu.dialog-types` — registry modeled on `amos-term.plugin-types`
- `protocol-7-menu.dialog-input-text` / `-password` / `-choice` — thin wrappers
  around the existing/new `cmd.*` implementations
- `protocol-7-menu.dialog-notification` — stub returning "not implemented"
- `protocol-7-menu.cmd.input-choice` — modal GTK3 dialog, one button per option,
  same shell/CSS palette as `cmd.input-text` (#000013 / #0055CC / #001066)
- `protocol-7-menu.pending-questions-init` + `.pending-indicator-update` +
  `.cmd.pending-question-{add,answer,open}` — ordinary provider push for
  "N pending questions"

## Wiring changes

- `src/protocol-7-menu.init_code` now calls `dialog-types` and
  `pending-questions-init`
- `cfg/zenki/protocol-7-menu/start` grants cube access to
  `input-choice` and `pending-question-*`
- `cfg/zenki/cube/access.zenki` mirrors that grant for `cred-mesh`
- `cfg/zenki/protocol-7-menu/subroutines.load-early` regenerated

## Non-obvious gotchas

1. `.cmd.` modules get a compiled-in `$call` header; calling them directly from
   a wrapper (`<[protocol-7-menu.cmd.input-choice]>->($params)`) works because
   the header assigns `$ARG[0]` to `$call->{'args'}` when it is not a hashref.

2. `dep-graph` / `gen-sub-whitelist` did not pick up the new `cmd.input-choice`
   or `pending-question-*` modules until they were added to the zenka's
   `access.cmd.usr.cube` list. The whitelist is compile-timing only, but
   commands referenced only by string (`p7c protocol-7-menu.cmd.pending-question-open`)
   need an access entry to become startup-reachable.

3. GTK3 button labels inherit color from the parent button's `color`, but the
   existing `label { color:#0055CC; }` rule would override it; adding an explicit
   `button label { color:#0055CC; }` keeps button text consistent with the
   accent. No new colors were introduced.

4. `delete-event` on the choice dialog returns 0 so GTK destroys the window;
  returning 1 would leave an undestroyed toplevel because the dialog is
  decorated=0 and the WM close path is not the primary exit anyway.

## Verification performed

- `./bin/dev/ptd -c` passes on all new modules and modified `init_code`
- `./bin/vc-changed-files -exc-len` reports no length violations
- `./bin/dev/dep-graph` + `./bin/dev/gen-sub-whitelist protocol-7-menu` picked
  up all new modules (545 subs)

## Remaining / out of scope

- `dialog-notification` full implementation
- coding-zenka tool wrappers (`ask_user_choice`, `ask_user_text`, etc.)
- amos-term `interaction` plugin track

#,,.,,,..,,.,,,,.,,..,.,.,,.,,,,,,.,,,..,,,,,,..,,...,...,...,,,,,...,.,.,,..,
#CWJOC6VFC4QC4SWFISYU26H3RIIBVXG4E4K3R7B4ZOK5KFXM7X7XW4JD2HU5FSZU7SNFQBWOI5MHO
#\\\|VLD5SDPXLYWIPF3LWC543IW4KE7K6KQEHZJJYZZTBEPUCGAOULJ \ / AMOS7 \ YOURUM ::
#\[7]6NH3WHU3EVIKNWRUKA3W2ABGK32JIUY6VYJRM6SASRYUTJN6EQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
