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
to restart by hand. NEVER use bare `v7.stop` on the zenka you are running
inside; use `v7.restart` [ stops AND starts ] or don't touch it.

## incident : `v7.reload init` TORE DOWN the entire network [ again ]

issued to re-scan zenka-startup.v7 files ; re-running v7.init_code hit
the fatal init path [ ai-mem kimi topic-routing-mode-implementation.md
warned exactly this ] → v7 SIGTERMed everything. root restarted v7 on
pts/3 ~2min later ; fresh boot picked up the new zenka config fine.
lesson confirmed : NEVER `v7.reload init|all` on a live network to
register a new zenka — wait for a network restart instead. single-zenka
`audio.reload source` worked fine for module iteration.

#,,..,,,,,...,,.,,.,,,..,,,,,,...,,,.,.,,,,,.,..,,...,..,,,,,,.,.,...,.,,,.,.,
#3U6VOQAMMG2AW7XXGMAYRW4KYK5IOCEISFGNDYM3JD2EYCHX3EIUEFMO2R23FRIBLDS56XX7E56TS
#\\\|UUK3FQFGDSK6A2VAWDDL33YETYCS7YMMN62HB4CKHUSR3AD6GNT \ / AMOS7 \ YOURUM ::
#\[7]GX4XBEQUXOA3F4PDEP226OLQ4MKNVJILRNKD3H63D6IMADRHZODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
