---
name: sourcecode-signature-corpus-scoping
description: when scoping a sourcecode.console.* signing/verify command to a caller-given file list, intersect against the authoritative sourcecode.source_path_set_up corpus, never a regex approximation of it; and add a :keyword: flag to the existing command rather than a new console command
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

#,,..,,,,,.,.,,.,,...,.,.,,,,,.,.,,,.,...,...,..,,...,...,.,.,.,,,,,.,,,.,..,,
#MSDLSEC7UJNIZ5FP4ODHPT4JXJHBDNQDSNFBXVZ7QQVHZJ5BTHDZ6CZQLTXLGURN5DM6W4NM4EOBI
#\\\|XYFK7MOV3CNA2TBTCHFQUJMKUSCFFONIK5DK2LOTA32MIZ5GJGP \ / AMOS7 \ YOURUM ::
#\[7]V4ZANK2BMGGWVHHQ6MLYI4KKT2737IN6LXFIL5FD4GWN4NVRHUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
