---
name: project-ncfg-parser-known-limitations
description: base.parser.config / base.extract_values / the mpv.dump debug view all do naive unescaped dot-splitting on config key names; dump output was meant to be re-importable but currently has irreversible compactions
metadata: 
  node_type: memory
  type: project
  originSessionId: ac11470d-39ce-43c4-b6a1-2a8f6b20ef2d
  modified: 2026-08-01T01:44:14.761Z
---

Protocol-7's ncfg-style config parsing has a long-standing, known gap: at least three separate
parser code paths independently do a blind `s|\.|'}{'|g` (or equivalent) on a directive's key
name to build nested hash levels, with no escape or quote support for a literal `.` in a key:

- `base.parser.config` (used by `v7.init_start_setup` to load `zenka-startup.v7` files)
- `base.extract_values` (used by `base.reload_values` / a zenka's own `start`-file / `.reload config`)
- whatever backs the `mpv.dump`/`mpv.set`/`mpv.get` devmod tree commands

A `\.`-escaped dot in a config-file key does NOT survive as one literal-dot key — confirmed by
direct testing (2026-08-01): a double-backslash-dot in a config line collapses through Perl's
own single-quote string escaping inside the generated `eval` string, producing two separate
nested hash levels (e.g. `{'an\'}{'other'}`) that happen to *display* identically to an escaped
single key when `dump` rejoins segments with `.`. The only way to actually get a literal dot
into a hash key is direct Perl code (hash-key assignment, e.g. in a `*.post_init` module),
bypassing the text parser entirely.

Separately: `mpv.dump`'s human-readable debug view has "irreversible compactions" — the user's
words — even though the *original design intent* (per source history, first `base.cmd.get` /
`net.get` commits are from Oct 2012) was for dump output to be safely re-importable by a zenka.
That round-trip property was never actually achieved and has been a known, mildly annoying gap
for over a decade. The read/display side did get one real fix in that window, though: commit
090ce7ee5 (2014-11-21, "refined 'dump' output to show a difference on keys containing '.'s")
made `dump` reliably distinguish a literal-dot key (quoted, e.g. `'a.n.o.t.h.e.r'`) from ordinary
nested-hash dot-joining — confirmed still accurate today (2026-08-01) and used as the reliability
check that debunked the `\.`-escaping hypothesis above. So `dump`'s *read* side has been trustworthy
for ~12 years; only the *write*/import side (config-file key parsing) was never brought up to match.

**Why:** the parser's simplicity was "once a feature" (intentionally minimal, expansion deferred
until actually needed — same philosophy as the agent config's deliberately-simple scope/condition/
loop-free syntax), but the user is bothered that these specific shortcomings (unescaped dot-split,
non-reimportable dump) are still unaddressed 14 years later.

**How to apply:** when a task needs a config key or value that might contain a literal dot, do not
assume `\.` escaping works — it doesn't, verified directly. Prefer storing such data in a *value*
(free-form string), never a dot-delimited key path, unless going through direct code/hash
assignment. If the user ever wants to tackle the parser itself, it's a real, scoped, and overdue
piece of work — not scope creep to suggest, just don't bundle it into unrelated fixes without
being asked (see [[topic-mpv-x11-dependency-cascade-restart]] for a case where this exact
constraint shaped a design decision instead of triggering a parser rewrite).

#,,,,,,..,,..,.,,,...,.,.,,.,,,,,,...,,..,,..,..,,...,...,.,.,..,,,,.,...,,.,,
#4SVZARFMFK2EOA722K3GOROTBRHM2XOOTTREV4DZUAP2XV3ZKEHKQLURSAF5H34REWIWI47HJJOMW
#\\\|MKVDR4EPACIUCQRQY52CW6OLM67ALTEC5JCX5BXQWGOGJAJS2AZ \ / AMOS7 \ YOURUM ::
#\[7]INA75MMWZ7XQDKDH7BI4U6AAESCZAGGVSKI26ZGEUTUHTCYE32AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
