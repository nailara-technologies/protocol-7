---
name: list return format for tool backends
description: tool backends returning lists must use mode 'size' with pre-formatted string, not mode 'true' with arrayref
type: feedback
originSessionId: 6538e52c-796d-4a00-bc99-63699ca261f0
---
List-type tool backends must return `{ mode => 'size', data => $formatted_string }`, NOT `{ mode => 'true', data => \@arrayref }`.

**Why:** The dispatch layer (`coding.tools.dispatch`) serializes arrayrefs to JSON via `JSON::PP->encode`, which produces ugly machine-readable output instead of clean human-readable text. The model sees formatted strings much better. Also, `base.sort` is just a simple string sort — use plain Perl `sort { ... }` for structured data.

**mode 'true' vs 'size':** Use `mode => 'true'` for single-line results (no newlines). Use `mode => 'size'` for multi-line output — the dispatch layer uses the string length as the content-length header. Mixing them up causes truncated or garbled output.

**How to apply:** When writing any backend that returns a list of items, format them as a multiline string (one entry per line with `sprintf`) and return with mode `size`. Single-line results (a greeting, an id, a status) use mode `true`. Reserve mode `true` with hashref/arrayref data for structured results that need machine parsing (e.g., `note.tag` returning `{ added => [...], all => [...] }`).

**Repeat-offense note, 2026-08-22**: wrote 7 new `.cmd.` confirmation
commands in one session (`plan9-connect`/`create`/`remove`/`rename`/
`resize`/`write-file`, `export-directory`) all with this exact bug —
single-line "created X" / "renamed X to Y" style messages using
`mode => 'size'` plus a manually-appended trailing `\n`, when every
one of them should have been `mode => 'true'` with no trailing
newline. This memory already documented the rule correctly; the miss
wasn't a knowledge gap, it was not actively checking a new `.cmd.`
reply against it before moving on. Also: this codebase's user-facing
reply strings are lowercase-leading (matching the same narrative-flow
convention CLAUDE.md documents for comments) — "created X", not
"Created X". **How to apply, reinforced**: before finishing any new
`.cmd.` file, explicitly ask "is this reply single-line or
multi-line?" and check the mode matches — don't let a habit of
copying the shape of the most recently written sibling command
propagate the same mistake forward (all 7 here were copy-pasted from
each other in sequence).

#,,,.,..,,,,.,,,.,,,.,,.,,,,,,,,.,,,.,,,.,,,,,..,,...,...,..,,.,,,.,,,...,...,
#I6DINMZS3GM4ML67MUW5X6Y32C7OWLRW4JFBYJTU2PHP7ZH7TFRA5MHCNMDK4TD2ZB4UWSTMKWUTK
#\\\|GFZKBN3DWR5PS5E77QKXRW7MGDEFF33NC5TZWFT6EZ6E4AR7HQQ \ / AMOS7 \ YOURUM ::
#\[7]RFJSGM6E3QKIFYCTMYBJOLYCLQNR7XSAKIFSGIVFIHNIKYBVAQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
