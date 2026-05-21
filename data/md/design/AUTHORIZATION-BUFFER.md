## [:< ##

# authorization buffer
# inspectable pending-approval queue with cryptographic verification
# and persistent remembered approvals

---

## concept

when a zenka, user, or command encounters an authorization boundary it
cannot automatically cross, the request enters the authorization buffer
rather than failing immediately. a human or authorized zenka inspects
the buffer, verifies the cryptographic proof, and approves or denies.
approved decisions are remembered — the same authorization is not asked
twice.

```
new zenka connects with unknown key
  → TOFU pin request enters auth buffer
  → admin: p7c auth.list
  → admin: p7c auth.inspect <id>   ## see key, fingerprint, BMW384 checksum
  → admin: p7c auth.approve <id>   ## remembered permanently
  → connection proceeds

next time same zenka connects: approved automatically, not re-queued
```

---

## buffer entry format

the auth buffer shares column discipline with the P7 log buffer —
ntime B32 as first column, space-separated, parseable by the same tools.
`p7c localtime <ntime>` works on any entry's timestamp.

**compact line format** (for list/log views):
```
<ntime-B32>  <type>      <subject>  <state>    <bmw384-short>  <summary>
XBCDEF123..  tofu_pin    system     pending    ABCD1234        key:EFGH... sig:VALID
YZZZZZ456..  cmd_elev    taeki      approved   BBBB5678        v7.teardown by:taeki
```

the compact format is log-compatible — auth events can be appended to the
main p7-log stream with a distinct prefix, giving a unified timeline of
security events alongside normal operational logs.

**full entry structure** (for inspect/store): each pending authorization has a defined, inspectable structure:

```yaml
id:           AUTH-NTIME-BMW384SHORT          ## unique identifier
type:         tofu_pin | key_rotation | cmd_elevation | route_access
state:        pending | approved | denied | expired
created:      <ntime B32>
expires:      <ntime B32>                     ## 0 = no expiry

subject:
  type:       zenka | user | key
  name:       system
  key_fp:     <C25519 key fingerprint>
  key_pub:    <base32-encoded public key>     ## for verification

request:
  action:     pin_key | approve_cmd | grant_route
  target:     v7.teardown                    ## what is being authorized
  source:     cube.system                    ## routing context
  reason:     "first connection from system zenka"

verification:
  bmw384:     <checksum of: type+subject+request+created>
  signature:  <C25519 signature by requesting key, if available>
  verified:   true | false | unsigned

decision:
  by:         taeki                          ## who approved/denied
  at:         <ntime B32>
  method:     manual | auto_tofu | policy    ## how decision was made
  remember:   permanent | session | N_days

notes: ""
```

the BMW384 checksum covers the request content — admin can verify
`p7c amos-chksum <content>` matches before approving. signature (if
present) proves the requester holds the private key for the public key
in the request.

---

## sort order

auth.list sorts by: numerical ntime primary, category priority secondary.
ntime B32 is reverse-byte-order — never lexicographic, always converted via
`base.ntime_BASE32_to_numerical` before comparison.

```perl
## auth.cmd.list sort spec (pager.sort.multi-key):
{
  keys => [
    {
      field => 'created',
      type  => 'ntime_b32',    ## numerical conversion, not string sort
      dir   => 'asc',
    },
    {
      field => 'type',
      type  => 'priority_map',
      dir   => 'asc',
      map   => {
        cmd_elevation  => 1,   ## most urgent — someone is blocked right now
        tofu_pin       => 2,   ## new identity establishing trust
        key_rotation   => 3,   ## existing identity changing key
        route_access   => 4,   ## route permission expansion
      },
    },
  ],
}
```

if `pager.sort.multi-key` does not yet support `type: ntime_b32` or
`type: priority_map`, extend it — both are generic additions useful beyond
the auth buffer. `ntime_b32` calls `base.ntime_BASE32_to_numerical` before
numeric compare; `priority_map` maps values to integers via a provided map.

## commands

```bash
## list pending authorizations (table view)
p7c auth.list
p7c auth.list 'pending'
p7c auth.list 'type:tofu_pin'

## full inspection of one entry
p7c auth.inspect AUTH-XXXXXXXX
## → shows full YAML, decoded key, BMW384 verification status

## verify cryptographic proof manually
p7c auth.verify AUTH-XXXXXXXX
## → re-computes BMW384, verifies C25519 signature if present
## → reports: checksum OK / signature VALID / key matches fp

## approve — remembered per the entry's remember policy
p7c auth.approve AUTH-XXXXXXXX
p7c auth.approve AUTH-XXXXXXXX remember:30d    ## override remember duration

## deny
p7c auth.deny AUTH-XXXXXXXX
p7c auth.deny AUTH-XXXXXXXX reason:"unrecognized key"

## revoke a previously approved authorization
p7c auth.revoke AUTH-XXXXXXXX
## → moves to denied, clears from remembered store
## → future requests of same type re-enter the buffer

## show remembered approvals
p7c auth.remembered
p7c auth.remembered 'subject:system'
```

---

## remembered approval store

approved decisions persist to the remembered store so they survive restarts.
format mirrors the buffer entry, state = approved, with decision block:

```
data/keys/auth-remembered/
  AUTH-XXXXXXXX.yaml     ## one file per remembered decision
  AUTH-YYYYYYYY.yaml
```

or as a branch in the %data tree:
```
<auth.remembered.AUTH-XXXXXXXX> = { ... }
```

on startup the authorization zenka loads all remembered decisions and
makes them available for fast lookup — no disk read per authorization check.

**remember policies**:
```
permanent    ## remembered forever, survives restarts, key rotation clears it
session      ## remembered until zenka restarts
N_days       ## auto-expires after N days, re-enters buffer on next use
```

---

## authorization zenka

the buffer lives in a dedicated `auth` zenka — isolated, minimal, auditable:

```
configuration/zenki/auth/
  start
  zenka-startup.v7
  access.usr.cube          ## who can read/approve buffer entries
```

cube routes authorization requests to the auth zenka automatically when
a boundary is encountered. access control: only trusted zenki and admin
users can approve (not the requesting zenka itself).

```
## auth/start
access.cmd.usr.cube    = list inspect verify     ## anyone can read
access.cmd.usr.taeki   = approve deny revoke     ## admin can decide
access.cmd.usr.system  = auto-approve            ## system can auto-approve
                                                 ## policy-defined entries
```

---

## integration points

**TOFU pinning** (see SIGNED-COMMAND-INTERFACE.md):
first connection with a new key → auth buffer entry of type `tofu_pin`.
admin verifies key fingerprint and BMW384, approves → key pinned permanently.
subsequent connections: fast lookup in remembered store, no buffer entry.

**signed command interface**:
a command arriving with an unknown key fingerprint (not yet pinned)
→ enters buffer as `key_elevation` rather than hard-rejecting.
gives admin visibility before blocking — less surprising than silent denial.

**route access** (see base-has-access-source-sid-matching.md):
a zenka attempting a route it doesn't have explicit permission for
→ buffer entry of type `route_access`.
admin approves once → access.zenki updated automatically (or remembered
in the auth store as an overlay on the static config).

**credentials zenka** (data/tasks/credentials-zenka.md):
auth buffer is the approval layer for credential access requests —
a zenka requesting a stored credential enters the buffer, user approves,
credential released, decision remembered per policy.

**auto-approval policies**:
the auth zenka can have policy rules for automatic approval:
```
## auth/zenka-startup.v7
auth.policy.auto_approve  = tofu_pin.source:localhost
auth.policy.auto_deny     = tofu_pin.key_age:0  ## brand new key, no history
auth.policy.queue         = *                    ## everything else: manual
```

---

## user experience

```bash
## admin workflow for a new system zenka first connection:
p7c auth.list
## ID                    TYPE       SUBJECT   STATE    AGE
## AUTH-XBCDEF123456     tofu_pin   system    pending  2s

p7c auth.inspect AUTH-XBCDEF123456
## type:    tofu_pin
## subject: system  key: C25519  fp: ABCD...
## pubkey:  <base32>
## bmw384:  VERIFIED ✓
## sig:     VALID ✓ (signed with the key it claims to own)

p7c auth.approve AUTH-XBCDEF123456
## → remembered permanently
## → system zenka connection proceeds
## → log: "auth: tofu_pin approved for system [key:ABCD] by taeki"
```

the cryptographic verification step is explicit and visual — the admin
sees the checksum is correct and the key self-signed before approving.
no implicit trust, no click-through. but also no ceremony — one inspect,
one approve, remembered forever.

---

## connections

- [[SIGNED-COMMAND-INTERFACE]] — TOFU pins flow through auth buffer
- [[NESTED-CUBE-NETWORK-SEGMENTATION]] — cross-boundary first connections
  generate auth buffer entries at the gateway
- [[base-has-access-source-sid-matching]] — route access approvals
- `data/tasks/credentials-zenka.md` — auth buffer as credential release gate
- `data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` — signature-as-identity

#,,..,..,,...,,,.,,,.,,.,,,,.,,..,,..,...,...,..,,...,..,,,..,...,,..,,..,,,.,
#EXVIS544PAEPPW64ASTT25ETZO7VL76ESFIE7LTRUG2ONBAJIR2CZGO232YAPDE5YT45U2UL6SJYE
#\\\|QURRE4B4XXI7LLH32TI6NN6K5M4SEZPIO3PI57R47SHZZJHZRWH \ / AMOS7 \ YOURUM ::
#\[7]DGHSX3XG2BXHQVB2YAJ6QZYN3Z3A6JUZ2Z365WZI63GOQHZIM2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
