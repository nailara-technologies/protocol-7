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

#,,,.,.,.,,,.,.,.,,,.,...,,,,,,.,,.,.,..,,,,.,..,,...,...,..,,,,,,..,,.,.,...,
#5BK47XDPX6RC4EXYALGNQORV6ZJCTYJRCMSGB2N4KBXHZ3FCSFL5EURKAIHRQUWISTZZ7CADQ25A6
#\\\|HHNC4E2SSSGVNAUZ362PF7TJV5FEWQF7ZR45KZQHYPUC5UNGFTW \ / AMOS7 \ YOURUM ::
#\[7]TZDAMQJEAVVK5DXI56JMHBWOQZ4M3C7WWRPV3ISSIWFUFJML5GCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
