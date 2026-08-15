# crypt.C25519 identity-hijack fix + zenka/user key split

## Goal

Fix a real, twice-confirmed bug in `modules/crypt.C25519.key_vars`: the
process's own identity (`<crypt.C25519.base_key_name>`) gets silently
claimed by whichever key name is FIRST passed EXPLICITLY to `key_vars` in
the process's lifetime — not by the process's own deliberate "who am I"
resolution. Then, additively, give `user-edit` a dedicated "user identity"
pointer distinct from the zenka's own process identity, so the two concepts
stop being conflated.

This is scoped narrowly to the confirmed bug and its immediate consumer.
Read `data/ai-mem/claude/bug-crypt-c25519-key-vars-base-identity-hijack.md`
and `data/ai-mem/claude/bug-auth-keypair-client-composition-gotchas.md`
(item #2) first — both document two independent live occurrences of this
exact bug, in unrelated code, on different days. This task fixes the root
cause both were worked around instead of fixed.

## Root cause — read `modules/crypt.C25519.key_vars` directly first

Around lines 29-37:

```perl
if ( defined $key_name ) {   ##  setting base key [ when not defined yet ]  ##
    if ( not defined <crypt.C25519.base_key_name>
        and <[crypt.C25519.key_exists]>->($key_name) ) {
        <crypt.C25519.base_key_name> = $key_name;
    }
} else {
    $key_name //= <crypt.C25519.base_key_name>
        // join( qw| . |, $key_usr, qw| base | );
}
```

This is inverted. A call with **no name** (`key_vars()`, bare) means "who
am I" — this is the legitimate identity-establishing call, made once at
zenka startup by `crypt.C25519.post_init:6` (`my $key_vars_ref =
<[crypt.C25519.key_vars]>;` — no args). A call **with an explicit name**
means "look up this specific key" — used by dozens of other callers across
`crypt.C25519`/`keys.console.*` for keys that are NOT necessarily the
process's own identity. Today it's backwards: the explicit-name branch is
the one that claims `base_key_name` (if unset), while the bare-call branch
computes a fallback and lets it evaporate without persisting it. So
`base_key_name` ends up set by whichever OTHER key some unrelated code
happens to look up first, not by the process's own startup resolution.

## The fix

Swap which branch claims identity:

```perl
if ( defined $key_name ) {
    ## explicit-name lookup: must NEVER mutate base_key_name as a side effect
} else {
    $key_name = <crypt.C25519.base_key_name>
        // join( qw| . |, $key_usr, qw| base | );
    <crypt.C25519.base_key_name> //= $key_name;   ## bare call establishes identity, once
}
```

Net effect: bare calls still resolve to exactly the same default name they
always did (`<user>.base` when nothing else is set) and now correctly
persist it — this is what `crypt.C25519.post_init`'s own startup call
already expects and relies on. Explicit-name calls for a DIFFERENT key no
longer have any side effect on the process's own identity. This is the
ONLY behavior change; every existing caller that calls `key_vars` bare or
with its own real identity name must come out byte-identical.

### Why this is safe for sourcecode/commit signing — verify, don't just trust this

This codebase's pre-commit hook depends on the `proto-7.sourcecode` signing
key resolving correctly — described directly by the project owner as the
one genuinely load-bearing piece of the whole key system today. Traced
already, both resolve it via a **hardcoded explicit name**, never through
`base_key_name`/the bare-call fallback:

- `modules/work.console.commit:19` — `my $sig_key_name = qw|
  proto-7.sourcecode |;` (local literal). The one bare `key_vars` call in
  that file, at line 23, only opportunistically loads the *user's own* key
  into memory (a separate, unrelated `$base_key_name` local var) — it has
  nothing to do with which key actually signs the commit.
- `modules/work.console.commit:31-33` and
  `modules/sourcecode.console.update-signatures:20-22` /
  `modules/source.load_signature_key` — all load/resolve the signing key
  by explicit hardcoded name, regardless of `base_key_name` state.

So this fix should not change sourcecode-signing behavior at all. Still,
**acceptance check #2 below (an actual successful signed commit) is a hard
gate** — prove this live, do not rely on the reasoning above alone.

## Additive: separate "user identity" pointer

`crypt.C25519` only ever had one concept — the zenka PROCESS's own key
(`base_key_name`), inherited across forked children, with no guaranteed
relationship to any human user. `user-edit`'s `identity_key` tab
(`modules/user-edit.form.schema_from_record`, look for the `identity_key`
field def and its explanatory comments referencing the hijack bug) borrows
`base_key_name` today as a stand-in for "the human's own key" — valid for
`user-edit` specifically (a zenka that represents exactly one human) but
conceptually a different thing.

Add `<crypt.C25519.user_key_name>` as a new, separate global var. Default
it via `//=` to `<crypt.C25519.base_key_name>` wherever `user-edit` first
needs it (same file, same place the existing priming call/identity
resolution lives) — do not thread it through `key_vars` itself, do not add
a dedicated setter sub. Match the existing convention already documented in
`crypt.C25519.post_init`'s own header comment (`# note = use
<crypt.C25519.base_key_name> to override the '<user>.base' pattern`) — add
an equivalent one-line note for `user_key_name`.

Then in `modules/user-edit.form.schema_from_record`, the `identity_key`
field switches from reading `<crypt.C25519.base_key_name>` to reading
`<crypt.C25519.user_key_name>`. The existing priming-call workaround (look
for the comments referencing "base_key_name hijack" / "locks base_key_name
in before that guard can ever" around where `identity_key` and `user_keys`
are built) becomes unnecessary once the root-cause fix lands — check
whether it's now dead code and remove it if so, or leave it if it's still
doing something useful; use your own judgement here and note which you did
and why.

## Explicitly OUT of scope — do not touch

- **The empty-checksum bug** (documented in
  `bug-crypt-c25519-key-vars-base-identity-hijack.md`, section "a second,
  DIFFERENT, still-unresolved gap": an encrypted non-identity key's
  checksum comes back incomplete `<::>` when queried from a process that
  already has a different key loaded as its own identity). Do not attempt
  to fix it. Re-test it after your change lands (acceptance check #4
  below) and report whether the symptom changed — that's it.
- A `work_key_name`/purpose-keyed map for things like `proto-7.sourcecode`.
  Checked directly: nothing needs it — see "why this is safe" above. Do
  not add one.
- Any signature-tree redesign, parent-key lifecycle signing
  (activate/remove events), dot-separated key-naming formalization, or
  moving TOFU hostkey pins to a separate directory. All still vision-only
  per `data/ai-mem/claude/project-keys-zenka-integration-direction.md`, not
  ready for implementation.

## Acceptance checks — all live, required (perl -c / ptd -c passing is a
## baseline, not sufficient on its own)

1. `p7c keys.list` (or `Protocol-7 keys list`, whichever this project's
   established headless pattern uses) — output unaffected, same shape as
   before the change.
2. **Hard gate**: make a real change to some harmless file, then actually
   run this project's real commit flow (`work commit "<message>"` /
   whatever invokes `work.console.commit`, through to the real pre-commit
   signature hook) and confirm it succeeds end to end, proving
   `proto-7.sourcecode` resolution is intact. Do not skip or stub this —
   if you cannot exercise the real hook in your environment, say so
   explicitly rather than reporting this check as passed.
3. `user-edit`'s `identity_key` and `user_keys` fields still render
   correctly for a real user record. Use the same `-no-tty`/`char-add`
   headless verification pattern already established for this zenka (see
   `data/ai-mem/claude/topic-user-edit-console-zenka-status.md` for the
   technique) — load a real record, confirm `identity_key` shows the
   correct key name/checksum and `user_keys` still lists the user's other
   keys correctly, exactly as before this change.
4. Re-test the empty-checksum bug (out-of-scope item above, do not fix):
   report whether `proto-7.sourcecode`'s checksum still comes back
   incomplete (`<::>`) when queried from `user-edit`'s process. Just
   report the result.
5. Spot-check one more existing explicit-name caller: call
   `crypt.C25519.sign_data` (or another `key_vars($name)` caller of your
   choice, e.g. `crypt.C25519.key_checksums`) with an explicit name for a
   key that is NOT the process's own identity, in a process that already
   has its own identity loaded (mirrors the exact shape of the original
   auth-keypair bug). Confirm the process's own `base_key_name` is
   unchanged afterward and the correct key was used for the operation.

Report each check's actual result (not just "passed") — this project
distrusts self-reported dispatch summaries and always re-verifies the diff
and live behavior independently after any dispatch.

#,,.,,..,,,..,,,,,,..,.,.,,,,,.,,,,,,,...,,,,,..,,...,..,,,,.,,.,,,,.,.,,,...,
#PXD5MM7U5ZASWE5RDIU5EIITHMAIFDRHWWBQA4BLXVQ4SED7EFQO4ZWGELFLSQNJJS23ZCL2YEECM
#\\\|SJ4GR6BDFV5EQNIVB45VM5YLD6Z2WQEO5S24Y3F2WOCGBN55XZJ \ / AMOS7 \ YOURUM ::
#\[7]JBLCJPNN74BDVSXLQBL6VR47YS3XR2SADLGNMIB5GEWR2VWZI2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
