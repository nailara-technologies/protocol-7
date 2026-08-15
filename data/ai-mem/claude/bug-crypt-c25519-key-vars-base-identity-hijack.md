---
name: bug-crypt-c25519-key-vars-base-identity-hijack
description: "SECOND confirmed occurrence of the key_vars base-identity-cache hijack already documented in bug-auth-keypair-client-composition-gotchas.md #2 -- this file adds the concrete priming-call fix pattern (used in user-edit's user_keys field) and a SEPARATE, still-unresolved gap: encrypted non-identity key checksums come back empty when queried from a process that already has a different key loaded"
metadata:
  type: project
---

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

[[topic-user-edit-console-zenka-status]]

#,,,,,,,,,.,,,.,.,.,,,.,.,.,.,.,,,,,,,,,,,,..,..,,...,..,,,..,..,,,,.,,,.,,.,,
#LPRJZ5OORFRKSSY63CAUUAK2GSG7K6JQNDJ3PH4EGJVIGHWL2LVYRUR7W5MBVELAEYCMD5O3KEW2O
#\\\|AZ7SEXCZF3H62QQDQWSFDIO6GCT4WDBE2FPID6R7ZDY6NCZG25J \ / AMOS7 \ YOURUM ::
#\[7]C5GWKNPVP6SKLXUOTWJHAZM2JEEQG2KEKGWWG4RFR5DOLQCSPGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
