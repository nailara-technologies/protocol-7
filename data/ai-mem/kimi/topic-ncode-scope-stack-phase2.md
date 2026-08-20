# ncode pattern-learning phase 2 — namespace scope-stack (2026-07-30)

Implemented data/tasks/ncode-pattern-scope-stack-phase2.md in full, live-verified via p7c.

## landed

- **part 0**: `modules/ncode.regex.apply` — `llm-required` status gate before the
  confidence check (flagged `requires_review`, `stats.skipped++`, never auto-applied
  regardless of confidence vs `auto_apply_threshold`).
- new helpers `modules/ncode.util.scope_match` (active-glob matching: `*` all,
  `foo.*` stem-or-below, plain = prefix, legacy `applicability.namespace` =
  one-entry stack, empty target ns never matches a scoped pattern) and
  `modules/ncode.util.file_to_namespace` (path → dot-notation, strips up to
  `modules/` + real source extension; braces delimiter — perltidy misparses
  `s|..(?:pl|pm|t)..||` with pipes inside pipe delimiters).
- `ncode.regex.apply` + `ncode.cmd.apply` both gate via scope_match; cmd.apply
  derives target ns from `$fix->{'file'}`, out-of-scope = skipped (not applied,
  not failed), own `out_of_scope_count` in summary, no stats touched.
- `ncode.regex.assess` builds scope stack from `context.namespace`
  (exact → widen-by-stripping → `*`), `scope_active_idx: 0`; absent ns = no scope key.
- `process_candidate` carries `scope`/`scope_active_idx` into the stored record.
- new `modules/ncode.cmd.widen-scope` (graduate adapter shape): confirm required,
  re-checks live streak (`ncode.cfg.review_streak_needed`), idx+1, **streak reset
  to 0**, status untouched, base.logs level 1.
- config: `widen-scope` added to `cfg/zenki/ncode/start`
  access.cmd.usr.cube; `gen-sub-whitelist ncode` + `gen-sub-whitelist coding`
  (coding loads ncode as a library — the two util subs are required there).
  Both whitelists unsigned, operator re-signs.

## verification method notes [ reusable ]

- `ncode.regex.apply` is NOT p7c-reachable in the ncode zenka; drive it inside
  the **coding zenka** via `p7c coding.eval-code` (coding access-lists
  exec-sub/eval-code and loads ncode as a library; needs `coding.reload source`
  + whitelist regen to pick up new ncode modules). eval-code accepts p7 syntax,
  returns string — wrap results in `JSON::PP::encode_json`.
- `p7c ncode.expand`/`pattern-review` return hashrefs that display as
  `REF(0x...)` (known pre-existing display bug) — verify behaviorally, not from
  the return rendering.
- `ncode.reload source` did NOT pick up the new cmd module; `p7c v7.stop ncode`
  (on-demand respawn) did. Same lesson as the chmod-child incident.
- `p7c v7.devmod-enable ncode` loads devmod fine, but eval-code still needs an
  access-list entry — not granted for ncode, deliberately not added.
- cmd.apply end-to-end used scratch targets under `/tmp/.../modules/` (path only
  needs a `modules/` component for ns derivation — no repo pollution), 0664
  taeki:taeki so the dropped-priv zenka group-writes; full steps→ptd-c→chmod-child
  write path exercised.

## side effects to note at commit time

zenka start/reload re-harmonized signatures: `cfg/protocol-7.src-ver`,
`read-me/md/README.md`, `read-me/project-identity/source-code-versions.md`,
plus auto-registered untracked `cfg/zenki/ncode/pm-dep/*` — system
automation, not manual edits. `data/ai-mem/claude/*` was dirty from elsewhere.

#,,,.,.,.,..,,..,,.,.,.,,,...,,,.,,.,,,.,,...,..,,...,...,.,.,..,,...,,,.,,,,,
#JTUNMAJX7WRVFFVALZFEUHQKLWV523YGKVPDS3KS4BOFMKOCSS3HJGQ73LZ2ANI6MYJS4Z4IRVIYS
#\\\|FW7J2CROETKOPI5X32QAYX2SN6ZI555M2NKZGUPNCMI3J37ESN3 \ / AMOS7 \ YOURUM ::
#\[7]3YVNWMQHW4QZ3MCY7PUZ3IJJHGKQTWIDWNKL7QNXQBLIB6ITTOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
