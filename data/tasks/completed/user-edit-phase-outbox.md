# user-edit console zenka — local edit outbox module

**Read first, both required:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7 module
  conventions, common mistakes to avoid. Pay particular attention to the
  "swapped module families" section — `base.file.*` calls at runtime as
  `file.*` (no `base.` prefix), `base.path.*` does NOT swap (keep the prefix).
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` — read `local_edit_outbox`
  specifically (search for that key). The rest of the doc (rendering, the actual
  form/submit flow, users-zenka integration, draft-auto-save) is NOT in scope here.

Two prior phases already exist and are committed:
- `cfg/zenki/user-edit/`, `src/user-edit.init_code` (skeleton)
- `src/user-edit.init_code` also already registers three path keywords via
  `base.path.register_keywords`: `VAR_P7` (→ this zenka's own var dir),
  `ETC_P7`, `HOME_N` (→ `~/.n`). Read the current file to see the exact
  registration — do not re-register these, they already exist.

## Goal

Build a standalone outbox module, `user-edit.outbox.*`, that can write, list, and
clear YAML-serialized edit records under `[VAR_P7]/outbox/` — using the keyword
already registered in phase 1b. This is infrastructure only: there is no actual
field-editing UI yet to call it, no `users.*` integration. The design doc's
`local_edit_outbox` describes the eventual lifecycle (write on submit, before
attempting a network commit; remove on confirmed commit; leave staged on
failure) — this task builds the write/list/clear primitives that lifecycle will
later be built on top of. Do not build the submit flow itself.

## Precedent to follow (do not invent new mechanisms)

- `src/format.yaml.write_file` — takes `($path, $yaml_data)`, an ALREADY
  RESOLVED absolute path (not a `[KEYWORD]` string) plus a Perl data structure.
  Read it.
- `src/format.yaml.load_file` — the read counterpart, same absolute-path
  convention. Read it.
- `src/format.yaml.load_keyword_path` — shows the pattern for combining
  keyword resolution with a format.yaml.* call: it calls
  `<[base.path.resolve_keywords]>->($path)` first, then passes the RESOLVED
  path to `format.yaml.load_file`. There is no `write_keyword_path` sibling —
  your write function needs to do the same two-step (resolve, then write_file)
  itself. Read this file as the exact shape to mirror.
- `src/base.path.resolve_keywords` — read it, confirm the exact substitution
  behavior (`[NAME]` → registered path).
- `src/base.file.make_path` — recursive directory creation, signature
  `($path, $mode, $owner, $group)`. At runtime this is called as
  `<[file.make_path]>->(...)` (swapped family, no `base.` prefix — see the
  coding-style.md section on this). The outbox directory
  (`[VAR_P7]/outbox/`, resolved) will not exist on a fresh zenka — your write
  function must ensure the directory exists before calling `format.yaml.write_file`.
  Look at `src/base.path-set-up.check-zenka-paths` for a real call-site
  example of `<[file.make_path]>` (mode/owner arguments) to match conventions —
  though your case is simpler (no owner/group juggling needed, this is the
  zenka's own working directory).
- `src/base.file.all_files` — directory listing, runtime name `<[file.all_files]>`
  (also a swapped family). Read its signature and return shape before using it.

## What to build

Three new modules:

1. `src/user-edit.outbox.write` — params: an entry identifier (string,
   e.g. a filename-safe id) and a data structure (hashref) to persist.
   Resolves `[VAR_P7]/outbox/<id>.yaml` via `base.path.resolve_keywords`,
   ensures the outbox directory exists (`file.make_path`), then calls
   `format.yaml.write_file`. Return whatever `format.yaml.write_file` returns
   (true/false + error, matching its own `wantarray` convention — check that
   file for exactly how it signals success/failure and propagate the same
   shape, don't invent a different one).

2. `src/user-edit.outbox.list` — no params, or an optional filter — lists
   entry ids currently staged in `[VAR_P7]/outbox/` (i.e. the `.yaml` files
   present, with the `.yaml` suffix stripped back to the bare id). Uses
   `file.all_files` against the resolved outbox directory. Returns an arrayref
   of ids (empty arrayref if the directory doesn't exist yet or is empty — not
   an error in that case).

3. `src/user-edit.outbox.clear` — params: an entry identifier. Removes the
   corresponding `[VAR_P7]/outbox/<id>.yaml` file. Use a plain Perl `unlink`
   with the resolved path (check whether there's a `base.file.*`/`file.*`
   wrapper preferred over bare `unlink` elsewhere in this codebase for
   consistency — `base.file.zenka_dir.unlink_file` is one such wrapper, but it
   operates on the zenka_dir convention directly rather than a resolved keyword
   path, so it may not fit here; use your judgment based on what you find, and
   say in your summary which you picked and why).

All three: validate the entry identifier is a safe bare string before building
a path from it (no `/`, no `..` — mirror the validation style already used in
`src/protocol-7-menu.position.save` or similar path-building code you find
in this codebase, don't invent ad hoc validation).

## Explicitly out of scope — do not implement

- the actual submit/outbox lifecycle (write-before-network-commit,
  remove-on-confirmed-commit) — that needs a caller that doesn't exist yet
- draft_auto_save, retry_mechanism, anything from `phase_2_rendering` or
  `phase_3_form`
- any `users.*` command surface or network calls of any kind
- do not touch `cfg/zenki/user-edit/start` or
  `src/user-edit.init_code`'s existing keyword registration

## Verification

- `bin/dev/ptd -c` each of the three new module files, confirm syntax ok
- state in your summary, for each of the three, the exact resolved path shape
  it would produce for a given example id (e.g. id `"test-user-42"` →
  `/var/protocol-7/user-edit/outbox/test-user-42.yaml`)
- do not attempt to actually run these against a live filesystem/zenka — this
  zenka is not network-reachable and has no runtime to execute against; static
  correctness + syntax check only

## P7 pitfalls (from prior kimi sessions, avoid these)

- swapped module families: `base.file.*` → `file.*` at runtime (no `base.`
  prefix); `base.path.*` does NOT swap, keep the full prefix. Get this wrong
  in either direction and the call resolves to an undefined sub.
- use `base.logs` (list form), not `base.log` (singular) unless confirmed
  otherwise by precedent
- never redeclare `my $call`
- `TRUE` = 5, `FALSE` = 0 in this codebase
- no fake/placeholder AMOS7 signature blocks — the human signs files
- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context — don't write multi-word `sprintf qw()` calls
- module calls use `<[module.name]>->(...)` syntax (or bare `<[module.name]>`
  when no args)

When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` if you hit anything non-obvious (e.g. whichever
unlink approach you picked and why, if it wasn't obvious).

#,,,.,.,.,,.,,.,.,.,,,...,,..,,,,,.,,,...,.,,,..,,...,...,...,,,,,,..,,..,,..,
#CQLZDKAMUPZRGUQFZZQ2IF6X4VZQY66ENCZDEGX4KS7VPO2JH4AVCUS5FUDSPJVQNNXNJNXJBIZP4
#\\\|RR6CQBVRDMYNPA4BYYLPHHRLUWECP4JNK7QAWUM73XBTEYXXWXQ \ / AMOS7 \ YOURUM ::
#\[7]VIBCTIM4DORGCECJ77HANORI6VTPEAVNUPTWKGTGJYDONHRQWIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
