## [:< ##

# name  = task: sourcecode.console.match-files -- dry-run file-matching preview
# descr = built and verified 2026-09-15 as a direct response to a real
#         incident: a hasty, untested change to file-matching logic
#         combined with a live signing run attempted to sign 18984 files
#         including vendored dependency configs, hit a fatal error, had
#         to be fully reverted. this tool exists so future match-logic
#         changes can be developed and checked fully dry first.

## what it is

`src/sourcecode.console.match-files` -- accepts the exact same
parameters as `update-signatures`/`verify-p7-signatures` (a bare file/
directory list, `path/**` for recursive, `:inlist:` to intersect against
the authoritative signed corpus), and does nothing but print the
resulting file list and a match count. No signing key loaded, no
signature verification, no writes, no git operations beyond whatever
`collect_file_list`/`sourcecode.source_path_set_up` already do
internally for their own matching (see the companion bug this safely
found: `data/tasks/collect-file-list-symlink-gitignore-crash.md`).

Registered in `cfg/zenki/sourcecode/subroutines.load-early` via
`bin/dev/gen-sub-whitelist sourcecode`. Invoke as:

```
bin/Protocol-7 sourcecode match-files <params> -q
bin/Protocol-7 sourcecode match-files ":inlist: data/**" -q
```

**deliberately NOT a refactor.** `update-signatures` and `verify-p7-
signatures` duplicate this matching-logic block almost verbatim (parse
`:inlist:`, call `collect_file_list`, optionally intersect against the
corpus, report a count) -- extracting that into one shared resolver both
they and `match-files` call would be the cleaner long-term design, but
was deliberately skipped this session: touching the two existing,
working, tested signing/verify tools felt like the wrong move
immediately after a real mistake on adjacent code. `match-files` is a
fully independent, additive-only file so it carries zero risk to either
existing tool. Revisit the extraction later, once there's been time to
build back confidence -- not blocking, just sequenced conservatively.

## verified, 2026-09-15

- `data/tasks` (bare, flat dir): 106 files, matches `find -maxdepth 1
  -type f` exactly.
- `data` (bare, dir with only a dotfile directly in it): correctly 0 --
  `collect_file_list`'s own `!m{/\.|~$}` exclusion drops the dotfile,
  confirming bare-directory shallow-scan is the genuine, faithfully-
  reproduced existing behavior (not a bug -- see the corrected memory
  note referenced above for the full account of nearly "fixing" this).
- `data/**` (recursive): ~13400 files, matches a live recursive `find`
  within the small margin expected from this being an actively-churning
  repo (background kimi dispatch processes writing/cleaning
  `data/state/*.out` files between the two scans, confirmed by diffing
  the exact mismatched entries -- not a tool bug).
- `:inlist: data` (shallow + corpus filter): correctly "no matches" (0
  shallow candidates to begin with).
- `:inlist: data/**` (deep + corpus filter, the actually-useful safe
  combo): ~7929 files -- a large, real drop from the raw ~13400,
  demonstrating the corpus filter does substantial, meaningful work.
- `:inlist: cfg/** data/** read-me/**` (the exact combo that would
  answer the original "safely sign everything actually in the corpus
  under these three trees" ask): reproduces the fatal symlink error from
  `collect-file-list-symlink-gitignore-crash.md` -- found safely, zero
  side effects, immediately actionable as its own separate task.

## status

Tool itself is done and working. The recursion-by-default UX
improvement the user originally asked about (`us data` behaving like
`us :inlist: data/**` without needing to spell out `:inlist:`+`/**`
every time) is NOT implemented -- deliberately parked pending a decision
on where it should live (caller-side auto-append of `/**` in the
`sourcecode.console.*` commands specifically, not a `collect_file_list`
default change -- a global default change was checked and found to
affect at least one other real caller, `protocol.protocol-7.protocol-
version-path-set-up`, which relies on the current shallow default for a
bare directory entry in its own path list). `match-files` is exactly the
tool to develop and verify that change against once it's scoped, without
any risk of repeating tonight's incident.

#,,,,,...,,..,..,,,.,,...,..,,...,...,,,,,...,..,,...,...,.,.,,..,.,.,.,.,,..,
#BWNNY2QXJTPW6QIJFXTFONGH25I67JXLTG6GR2J2XSUNURLWWH5WY3QWVOZUJFXVWKCIWVICBBACY
#\\\|IHOZA3UASOAXTBIIZAICEP7GFQRM65CGRVHOBTUDLHZWTFE7P4U \ / AMOS7 \ YOURUM ::
#\[7]QNXNY5DUSETBYHMSQIVEU57GMXYF2UDCYE5XV4UACKSJ2LJXTAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
