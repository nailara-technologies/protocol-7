# repo pii leak prevention [ from data/md/design/REPO-PII-LEAK-PREVENTION.md ]

catch personal \ sensitive data before it enters git history, audit the
history for what is already there, and check outbound dispatch payloads.
read `CLAUDE.md` and the design file [ its nine leak vectors ] first.

**this file, its commit message and every finding report must name
CATEGORIES only -- never a real name, domain, address or filename that
embeds one [ design vector 8 ].**

## what exists [ 2026-09-30 ]

- hooks are repo-tracked : `core.hooksPath = bin/dev/git-hooks`
  - `pre-commit` : version + signature checks [ Git::Wrapper ]
  - `commit-msg` : already filters patterns out of the message
    [ `@filter_patterns`, l.34 ] -- the place for vector 4
  - `post-checkout` : permission normalizing
- the rule "patterns live OUTSIDE the repo" : `/data/<project>-data/` or
  the user's `~/.7/` [ see memory feedback-no-personal-data-in-repo-tree ]
- outbound dispatch : `bin/mcp-server-p7` [ `tool_external_command`,
  kimi_* \ claude_* ] -- the one place vector 9 can be checked

## phase 1 : check, do not block [ report only ]

1. pattern file outside the repo [ path from config or env, absent =
   check skipped with one warning, never a failure ] ; format : one
   regex per line, categories as comments
2. `pre-commit` : scan the STAGED DIFF [ added lines, not whole files ] +
   added \ renamed PATHS against the patterns ; report category + file +
   line, never echo the matched text in full
3. `commit-msg` : the same scan on the message [ vector 4, both
   directions -- a removal commit narrating what it removed ]
4. tag messages [ vector 5 ] : a `bin/dev` audit command, not a hook

## phase 2 : history audit [ read-only tool ]

`bin/dev/pii-audit` : walks all commits [ messages, paths, blobs of the
added lines ], all tags, with the external pattern file ; output
categories + commit ids + paths only. rewriting history is the USER's
decision [ destructive, affects every clone ] -- the tool never does it.

status [ 2026-10-13 ] : built, `bin/dev/pii-audit`. pattern file default
`/etc/protocol-7/pii-audit/patterns` [ -p \ $P7_PII_PATTERNS override ], warns
when readable by others ; `# category` lines group the regexes below
them. matches inside reported paths \ tag names are masked `[..]`, regex
errors name the line number only. tested on a throwaway repo with
manufactured data ; full history [ 10018 commits, 132 tags ] ~40 s.
exit 0 clean \ skipped, 1 findings, 2 error.

## phase 3 : dispatch payload check

in `bin/mcp-server-p7` before a kimi_* \ claude_* prompt leaves : the same
pattern scan ; on a match refuse with the category, the caller rewords.
config switch to disable.

## after phase 1 has run clean for a while

make the pre-commit scan blocking [ user's decision ], with an explicit
per-commit override that is itself logged.

## open for the user

pattern file location, which categories [ names, phone \ address shapes,
private domains, assessment-file markers ], blocking or report-only,
whether a local-model second pass [ coding zenka ] is wanted.

#,,..,...,...,.,,,.,.,,,.,,..,,.,,.,.,...,,,.,.,.,...,...,.,,,...,,,.,..,,,..,
#GK7BPDETPAJTXDP2OJXC2O7BQD64B2CTI6RW7UYKI4655OQUJEE3L6GEKM7N3BQMNDJBVUUOOHF4K
#\\\|OVKKNAYHM2BZTO3LCUQ4IQBOCLSDOPJ6E6NGO7SOTH74A5EAGZG \ / AMOS7 \ YOURUM ::
#\[7]BOJTRNOSGQHNGBCFKOTD7UCJZA24EGFLIJTJXTOOAJZ3TT4QV2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
