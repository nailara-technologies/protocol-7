# task: extract inline helper subs (download/letsencr/source/space/work)

## relation

continues the inline-`sub _foo {}` cleanup series [ prior landings:
`base.stdio.frame.decode` -> `eff1ee210`, `base.stdio.frame.encode` +
`base.stdio.transport.emit` -> `4c5d518b9`, `tree.sort.trunk.*` +
`branch.space.*` -> `119eed733` ]. found via `ncode s src 'sub _'`.
runs alongside a sibling task `inline-subs-batch-weather-language.md`
[ disjoint files, safe to run in parallel ].

use `data/yaml/context-templates/extract-inline-subs.yaml` as the
workflow reference [ verbatim copy, one module at a time, P7 module
format, `<[...]>->(...)` call syntax, `$ARG`/`@ARG` not `$_`/`@_`,
no `.cmd.` in extracted util namespaces, drop leading `_` from sub
names ].

## scope : 7 inline subs across 5 modules

### 1. `modules/download.init_code` line 41 : `sub _resolve`
extract to `modules/download.util.resolve`

### 2. `modules/letsencr.child.continue_challenge_processing` line 11 :
`sub _cleanup_challenge`
extract to `modules/letsencr.child.util.cleanup_challenge`

### 3. `modules/source.signature_valid` line 634 :
`sub _verify_signature_with_data`
extract to `modules/source.signature.util.verify_signature_with_data`
[ this is a large module (770 lines) — read carefully, the sub is near
the end. verify there is exactly one call site. ]

### 4. `modules/space.search` line 151 : `sub _fallback_resonance`
extract to `modules/space.search.util.fallback_resonance`

### 5. `modules/work.parent.scan_history` lines 463/477/484 : three
helper subs, with a dependency between two of them:
- `sub _version_cmp` [ line 463 ] -> `modules/work.parent.util.version_cmp`
- `sub _version_diff` [ line 484 ] -> `modules/work.parent.util.version_diff`
- `sub _version_gap` [ line 477 ] -> `modules/work.parent.util.version_gap`
  — this one calls `_version_diff(...)` internally; rewrite that
  internal call as `<[work.parent.util.version_diff]>->(...)`.
  extract `_version_diff` BEFORE `_version_gap` so the rewrite target
  already exists.

for each: read the full source module first, find all call sites of
the inline sub [ may be called more than once ], replace every call
site with `<[new.module.name]>->(...)`, then remove the `sub _foo {}`
declaration [ and any `## ... ##` divider/comment around it ].

## registration

after all 7 new modules are created and source files updated:
- add all 7 new module names to `modules/base.list.subroutines`
  [ no strict alphabetical ordering required — follow existing local
  pattern, group near related `download.*` / `letsencr.*` /
  `source.*` / `space.*` / `work.*` entries ]
- regenerate `data/md/documentation/module-dependency-graph.asc` via
  `./bin/dev/dep-graph` [ do NOT hand-edit it — note: this may conflict
  with the sibling weather/language batch's regeneration if both run
  it; if the file has unexpected diffs from the other batch, just
  re-run `./bin/dev/dep-graph` again after both batches' module edits
  are in place ]

## verification

- `ncode s src:download 'sub _'`, `ncode s src:letsencr 'sub _'`,
  `ncode s src:source 'sub _'`, `ncode s src:space 'sub _'`,
  `ncode s src:work 'sub _'` return no matches
- all 12 modules [ 5 edited sources + 7 new ] pass `perl -c`
- for whichever zenki load `download.*`, `letsencr.*`, `source.*`,
  `space.*`, `work.*` [ check `cfg/zenki/*/start` for
  `modules.load` entries ], `p7c <zenka>.reload` completes with
  `reload source [success]` and `reinit source [success]`
- the combined v7 console output is tailable at
  `/dev/shm/.7/STDOUT/NIW7OAQ` if you need to watch reload output live

## non-goals

- no behavior change — pure refactor, same logic moved to sibling files
- do not touch `modules/weather.*` or `modules/base.language.*` —
  those are the sibling batch

## signatures note

no `#,,..` stubs. do NOT run update-signatures. lowercase comments,
`[ word ]` annotations, `$ARG`/`@ARG` not `$_`/`@_`, one-sub-per-file
[ no inline `sub {}` helpers ]. keep `# descr =` lines under 55 chars.

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,

#,,,.,,..,.,.,,..,,.,,.,.,,,,,,,.,,..,,..,.,,,..,,...,...,...,,.,,.,,,...,..,,
#JMSMT7OO7IRSIGA7VBIDGNBVEMBKSCZWVGQ7UQC2YHHTGVZPAAK2ZDQCWQDHTAWMGFCQ6IGAGHSRU
#\\\|X6ET64VKVESZ7ZQDLKXR5ESAK44JE34RYSWZOO2CVAGVFMOYJKY \ / AMOS7 \ YOURUM ::
#\[7]3D4IMWMVUA2C6SCBECWB6DL6VW5CMYD27X2DSYHA7ZGNAWEFZGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
