---
name: list return format for tool backends
description: tool backends returning lists must use mode 'size' with pre-formatted string, not mode 'true' with arrayref
type: feedback
---

List-type tool backends must return `{ mode => 'size', data => $formatted_string }`, NOT `{ mode => 'true', data => \@arrayref }`.

**Why:** The dispatch layer (`coding.tools.dispatch`) serializes arrayrefs to JSON via `JSON::PP->encode`, which produces ugly machine-readable output instead of clean human-readable text. The model sees formatted strings much better. Also, `base.sort` is just a simple string sort — use plain Perl `sort { ... }` for structured data.

**How to apply:** When writing any backend that returns a list of items, format them as a multiline string (one entry per line with `sprintf`) and return with mode `size`. Reserve mode `true` with hashref/arrayref data for structured results that need machine parsing (e.g., `note.tag` returning `{ added => [...], all => [...] }`).

#,,,.,,,,,...,,.,,,,,,..,,,,,,.,,,...,,,,,...,..,,...,...,...,.,.,...,...,..,,
#O5YI6LTEJ3MMPTD5BI3473K5SXTM365XNRN3KTI62BWLQLDWOV55VA5ZNZDP3223YEBI7CX67ZJEE
#\\\|C2YJ2VHMKOXMNEXCO6OXHC44BKQUYM2QOS464OY4JTWDENKZRML \ / AMOS7 \ YOURUM ::
#\[7]G6V5TSTWWOTDYJOMK4BFWQNVOBYUMYULSWD6OA6JDFLLJT6ODGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
