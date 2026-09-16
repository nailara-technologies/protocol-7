---
name: reference-git-tools-ownership-and-loader-lessons
description: how the coding-zenka git tools really work after the 2026-09 fix -- safe.directory chain (binary + libgit2), Git::Wrapper parser gotchas, the modules.load namespace rule, config continuation-comment syntax, and the Git::Native::Diff landmine
metadata:
  type: reference
---

Durable lessons from repairing the coding zenka's git tools (committed b5fd7886d, 2026-09-16).

## safe.directory needs TWO mechanisms, not one

- the git BINARY honors `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0`/`GIT_CONFIG_VALUE_0` env
  vars (set in coding.init_code since March 2026) AND `GIT_CONFIG_GLOBAL`.
- libgit2 >= 1.7 (Git::Native) refuses foreign-owned repos with GIT_EOWNER and
  IGNORES GIT_CONFIG_COUNT -- it only honors GIT_CONFIG_GLOBAL/SYSTEM, and ONLY when
  the repo was opened with `GIT_REPOSITORY_OPEN_FROM_ENV` (use_env flag gates
  config_path_global in the ownership check; verified in libgit2 1.9.7 source).
  plain `Git::Native->open` = open_ext(NO_SEARCH) -> use_env never set -> env
  invisible. `src/git.native.open` wraps open_ext(flags => 1|16).
- config ships in-repo at `cfg/git/safe-directory.config`; entries are path literals,
  inert where absent. dev: /data/projects/protocol-7 ; production: /usr/local/protocol-7
  (canonical prod root: systemd units, remote-sync-tunnel sshfs mount, workspace-transfer
  detection). sshfs mounts present the server's uid -> dubious ownership triggers on
  EVERY git call there; the in-repo env + config cover it with no host-local edits.

## Git::Wrapper gotchas

- `log()` FORCES `--pretty=medium` and Smart-parses `^commit <sha>` lines. passing
  `--oneline` overrides the format on the command line -> parser dies
  `unhandled: <first line>`. use structured objects (`$git->log(-N)`, ->id/->message)
  and build oneline shape yourself. broken silently since March 2026 behind an eval.
- `diff()` (and other non-Smart commands) pass args through RAW -- safe for
  `--stat`, `--cached`, patches.
- NEVER let eval around git calls be fully silent: a legitimately quiet repo and a
  failed git call must not collapse into the same `<!-- no recent changes -->`.

## Git::Native::Diff is landmined

after its FIRST diff call in a process, every subsequent diff entry point dies
`invalid version <stable-garbage> on git_diff_options` (diff_prepare_iterator_opts,
libgit2 1.9.7) -- reproducible one-shot, owner-independent, stat-only too. opts
pointer arrives corrupted; caller-side struct intact. root cause untraced
(FFI/Platypus state vs libgit2). do NOT reintroduce per-request native diff calls
until traced. both tools use the git binary now.

## loader rules that bit this session

- a multi-dot call `<[ns.module.name]>` needs the NAMESPACE in the zenka's
  `modules.load` in cfg/zenki/<zenka>/zenka.v7 -- subroutines.load-early +
  base.list.subroutines registrations alone do NOT put it in %code. probe with
  `p7c <zenka>.list-subs <ns>` (or coding.eval-code exists-check).
- `reload source` does NOT load newly-listed modules -- only a zenka restart does.
- config continuation syntax: a `##` comment on its own line UNDER a continuation
  backslash is parsed as VALUE content (shifts every following statement -- saw a
  phantom `=` module and plugins.load break). comments must stay INLINE after the
  value, no trailing backslash.
- zenka source files must be signature-clean to load: fabricated footers get skipped
  silently; the user runs `bin/Protocol-7 sourcecode update-signatures`, then
  version bump via `./bin/dev/update-version`, then commit (hooks enforce both).

## session-end ritual

user signs + stages -> commit (with version bump) -> user rebuilds the bundle via
`gbc` alias (git bundle create + verify to /mnt/ext-xfs-data/repository/) -> push
`hub base` (github nailara-technologies). ext-bundle remote is the bundle FILE --
read-only; pushing to it fails by design.

#,,,.,,,.,,,.,,,,,,,,,,,.,,.,,.,,,..,,.,,,..,,..,,...,...,,.,,,,.,,..,..,,,,,,
#D6DJWCE7LCXCNT6CF2ZTYDHNU436Y6AHNLCLGEFNCI2ZZ6M7GB3GNNTCI2YZBGU6CYYKE2KP5KCVK
#\\\|L2L3442ZVGWCEELAVSUO4CAHVV2QO3N73NSC7JXE4MBOZLIAZRC \ / AMOS7 \ YOURUM ::
#\[7]US4OMXICXBYSDYXFMFZ2IMDD5F7YTVX6ISQS4HI5SJKU6D5EFWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
