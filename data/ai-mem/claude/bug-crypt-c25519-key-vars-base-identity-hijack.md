---
name: bug-crypt-c25519-key-vars-base-identity-hijack
description: "crypt.C25519.key_vars sets the global <crypt.C25519.base_key_name> cache to whichever key name it is FIRST called with explicitly in a process's lifetime -- querying any OTHER key by name before the real identity has been established this way silently makes the zenka think that other key is its own identity. Fixed for user-edit's user_keys field via an explicit priming call; the underlying key_vars behavior itself was left alone (real, separately-scoped work, wide blast radius)"
metadata:
  type: project
---

**Found 2026-08-14** while adding a `user_keys` field to `user-edit` (list of
the invoking user's OTHER C25519 keys, next to the existing `identity_key`
tab -- see [[topic-user-edit-console-zenka-status]]). Computing a checksum
for a second key (`crypt.C25519.key_checksums`/`cached_chksum`/
`keys.checksum_href` all eventually call `crypt.C25519.key_vars($name)`
internally) made `identity_key` itself start showing that OTHER key instead
of the real identity, live-reproduced and confirmed.

## the actual bug, read directly from `modules/crypt.C25519.key_vars`

```perl
if ( defined $key_name ) {    ##  setting base key [ when not defined yet ]  ##
    if ( not defined <crypt.C25519.base_key_name>
        and <[crypt.C25519.key_exists]>->($key_name) ) {
        <crypt.C25519.base_key_name> = $key_name;
    }
}
```

`<crypt.C25519.base_key_name>` is a single, process-global keyword slot.
Whichever key name is FIRST passed EXPLICITLY to `key_vars` in this
process's lifetime claims that slot permanently (the guard only fires
`if (not defined ...)`), and every later BARE call (`<[crypt.C25519.
key_vars]>->{'key_name'}`, no name argument -- what `identity_key`'s own
render and much of `crypt.C25519.cmd.get-public-key` use) returns whatever
got cached under that hijacked identity from then on.

A bare call alone never sets this slot -- only an explicit-name call does,
in the branch above. So the ordering that matters is: **whichever caller
first names a specific key wins the zenka's whole notion of "its own"
identity**, regardless of whether that caller meant to claim it.

## why this hadn't surfaced before

Nothing in `user-edit` (or apparently anywhere else touching `crypt.
C25519` from a single long-lived process) had previously called `key_vars`
-- or anything that calls it internally -- with an EXPLICIT name for a
key other than the zenka's own identity. `user_keys` was the first code
to do that in this zenka, by querying a second key's checksum.

## the fix used, NOT a fix to key_vars itself

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

#,,,.,,.,,,..,...,,..,,,.,..,,.,,,,..,.,.,,..,..,,...,...,,..,.,,,,,.,,,,,...,
#GNNL42XNAXPJJ3RVPONJP7I56R6Q6BD7XSMP7U7FHUDLGMAGCALMALP7LILCDP2JEF3ZENPNUETMK
#\\\|P7V2532Q3ENORYUAOHH6TGXEHGVM5ZEQ5WQ363PQGLHRXTXPWKJ \ / AMOS7 \ YOURUM ::
#\[7]E37N5DGIMNKIIBCFAZUOJEYLPYR6BK4GLMXKTB3HWGJX6KYIZODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
