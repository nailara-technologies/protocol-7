---
name: project-bin-todo-ntime-b32-timestamps-landed-2026-08-20
description: "LANDED: bin/todo's added/done_at switched from ISO8601 strings to ntime.B32, standalone-ported the same way gen_id ports base.gen_id; all 35 pre-existing ISO timestamps migrated in place; default.yaml renamed to base.yaml"
metadata:
  type: project
---

Session 2026-08-20, commits `4514a8aed` (unrelated 3rd priority-sort
pass + trailing-blank-line trim, same session), `48ef291d9` (unrelated
loop-detection reset fix), `4f9a57d59` (this), `33aba773b` and
`7e9007f3b` (web-browser snapshot filename follow-on, separate memory).

## what changed

`bin/todo`'s `added`/`done_at` fields switched from `iso_now()`
(`YYYY-MM-DDTHH:MM:SS`) to a new `ntime_B32_current()` — protocol-7's
own network-time primitive (`(unix - 1023228000) * 4200`, base32r
encoded via `Crypt::Misc::encode_b32r`), matching the format the rest
of the project already uses everywhere (`<[base.ntime.b32]>`, e.g.
`configuration/protocol-7.src-ver`'s own version stamps).

**Same shape as [[bin-todo-random-id-scheme]]'s `gen_id()`**: `bin/todo`
is a standalone script, not a zenka module, so it can't call
`<[base.ntime.b32]>` (the real core sub, defined in `bin/Protocol-7` as
`p7_ntime__b32`) directly. The fix was porting the same logic
standalone — this had already been done once before, in
`bin/dev/update-version`'s `ntime_B32`/`ntime` subs, which `bin/todo`'s
new `ntime_B32_current`/`ntime_b32_decode` mirror closely (constant
`NTIME_START => 1023228000`, `Time::HiRes::time()` seed, harmonic retry
via `AMOS7::Assert::Truth::is_true` — already an existing `bin/todo`
dependency for `gen_id`'s own harmony gate). Decode direction
(`ntime_b32_decode`, needed for `format_relative_time`) has no existing
standalone precedent — ported directly from `bin/Protocol-7`'s
`p7_ntime_BASE32_to_numerical` + `modules/base.n2u_time`'s
`ntime/4200 + NTIME_START` formula.

`format_relative_time` tries `iso_to_epoch` first, falls back to
`ntime_b32_decode` — so pre-upgrade ISO entries keep displaying
correctly even without migration. Migration was done anyway (see
below) so the shipped `base.yaml` (see rename below) is 100%
ntime.B32; the dual-format fallback exists for any *other* todo list
file a user might still have around from before this landed.

## migration approach for the 35 pre-existing ISO timestamps

Deliberately **not** a full YAML round-trip (parse with YAML::PP, dump
back out) — the file carries an AMOS7 signature footer at the end that
a full re-serialize risks reformatting/reordering around, plus general
key-order/quoting churn unrelated to the actual change. Used a
one-off raw line-substitution script instead: regex-match only lines
shaped like `(added|done_at): <iso>`, decode each `iso` to unix epoch
with the same regex `iso_to_epoch` already uses, re-encode with a
`ntime_b32_from_unix($epoch)` variant (jitters by whole ntime units,
~238μs each, to satisfy the harmonic gate without drifting outside the
original displayed second), write the line back verbatim otherwise
untouched. Verified every decode round-trips to the exact original
ISO value before applying to the real file (tested against a scratch
copy first). Diff was exactly 35 changed lines, nothing else touched.

## default.yaml → base.yaml rename

`bin/todo`'s `$list_name` default changed from `'default'` to
`'base'` (matching this branch's own name, i.e. the same convention
`configuration/zenki/*` and `modules/base.*` already follow) — the
backing file was `git mv`'d from `data/yaml/todo/default.yaml` to
`data/yaml/todo/base.yaml` in the same commit as the timestamp
migration, so code and data stayed in sync. `-list <name>` help text
updated to match. No other file in the repo referenced the old
`default.yaml` path or `'default'` list name (grepped before renaming).

**How to apply**: if `bin/todo` (or a similar standalone `bin/`
script) ever needs another zenka-only primitive, check
`bin/dev/update-version` first for an existing standalone port before
writing a new one from scratch — `ntime`/`ntime_B32`/`gen_id`'s shape
are all precedent for the same pattern (`bin/Protocol-7`'s core subs
can't be called via `<[...]>` outside a running zenka; port the exact
formula/algorithm instead, don't approximate it).

#,,,.,...,.,,,,,.,...,,..,,.,,,,.,...,,..,.,.,.,.,...,...,..,,.,,,..,,,,.,,..,
#AV3WAJ3ZL2JU5ARE7K5R4PHTXUAGKXH365JSXVCRN6V6IIFYOTFDYL2LP4KY7TBRGCBK6GK2RAGOA
#\\\|CDI7A6S5PNRZL3WV4ZUZJKLWEMSSMNV3M5BKLSVGTRQCBE5KQCF \ / AMOS7 \ YOURUM ::
#\[7]WZIRMRTJ7HC44PQUJLXYMGM5EK7AJDOSBMDRE73XORWPHEW6HWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
