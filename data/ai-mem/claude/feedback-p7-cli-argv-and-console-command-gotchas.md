---
name: p7-cli-argv-and-console-command-gotchas
description: bin/Protocol-7 CLI quirks hit testing sourcecode signature commands - -v/-vq flags must come after the zenka name, and space-joined argv means filenames with spaces/leading-!/embedded-* can't be passed through a console command's file-list parameter
metadata:
  type: feedback
---

Found while live-testing `bin/Protocol-7 sourcecode verify-p7-signatures`
for [[feedback-sourcecode-signature-corpus-scoping]] (2026-09-13):

**`-v`/`-vq`/etc must come after the zenka name, not before.**
`bin/Protocol-7` resolves the zenka name from `$ARGV[0]` specifically (only
when it doesn't start with `-`). `bin/Protocol-7 -vq sourcecode foo` leaves
`$ARGV[0]` as `-vq`, so zenka-name resolution fails, it falls back to
`<stdin>` config mode, and the command silently does nothing (waits on a
config stream that never comes, exits 0 with no output). Always write
`bin/Protocol-7 <zenka> <command> [args] -vq`, verbosity flags last (or at
least after the zenka name).

**Space-joined/re-split argv can't carry a filename containing a space,
leading `!`, or `*`.** `bin/Protocol-7`'s arg handling (around line 607-608)
joins all non-dash `@ARGV` entries with a single space into one
`command_params` string; `base.source.collect_file_list` then re-splits
that same string on whitespace. Shell-quoting a path with a space at the
call site does *not* survive this round trip — the shell quoting is gone by
the time `bin/Protocol-7` re-joins argv, so the path re-splits into
unrelated fragments once it reaches `collect_file_list`. Empirically this
doesn't hard-crash (`collect_file_list`'s loose `file.match_dirs` pattern
matching just silently absorbs the fragments, at worst pulling in unrelated
files) — it neither crashes nor cleanly reports the fragmented path as
missing. A leading `!` is read as an exclusion pattern and a bare `*` as a
glob for the same underlying reason. No filename in this repo currently
uses any of these, so treat one turning up as worth a distinct warning
rather than assuming quoting protects you.

**How to apply:** when scripting against any `bin/Protocol-7 <zenka>
<command>` invocation — testing a console command from the shell, or
building tooling like the pre-commit hook that shells out to one — put
flags after the zenka name, and if the file list comes from an external
source (e.g. `git diff --name-only`), guard against space/`!`/`*` in the
names explicitly rather than trusting shell-quoting to carry them through.

#,,.,,,.,,.,,,.,,,,,.,,.,,,..,,,.,,..,,,,,,,,,..,,...,...,.,,,.,.,,,,,,,.,,..,
#ZKITNST7XKMERKRHLVDXF7VBHTPX6LE3IUCI2WIVV26RQVO2CQFOAQXF3MF2PYE2EFBV6YWOSCI7Q
#\\\|OQZAOZMRLKH7TVO62NWVKB7ASRJTYVTE6DCD5UUFWSJ7NRRQH7Y \ / AMOS7 \ YOURUM ::
#\[7]46YLEON3ZYNWIN56MCHGIM4LORL6RBB365PE4W5DPBJ4IORNROBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
