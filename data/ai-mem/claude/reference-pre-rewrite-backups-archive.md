---
name: reference-pre-rewrite-backups-archive
description: the 9 old ../p7.bak.* directory copies are archived [ bundle per copy incl. stashes as refs/saved-stash/NN + tar.xz of loose files ] in /mnt/ext-xfs-data/repository/pre-rewrite-backups/ -- reviewed 2026-10-14, nothing left to import ; old ids + llm emails : never push
metadata:
  type: reference
---

`/mnt/ext-xfs-data/repository/pre-rewrite-backups/` [ 0700 \ 0600, 873 MB ] :
`p7.bak.<n>.bundle` [ all refs, every stash as `refs/saved-stash/NN`,
untracked stash parts included ] + `p7.bak.<n>.files.tar.xz` [ uncommitted,
untracked and ignored-but-unique files ]. directories deleted 2026-10-14.

restore : `git clone <n>.bundle` or
`git fetch <n>.bundle 'refs/saved-stash/*:refs/saved-stash/*'` -- into a
SCRATCH repo, never the live one [ pre-rewrite ids, llm author emails ].

review result 2026-10-14 [ content check against live HEAD, not patch-ids --
earlier rewrites changed those ] : side branches \ stashes \ loose files are
landed in other form, superseded, or must stay out [ 3 job-assessment files
with personal names ]. only the diff-modified fix was re-applied [ a7ebe55b2 ].

**Why:** the user's pre-git decade lost and duplicated work across parallel
directory copies -- check copies for stashes \ branches \ dirty files before
deleting, and keep one archive instead of scattered copies.

#,,,,,,.,,,.,,,..,,.,,,..,,,,,,.,,..,,,,.,.,,,..,,...,...,.,.,..,,...,,,,,...,
#XC3KVKL4KHDAZJUSKWMJ44OHF5A3C5DJSKV7QIV2XGJYFWM3KQTC472CE5NUNSIZL6UM77JZ7MGJK
#\\\|S56EG47N6DZNDTKM5N2GHOLN4RLI6HTVLFYXOHWVXHMPA7AAQDC \ / AMOS7 \ YOURUM ::
#\[7]CUECFR6G5YVHK3PFMZ5ZYB5FOTM2GKJHA3DV63FFRDA7666VGWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
