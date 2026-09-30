# hybrid zenka start-up : follow-ups [ from data/md/design/ZENKA-HYBRID-STARTUP-DISPATCH.md ]

the hybrid start-up [ module set chosen by the invoked console command ]
is built and proven in the `zenki` zenka. this task collects the design's
open decisions that are still open on 2026-09-30. read `CLAUDE.md` and the
design file first.

already resolved, do not redo : the `plugin.auth.unix` peer-user
tautology the design lists last -- fixed 2026-09-20 [ 38e604b29 ].

## 1. no "safe to manage" marker [ highest value ]

a console-only [ `configure`-shaped ] start file ends in
`[base.call.console_command:<system.args>]`. started by v7-zenki, args are
empty, `base.call.console_command` falls through to `commands`, the zenka
prints its whole command table, exits, and v7-zenki restarts it with
`start-retries : limitless` [ seen live for `work` and `session` ]. since
the `zenki` front door, one unprivileged command reaches it.

**the rule [ user, 2026-09-30 ] : console-only zenki have NO start.cfg.**
v7-zenki only sees zenki that have one, so without it they are not
startable by v7-zenki at all -- the marker already exists. the ones that
have a start.cfg got it from models not knowing the difference.

inventory 2026-09-30 [ zenka.v7 ending in `console_command` ] :
configure, keys, sourcecode, user-edit, vault-edit -- no start.cfg,
correct. **session, work -- have one** [ both arrived with 7ae191258,
the 2026-08-21 `zenka-startup.v7` -> `start.cfg` rename ; nothing refers
to them ] : both removed 2026-09-30 [ user's go ].

- optional guard : `v7-zenki.load_zenka_startup_cfgs` warns once when a
  zenka with a start.cfg has a zenka.v7 without `[zenka.loop]` \
  `[init-done` \ a hybrid console command -- catches the next one
- also : the limitless retry for a zenka that exits cleanly at once

## 2. the argv option filter drops only one of two adjacent flags

`bin/Protocol-7:88` : `s<(^| +)\-([v]+h?z?d?|N\S+|lpw=(\d{1,2}))( +|$)>< >g`
consumes the separating space with each match, so a second adjacent
filtered flag never sits at a boundary [ e.g. `-v -N<x>` -> `-N<x>`
left in `<system.args>` ; the design saw `-v` left over ]. fix : a zero-width
end, `(?=\s|$)`, or a token-wise filter [ split, grep, join ]. the same
code may exist in `P7Syntax.pm` \ other launchers -- grep. takes effect
only at a process start [ main:: code, see bin-protocol-7-main-subs-to-modules.md ].
then remove the local workaround in `zenki.parent.select-modules`.

## 3. rename the `zenki` zenka

it collides with the `zenki.*` shared-code namespace it loads [ same
class as the v7 -> v7-zenki rename ]. a rename proposal [ name, every
reference via `bin/ncode` ] for the user -- judged on improvement only.

## 4. later, separate decisions [ not in this task ]

- the pattern in v7-zenki itself [ callable without the fleet running ]
  -- only together with `v7-zenki-hot-self-restart.md`, never in the
  same change as other v7-zenki work
- the non-root bootstrap [ sudo path or a root-side helper ]

## output

per item : findings with file:line, a proposal, test on mod-test \ a
copy of a console-only zenka. item 2 may be fixed directly [ small,
verifiable ] ; items 1 and 3 need the user's choice first.

#,,.,,..,,,,.,,..,...,..,,,..,.,.,.,.,..,,,.,,.,.,...,...,,..,,,,,,..,.,.,.,,,
#YNLKAVZRZGIL6A3BS5PLDQIJHKOZ7FAGVDT2ZSACQD6X5XEM34AWXXRAK2FALQLQNN2IU3MBEYAXY
#\\\|4EUNNULZXYPJCKURT7GVPR5FFE5VGY4Y52EPJ2LTXHA4X5CWQ76 \ / AMOS7 \ YOURUM ::
#\[7]37T4WGHVRTCRE5G2HGLD6APZJVB76TMPTUBWHK2VD7NIPOXLPKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
