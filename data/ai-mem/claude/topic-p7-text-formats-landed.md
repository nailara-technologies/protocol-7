---
name: topic-p7-text-formats-landed
description: "format.kv_block + format.inline-nested serialization formats landed and validated; show-access consolidated onto inline-nested; YAML-config-codegen and reverse P7<->Perl translation still open"
metadata:
  type: project
---

**Landed 2026-07-23/24**, a multi-session arc starting from "devmod.cmd.eval-code
should accept p7 syntax, not just perl" and expanding into a general
key-value text serialization effort.

## What shipped

- **`base.syntax.translate`** (`bin/Protocol-7`): the `<[...]>`/`<data.key>`
  regex chain used by the module loader, extracted into a standalone
  `p7_syntax__translate` sub, auto-exported via the existing
  `p7_import_main_subroutines` convention. `devmod.cmd.eval-code` now runs
  input through it before `eval`, so it accepts p7 syntax, not just pure perl.
  Only the forward (p7→perl) direction; reverse (perl→p7) is NOT built.

- **`format.kv_block.encode`/`.decode`**: row-format serializer (`:  key  :
  value` rows, blank-line paragraph breaks, hybrid wrapped-vs-free-format
  paragraph reconstruction). Built by Kimi K3, verified independently.
  **Retired but kept** (2026-07-24): its only consumer (`show-access-kv`,
  a comparison prototype) was removed once `inline-nested` proved superior.
  Deliberately NOT deleted — matches the "collect formats until the right
  one crystallizes from usage" philosophy the user stated explicitly. If
  revived for a real use case, the `kv_` name prefix should probably be
  renamed first (it's just short for "key-value", never settled as final).

- **`format.inline-nested.encode`/`.decode`**: the format that won. Each
  entry is framed by a lone `.` (opening) and a trailing `:` (closing),
  positioned at a fixed column — robust against blank-line loss in a way
  `kv_block` isn't (kv_block only disambiguates rows via a key-charset
  regex at a known column; inline-nested has a structural, content-independent
  boundary marker). Supports a bare/standalone leaf form and an
  inline-wrapped form (`.:[ title ]:.` header / `:.` footer, reusing the
  existing inline-subs DATA-block convention verbatim) for nesting inside
  other blocks. Header/title accepts either a strict dot-path (machine key)
  or free-form text (human title/alias, e.g. `"cube zenka access permission
  set-up"`) — disambiguated purely by charset, greedy-regex-safe against
  titles containing the literal closing delimiter. `pad_lines` opt-in
  (default off) adds the SIZE-reply leading/trailing blank-line convention;
  deliberately NOT baked in unconditionally since blocks nest and unconditional
  padding would leak terminal-display formatting into embedded content.
  **Promoted to `base.*` namespace** (`base.format.inline-nested.*` +
  `base.format.inline-nested.pre_init` calling `base.swap_subs`) so every
  zenka gets it by default without an explicit `modules.load` entry — see
  [[feedback-base-swap-subs-promote-pattern]].

- **Container framing convention, worked out via the inline-subs
  precedent**: a block's closing `:.` footer is preceded by an unconditional
  blank `:` line acting as a "trailer boundary" marker (empty trailer =
  none defined yet, matching the checksum/size trailer the DATA-block
  convention already uses for a *different* purpose) — this is INDEPENDENT
  of each entry's own opening-`.`/closing-`:` framing, not a merge of the
  two. Discovered via three rounds of "is this the same thing or two things"
  with the user; got it wrong twice before landing on: yes, two independent
  concerns, both present.

- **`show-access` consolidated**: the original hand-formatted `base.cmd.show-access`
  now emits `format.inline-nested` directly (dynamic title: zenka name for
  the full listing, queried user for the filtered view). `show-access-kv`
  and `show-access-nested` (both temporary/comparison commands) deleted.
  Verified against real live output multiple times (`show-access-nested v7`,
  `mpv`, `taeki`) including decode round-tripping actual captured terminal
  output, not just synthetic test data.

## Still open

- **YAML → agent/zenka config codegen**: not started. Original ask was
  "so zenki can write or rewrite configs from internal %data structures."
- **Reverse Perl → P7 syntax translation**: not started, only forward
  direction exists (`base.syntax.translate`).
- **Config-writer / comment-preserving parser**: extensive design discussion
  landed on: build a parser that classifies config lines as
  `{comment|blank|kv}` nodes (indent-preserving), patch only changed values
  from `%data` back through the existing node sequence so hand-authored
  comments survive a rewrite (verbatim in v1, no reformatting yet). Real
  fork identified via `access.users`: `%data` only ever holds *resolved*
  values (`taeki`), never the template form (`<admin-user>`) — reconstructing
  templates on serialize needs `base.access.special-user-map`'s own template
  list as the reverse-lookup source (NOT `show-access`'s ad-hoc `$special_users`
  scan, which is a broader/different set built for display annotation only).
  Explicitly scoped OUT: extending the same parser to Perl source code
  itself (a much bigger, separate problem) — that's `bin/format-code`'s
  territory, see [[topic-format-code-bugs-fixed]].

## Existing infra discovered along the way (don't rebuild)

`base.parser.config` (config lines → perl statement strings, recognizes
`.:[ description ]:.` as a title convention — unprompted validation that
inline-nested's header syntax fits the project's existing grain),
`base.load_section_code`/`base.parse_ncfg_code` (`.: section :.` hierarchical
grammar — visually similar to but syntactically distinct from inline-nested's
`.:[ name ]:.`, no collision), `base.execute_zenka_code` (evals the parsed
statements). No existing config *writer* — confirmed by grep, same pattern
as the earlier YAML-codegen check (nothing existed there either).

## related

[[feedback-base-swap-subs-promote-pattern]] · [[topic-format-code-bugs-fixed]]

#,,,.,.,,,..,,.,.,,,.,,..,,,.,.,.,..,,,..,,,.,..,,...,...,..,,...,,,.,.,,,..,,
#BMXE223Q7DH5D2BUWJQ7PLTJ5X2H46Z3EZMA4MWPNQWAEUQSLVVBE46RJ2RRSRJMWFWQOC5YKMRBE
#\\\|KJFPYE7OLHRBMZW5E5KIAKJCDQBHJWJNDREUNNLTNT54HMVFSAQ \ / AMOS7 \ YOURUM ::
#\[7]VG6QW4OAE6U547EG3A2EBKHIGYBZVF2JDJFW6JZ2IXCP7MVABMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
