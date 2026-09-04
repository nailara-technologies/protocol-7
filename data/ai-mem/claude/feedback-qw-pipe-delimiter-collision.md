---
name: feedback-qw-pipe-delimiter-collision
description: qw| foo|bar | is a syntax error when the list element itself contains a literal pipe (e.g. Getopt::Long's 'options|h' alias syntax) -- the embedded | is parsed as qw's own closing delimiter; switch to qw{ } or qw[ ] for that one element
metadata:
  type: feedback
---

This codebase defaults to `qw| ... |` almost everywhere (option hashes,
GetOptions lists, word lists in general — see `CODE-STYLE-AND-LLM-INTEGRATION.md`
conventions). That's fine as long as no element contains a literal `|`
character. It breaks silently-confusingly when one does: writing a
Getopt::Long alias like `qw| options|h | => sub {...}` is NOT "the
word `options|h`" — Perl reads `qw|` as opening with `|` as the
delimiter, then hits the embedded `|` in `options|h` and treats THAT
as the closing delimiter, leaving `h |` dangling as bare code and
producing a confusing `Bareword found where operator expected` syntax
error nowhere near the real cause.

**How to apply:** when a `qw` list element needs to contain a literal
`|` (Getopt::Long `long|short` alias forms are the common case), use a
bracketing delimiter for just that element — `qw{ options|h }` or
`qw[ options|h ]` — instead of a plain quoted string, which was the
user's suggested style once the `qw| |` collision was pointed out
(2026-09-04, `bin/dev/md-link-tree`). Keep `qw| |` for every other
element in the same list; only the pipe-containing one needs a
different delimiter.

#,,,.,.,.,,.,,.,.,,,.,,.,,,,,,...,..,,.,.,..,,..,,...,...,..,,.,.,.,,,.,.,,.,,
#YI5LU5VC6HOUUO7MKQVXNNDORWOBWG4MQVYH7DF5M3GT4JYASQ5PWZLEHJ3MT7B4UMAM3I346GKQ6
#\\\|O3AAYDP4H5HP3NVAYZGW756RDU2HBCML4DDTRISDP6FUNB6UAZG \ / AMOS7 \ YOURUM ::
#\[7]HDPRO44IB774MIOSQHQPNTT6AXVITTMHS2LYMQJ5PFUKOBCHZABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
