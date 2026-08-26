# relocate-repo-tree-runtime-state — fix mis-placed runtime state under the repo tree

**Priority:** Medium
**Type:** Path-config cleanup
**Component:** bin/chat, bin/mcp-server-p7, src/sys-deps.*, bin/dev/git-hooks/pre-commit, .gitignore

## Overview

Two unrelated problems share the same trigger (`git clean -fxd` wiped both on
2026-07-26, along with several stray `pm-dep`/`source` touch-files across
multiple zenki — unrelated bug, already fixed separately in
`base.register_src_deps`) but need **opposite** fixes:

1. **`var/sys-deps/`, `data/state/`** — genuine operational bookkeeping
   (dependency tracking, MCP focus/follow-up state) that was never meant to
   live inside the git working tree at all. A repo-local `var/` was never an
   intentional convention here — it's specifically the pattern the project
   has been moving *away* from. Fix: move these under the project's existing
   external-runtime convention (`<system.path.zenka-dirs>{'var_P7'}`, i.e.
   `/var/protocol-7` or `$ENV{PROTOCOL_7_VAR}`, set up by
   `src/base.path-set-up.zenka-directories`).
2. **`data/chat/`** — task- and development-related chat history between
   models/zenki, explicitly intended to be committed alongside the code
   state it discusses. `data/chat/channel/*/history`, `summary.md`, and
   `persona` are already git-tracked and working as intended. `archive/`
   (rotated-out channel history via `bin/chat -clear`/`-trim`, compressed to
   `.xz`) and `inbox/` (per-recipient message drops — there will be more than
   just `claude`) are the *same kind* of content, just currently gitignored
   by mistake. Fix: untrack them from `.gitignore` so they get committed too,
   not relocate them externally. The dividing line for what belongs in the
   repo path is sensitivity, not "is it a live queue" — anything genuinely
   sensitive should simply never be written under `data/chat/` in the first
   place; that's a content-level judgment call for whoever/whatever is
   populating it, not something a directory move can fix.

   Also rename `data/chat/` → `data/development/chat/` while touching these
   same files — `data/coding/chat/` was considered and rejected: `coding` is
   already the name of a real zenka (`src/coding.*`), so it read as "the
   coding zenka's chat" rather than "dev conversations in general" the
   moment it was written down. `git mv` to preserve history, then update the
   hardcoded paths in `bin/chat` (`$CHAT_DIR`, ~line 58),
   `bin/mcp-server-p7` (~lines 1159, 1234), and the `data/chat/` skip-sign
   exemption in `bin/dev/git-hooks/pre-commit` (~line 254,
   `next if $file =~ m{^data/chat/};`).

`.gitignore` negation (`!pattern`) was considered for case 1 and does **not**
solve it: negating a path just makes it visible to plain `-fd` instead, it
doesn't create a state that's ignored-but-immune-to-`-x`. The only real fix
for genuinely external state is to stop writing it inside the repo tree.

## Step-by-step plan

1. **`var/sys-deps/`** (live, needs a real code change) — used by
   `src/sys-deps.init_code`, `src/sys-deps.cmd.install`,
   `src/sys-deps.cmd.promote`, `src/v7.check_zenka_deps`, and
   `bin/os-pkg` (currently `File::Spec->catdir($P7_ROOT, qw|var sys-deps|)`).
   All of these build the path from `<system.root_path>` / `$P7_ROOT`
   (repo root) — switch them to `<system.path.zenka-dirs>{'var_P7'}` (or
   `$ENV{PROTOCOL_7_VAR} // '/var/protocol-7'` for the standalone
   `bin/os-pkg`), under a `sys-deps/` subdir, matching every other zenka's
   directory-naming convention.
2. **`data/state/`** (live, needs a real code change) — used only by
   `bin/mcp-server-p7`:
   - `$FOCUS_FILE = "$ROOT_PATH/data/state/mcp-summary-focus.txt"` (~line 324)
   - `"$ROOT_PATH/data/state/auto-followup.log"` (~line 1971)
   - two `make_path("$ROOT_PATH/data/state")` calls (~lines 1980, 2003-2004)

   Standalone script, doesn't go through `base.path-set-up.zenka-directories`
   — needs its own lightweight equivalent: resolve from
   `$ENV{PROTOCOL_7_VAR} // '/var/protocol-7'`, subdir e.g.
   `mcp-server/state/`, create with mode `0775` (matching
   `base.path-set-up.zenka-directories`) if missing.
3. **Dead `.gitignore` entries** — `var/credential_fabric/`, `var/index/`,
   `var/inference-cache/`, `var/nameserv/` have zero code references and
   don't exist on disk today. Confirmed superseded, not just unused: e.g.
   `index`/`index-mem` zenki already moved to absolute
   `/data/index/...`/`/data/index-mem/...` paths
   (`cfg/zenki/index/zenka.v7`, `cfg/zenki/index-mem/zenka.v7`),
   not `var/index` at all. Re-grep at implementation time to be sure nothing
   new picked these paths back up, then delete the four lines.
4. **`inbox/` and `archive/` under the renamed chat dir** — remove both
   `data/chat/inbox/` and `data/chat/archive/` lines from `.gitignore`
   (currently lines 36-37; update them to the new `data/development/chat/...`
   paths as part of the same edit) so they track like `channel/` already
   does. Note `data/chat/inbox/claude` is already tracked in git despite the
   ignore rule (added before the rule existed, or force-added) — once the
   rule is gone this stops being an inconsistency. Worth a pass over
   whatever's currently sitting in `archive/`/`inbox/` before committing, to
   confirm nothing sensitive slipped in while it was assumed disposable.
5. Once steps 1-2 land, remove the now-dead `var/sys-deps/` and `data/state/`
   lines from `.gitignore` and delete the now-empty directories from the
   working tree.

## Non-goals

- No shell-alias/wrapper-script workaround for `git clean` — the fix for
  case 1 is structural (don't put real state inside the repo tree), not
  procedural (remembering to pass extra flags, which doesn't survive a fresh
  checkout or a new install).
- Not touching `.deps/cache/` — currently root-owned, incidentally already
  immune to a non-root `git clean -fxd` (permission denied), separate from
  this cleanup.
- Not deciding *what* content should or shouldn't flow into `data/chat/` —
  only fixing where already-intended-to-be-committed chat content lives
  relative to `.gitignore`.

## Notes

- signatures_note: leave signing to the system, no stub lines

#,,..,,..,.,,,,..,.,.,...,,.,,.,,,,,.,...,...,..,,...,...,.,.,,..,,..,.,,,,,,,
#M76PSNY4J5PWKH5BJH3PJ7TY3K2EOQWDOWDB722APNJGRJECV3TTCTGPA7VZXIOMOOOBVST2VIVGO
#\\\|DWOKHBG5STMYEQTJGWRU7IAGMGLABJHUOZXQQEYD63RMEHWLIVH \ / AMOS7 \ YOURUM ::
#\[7]SJXTHIJDAEM5ZT6TGVTQ57LE7IPFG2GYGXGZZVMSKZ22MXVPACAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
