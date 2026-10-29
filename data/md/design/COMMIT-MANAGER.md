# COMMIT-MANAGER

a commit as a requirement chain : which steps a change needs is derived
from the changed files, the steps run in their dependency order, signing
goes through p7-sign-agent with ONE approval, and the commit message is
prepared while the working session is still warm.

status : design [ 2026-10-29 ], from the HX4 follow-up session. builds on
`work.console.commit` [ "LLM-friendly commit with auto-signing" ] -- extend
or retire it, never run both.

## why

one session [ 2026-10-29 ] hit every manual gap at least once :

- four `AMOS7::deps::*` `$VERSION` lines stale since earlier sessions
- `update-version` rewrote `cfg/protocol-7.src-ver` without its footer -- the
  pre-commit hook refused the commit, a second approval was needed
- format-code was not part of the `:agent:` path at all : a reformat after
  RUN makes the agent refuse the file [ `content changed` ]
- the sign run stages EVERY modified signed file [ also unreviewed agent
  edits ]
- the final message needs the session that did the work ; after a cache
  time-out it has to be revived for one paragraph

## the chain

order is set by what each step READS and what it CHANGES :

| # | step | reads | changes | needed when |
|---|---|---|---|---|
| 1 | `format-code -c` then `-r` | sources | sources | any changed `src/*`, `bin/*` perl, `*.pm` |
| 2 | `update-amos-versions` | formatted module source | `$VERSION` lines | a changed `*.pm` |
| 3a | `dep-graph` | sources | `module-dependency-graph.asc` \ `.dot` \ `.txz` | module added \ deleted \ renamed, or a `<[call]>` edge changed |
| 3b | `update-sub-list` | `src/` file names | `src/base.list.subroutines` | module added \ deleted \ renamed [ git A \ D \ R ] -- content edits never |
| 3c | `gen-sub-whitelist <z>` | its own `dep-graph -list-subs -zenka=<z>` | `cfg/zenki/<z>/subroutines.load-early` | `<z>` in `affected-zenki` AND the regenerated list differs |
| 4 | `update-version [ amend \| reset ]` | the operation type | `cfg/protocol-7.src-ver`, read-me version files | every commit that changes content |
| 5 | sign [ `:agent:` ] | everything above | footers | one request : changed sources + regenerated lists + version files |
| 6 | commit | the prepared message | -- | `AMEND=1` for an amend |

1 aborts the chain on any error [ syntax, `[ perl 5.32 ]` floor ] and returns
the report to the CALLER at once -- a coding model sees the anomaly in its own
tool output, the user never gets a prompt for broken code. 3a \ 3b \ 3c are
independent of each other [ 3c calls dep-graph itself, per zenka ] and run in
parallel after 2.

## affected-zenki : the reverse lookup

forward views exist : `p7-sourcecode modules <zenka>` [ namespaces ],
`p7-sourcecode subroutine-list <zenka>` [ subs ]. the inverse :

- **`dep-graph -affected-zenki <sub|namespace>[,..]`** holds the logic. it
  builds the call graph from source, so new subs [ in no list yet ] resolve
  exactly : walk each zenka's `modules.load` closure once, invert, look up.
  one pass covers all zenki [ a `base.*` change touches all 128 ].
  standalone : works with every zenka down -- when a broken set-up needs it
  most.
- **`p7-sourcecode affected-zenki`** : a thin command over it, next to
  `modules` and `subroutine-list` [ p7c-reachable, for the commit manager and
  coding models ].
- the reverse of the stored `subroutines.load-early` lists stays a cheap
  cross-check [ is a stored list stale ? ], not the source of truth.

input from the staged change : a changed file's `<[call]>` set [ before vs
after, from the diff ] feeds its own sub ; an added \ deleted \ renamed module
feeds that sub ; a `zenka.v7` change names its zenka directly.

## operation types

the type decides the version number kind -- chosen at PREPARE, stored with the
prepared commit, shown in the approval prompt :

| operation | version | commit |
|---|---|---|
| new commit | `update-version` [ next ] | `git commit` |
| amend, content changed | `update-version amend` | `AMEND=1 git commit --amend` |
| amend, message only | none | `AMEND=1 git commit --amend` |
| undo a bump \ rebuild | `update-version reset` | as the follow-up needs |

so a stale `AMEND=1` in the environment can never turn a new commit into an
amend, and a new commit can never skip its version. the hook accepts `AMEND`,
`GIT_AMEND`, `PERSISTENT_AMEND` [ not '0' ].

## prepare \ approve

- **prepare** [ while the session is warm ] : the model that did the work
  hands in the message [ e.g. `commit.prepare-message` ]. stored with the
  operation type and a checksum of the staged diff.
- **approve** [ any time later ] : the p7-sign-agent prompt
  [ `AMOS7::TERM::confirm_key` : y \ n \ d, a denial reason ] shows the type,
  the version it will get and the message. `d` pages the diff.
- **stale message** : the staged checksum changed since prepare -> marked
  stale, redrafted by a local model or a short kimi dispatch from the diff and
  the old message. no session revival.
- message checks enforced by the tool, not the model : the `vc_commit` length
  and harmony rules, no attribution lines [ the hook strips them anyway ], a
  signed version per commit, and the hook's message FORM [ 'area : short
  topic title', a single line at most 100 chars, details in a body of
  '- ' lines wrapped at ~75 -- AI-COLLABORATION-GUIDE.md ] checked at
  prepare, so a rejected form never reaches the commit step.

## output

- quiet by default : `update-signatures` is silent since 2026-10-29
  [ `:verbose:` \ `SIGN_VERBOSE` for the octal iteration lines ]
- after approval the agent clears the screen and shows the bin/format-code
  file progress bar per SIGN, until END, then a summary [ next round ]

## related

- `data/md/design/VAULT-AGENT-SIGNING.md` -- the agent, todo HX4
- `data/md/design/VERSION-BRANCHES.md` -- re-signing as the hand-over gate
- `src/work.console.commit`, `src/work.parent.fix_signatures`
- `bin/admin/vc_commit` -- message length \ harmony gate
- `bin/dev/git-hooks/pre-commit` -- permissions, version files, signature check

#,,,,,...,,..,,.,,,,,,,.,,,.,,,,.,...,.,,,...,..,,...,...,,,,,,..,,..,,,.,,.,,
#ORBIKFPNRQCF26B67RAWNMVW6T6D3A3DLWCD3BSLAWDH6542GA2N67HPFWK6BCA3RAJB7YKECY7YE
#\\\|FZHERIGXE5P2UPHKTN2PCJEDDYECKN6KUYSAD35LIL6RE7RCDKT \ / AMOS7 \ YOURUM ::
#\[7]CAP77PQH3GLQIIOCBRDAFNQZOI4FKF37QCYVR5UIRQPZEYMTCSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
