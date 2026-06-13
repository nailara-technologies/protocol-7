# task: extract inline helper subs (weather + base.language)

## relation

continues the inline-`sub _foo {}` cleanup series [ prior landings:
`base.stdio.frame.decode` -> `eff1ee210`, `base.stdio.frame.encode` +
`base.stdio.transport.emit` -> `4c5d518b9`, `tree.sort.trunk.*` +
`branch.space.*` -> `119eed733` ]. found via `ncode s src 'sub _'`.

use `data/yaml/context-templates/extract-inline-subs.yaml` as the
workflow reference [ verbatim copy, one module at a time, P7 module
format, `<[...]>->(...)` call syntax, `$ARG`/`@ARG` not `$_`/`@_`,
no `.cmd.` in extracted util namespaces, drop leading `_` from sub
names ].

## scope : 5 inline subs across 5 modules

### 1. `modules/weather.cmd.current` line 36 : `sub _format_current_widget`
extract to `modules/weather.current.util.format_current_widget`
[ drop `.cmd.` per convention: `weather.cmd.current` -> `weather.current` ]

### 2. `modules/weather.cmd.forecast` line 61 : `sub _format_forecast_widget`
extract to `modules/weather.forecast.util.format_forecast_widget`

### 3. `modules/weather.cmd.widget` line 29 : `sub _get_weather_widget_css`
extract to `modules/weather.widget.util.get_weather_widget_css`

### 4. `modules/base.language.detect` line 64 : `sub _wordlist_detect`
extract to `modules/base.language.util.wordlist_detect`

### 5. `modules/base.language.heuristic` line 14 : `sub _encoding_special_chars`
extract to `modules/base.language.util.encoding_special_chars`

for each: read the full source module first, find all call sites of
the inline sub [ may be called more than once ], replace every call
site with `<[new.module.name]>->(...)`, then remove the `sub _foo {}`
declaration [ and any `## [ ... ] ##` divider comment around it ].

## registration

after all 5 new modules are created and source files updated:
- add all 5 new module names to `modules/base.list.subroutines`
  [ no strict alphabetical ordering required — follow existing local
  pattern, group near related `weather.*` / `base.language.*` entries ]
- regenerate `data/md/documentation/module-dependency-graph.asc` via
  `./bin/dev/dep-graph` [ do NOT hand-edit it ]

## verification

- `ncode s src:weather 'sub _'` and `ncode s src:base.language 'sub _'`
  return no matches
- all 10 modules [ 5 edited sources + 5 new ] pass `perl -c`
- `p7c weather.reload` and `p7c <zenka>.reload` for whichever zenka
  loads `base.language.*` [ check `configuration/zenki/*/start` for
  `modules.load` entries ] complete with `reload source [success]` and
  `reinit source [success]`
- the combined v7 console output is tailable at
  `/dev/shm/.7/STDOUT/NIW7OAQ` if you need to watch reload output live

## non-goals

- no behavior change — pure refactor, same logic moved to sibling files
- do not touch `modules/download.*`, `modules/letsencr.*`,
  `modules/source.*`, `modules/space.*`, `modules/work.*` — those are a
  separate batch

## signatures note

no `#,,..` stubs. do NOT run update-signatures. lowercase comments,
`[ word ]` annotations, `$ARG`/`@ARG` not `$_`/`@_`, one-sub-per-file
[ no inline `sub {}` helpers ]. keep `# descr =` lines under 55 chars.

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,

#,,,.,,,,,.,.,,,.,,,.,...,,,.,,..,.,.,,,.,,..,..,,...,...,.,.,...,...,...,...,
#YDV6DQBB2FAHZQJLLUYVC3OZNBXRHBORQN7LUCD7TTMBHCQWNT2SHDSNFM32DK7X3UGPSV6RK6TKG
#\\\|SUNFOEG25GMVUMH5WEMOOLAXSUNXYQWJENIFPI2SKS6WDSDQFSD \ / AMOS7 \ YOURUM ::
#\[7]T2ATUIFS33MRHKHEEFZ7YASN6667QABCXKDH6XY433FCLQQ5SCAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
