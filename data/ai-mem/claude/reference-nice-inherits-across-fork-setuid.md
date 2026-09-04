---
name: reference-nice-inherits-across-fork-setuid
description: to make an unprivileged forked child process run at a negative (elevated) nice value in protocol-7, renice the zenka itself while still root, before root.drop_privs -- not the child after it's already spawned unprivileged
metadata:
  type: reference
---

Process niceness is inherited across `fork`/`exec` and survives `setuid`.
Several zenki (`cube`, `X-11`) call `[base.change_prio:-N]` on themselves
very early in `zenka.v7` — before `[root.drop_privs:...]` and, for X-11,
before it even forks its server child. Because nice is inherited, every
child a zenka later forks (even long after dropping privileges) starts
at the same nice value the zenka had at fork time.

**Why this matters:** `base.change_prio` (`src/base.change_prio`) refuses
to set a negative priority unless `$REAL_USER_ID == 0` — i.e. it can only
elevate priority while still root. A zenka that drops privileges early
(most of them do, right after `[init_modules]`) can NEVER successfully
renice a child it forks later in its lifecycle (e.g. after
`[base.net.connect]`, deep in an async init chain) — the call will
silently no-op via that guard, looking like it should work but doing
nothing.

**How to apply:** to make a late-forked child (e.g. mpv's actual player
process, forked well after drop_privs) run at an elevated priority,
DON'T try to renice the child directly post-fork. Instead add
`[base.change_prio:-N]` to the zenka's own `zenka.v7`, placed anywhere
before its `[root.drop_privs:...]` line (mirroring cube's placement,
right after the initial `load_config_file` calls). Verify with
`ps -o pid,ni,user,stat,comm -p <zenka-pid>,<child-pid>` — both should
show the same `NI` value and the `<` STAT flag. Fixed this way for the
mpv zenka 2026-09-04 (commit `04ca71e4b`) after an EFFECTIVE_USER_ID-guarded
attempt to renice the child directly turned out to be dead code — the
zenka is always unprivileged by the time mpv.open_player runs.

#,,.,,,,.,..,,,,,,.,.,...,,..,,.,,,,,,.,,,,..,..,,...,..,,...,,.,,,,,,,..,,..,
#DEPKRISLQSRLKKAEIZTCF74HFJORCMYBSORNIOALUMQIUHJFV6JAVAFD57DKWPZ624TCRU2Y4GHEE
#\\\|HK24DFRO2E4LTMFHSGIL65YF6KY6OTHPBN547ST34OUHN6SR5OM \ / AMOS7 \ YOURUM ::
#\[7]RWHMFBAYA2RV2RLNSRIB425ZNPGAWQL4J4D7EQQIU4ZYJFLNASDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
