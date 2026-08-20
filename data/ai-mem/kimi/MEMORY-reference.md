# Kimi Development Memory — Reference (Protocol-7)

> durable how-to + settled rules moved out of `MEMORY.md` to keep the auto-loaded index slim.
> links remain valid.

## Memory Update Tool — Length-Aware Routing (June 2026)

`p7_memory_update` enforces per-agent line limits on `MEMORY.md` (claude ~180/200,
kimi ~300/400), supports `target` for external topic files, and auto-routes `UPDATE FILE:`
directives. see [topic-memory-update-tool.md](topic-memory-update-tool.md)

## Project Workflow Rules (CRITICAL)

- signature updates require user passphrase — ask user to run signing command, never skip hooks
- version file: `cfg/protocol-7.src-ver` — update with `./bin/dev/update-version`
- pre-commit checks: permissions, version, signatures, source integrity

## %code Presence/Call Primitives + Rename Grep Caveat (July 2026) [ CRITICAL ]

new cross-namespace call pattern from commits b674ecd80/ae6b1f79b: never
write `exists $code{'literal.name'}` inline [ the referenced-sub scanner
flags it ] and never use `<system.zenka.name> eq 'v7'` as a proxy. use
`base.code.exists` / `base.code.call_expected` / `base.code.call_optional`
/ `base.mod.exists` [ ground truth: `<base.p7_mod.loaded>` ]. undef subs
land in the `undef-subs` buffer [ `show-buffer undef-subs` ]. also: before
any module rename, grep for `sprintf`-resolved names, not just literal
calls — two dynamic-dispatch renames broke silently in one session.
full details in [coding-style.md](coding-style.md) "code presence checks"
section and `data/yaml/code-style/CONVENTIONS.yaml`
`code_presence_and_cross_namespace_calls`.

## Module Name Swaps via `base.swap_subs` (July 2026) [ CRITICAL ]

some module families are renamed at runtime (`base.event`→`event`,
`base.file`→`file`, etc.). the file on disk does not match the post-init
`%code` key; calling the long form after init crashes. see the
swapped-module-families note in [coding-style.md](coding-style.md).

## Command Return Style — Deferred Replies (June 2026)

`qw| deferred |` returns keep the route open and reply later via the remembered route id.  They must **not** include a `'data'` key.  Args must always default with `// ''`.  See [topic-cmd-style-notes.md](topic-cmd-style-notes.md).

## perlmod load/autoload categorization notes (July 2026)

static classification of 152 suspected call sites found ~8 files are grep false positives (they reference `base.perlmod.loaded` or contain the literal string, but make no actual `base.perlmod.load`/`autoload` call). a few modules use direct `use Module;` instead of the wrapper — those are outside the refactor scope. heavy GUI deps (`Gtk3`, `Curses::UI`) and interactive-only modules (`AMOS7::TERM` for password prompts) are intentionally kept lazy so non-GUI / non-interactive zenki do not pay the load cost at boot. see `data/tasks/perlmod-categorization-results.md` for the full table.

MOVE re-verification (2026-07-26, `data/tasks/perlmod-move-reverification-results.md`):
only **11 of 59** MOVE rows survived caller tracing — the rest were
frequency-inflated `.cmd`/`.handler` rows or already-redundant loads. durable
lessons for any future load-placement call:
- `base.perlmod.load` short-circuits via `<base.perlmod.loaded>` — repeat per-call
  loads are one hash lookup. a MOVE must be justified by first-call latency or boot
  consolidation, not per-call overhead; this deflates most cases for core perl mods
  (POSIX, JSON::PP, Time::HiRes, MIME::Base64, HTTP::Tiny, IPC::Open3, Math::BigRat).
- Crypt::Misc is already base-loaded at startup in any networked zenka
  (base.chk-sum.jha.init_code, base.handler.link-upgrade,
  base.handler.write.encoding-wrapper) — inline loads elsewhere are no-ops.
- channels zenka is `start.on-demand = 1` with dev-only cube wildcard grant —
  "granted" != "hot". several channels/context.share/branch modules are dead or
  unwired code with zero callers (design-stage namespaces).
- image-quality.* runs inside vision-batch child processes whose own
  vision-batch.child.init_code already preloads JSON::XS — moving the load to
  image-quality.init_code would not cover the real execution path. always check
  WHICH process actually executes the module.

## user-edit local outbox primitives — unlink choice (2026-08-10)

`user-edit.outbox.clear` uses plain `unlink` on the keyword-resolved
absolute path instead of `file.zenka_dir.unlink_file`. The zenka_dir
wrapper owns its own relative-path prefix logic for var/etc dirs; the
outbox file is already an absolute path from `[VAR_P7]/outbox/<id>.yaml`
+ `base.path.resolve_keywords`, so direct `unlink` is the simpler fit.

#,,,,,.,.,,,.,,,.,.,.,,,.,,,.,...,.,,,..,,..,,..,,...,...,,.,,..,,,,.,,..,,,,,
#J3O46FZJO43TN4OCMXDUEBHP53SPKGLUXFPYCQT24ZP4MEIUYIKRCZPDY7ZHYBDCUQIJA56BKRLYY
#\\\|JRZKTFYQZV3AX4Q65JIE35XTOYZHULXYZBESCLGDDGVLJWVK5WM \ / AMOS7 \ YOURUM ::
#\[7]QY6UU6ZKTTDH6K4LGD6RR7VY2FPHUK3UU3U6CLWRDRA2NZXMGWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
