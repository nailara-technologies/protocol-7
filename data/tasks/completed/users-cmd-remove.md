# users.cmd.remove

## Goal

Add a `users.cmd.remove <username>` command to the `users` zenka that
deletes an existing user record. Today there is no way to remove a record
once created (`users.cmd.create-default` and `users.cmd.value-set` can only
create/overwrite), so throwaway/test records accumulate with no cleanup
path.

## Precedent to mirror

**Read `src/users.cmd.create-default` first** — this new module is a
near-exact structural mirror of it, with the existence check INVERTED:
create-default refuses if a record already exists; `remove` must refuse if
the record does NOT exist. Same header-comment style, same arg-parsing
block (trim, first whitespace-delimited token only, reject `/`/`\` in the
username), same two-step path resolution
(`<[users.record.path]>->($username)` then
`<[base.path.resolve_keywords]>`), same
`<[format.yaml.load_keyword_path]>->($file_path)` existence probe, same
`{ mode => 'true'/'false', data => ... }` return shape.

Also read:
- `src/users.record.path` — explains the on-disk layout: a record is a
  **directory**, `[USERS_HOST]/<username>/details.yaml`, not a flat file.
  It can also grow a `log/` subdirectory (documented, not yet built). This
  matters for deletion: you must delete the whole
  `[USERS_HOST]/<username>/` directory, not just `details.yaml`.
- `src/users.record.ensure_dir` — shows the equivalent
  resolve-and-touch pattern on the creation side, for how to resolve the
  directory path (as opposed to the document path) via
  `<[base.path.resolve_keywords]>->(sprintf(qw| [USERS_HOST]/%s |,
  $username))`.
- `src/base.file.remove_tree` — the existing recursive-delete
  primitive to call for the actual deletion. Do not write a new one.

## What to build

New module `src/users.cmd.remove`:

1. Parse `$call->{'args'}`, trim leading/trailing whitespace, take only the
   first whitespace-delimited token as the username (same as
   create-default).
2. Reject empty args: `{ mode => 'false', data => 'usage: users.remove
   <username>' }`.
3. Reject `/`/`\` in the username: `{ mode => 'false', data => 'username
   cannot contain path separators' }` (same guard, same wording as
   create-default).
4. Resolve the record's document path via `<[users.record.path]>` and
   probe existence via `<[format.yaml.load_keyword_path]>`, exactly as
   create-default does — but **refuse if it does NOT exist**:
   `{ mode => 'false', data => sprintf("user '%s' record does not exist",
   $username) }`.
5. Resolve the record's **directory** path (not the `.yaml` document path)
   via `<[base.path.resolve_keywords]>->(sprintf(qw| [USERS_HOST]/%s |,
   $username))`.
6. Delete it with `<[base.file.remove_tree]>->($resolved_dir)`. On
   failure: `{ mode => 'false', data => sprintf("failed to remove user
   '%s': %s", $username, $err // 'unknown error') }` — check
   `base.file.remove_tree`'s actual return shape/error signaling and match
   it, don't assume it matches `format.yaml.write_file`'s `($ok, $err)`
   shape.
7. On success: `{ mode => 'true', data => sprintf("user '%s' record
   removed", $username) }`.

Same AMOS7 module header/footer signature convention as every other file in
`src/` (the pre-commit hook enforces this — don't hand-write a fake
signature block, leave it for the normal signing step if you can't produce
a real one).

## Whitelist registration

Add `users.cmd.remove` to
`cfg/zenki/users/subroutines.load-early` — `create-default` and
`value-get` are both already listed there (this is the users zenka's own
subroutine whitelist, separate from cube-level access control). Prefer
regenerating it via `bin/dev/gen-sub-whitelist users` over hand-editing, if
that script works cleanly here; fall back to a hand-added line matching the
existing entries' format if not.

**No `access.zenki`/`access.users` change is needed** — `users.*` commands
are already reachable under the existing admin/root wildcard grants in
`cfg/zenki/cube/access.users`. Do not add anything there.

## Acceptance checks — run these live via `p7c`, not just `perl -c`

`perl -c`/`bin/ptd -c` passing is a baseline gate, not sufficient on its
own. After `v7.restart users` (code changes to a running zenka need a
restart to take effect), run:

1. `p7c users.create-default zz-remove-test` → true
2. `p7c users.remove zz-remove-test` → true, confirms removal
3. `p7c users.value-get zz-remove-test` → false / record not found
4. Confirm the directory `[USERS_HOST]/zz-remove-test` (resolve
   `[USERS_HOST]` the same way the code does, or just check under
   `/etc/protocol-7/users/host-system/`) is actually gone from disk
5. `p7c users.remove zz-remove-test` again → refuses cleanly with "does
   not exist", does NOT crash or falsely report success
6. `p7c users.remove ../escape-test` (or similar) → rejected by the
   path-separator guard, no directory created/touched outside
   `[USERS_HOST]`

Report the actual command output for each check, not just "tests pass" —
this project has a standing distrust of self-reported dispatch summaries
that aren't backed by shown output.

## Explicitly out of scope

- No `user-edit` console/UI wiring for this — it's a `users`-zenka-only
  command for now, callable via `p7c`.
- No confirmation-prompt/dry-run flag — the existing `create-default`
  precedent has no such thing either; keep the same directness.
- Do not touch anything under `credentials`/`cred-mesh`/`sessions` — this
  task is scoped to the `users` zenka's own record storage only.

#,,..,,..,,,,,..,,..,,...,...,.,.,,,,,,,.,.,,,..,,...,...,...,..,,,.,,.,,,,..,
#57ML5BC3BMSYFX54WBM6ZE5JGISUKZ4IBLIAHF7FTVICITCL3TTRZTZ7SFL2ONDX3XJ2MGLHTWYWE
#\\\|6UQVNEWVMF6M5XKUBLPPSFK4WNBVXT3UTHKRO5PSS4MA6VSG5AN \ / AMOS7 \ YOURUM ::
#\[7]YAUO6DS56ZPNUPV3K2447EZHDNFO5V5BRRP4VWR3ETC34FVEXEAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
