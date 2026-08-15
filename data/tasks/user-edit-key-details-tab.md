# user-edit key details tab (basic, self-record-only)

## Goal

Add a read-only "key details" tab to `user-edit`'s form, showing the
invoking Unix user's own C25519 identity (key name, checksum, public key).
Per user direction: **self-record-only** — the tab appears ONLY when the
record currently open is the invoking user's own record (e.g. running
`v7.user-edit show-form taeki` as Unix user `taeki`). Viewing any other
user's record must NOT show this tab at all, and must NOT show your own
key data next to someone else's fields.

This is explicitly a "basic" first cut: display only, no editing, no key
management actions (create/rotate/etc). Read `topic-user-edit-console-
zenka-status.md` and `project-keys-zenka-integration-direction.md` in
`data/ai-mem/claude/` for the fuller context this was scoped out of.

## Why this isn't an ordinary record field

Every existing field in the form comes from `user-edit.form.
schema_from_record` iterating the ACTUAL record's `fields` hash (whatever
is really stored). Key/identity data is not record data — it lives in
`crypt.C25519`'s in-process key state, not in `users`' storage. So this
cannot be built as an ordinary stored field, and must not be added to
`users.record.default_fields`/`optional_fields`.

## Data source — already proven live, use these, don't touch `keys.console.*`

`user-edit` already autocreates and holds its own `taeki.base`-style
identity via `crypt.C25519` (confirmed live: `crypt.C25519.key_vars`,
`key_exists`, `key_checksums`, `key_bin_checksums` are all already in
`configuration/zenki/user-edit/subroutines.load-early` and already
exercised by this zenka's own bootstrap). Use:

- `<[crypt.C25519.key_vars]>->{'key_name'}` — the zenka's own currently
  loaded session key name (e.g. `taeki.base`). Read `modules/crypt.
  C25519.cmd.get-public-key` first: it resolves the same way (`my $name
  = <[crypt.C25519.key_vars]>->{'key_name'};`) and is the exact precedent
  to mirror for "the zenka's own key, no name param needed."
- `<[crypt.C25519.cmd.get-public-key]>->()` — returns `{ mode => 'true',
  data => "[<name>] <b32-public-key>" }` for the already-loaded key. This
  one module is NOT yet in `user-edit`'s `subroutines.load-early` (the
  other four are) — add it via `bin/dev/gen-sub-whitelist user-edit`
  after wiring the call site, same as any other new reference; it's a
  literal `<[...]>` macro call from a scanned file, so the regeneration
  should pick it up automatically without hand-editing, the same way
  `base.file.remove_tree` was picked up automatically in the previous
  `users.cmd.remove` dispatch (only entry points reached purely via
  dynamic command dispatch need a manual whitelist add — this is not
  one of those).
- `<[crypt.C25519.key_checksums]>->(<[crypt.C25519.key_vars]>->{'key_name'})`
  — returns the harmonized checksum for that same key (already loaded,
  so this returns quickly without a load/decrypt round trip). Do NOT
  call `keys.console.get-encoded-key` or any other `keys.console.*`
  module — those are interactive-console modules that `print`/`say`
  directly to STDOUT rather than returning clean data, wrong shape for
  a render function, and would need new whitelist entries this dispatch
  doesn't need to take on.

**Verify against the user's own live output before considering this
done**: `taeki`'s real checksum was captured live as `<:ZITAETA:YKO7BCA:>`
for key name `taeki.base` (from `Protocol-7 keys list` run directly, not
through user-edit). The new tab's rendered checksum for a real `taeki`
session MUST match this exactly — same underlying key, same checksum
function family. If it doesn't match, something is wrong with the call,
not with the precedent number.

## Self-record-only gating — exact precedent to mirror

`modules/user-edit.handler.value_get_reply` already does this comparison
for the create-admin gate:

```perl
<user-edit.unix_user> eq ( <system.admin-user> // '' )
```

Use the same `<user-edit.unix_user>` keyword, compared against
`$record->{'name'}` (the record envelope's own username field — confirmed
present: `checksum`/`fields`/`metadata`/`name`/`timestamp`) instead of
`<system.admin-user>`.

## What to build

1. **`modules/user-edit.form.schema_from_record`** — after the existing
   `foreach my $name ( <[base.reverse-sort]>->($fields) ) { ... }` loop
   that builds `@field_defs`, and BEFORE the `if ( not @field_defs ) {
   return undef; }` empty-guard (a self-viewing bootstrap record with
   zero real fields yet must still get a form containing just this tab,
   not bail out) — conditionally push one more field_def:

   ```perl
   if ( <user-edit.unix_user> eq ( $record->{'name'} // '' ) ) {
       push @field_defs, {
           qw| name |             => qw| identity_key |,
           qw| type |             => qw| freeform_line |,
           qw| default |          => '',
           qw| readonly |         => TRUE,
           qw| plugin |           => qw| plugin.user-edit.key-details |,
           qw| display_override | => sub {
               my ( $render_state, $render_field ) = @ARG;
               return exists $code{'plugin.user-edit.key-details.render'}
                   ? $code{'plugin.user-edit.key-details.render'}
                       ->( $render_state, $render_field )
                   : '';
           },
       };
   }
   ```

   Use the literal field name `identity_key` (not `key_info` or anything
   shorter) — deliberately unlikely to collide with a future real record
   field. This mirrors the EXISTING pinned-plugin field_def shape in this
   same function almost exactly (read that block first, a few lines above
   the loop's closing brace) — same `readonly`/`plugin`/`display_override`
   keys, just synthesized instead of derived from a real `$fields` entry.

2. **New module family `plugin.user-edit.key-details.*`**, same shape as
   `plugin.user-edit.example.*` / `plugin.user-edit.address-cluster.*`
   (read both — example is the minimal reference, address-cluster is the
   fullest real one, but this task needs neither's editing complexity):
   - `.render($render_state, $render_field)` — builds and returns a short
     display string combining the key name, checksum, and public key from
     the three calls above. Exact formatting is your call, but all three
     pieces must be present and the checksum must be verifiable against
     `keys list`'s own live output for the same key (see above). Handle
     `crypt.C25519.cmd.get-public-key`'s `mode => 'false'` case
     gracefully (return a short "not available" string, don't die) —
     this can legitimately happen if the session key somehow isn't loaded
     when render fires.
   - `.tab_info` — `{ label => 'key details' }`. This field is NOT going
     through the `plugin.user-edit.registry`'s `by_key` pinned-field
     lookup (that path is for fields that exist in `$fields`; this one is
     synthesized directly in `schema_from_record` per step 1 and already
     carries `plugin => 'plugin.user-edit.key-details'` on its own
     field_def) — `tab_info` here is just for the plugin registry's
     bookkeeping/discovery, not a `pinned_keys` binding. Check `plugin.
     user-edit.registry.post_init` to confirm this doesn't assume every
     registered plugin must appear in `by_key` — if it does, this may
     need a small, narrow adjustment there too, but don't restructure
     the registry mechanism itself for this.
   - `.handler.key($editor_state, $key, ...)` — this field never enters
     an editable mode. Decline every key immediately (same return shape
     `plugin.user-edit.example.handler.key` uses to signal "not handled"
     — read it first) so pressing Right/Enter on this field is a no-op
     that stays parked on it, or exits back out gracefully — whichever
     matches the existing decline-signal convention already established.
     Do not build any editing/scrolling interaction for this field.

3. **`modules/user-edit.form.submit`** — `identity_key` must NEVER reach
   `users.value-set`'s JSON payload, same reasoning as masked fields (see
   the existing `@masked_fields` / `%secret_values` block a few lines into
   this file — read it first). Simplest correct fix: delete
   `$values->{'identity_key'}` unconditionally right after the existing
   masked-fields deletion block, with a one-line comment explaining it's
   synthetic display-only data, never real record content. Do not
   generalize this into a new "synthetic field names" list/module for a
   single hardcoded name — that's premature abstraction for one field.

## Whitelist

After wiring the `crypt.C25519.cmd.get-public-key` call site, run
`bin/dev/gen-sub-whitelist user-edit` and confirm the new entry appears
in `configuration/zenki/users/... ` — wait, `configuration/zenki/
user-edit/subroutines.load-early` (this zenka is `user-edit`, not
`users` — don't confuse the two, they are separate zenki with separate
whitelist files). No other whitelist changes should be needed — the
other four `crypt.C25519.*` subs used here are already present.

## Acceptance checks — run live via the `-no-tty`/`char-add` driver

Read `reference-user-edit-headless-driving.md` in `data/ai-mem/claude/`
first for the established technique (this whole zenka's interactive form
has been tested this way all session; `perl -c`/`ptd -c` passing is not
sufficient on its own). Use a THROWAWAY record for the non-self case —
do not use `taeki`'s own real record for anything destructive, and clean
up any throwaway record you create via `p7c users.remove <name>`
afterward (that command exists now, see `users.cmd.remove`).

1. Start `user-edit` in `-no-tty` mode as Unix user `taeki`, `show-form
   taeki` (or open `taeki`'s record via `browse`) — the key details tab
   MUST appear. Enter it and confirm the rendered checksum matches
   `<:ZITAETA:YKO7BCA:>` exactly (the live value captured for `taeki.base`
   this session) and that a plausible-looking public key string is shown.
2. Create a throwaway record (`p7c users.create-default zz-keytab-test`),
   open IT while still running as Unix user `taeki` — the key details tab
   MUST NOT appear (different `$record->{'name'}` than `<user-edit.
   unix_user>`).
3. Submit a change to `taeki`'s real record's OWN identity field is
   NOT what to test here — instead, submit ANY ordinary field change while
   the key details tab is present in the schema, then read `taeki`'s
   `details.yaml` directly on disk and confirm it contains no
   `identity_key` key anywhere.
4. Confirm nothing in the zero-field bootstrap path regressed: a fresh
   `create-default`'d throwaway record, opened by `taeki` for a
   DIFFERENT username than `taeki` (so the key tab should NOT show), still
   goes through the existing zero-field cycler bootstrap correctly (this
   is just a no-regression check on step 1's guard-ordering change, not
   new behavior).
5. Clean up: `p7c users.remove zz-keytab-test`.

Report actual command/capture output for each check, not just "passed."

## Explicitly out of scope

- No key creation/rotation/management actions from this tab — display
  only.
- No `keys.console.*` calls anywhere in this change.
- No changes to `users.record.default_fields`/`optional_fields`.
- No generalization of the submit-exclusion into a reusable named list.
- No changes to `plugin.user-edit.registry`'s core mechanism beyond
  whatever minimal, narrow fix step 2's `tab_info` note above turns out
  to actually require (check before assuming — it may need nothing).

#,,,,,,.,,.,,,.,.,.,.,.,,,..,,.,,,,,.,..,,,..,..,,...,...,.,,,,,,,..,,,,.,,,.,
#YUTE7CAKKRA3LMDOKSBDCWPN6L42L5P7JCML45AXJXXIDD2KBJN3BEXRUGFQGZGWM5THPT7P6NAIQ
#\\\|B4HW6UGM43MQMUC36AVRL6Q4NO4FQR2KUNK4PUQDBFWWICRMXIK \ / AMOS7 \ YOURUM ::
#\[7]Z6KLXXOAYBZOQSPZJTLH5E3KF2MP2WVX2LCT4FIGQ6ITSEQYW6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
