---
name: bug-crypt-c25519-key-vars-base-identity-hijack
description: "RESOLVED 2026-08-15, commit 0bd1f6679: key_vars' claim side-effect moved from explicit-name calls to bare calls, root-fixing the twice-confirmed hijack this file originally documented as worked-around-not-fixed. Also added crypt.C25519.user_key_name (separate 'human identity' pointer) and two follow-up fixes in source.load_signature_key the root fix required. The empty-checksum gap below is still open, confirmed unchanged post-fix."
metadata:
  type: project
  modified: 2026-08-15
---

## RESOLVED 2026-08-15 — root cause fixed, not worked around

Commit `0bd1f6679`. Dispatched to kimi (K3-256k) via
`data/tasks/crypt-c25519-key-vars-identity-split.md`, then two more real
bugs found live by the project owner and fixed directly in-session on top
of kimi's landing — see full account below and
[[project-keys-zenka-integration-direction]] for the scoping/advisor
context. The priming-call workaround described further down in this file
is now DEAD, removed from `user-edit.form.schema_from_record`.

**The root fix** (`modules/crypt.C25519.key_vars`): swapped which branch of
the `if (defined $key_name)` claims `base_key_name` — moved from the
explicit-name branch to the bare-call branch. A bare `key_vars()` call
("who am I") now persists its resolution; an explicit-name call ("look up
this specific key") never mutates `base_key_name` as a side effect again.

**Two follow-up bugs found live**, both in `modules/source.load_signature_key`
— the sourcecode-signing zenka's own bare `crypt.C25519.sign_data()` call
(via `source.sign_data`/`source.fill_source_template`) turned out to be
*relying* on the old hijack: the FIRST explicit `key_vars('proto-7.sourcecode')`
call used to accidentally claim `base_key_name` for it, which is exactly
what made the later bare sign call resolve correctly. Root-fixing key_vars
broke sourcecode signing outright, caught live by the project owner running
the real signing command (not by the dispatch's own testing, which never
hit this path since it never has the passphrase to actually sign).
Fixed by making `source.load_signature_key` **deliberately** set the
override, the way `crypt.C25519.post_init`'s own header comment already
documents as the intended pattern:
1. `<crypt.C25519.base_key_name> = $sigkey_name;` — **must be unconditional
   `=`, not `//=`**. First attempt used `//=` and silently no-op'd, because
   `post_init`'s own bare startup call had ALREADY set `base_key_name` to
   `<user>.base` before `load_signature_key` ever runs.
2. `delete <crypt.C25519.key_vars>;` — the SEPARATE full-hashref cache
   (distinct from `base_key_name` itself) has its own early-return guard
   that only checks whether the requested name is undef/matches the
   *current* `base_key_name` — it never checks whether the *cached
   hashref's own* `key_name` still matches. So overriding `base_key_name`
   alone was not enough; a stale cache from the zenka's own earlier
   `post_init` bare call kept getting served to `sign_data`'s later bare
   call regardless. Same invalidation `crypt.C25519.init_code` already does
   once at zenka startup, needed again here since `base_key_name` is now
   changing mid-process, not just once at boot.

**How to apply**: any FUTURE code that deliberately overrides
`base_key_name` mid-process (not just at startup) needs BOTH of these —
an unconditional assignment, and an explicit `delete <crypt.C25519.key_vars>;`
right after. Missing either one fails silently (wrong key used, or stale
cache served) with no error, exactly like the original hijack bug's own
failure mode.

**Additive**: `<crypt.C25519.user_key_name>` — new, separate pointer for
"the human's own identity key," distinct from the zenka process's own
`base_key_name`. Defaults via `//=` to `base_key_name` where `user-edit`
first needs it. `user-edit`'s `identity_key`/`user_keys` fields now read
this instead of `base_key_name` directly.

**Verification**: `keys.list` byte-identical to baseline; an actual
`git commit` succeeded through the real pre-commit signature hook
(`sourcecode verify-p7-signatures` passed against the whole tree); the
sourcecode zenka's real `update-signatures` command — the actual repro the
project owner used to catch both follow-up bugs — signed cleanly after the
second fix.

Read [[bug-auth-keypair-client-composition-gotchas]] item #2 first for the
root cause itself (`crypt.C25519.key_vars`'s `<crypt.C25519.base_key_name>`
global cache gets claimed permanently by whichever key name is FIRST
passed to it explicitly, in a process's whole lifetime) -- found there
2026-08-11 in auth-keypair signing, and independently hit AGAIN here
2026-08-14 in a completely unrelated context: `user-edit`'s `user_keys`
field (list of a user's OTHER C25519 keys, next to the existing
`identity_key` tab -- see [[topic-user-edit-console-zenka-status]]).
Computing a checksum for a second key (`crypt.C25519.key_checksums`/
`cached_chksum`/`keys.checksum_href` all eventually call `crypt.C25519.
key_vars($name)` internally) made `identity_key` itself start showing
that OTHER key instead of the real identity, live-reproduced and
confirmed. Two independent hits on the same sharp edge -- treat this as
a standing hazard for any future code that queries more than one named
C25519 key from a single process, not a one-off.

## the fix used here, NOT a fix to key_vars itself

`user-edit.form.schema_from_record` now primes the cache explicitly,
before any other-key lookup can run:

```perl
<[crypt.C25519.key_vars]>->($identity_name) if length $identity_name;
```

Since `base_key_name` is then already defined, the hijack guard's `not
defined <crypt.C25519.base_key_name>` is false for every subsequent call,
no matter which other key names get queried afterward. Confirmed live
across multiple fresh-process test runs: `identity_key` stayed correct
through repeated `user_keys` checksum lookups once this priming call was
added.

**How to apply**: any FUTURE code in a zenka that already has its own
C25519 identity loaded, and that needs to query a DIFFERENT key by name
for the first time (checksum, public key, anything routing through
`key_vars($name)`), should prime `base_key_name` with an explicit call for
the real identity first, exactly this way -- don't assume querying a
second key by name is side-effect-free.

**Not fixed**: `key_vars`'s own "first explicit caller wins" design is
real, pre-existing, and used by a wide range of other callers across the
`crypt.C25519`/`keys` family -- changing it properly is separately-scoped
work, not something to bundle into a display feature. Left alone
deliberately.

## a second, DIFFERENT, still-unresolved gap found in the same work
## [ re-confirmed unchanged after the 2026-08-15 root fix above, per task ]

Once the hijack was fixed, `user_keys`' checksum for `proto-7.sourcecode`
(an encrypted key, NOT the process's own loaded identity) still comes back
incomplete (`<::>`) in `user-edit`'s process -- even via `keys.
checksum_href`, called bare/unfiltered, the EXACT call shape `keys.
console.list` itself uses and which works correctly there. Tried, in
order, all confirmed NOT to fix it: `crypt.C25519.key_checksums($name,
FALSE, 2)` directly, `crypt.C25519.cached_chksum($name)` (the wrapper
`keys.checksum_href` itself calls, which turned out to reduce to the exact
same underlying call on a cold/uncached key anyway), and finally `keys.
checksum_href` unfiltered/bare, matching the proven-working reference code
line for line.

The one variable that differs between the working case (`keys` zenka, run
fresh via `Protocol-7 keys list`, nothing pre-loaded) and the broken case
(`user-edit`, `taeki.base` already loaded as its own active session
identity before the query) is exactly that pre-existing load. Not
root-caused further -- committed broken (checksum column shows `<::>` for
this case) per user direction, "commit it broken." User may take this on
directly rather than dispatch it further.

## what "identity key" actually means here — a NEW concept, not an existing one

Worth being precise about, per user, since it shapes how any future fix
to `key_vars`/`base_key_name` should be framed: **there was no pre-existing
"user identity key" concept anywhere in `crypt.C25519` before `user-edit`'s
`identity_key` tab.** `crypt.C25519` only ever had "the zenka's base key"
(`base_key_name`) — a property of the PROCESS, inherited across forked
children, with no guaranteed relationship to any human user. `identity_key`
is the first place in this system that names and displays "this is the
human's own key" as a concept at all. It got there by borrowing
`base_key_name` opportunistically, because `user-edit`'s own design
happens to make that borrowing valid — not because `crypt.C25519` was ever
designed to carry that meaning. Any future work generalizing this should
treat "user identity key" as a genuinely new primitive to introduce
deliberately, not something to extract from existing `crypt.C25519`
semantics, because there is nothing there yet to extract.

**Why the borrowing is "to some degree valid," and exactly where that
degree runs out**: `key_vars`'s own bare-call default is
`join('.', $key_usr, qw|base|)` — literally the string `"base"` hardcoded
as the fallback KEY NAME, e.g. `taeki.base`. This name only exists on disk
because `crypt.C25519.autocreate-user-key` is enabled (a config flag) and,
when enabled, autocreates a key under exactly that name if none exists yet
for that user. `"base"` is a NAME, not a semantic marker — it is the
DEFAULT name the autocreate mechanism happens to use, not a guarantee that
whatever key is named `<user>.base` is the user's REAL, intended working
identity. A user could have (or prefer) a differently-named key as their
actual identity; `identity_key`'s current display is only as correct as
the convention "the default autocreated key is the one you actually use"
holds for a given user. It holds today for `taeki` because nothing has
diverged from the default yet — it is not a property `crypt.C25519`
enforces or checks.

[[topic-user-edit-console-zenka-status]]

#,,..,.,.,..,,.,.,,..,,,,,,.,,,,,,,..,,,,,...,..,,...,..,,.,.,.,,,...,.,.,.,.,
#GOK4XEIX3OJRSNMGS37AKRLG446R7YTEF4HYX2F45MX3MCDJC4BFARL77U7YHMCGS2BKHASJWJJBS
#\\\|7OHRGHGLMJPE2DSWIE7DMYI3I2QAEKHA45K4GYE76ZYAWBC7SRV \ / AMOS7 \ YOURUM ::
#\[7]DK34NUXYDWT27N56KIU2KMVSY3BF7PUKKEPGB47QL4LHWTKUWUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
