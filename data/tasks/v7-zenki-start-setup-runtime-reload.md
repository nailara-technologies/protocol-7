# v7-zenki : reload start setups [ start.cfg ] at runtime

## problem [ 2026-09-30 ]

a change to a zenka's `cfg/zenki/<zenka>/start.cfg` did not take effect
after `reload config` \ `reload all` of v7-zenki -- only after a backend
restart [ observed : restart.keep_children for mod-test ]. cost today :
four backend restarts [ keep_children, start.on-demand for mod-test, a T-C
dependency test, keep-children tests ] -- each one ends invoke.ai and every
running zenka.

## first : find out exactly why [ corrected 2026-09-30 ]

the files ARE read on a reload : `v7-zenki.init_code` l.134 calls
`<[v7-zenki.load_zenka_startup_cfgs]>` unconditionally, which slurps every
`cfg/zenki/*/start.cfg` into `$s_cfg_data` [ `base.parse_ncfg_code` ].
[ `load_start_setup` l.126 is only the `start-set-up.*` profile. ] so the
loss happens AFTER reading : follow `$s_cfg_data` to where it lands in
`<v7-zenki.start_setup.zenki.config>` [ `v7-zenki.init_start_setup` ? ] --
merged only for zenki not yet known ? `//=` keeping old keys ? a guard on
reinit ? do not guess -- see
data/ai-mem/claude/feedback-llm-fix-regressions-pattern.md. [ an earlier
note of mine said "start setups are only read at v7-zenki's first start" --
wrong in that form ]

## reproduced 2026-09-30 ~17:50 [ clean case ]

- mod-test's start.cfg had `dependencies = cube models` [ T-C test ] when
  v7-zenki started [ 16:42 ] ; the file then went back to `dependencies =
  cube` [ committed 181c26372, 16:49 ]
- `p7c v7-zenki.list dependency` after a v7-zenki reload : mod-test still
  `cube models` -- restarting mod-test cascade-started models
- after a full v7-zenki restart : `cube` only
- so : a REMOVED dependency survives the reload. check first whether the
  merge only adds [ `dependency.add` for keys it finds, nothing for keys
  that are gone ]

## likely direction [ unverified ]

`v7-zenki.cmd.drop-dependency` already removes dependency objects :
`dependency.get_reverse` + `dependency.del`. but it drops ONE zenka from ALL
chains [ a manual override ] -- a reload needs the per-zenka form : for each
zenka whose start setup changed, delete its dependency objects that are no
longer in `dependencies =`, add the new ones. `drop-dependency` is also the
manual workaround until this is fixed [ affects every dependent of the
dropped zenka ].

## fixed : dependencies [ 2026-09-30, claude ]

root cause : `v7-zenki.post_init` called `set_up_zenka_dependencies` only
with the zenki ADDED since the last run, and `dependency.add` only appends
-- a known zenka never had its chain rebuilt. now : called every run,
objects only for the added zenki [ stable ids ], every chain deleted and
rebuilt from its current config. tested live : baseline identical after
a reload, `models` added -> `cube models`, removed -> `cube`, all other
chains identical. a `drop-dependency` override now lasts until the next
reload. on-demand registration follows a reload too [ verified : 3
zenki flagged -> "registering 3 ondemand zenki at cube", no restart ].
still open from the goal below : a log line per changed zenka, zenki removed from cfg [ see
zenki-ondemand-config-consistency.md ].

seen 2026-09-30 ~20:00 : after removing session \ work start.cfg + a
reload, `list dependency` still lists both. `init_start_setup` resets
`<v7-zenki.start_setup.zenki.config>` only for zenki it finds, so the
removed ones keep their old config, and `set_up_zenka_dependencies`
rebuilds their chains from it. fix : on reload, zenki in
`$removed_all_ref` [ v7-zenki.post_init ] lose their config, setup
entry and dependency object \ chain -- unless an instance is running
[ then keep until it ends ].

## goal

a runtime reload of the start setups -- e.g. `p7c v7-zenki.reload-start-setup
[ <zenka> ]` or as part of `reload config` :
- new \ changed keys take effect for the NEXT start \ restart of a zenka ;
  running instances keep their state [ no restart triggered by the reload ]
- removed keys are removed [ not silently kept from the old load ]
- dependency objects [ `dependency.*`, built from `dependencies =` ] are
  updated to match -- careful : dependency.ok \ ok_resolve read them
- on-demand registration [ `v7-zenki.register_ondemand_zenki` ] follows a
  changed `start.on-demand`
- log once per zenka whose start setup changed [ which keys ]

## test

on mod-test [ the free test zenka ] : change a key in its start.cfg, reload,
check `p7c v7-zenki.list dependency mod-test` and the behavior at the next
mod-test start -- without a v7-zenki restart.

#,,.,,.,.,,.,,,..,..,,..,,,,,,,.,,,,,,,,,,,..,..,,...,...,,,,,,..,,.,,,,.,.,,,
#7VOUQM4JK4STUO4B66JEIOTXKMPMKMASQ2TPZTEC5KAI3IKH4WIEYBPKFOQXTGQ46BTT6EOLUG53O
#\\\|5QQ2TETPKSVMTKAWSL3NILXU2SVPWNYXAVSHQCJTVHNVHSZP2RK \ / AMOS7 \ YOURUM ::
#\[7]WNNHP7V4AIC5WKCP2PRWWPPBWC447BBMOXL7XGXH7ZPAUZ5K7EBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
