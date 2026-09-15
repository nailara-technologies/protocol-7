## [:< ##

# name  = task: git check-ignore batch crashes on a repo-external symlink, silently skips filtering
# descr = base.source.collect_file_list's gitignore-exclusion step (added
#         2026-09-12) hard-fails whenever a candidate path goes through
#         cfg/development/workspace-transfer-repository (a symlink to
#         ../../../workspace-transfer, outside the repo) -- and the
#         failure is silent: the exclusion step just no-ops instead of
#         erroring loudly or excluding the one bad path

## context

found 2026-09-15, safely, via the new `sourcecode.console.match-files`
dry-run command (see `data/tasks/match-files-dry-run-tool.md` for that
tool) while investigating a real incident where a `bin/Protocol-7
sourcecode update-signatures` run attempted to sign 18984 files and hit:

```
fatal: pathspec 'cfg/development/workspace-transfer-repository/lib/ENV.pm' is beyond a symbolic link
```

`match-files ":inlist: cfg/** data/** read-me/**"` reproduces the exact
same fatal line with zero side effects (no signing key loaded, no files
touched) -- confirming this is NOT related to the incident's other real
mistake (a hasty, reverted change to collect_file_list's directory-
recursion behavior), it's a separate, pre-existing bug that fires on ANY
invocation broad enough to include this symlinked path, including a
bare `bin/Protocol-7 sourcecode update-signatures` with no target args
at all (confirmed: that's what actually crashed originally, per the
user's own transcript -- the 18984-file attempt was the FOLLOW-UP run).

## root cause, precisely located

`src/base.source.collect_file_list:252-268`:

```perl
if ( @source_paths and -d catfile( $work_tree, qw| .git | ) ) {
    my $list_file = sprintf( ... );
    <[file.put]>->( $list_file, join( "\n", @source_paths ) . "\n" );
    my @ignored
        = qx| git -C \Q$work_tree\E check-ignore --stdin < \Q$list_file\E |;
    chomp @ignored;
    unlink $list_file;
    if (@ignored) {
        ...
        @source_paths = grep { not $ignored{$ARG} } @source_paths;
    }
}
```

`cfg/development/workspace-transfer-repository` is a symlink (`lrwxrwxrwx
... -> ../../../workspace-transfer`) pointing OUTSIDE the repo root. Git
refuses to resolve any pathspec that traverses a symlink leaving the
repository boundary -- `git check-ignore --stdin` aborts the WHOLE batch
the moment it reaches such a path in its input, printing `fatal:
pathspec '...' is beyond a symbolic link` to stderr and exiting non-zero.
Since `qx` only captures stdout, `@ignored` ends up empty (git crashed
before emitting useful output), so `if (@ignored)` is false and the
entire gitignore-exclusion step silently NO-OPS -- every candidate,
including genuinely gitignored ones that this step exists specifically
to drop, proceeds unfiltered. No warning, no log line, nothing but git's
own raw `fatal:` line scrolling past in the console output looking like
(but not actually being) a crash of the P7 script itself.

## why this made the original incident worse

The 18984-file count from the reverted-recursion-fix run would have been
smaller with a working gitignore filter (data/state/kimi-dispatch-*.out
files, data/backup/*, and whatever else is legitimately gitignored under
cfg/data/read-me all stayed in the candidate list instead of being
dropped). Not the primary cause of that incident (the primary cause was
treating non-recursive-by-default as a bug and patching it without
understanding `:inlist:`+`/**` was the existing safe mechanism -- see
`data/ai-mem/claude/feedback-sourcecode-signature-corpus-scoping.md`),
but a real compounding factor, and a bug in its own right independent of
that mistake -- it would fire on the correct `:inlist: cfg/** data/**
read-me/**` invocation too, as confirmed above.

## proposed scope, not started

- process paths through `git check-ignore` individually (or in smaller
  batches with per-path error isolation) instead of one all-or-nothing
  `qx` call, so one problematic path can't silently defeat filtering for
  every other candidate.
- OR: pre-filter candidates to drop anything resolving through a symlink
  that leaves `$work_tree` before ever handing the list to `git check-
  ignore` -- `cfg/development/workspace-transfer-repository` is very
  likely never meant to be part of the signed corpus at all (it's a
  bridge/mirror into an external workspace, not this repo's own source).
- at minimum: detect `$CHILD_ERROR` after the `qx` call and log a loud,
  explicit warning when the gitignore-exclusion step fails outright,
  rather than silently proceeding as if nothing needed excluding -- the
  current silent-no-op behavior is the more dangerous half of this bug,
  independent of which fix direction is chosen for the symlink itself.

no design/implementation work done yet -- this is a capture-for-later
task file only, found and verified safely via match-files, never
requiring a real signing run.

#,,,,,,..,.,.,,,,,,.,,...,,,.,..,,.,,,,..,,..,..,,...,...,,..,...,.,,,,,.,...,
#QPCSO6SVZ3CQIAMR5BQJBXJACJBLKZUUA6WX6MANKKK37X4WRSEC3ZBONF4DRNAGGREDPQRK5545K
#\\\|QXDRX5DCJJBZYS33SZJVXGP5NYRCDNI4EPWAL5XZ5YTTYG2RMPR \ / AMOS7 \ YOURUM ::
#\[7]X4JLGSH6RBTDPM45YZTLVOYWPJYJDYMJDDWVJSCRQKFT3VN2PUDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
