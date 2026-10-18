---
name: feedback-single-dash-long-options
description: new command-line options of our own use the single-dash long form [ -dry-run, -write ], never the GNU double dash
metadata:
  type: feedback
---

new options of protocol-7's own tools take ONE dash even when long :
`-dry-run`, `-write <name>`, `-keep`, `-remove` -- never `--dry-run`.
[ user, 2026-10-18 : "the long -- form is avoided for new options of our
own" ]. existing double-dash options [ e.g. p7-deps --no-cache, --help ]
are not renamed silently -- ask first, see
[[changed-established-behavior-silently]].

**Why:** the house form for the project's own tools ; kimi and cloud
sessions default to the GNU style and drifted twice in one day
[ detect-hw --write, the N7FS --dry-run \ --keep \ --remove ].

**How to apply:** say it explicitly in every dispatch brief that adds
options, and check new option names in the review before committing.

#,,,.,,.,,.,,,.,.,.,,,..,,,,.,,.,,,.,,.,,,..,,..,,...,..,,.,,,,.,,..,,,..,,..,
#DO6HL5Q6OQQ3RILHZSUJY6V5WWFTTFPWNQ5XH4YIKD4W5AGKMXPBX5WOFQMGC5DKM464OHBQKBPVS
#\\\|3EQ64ALICXPCH73HI7RA3WGRAEGGO6XZCJ2AW5UNOXDDXTC4VD2 \ / AMOS7 \ YOURUM ::
#\[7]NLAIF2JXOXLBZMIQ4NVCEDZ3KMV3HSTI3Q7TLKKH5PFSD7TAKACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
