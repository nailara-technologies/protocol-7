---
name: sourcecode-signature-corpus-scoping
description: when scoping a sourcecode.console.* signing/verify command to a caller-given file list, intersect against the authoritative sourcecode.source_path_set_up corpus, never a regex approximation of it; add a :keyword: flag to the existing command rather than a new console command; and never "fix" collect_file_list's bare-directory non-recursion without checking `/** + :inlist:` first -- that's the existing safe mechanism, not a gap
metadata:
  type: feedback
---

Implementing ADR "scope pre-commit signature check to staged files" (2026-09-13,
commit `6ad8a043b`), two corrections landed mid-session, both from the user:

**1. Corpus membership must be checked against the real resolver, never
approximated with a regex.** My first pass filtered staged files with a
loose heuristic (extension/prefix regex) to decide which ones "should" be
signed, then handed that list to `verify-p7-signatures`. The user caught it
immediately: `sourcecode.source_path_set_up`'s inclusion globs plus its
`!`-prefixed exclusion patterns (`test-fixtures`, `cfg/backup`, `c_src`,
`.pyc$`, etc.) are the only authoritative definition of "is this file part
of the signed corpus" — a hand-rolled regex will diverge from it (e.g. any
staged `.md` file anywhere matches `\.md$ + /`, but the real corpus only
covers specific subtrees like `data/md/**`, `read-me/**`). The fix: resolve
`<[sourcecode.source_path_set_up]>` and intersect the candidate list against
it as a hash lookup, never re-derive membership by pattern-matching the
candidate paths themselves.

**2. Prefer a `:keyword:` flag on the existing command over a new console
command.** I initially added a whole new `sourcecode.console.list-source-paths`
command to fetch the corpus for an external intersection. The user redirected:
`sourcecode.console.verify-p7-signatures` / `update-signatures` already parse
inline flags this way (`:verify-silent:`, `:repair-mode:`, `:workers=N:` —
regex-stripped from `$command_params` at the top of the file before the real
argument is parsed). Adding `:inlist:` alongside them keeps the intersection
logic server-side (single source of truth, no second process round-trip) and
matches the codebase's own established pattern for toggling a bulk command's
behavior. Deleted the standalone command once this was pointed out.

**How to apply:** any future scoping work on `sourcecode.console.*` (or
similar bulk-corpus commands) should (a) resolve membership via the real
`*_path_set_up`/`collect_file_list` call, never a hand-written regex, and
(b) look for the file's own `:name:`-flag parsing block before adding a new
console command — a keyword flag is very likely the idiomatic fit.

See also [[feedback-p7-cli-argv-and-console-command-gotchas]] for the CLI
invocation quirks hit while testing this (`-vq` positioning, space-joined
argv can't carry filenames with spaces).

**addendum, 2026-09-15 — a real incident from treating this module's
own non-recursive-by-default behavior as a bug.** `bin/Protocol-7`'s
`base.source.collect_file_list`, given a bare directory argument (e.g.
`data`, not `data/**`), deliberately scans ONLY that directory's
immediate files — the final loop calls `<[file.all_files]>->(
$absolute_path, \@all_files )` without the recursive flag, which is NOT
a bug: it's the conservative default for an unqualified directory name.
Genuine recursion is already a first-class, existing feature — a
trailing `/**` on the path (`data/**`) hits a completely different,
correctly-recursive branch a few lines up (`<[file.all_files]>->(
$base_path, qw| recursive | )`). I "fixed" the wrong branch instead of
using the existing one: patched the bare-directory loop to always force
recursion, which — combined with running the *unscoped* `sourcecode
update-signatures` variant instead of `:inlist:`-scoped — caused a
live run to attempt signing 18,984 files, including vendored dependency
configs (`cfg/zenki/*/deps/**`) never meant to be part of the signed
corpus, and hit a fatal `pathspec ... is beyond a symbolic link` error
partway through. Caught live by the user, fully reverted (confirmed
`git diff` clean against HEAD) before anything landed.

**the correct, already-safe way to get "sign everything actually in the
corpus under these directories, recursively" is a combination already
built for exactly this**: `:inlist: cfg/** data/** read-me/**` — the
`/**` suffix gives real recursion (the existing, correct mechanism,
confirmed by reading the wildcard-handling branch directly, not
assumed), and `:inlist:` intersects the result against
`sourcecode.source_path_set_up`'s authoritative corpus, so even a
recursive glob that happens to reach a vendored/excluded path can't get
a signature appended for nothing. Neither half alone is enough: `/**`
without `:inlist:` has no corpus safety net (the same over-broad-touch
risk this incident hit); `:inlist:` without `/**` has nothing to
recurse into and correctly reports "nothing to sign" if it's the only
thing given. **How to apply**: before changing `collect_file_list`'s
directory-matching behavior again, or before running a broad signing
pass, use the `/** + :inlist:` combination above rather than a bare
directory name — and if a shallow-vs-deep default genuinely needs
changing, that's a considered API/behavior-change decision for the
project owner, not a "fix" to apply confidently mid-session on a first
read of the code.

#,,.,,...,.,.,..,,..,,.,.,,.,,,,,,..,,,,.,,,.,..,,...,...,,,.,,..,...,.,,,..,,
#CDXMEE4HZHLW333JURLP3OG7GMNVVZRIPPT5USSP3ZBD7SDHWM7IAGB53WOQB4HEQCT4NUQXI4QJG
#\\\|KV7HIC6UPZWWXNM5TWCJ7XI3TL3XGUGP6W6IMQZ26PEWCRGR27B \ / AMOS7 \ YOURUM ::
#\[7]2NS2TFZGWJYD4AWTAWZTEUWY5S36ELNPTJIGMLERN6DB2LDDWADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
