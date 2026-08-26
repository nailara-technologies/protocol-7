# task: add `ui` to modules.load for zenki that use it

## relation

`ui-namespace-extraction.md` (landed `f753e1a5d`) renamed `base.ui.*`
-> `ui.*` and `base.cmd.ui-show` -> `ui.cmd.ui-show`, updating 104
`cfg/zenki/*/subroutine.white-list` files. that rename
surfaced an open gap (recorded in memory `topic-next-steps.md`,
"OPEN follow-up: ui.* not in any modules.load"):

- `base.*` is unconditionally compiled for every zenka:
  `unshift( @module_names, qw| base | ) if $base;` in
  `bin/Protocol-7` (~line 1398)
- `ui.*` has no such treatment — `src/ui.*` files are only
  compiled for a zenka if `ui` appears in that zenka's
  `modules.load = ...` line (see `bin/Protocol-7` ~line 1513:
  `$src_rel =~ m|^(.*/)?$code_name(\..+)?$|` matches `ui.fold` etc
  against the load-list entry `ui`)
- right now NO zenka has `ui` in `modules.load`, so:
  - `ui.cmd.ui-show` is never compiled anywhere -> `$data{'base'}{'cmd'}
    {'ui-show'}` never gets auto-registered -> the `ui-show` fallback
    command (the whole point of `console-fold-primitive` /
    `1cf36cb34`) is currently unreachable for every zenka
  - `base.slot.fold` / `base.slot.move` / `base.slot.refresh` (in
    `base.*`, blanket-compiled) call `<[ui.fold]>`/`<[ui.unfold]>`,
    which resolve to undef and are caught by existing `eval` wraps —
    no crash, but slot fold/unfold currently no-ops everywhere

## scope

add `ui` to `modules.load = ...` in `cfg/zenki/<name>/start`
for every zenka whose `subroutine.white-list` already contains `ui.*`
or `ui.cmd.ui-show` entries (the same ~104 zenki from
`ui-namespace-extraction.md` — get the current list with
`grep -rl 'ui\.' cfg/zenki/*/subroutine.white-list` and
cross-check filenames are the renamed ui.* ones, not stale leftover
`base.ui.*` strings).

for each matching zenka:
- read `cfg/zenki/<name>/start`, find the
  `modules.load = ...` line
- append `ui` to the space-separated list (placement: alongside other
  generic/shared namespaces already in that line — check a few
  examples for convention, e.g. `crypt.C25519`, `auth.zenka`)
- if a zenka's `start` file has NO `modules.load` line at all (some
  minimal/standalone zenki may not), check whether it loads modules
  another way (`grep -n load_modules cfg/zenki/<name>/start`)
  before adding one — do not invent a new loading mechanism, report
  any such zenki instead of guessing

## verify

pick 2-3 representative zenki (e.g. `v7`, one always-on zenka, one
on-demand zenka) and confirm via `p7c <zenka>.list-subs` or similar
(`grep -rn list-subs src/base.*` to find the right introspection
command) that `ui.fold`, `ui.unfold`, `ui.cmd.ui-show` etc now appear
in `%code` for that zenka. if live verification against a running
instance isn't possible in this environment, at minimum confirm the
static `modules.load` change is syntactically consistent with how
other multi-namespace `modules.load` lines are written elsewhere.

## acceptance

- every zenka from the `ui.*`-whitelist set has `ui` added to its
  `modules.load` line in `cfg/zenki/<name>/start`
- no zenka gets a newly-invented `modules.load` line where one didn't
  exist before — those are reported as exceptions instead
- `base.slot.fold/move/refresh`'s `<[ui.fold]>`/`<[ui.unfold]>` calls
  become reachable (non-undef) for any zenka in the updated set that
  also has slot.* whitelisted
- `ui.cmd.ui-show` becomes reachable (registers
  `$data{'base'}{'cmd'}{'ui-show'}`) for any zenka in the updated set

## non-goals

- do not move `base.slot.*` to `ui.slot.*` (option (b) from the prior
  task — this task implements option (c) instead)
- do not modify `bin/Protocol-7`'s loader itself
- do not add `ui` to zenki that were NOT already in the `ui.*`
  whitelist set — if you think a specific zenka should be added,
  report it as a suggestion rather than doing it

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`. this task touches `cfg/zenki/*/start`
files, not `src/` — confirm whether `start` files carry the same
signature footer convention as modules before assuming none is needed.

## checks

```
perl -c src/ui.fold src/ui.unfold src/ui.cmd.ui-show
grep -c 'modules.load.*\bui\b' cfg/zenki/*/start
```

#,,,.,.,,,..,,..,,...,...,.,,,,,,,.,,,.,,,,,.,..,,...,...,,..,..,,...,.,.,,,.,
#ENN66TG4AHWKMUG4QHHBQXESJD2ZNBGSVPC46XDKAB7EOBJ3D2DINGQWGBH2D7SSWU23UYGS5YAMC
#\\\|LP5ANPEUP5G5MXQ6DEYSDQYSLMMOZWKEDFFNJVNHXW6BQAYW3PG \ / AMOS7 \ YOURUM ::
#\[7]IRQNCQXLQCRZC3Q4EGZYPRNVZ6L7QILD6PJEORCANADTSDOIBSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
