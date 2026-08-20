## [:< ##

# signed command interface
# cryptographically secured high-security commands with optional footer support

---

## concept

certain commands — teardown, host-reboot, forced-mod-reload, key operations —
require cryptographic proof that the sender holds an authorized private key.
the command carries a signature footer (same structure as AMOS7 module
signatures) that the receiving zenka verifies before executing.

for admins the experience is transparent: p7c and p7-r detect that a command
requires signing, invoke a Perl crypto subprocess, and attach the footer.
the admin's key is already present in `src/USR.[username].*`.

---

## signature footer format

mirrors the AMOS7 module signature footer exactly — same crypto, new context:

```
v7.teardown reason:maintenance
#,,.,,...,,,..,..
#<BMW384 of: command-string + timestamp-ntime + nonce>
#\\\|<C25519 signature of above>  \ / AMOS7 \ YOURUM ::
#\[7]<key fingerprint>  7  CMD SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::
```

**fields**:
- BMW384 hash: covers the full command string + ntime timestamp + random nonce
- C25519 signature: signs the BMW384 hash with the sender's private key
- key fingerprint: identifies which key signed (for verification lookup)
- ntime timestamp: replay protection — command valid for configurable window
- nonce: prevents identical commands from producing identical signatures

the footer is stripped by the receiving zenka before the command reaches
its handler — handlers never see raw signature data.

---

## command-level security tiers

```
## in zenka start config (e.g., cfg/zenki/v7/start):
security.cmd.require-signed  = teardown host-reboot forced-mod-reload \
                               root.drop_privs key-operations
security.cmd.signed-optional = restart stop start    ## signed preferred, not required
security.cmd.unsigned         = *                    ## default: all others unsigned ok
```

when a signed command arrives unsigned: rejected with `{ mode: false,
data: 'command requires cryptographic signature' }`.

when a signed command arrives with invalid signature: rejected with
`{ mode: false, data: 'signature verification failed' }` — no information
about WHY it failed (timing attack prevention).

---

## verification in the receiving zenka

```perl
## base.cmd.verify_signature (new module)
## called by command dispatch before handler invocation

my $cmd_string = $call->{'cmd_string'};
my $footer     = <[base.cmd.extract_signature_footer]>->( $cmd_string );

return { 'verified' => FALSE }
    unless defined $footer;

## replay protection: ntime must be within window
my $cmd_ntime  = $footer->{'ntime'};
my $age        = <[base.ntime_age_seconds]>->( $cmd_ntime );
return { 'verified' => FALSE }
    if $age > <[base.cfg.cmd_signature_window]> // 30;

## nonce dedup: reject replayed signatures
return { 'verified' => FALSE }
    if <[base.cmd.nonce_seen]>->( $footer->{'nonce'} );
<[base.cmd.nonce_record]>->( $footer->{'nonce'}, $cmd_ntime );

## verify C25519 signature
my $key = <[crypt.C25519.load_public_key]>->( $footer->{'key_fp'} );
return { 'verified' => FALSE }
    unless defined $key;

my $digest = <[base.chk-sum.bmw384]>->( $footer->{'signed_content'} );
return {
    'verified' => <[crypt.C25519.verify]>->( $digest, $footer->{'sig'}, $key ),
    'key_fp'   => $footer->{'key_fp'},
    'source'   => <[base.cmd.key_to_username]>->( $footer->{'key_fp'} ),
};
```

the verified source identity (username from key fingerprint) is available
to the command handler — `$call->{'signed_by'}` — for audit logging.

---

## p7c transparent signing

p7c (C binary) detects `require-signed` on the target command:

```c
/* p7c: before sending command, check if signing required */
if ( cmd_requires_signature( target_zenka, cmd_name ) ) {
    /* spawn perl subprocess for C25519 signing */
    sign_command_footer( cmd_buffer, user_key_path );
    /* appends signature footer to cmd_buffer */
}
```

the Perl subprocess (`bin/p7-sign-cmd`) handles the crypto:

```perl
## bin/p7-sign-cmd
## reads: command string from stdin + key path from argv
## writes: command string + signature footer to stdout

use AMOS7::CHKSUM::BMW384;
use Crypt::PK::X25519;

my $cmd    = do { local $/; <STDIN> };
my $ntime  = <[base.ntime]>->();
my $nonce  = <[base.random.bytes]>->(16);

my $to_sign = $cmd . $ntime . $nonce;
my $digest  = bmw384( $to_sign );
my $sig     = sign_c25519( $digest, $key_path );

print $cmd . "\n";
print signature_footer( $digest, $sig, $ntime, $nonce, $key_fp );
```

**p7-r** (perl subprocess runner) gets the same treatment — signs before
sending, same subprocess invocation, same key infrastructure.

signing adds ~2ms latency from the Perl subprocess spawn — acceptable for
high-security commands which are never on the hot path.

---

## key authorization

signing proves identity. authorization — whether that identity is permitted
to execute the command — is a separate check via the existing access control
system, extended with key fingerprint matching:

```
## v7/start
security.cmd.authorized_keys.teardown  = <key-fp-taeki> <key-fp-system>
```

a valid signature from an unauthorized key is still rejected. both checks
must pass: valid signature AND authorized key fingerprint.

this separates authentication (you are who you say) from authorization
(you are permitted to do this), cleanly.

---

## optional footer support (non-required commands)

commands that are signed-optional: if a footer is present it is verified
and the verified source identity is available to the handler. if absent
the command proceeds normally as unsigned.

use case: audit trail enrichment — a command handler can log `signed_by`
when present, providing stronger attribution for audit without requiring
all callers to sign.

---

## admin experience

```bash
## p7c transparently signs:
p7c v7.teardown reason:maintenance
## → p7c detects teardown requires signing
## → invokes bin/p7-sign-cmd with ~/.p7/keys/taeki.priv
## → attaches footer
## → sends to cube → v7
## → v7 verifies, executes
## → log: "teardown authorized: signed by taeki [key:XXXX]"

## explicit sign (for scripts):
p7-sign-cmd <<< "v7.teardown reason:maintenance" | p7c -stdin

## verify a signed command without executing:
p7c base.cmd.verify "v7.teardown reason:maintenance
#,,. ...signature footer... "
```

---

## key generation — generate on first use + TOFU pinning

no pre-provisioning required. keys are generated automatically on first use.

**generate on first use**:
```
p7c v7.teardown reason:maintenance
  → p7c: no signing key found for taeki
  → generate C25519 keypair → store at ~/.p7/keys/taeki.{priv,pub}
  → sign command with new key
  → attach public key inline in first signed command:
      #\[7]<key-fp>  7  CMD SIGNATURE :: NEW KEY
      #\[pub]<base32-encoded public key>
```

the receiving zenka sees `NEW KEY` marker and stores the public key
against the fingerprint — trust on first use.

**TOFU pinning** (optional):
```
## v7/start
security.tofu.enabled        = 1
security.tofu.store           = data/keys/tofu/
security.tofu.pin_on_first    = 1     ## auto-pin on first signed contact
security.tofu.strict          = 1     ## reject key changes after pinning
```

once pinned: any subsequent command signed with a different key for the
same identity is rejected — substitution attack prevented. the pinned key
must match forever, or an explicit rotation ceremony is required.

**key rotation**:
```
p7c base.cmd.rotate-key <zenka-or-username>
## → generates new keypair
## → signs rotation request with OLD key
## → new public key attached, old key fingerprint as authorization
## → receiver: validates old-key signature, updates pin to new key
```

rotation requires proving possession of the old key — no rogue rotation
without the private key.

**every entity gets its own key**:
- every zenka: generates key at first signed operation
- every user: key generated at first p7c/p7-r signed command
- every route endpoint: can have its own signing identity
- no central CA, no pre-registration, no certificate expiry
- keys emerge from first use — system self-provisions identity

TOFU is optional per deployment: high-security environments pin aggressively,
development environments may skip pinning for flexibility.

---

## connections

- `src/crypt.C25519.*` — existing key infrastructure
- `src/USR.[username].*` — user key files
- `src/base.chk-sum.bmw384.*` — BMW384 hash
- `bin/p7.c` — p7c binary, needs signing detection + subprocess call
- [[ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT]] — teardown and reboot are first
  candidates for require-signed
- [[base-has-access-source-sid-matching]] — key fingerprint authorization
  builds on the same access control extension
- `data/md/development/CHILD-PROCESS-LIFECYCLE-POLICY.md` — commands that
  affect child lifecycle are natural require-signed candidates

## implementation order

1. `base.cmd.extract_signature_footer` + `base.cmd.verify_signature`
   — receiver side, pure Perl, no binary changes needed
2. `bin/p7-sign-cmd` — standalone Perl signing script
3. v7/start `security.cmd.require-signed` config + dispatch hook
4. p7c signing detection + subprocess spawn (C change)
5. p7-r signing support
6. key authorization list per command
7. nonce dedup store (simple ntime-windowed set)

#,,.,,.,,,,,.,,.,,..,,.,,,,,,,,,,,,,.,.,,,,,,,..,,...,...,.,.,...,,.,,,,.,.,,,
#HAWXTINDO6QDCPDCWZTRZVAP4T2A2QD26CWECQXZ4MBC5C2ZWOS3N5NGTY7H55DQV6PRPBTNVWJPK
#\\\|M3346HSGC3T4KF4CTSNCVPP6MP67KZFAIGQYEIBKXVI4E2MS3KI \ / AMOS7 \ YOURUM ::
#\[7]7DV6IUEWIYR5T35I35DDDCU3TQ3HKXPYYANDWR577T3XD23ARMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
