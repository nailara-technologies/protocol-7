---
name: feedback-file-stat-object-override
description: the coding zenka's process has stat() overridden to File::stat's object-returning form globally -- (stat $x)[N] silently returns undef instead of erroring, always use scalar-context stat()->mtime/size/etc.
metadata:
  type: feedback
---

Found 2026-09-14 building `coding.cmd.list-backups`: `( stat $full )[9]` (the
plain list-index idiom for mtime) silently returned `undef` for every entry,
sorting the "recent backups" list into effectively readdir-order instead of
by actual mtime. Confirmed live via `coding.eval-code`: in the coding zenka's
process, `stat` returns a 1-element list containing a `File::stat` object
(`ref($s[0]) eq 'File::stat'`), not the normal 13-element array — so
`(stat $x)[9]` indexes into a 1-element list and gets `undef`, no error, no
warning.

**Why:** this is a deliberate project convention, not an accident or bug to
route around. The user's correction, live: "we are using File::stat
usually, is there a need for CORE::stat specifically?" — confirmed the
override is intentional house style (matches `coding.init_code`'s own
`File::stat::stat(...)` calls), not something to bypass with `CORE::stat`.

**How to apply:** in this codebase, always call `stat()` in scalar context
and use the object's methods (`->mtime`, `->size`, `->mode`, etc.), never
the classic `(stat $x)[N]` list-index idiom — it compiles and runs with no
error, just silently returns `undef` for every field, which is worse than a
crash because it can drift for a long time (as it did here) before anyone
notices the derived value — sort order, in this case — is subtly wrong.
Fix pattern: `my $st = stat($path); my $mtime = defined $st ? $st->mtime : 0;`

#,,,,,..,,...,..,,,,,,.,,,..,,.,.,.,,,,,.,.,,,..,,...,...,.,,,.,,,,,,,,,.,.,.,
#D4BWVW66UYOEEPC4CA7I5PE4XDIOSYC4ATTIHN7AMXINHARTUIZTHI4RZ7YTWC52DVZZGFTXMV24S
#\\\|MNOJ37TOTIVAFLLOO6RPMPC37RNDA66ZW3X6QFNQEVCSIQNPDIN \ / AMOS7 \ YOURUM ::
#\[7]CENQ7DUVVLKREW35HKKDKNVX4Z5U6XIKISPD7HURNXMXJ6TWOADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
