# Kimi Development Memory — Feedback (Protocol-7)

> gotchas, failure modes, and incidents moved out of `MEMORY.md` to keep the auto-loaded index
> slim. links remain valid.

## fork-child Critical Gotchas (Mar 2026)

`access.cmd.usr.child` keeps `cube.` prefix (post-hop form). `event.add_signal` hashref form only.
`route-send` for cube-routed commands; not for `child.*` aliases.
see `data/ai-mem/claude/critical-patterns.md`

## iteration-counter vs code-quality — REJECTED-ON-CHECK (2026-08-04)

file-level test of the footer's amos-iterations-remaining as quality signal:
three blind measurements [ 9B n=240 rho=+0.057 ; k2.7 n=168 rho=+0.033 ;
scripted metric n=5055 rho=+0.008 ] + distortion-injection [ 12 bugs +
2 comment-only controls, both directions, controls swing as much as bugs ].
also: the count is signing-KEY dependent — identical body, different key →
unrelated count. full writeup: data/tasks/iteration-counter-quality-results.md.

## incident : v7.stop vs v7.restart deadlock (2026-08-04)

ran `v7.stop kimi` instead of `v7.restart kimi` while iterating — with the
zenka stopped there is NO path to send `v7.start kimi` from inside the
session [ all p7_command/cube routing to kimi dies with it ]. needed user
to restart by hand. NEVER use bare stop on the zenka you are running
inside; use a combined restart [ stops AND starts ] or don't touch it.

**rename update (2026-09-09)**: `v7` zenka renamed to `v7-zenki`, and
`v7.stop`/`v7.stop-implicit` renamed to `v7-zenki.terminate`/
`v7-zenki.terminate-implicit` [ commits a315a0e5a, 23a0e8d53 ]. the
LESSON above is unchanged, but the commands are now `v7-zenki.terminate
<zenka>` [ still dangerous on your own zenka, same deadlock risk ] and
`v7-zenki.restart <zenka>` [ `src/v7-zenki.zenka.cmd.restart`, still a
real single command doing stop+start together -- use this one, not a
manual terminate-then-start sequence, unless you specifically need
`:twin:` zero-downtime handover, which only `restart` supports ].

## incident : `v7.reload init` TORE DOWN the entire network [ again ]

issued to re-scan start.cfg files ; re-running v7.init_code hit
the fatal init path [ ai-mem kimi topic-routing-mode-implementation.md
warned exactly this ] → v7 SIGTERMed everything. root restarted v7 on
pts/3 ~2min later ; fresh boot picked up the new zenka config fine.
lesson confirmed : NEVER `v7.reload init|all` on a live network to
register a new zenka — wait for a network restart instead. single-zenka
`audio.reload source` worked fine for module iteration.

#,,..,...,,.,,.,,,,.,,.,.,,.,,,.,,.,.,.,.,,..,..,,...,...,..,,,,,,,.,,,,,,,,.,
#JX4JMXHHDDAWR62U2KXPVPSPVDHZGHYUZY6P25WLCCWHKZSXXSW6VGM2VTRQ5X6ELFUE5J7TBB6LK
#\\\|YVSHLESUVCQTZHIWUR5XUARBADRROGAFF5DTYZQW4RVVNLS2KC6 \ / AMOS7 \ YOURUM ::
#\[7]REKI7EUEUJL3KEG5WQVKINMEHM2HQQ6JHFPVA34PPRRCQ5JZPWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## web-browser capture-slideshow var-watcher [ 2026-08-28 ]

The `event.add_var` var-watcher armed by `web-browser.cmd.start-capture-slideshow`
works correctly once the watched scalar is passed as an explicit
`\$data{'seg1'}{'seg2'}{'leaf'}` reference. The Glib::Event-backed `web-browser`
main loop services `Event->var` watchers normally; the earlier failure was the
escaped `\<web-browser.slideshow.url_index>` form, which the macro translator
turns into a reference to the literal name string and therefore never fires.

Also fixed: `src/web-browser.cmd.stop_slideshow` line 7 was doing a bare `== 0`
comparison against `<web-browser.slideshow.running>`, throwing an undef warning
when called on an already-stopped slideshow. Guarded with `( // 0 )`.

#,,.,,,,.,...,..,,,.,,,,.,,.,,.,.,...,.,.,,..,..,,...,..,,..,,,.,,..,,,.,,,,,,
#FHBT6SGPJXCIWYWIDJIGZPHKZC4HAU4DD7PK4MK5YPI5K6GTNHPHDUVUNKIBHNSWO6QZDU7EM5OU4
#\\\|CPD25MNO7OEFDGS2YI7QYB6OWNYPFGIHTLZTLCRJRWYKELEMWPV \ / AMOS7 \ YOURUM ::
#\[7]IQXDPHBGWTLSJOBBWZHS6NVINIFZU3CNLM5M4YSYR54YZL5FWGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
