---
name: project-web-browser-snapshot-naming-landed-2026-08-20
description: "LANDED: web-browser.cmd.get_snapshot filenames are now snapshot.<amos-chksum of page url>.<ntime.B32>.png -- groups captures by page first, capture time second, chksum doubles as a direct lookup key"
metadata:
  type: project
---

Session 2026-08-20, commits `33aba773b` then `7e9007f3b` (user's own
follow-on idea, same session).

## what changed

`modules/web-browser.cmd.get_snapshot` built output filenames from raw
`time` + `$$` (pid): `snapshot_<unix_time>_<pid>.png`. Two-step
upgrade, both landed same session:

1. switched to `<[base.ntime.b32]>->(5, TRUE)` — `snapshot-<ntime.B32>
   .png` — mirroring the existing, unrelated `screenshot.cmd.capture-
   to-disk` module's own `screenshot-<ntime.b32>.png` stamp (found by
   grepping for other `<[base.ntime.b32]>` filename users first; this
   one is the closest analog, same "grab current view, save timestamped
   png" shape). Unlike `bin/todo`'s ntime.B32 work (see
   [[bin-todo-ntime-b32-timestamps-landed-2026-08-20]]), **no
   standalone port needed here** — this module runs inside the full
   zenka runtime, so the real `<[base.ntime.b32]>` core sub is called
   directly.
2. user's own follow-on idea: lead the filename with an amos-chksum of
   the *current page URL* (`$view->get_uri`), via `<[chk-sum.amos]>`
   — the short form, `base.` prefix stripped per
   [[base-prefix-stripped]] (`base.chk-sum.amos` → `chk-sum.amos`
   after `pre_init`'s `swap_subs`). Final shape:
   `snapshot.<url-chksum>.<ntime.B32>.png`, e.g.
   `snapshot.SVJGG3A.3WYYHQ4MEO5HW.png` — dot-separated, matching
   `bin/amos-chksum <url>`'s own output exactly (verified:
   `AMOS7::CHKSUM::amos_chksum(\$url)` with default modes gives the
   identical 7-char code the CLI tool prints).

**Why the chksum leads**: a directory listing sorts/groups snapshots by
page first (same URL → same leading chksum → adjacent entries), capture
time second within that group — makes browsing clusters of the same
test URL trivial, while the chksum itself still works as a direct
lookup key for a known URL (no separate index needed). Small instance
of the project's broader checksum-addressing philosophy — see
[[topic-addressing-trinity]] / [[topic-checksum-addressing]].

**How to apply**: if another zenka's capture/export path wants the
same "group by source, order by time" filename shape, this exact
two-field pattern (`<amos-chksum of the grouping key>.<ntime.B32>`)
is the one to reach for — cheap, needs no index file, sorts correctly
by construction.

#,,.,,,..,...,.,.,,,.,.,.,,.,,...,,,.,..,,,,,,.,.,...,...,...,..,,..,,,,.,,..,
#TG4BHFFUFEADOKOIC6Z3JUC5CWRBQ2Y6V7CJNDGKKBTOJLYFDEQKATEBTLW3BHFO56P43LOPAIOV2
#\\\|2OBJY2OEPNHAZMA5MRCRIT74DBIYQJVENKVMCTH2TF5OSNVWJW4 \ / AMOS7 \ YOURUM ::
#\[7]BODQNCFHNP7LCYXCG4HTTN4M6ZC5I5LGD2XRM3EQNMLPNDW2SUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
