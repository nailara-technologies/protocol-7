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

#,,,.,.,,,,..,,,.,...,,,.,..,,...,.,,,,.,,..,,..,,...,...,.,.,.,.,...,...,..,,
#3B6EWZHYMIRTTAE5TKV4UJQDSYDBZGGBFKEZI27QXTIWGXCXK2WBLMOT3SZ4CHUABBDX33EL36YOS
#\\\|BF5OMFDJMCRNS7ZMSNEHEN7U437R4Y7TWNE5RGJHMMTY63DE7DH \ / AMOS7 \ YOURUM ::
#\[7]MBDT4OQZIWR3FW2DUHMQ6MGLQEVIVIYPCYFIIXZDOTVFT3RJTSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
