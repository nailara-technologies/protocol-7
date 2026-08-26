# task: workspace-transfer zenka — unbuilt bridge to the external workspace-transfer repo

## background

found 2026-08-21 while extracting content that had been misplaced into
`cfg/zenki/workspace-transfer/deps/src-used/` (formerly `source/`, a
namespace-marker directory, not a code directory — see
[[deps-os-short-leaf-names]] / the `deps/` ambiguity-cleanup rename for
context on how it got there).

14 stub scripts existed there, all bearing a literal
`PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_*` footer (never really signed,
confirming draft/scratch status) and never wired into
`workspace-transfer`'s `modules.load`. 6 of them (`bug`, `bug-commit`,
`checkpoint`, `status-check`, `todo`, `todo-commit`) were byte-for-byte
superseded by a real, working, properly-integrated native
reimplementation already living in `src/workspace-transfer.cmd.*` +
`.console.*` — those were deleted outright, no information lost.

**this task is about the other 8**, which were never natively rebuilt
and describe real, still-plausible functionality:

## what they wrapped

all 8 delegate via `exec()`/backticks to scripts inside an *external*
companion repository, not anything in protocol-7 itself:

```
https://github.com/nailara-technologies/workspace-transfer.git
```

cloned on demand to `/var/run/.7/workspace-transfer` (via an
`ensure-workspace` helper, itself superseded by the native
`src/workspace-transfer.util.ensure_workspace`).

this clarifies the shape of what happened: two design directions were
explored for workspace-transfer functionality —
1. **wrap the external companion repo's own scripts** (this stub batch)
2. **reimplement natively as protocol-7 zenka commands** operating on
   the workspace's own local git state (what actually got built, for
   the tracking subset: bug/todo/checkpoint-save)

direction 2 won for tracking, but never got extended to cover what
direction 1's stubs point at — so this functionality currently exists
**only** in the external repo, if it exists there at all (not verified
here — the external repo's actual current state wasn't checked).

## the 8 unbuilt commands

| stub name | descr | external target |
|---|---|---|
| `bootstrap` | Initialize workspace-transfer environment | `bootstrap.pl` |
| `init` | Check workspace initialization status | `init.pl` |
| `load-checkpoint` | Load and view saved conversation checkpoints | `scripts/load-context-checkpoint.pl` |
| `quick-save` | Quick save workspace to GitHub | `github-integration/quick_save_workspace.pl` |
| `sign` | Sign workspace files with cryptographic signatures | `workspace-sign.pl sign` |
| `verify` | Verify signed workspace files | `workspace-sign.pl verify` |
| `transfer` | Transfer files from workspace-transfer to protocol-7 | `scripts/transfer-to-protocol7.pl` |
| `configure-remote-PAT` | Configure GitHub Personal Access Token (delegates to keys zenka) | *(no external script — printed manual instructions pointing at `keys.console.github-pat`, which does exist in `src/`)* |

**`load-checkpoint` is the most notable gap**: the native
reimplementation built `checkpoint` (save) but never got a restore/view
counterpart. if checkpoint save-without-restore is actually in use,
this is the one worth prioritizing.

**`configure-remote-PAT` is the least stale**: `src/keys.console.github-pat`
already exists — this stub's job would just be wiring workspace-transfer
up to call it, not building new functionality.

## decision needed

not evaluated here: whether the external `nailara-technologies/
workspace-transfer` repo is still actively maintained/relevant, whether
wrapping it is still the right shape vs. a third native reimplementation
pass (matching what happened with the tracking commands), or whether
this functionality is simply no longer wanted. revisit when
workspace-transfer needs are actually being discussed again.

the original stub source (348 lines, all near-identical
exec-wrapper boilerplate) was not preserved verbatim — the table above
plus `git log` on this task file / the deletion commit covers what's
needed to reconstruct the shape if picked back up.

#,,,.,.,,,,.,,..,,...,,,,,,..,..,,.,,,,..,..,,..,,...,..,,..,,..,,,,.,..,,,..,
#G5EURHMI5LIZWRY3ILS5F5DBJN46T667RJFZXLVRWXXTPDIBVUCPM3S2ANQGGAFDICJMMU3WSUXUC
#\\\|26HUJB5R7IQUIRWXXC4ZDVHFCHAYX6RC2GQI2OATP3UFFUSPAOO \ / AMOS7 \ YOURUM ::
#\[7]XFKZUAZ57XS5KP4HWHERLT4REBL4POX56MXKGWWQPOBCW42VO2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
