## [:< ##

# privacy-preserving identity credential system

## core principle

credentials are stored as signatures — not as usernames, public keys,
or any plaintext attribute. the signature IS the identity record.

```
credential = C25519.sign( username || created_ntime || flags, private_key )
```

stored on disk: the credential bytes only.
nothing else is required or retained.

---

## credential structure

the signed payload is a concatenation of whatever attributes the user
chooses to bind to this identity at setup time:

```
payload = username
        | created_ntime     ## high-precision network time of account creation
        | security_level    ## authorization flags (e.g. level 1/2/3)
        | scope_flags       ## optional: allowed services, zenki, channels
        | ...               ## any additional attributes
```

the user signs this payload with their C25519 private key.
the resulting signature is the credential — stored as opaque bytes.

---

## account setup

1. user generates a C25519 keypair locally (never leaves their device)
2. user composes the payload: username + ntime + desired flags
3. user signs: `credential = C25519.sign(payload, private_key)`
4. system stores: `credential` only

system learns:
- that someone with a valid key pair set up an account
- nothing else

system does NOT store:
- username
- public key
- attributes
- any plaintext

---

## login

user presents: `( username, attributes, public_key )`

system verifies: `C25519.verify( credential, payload, public_key )`

if TRUE → user is authenticated with the exact attributes they claimed at setup.
attributes are cryptographically bound — cannot be escalated without re-signing.

system retains nothing from the login interaction (by default).

---

## multiple personas

the same private key can sign different attribute combinations:

```
credential_A = sign( username || LEVEL_1 || created_2025 )
credential_B = sign( username || LEVEL_3 || created_2026 )
credential_C = sign( alt_username || LEVEL_2 || created_2026 )
```

each credential is a distinct opaque blob.
without the private key, there is no mathematical link between them.
forensic analysis of stored credentials reveals: n opaque byte strings.

```
to prove X and Y belong to the same user you need:
  - the private key  (only the user has it)
  - or: observation of the public key at login for both (requires active logging)
  - or: seizure of the device storing the private key
```

---

## key hierarchy integration

different personas can use different child keys derived from the same parent:

```
parent_key
  ├── child_key_A → persona on network X
  ├── child_key_B → persona on network Y
  └── child_key_C → autonomous zenka authorization
```

parent authorizes child keys (signs them).
each child key creates credentials independently.
even with access to the parent key's public component:
- you cannot derive which child keys exist
- you cannot link child key credentials to each other
- you can only verify that a given child key was authorized by the parent

---

## drone / autonomous zenka scenario

a zenka traveling to a foreign P7 node carries:
- its own C25519 keypair
- credentials signed by its user
- no username, no parent network identity, no user public key

the foreign node validates the zenka via its parent key registry (sequential
check — statistically ordered for efficiency, not brute-force). the node
learns: "this zenka is authorized by someone I trust." nothing more.

if the foreign node is later seized:
- credentials on disk: opaque byte strings
- no username, no public key, no parent identity
- no provable link to the user who authorized the zenka

the zenka was there. the user remains unknown.

---

## forensic resistance — progressive erosion model

privacy is the default. surveillance requires deliberate, auditable additions:

```
level 0 [ base architecture ]
  stored:   credential blobs only
  provable: that an authorized credential exists
  hidden:   username, public key, attributes, persona count, user identity

level 1 [ + login key logging ]
  added:    log( login_timestamp, H(public_key) ) per session
  enables:  correlate sessions using the same key
  requires: active logging infrastructure, storage, legal authority to retain
  defeated: using different child keys per context (key hierarchy)

level 2 [ + network traffic analysis ]
  added:    passive observation of connection timing + IP addresses
  enables:  timing correlation across sessions
  requires: network-level access, sustained observation
  defeated: tor / mixnet / P7 relay routing

level 3 [ + seized parent node ]
  added:    access to parent key's public component
  enables:  verify that child credentials were authorized by this parent
  requires: physical/legal seizure of a specific network node
  defeated: multi-hop key hierarchy, distributed authorization

level 4 [ + device seizure ]
  added:    access to private key
  enables:  full identity reconstruction
  requires: seizure of the user's personal device
  not defeated: this is the physical security boundary
```

each level requires a deliberate investment in surveillance infrastructure.
privacy is not achieved by obscurity — it is the structural default.

---

## attribute binding

attributes signed into the credential are immutable:

```
security_level = 3 → stored in credential → verified at login
```

a user cannot claim a higher level than what was signed at setup.
the system grants exactly the attributes bound in the credential — no more.

time-limited credentials: include `expires_ntime` in the payload.
the system checks `current_ntime < expires_ntime` at login.
expired credentials are rejected even with valid signatures.

---

## connection to p7 infrastructure

all primitives already exist:

```
C25519.sign / verify     → crypt.C25519.sign_data / verify_data
ntime                    → base.ntime.b32 (high-precision network time)
BMW384 of credential     → content-addressed storage (same as SHM pipeline)
parent key hierarchy     → discover.process_incoming_packet key cert pattern
sequential key check     → discover parent key registry (ordered by frequency)
```

credential storage in p7: `$data{'auth.credentials'}{bmw384_b32(credential)}`
— content-addressed by BMW384 of the credential bytes.
- lookup: given (username, public_key), compute expected credential, compute
  its BMW384, check if that key exists in the store
- no plaintext index needed
- collision-resistant: two different credentials never share a BMW384 key

---

## what this enables

- **anonymous account creation**: system accepts valid credentials without
  knowing who created them
- **zero-knowledge authorization**: prove you are authorized without revealing
  who you are
- **deniable persona management**: multiple personas with no provable linkage
- **autonomous agent authorization**: zenki authorized by users who remain
  unknown to the nodes the zenki visit
- **seized-system resistance**: a compromised node reveals nothing about its
  users to forensic analysis
- **gradual trust establishment**: start with level-1 credential, create a
  separate level-3 credential later — no audit trail linking them unless the
  user chooses to reveal the link

---

## credential upgrade — self-replacing checksums

content-addressing makes upgrades self-consistent. the credential IS its
address. changing settings creates a new address. two upgrade modes:

```
old_credential  →  BMW384(old)  →  store entry
new_credential  →  BMW384(new)  →  new store entry
```

**mode A — with reference** [ traceable upgrade ]:
```
store[ BMW384(old) ] = { credential: old_bytes, next: BMW384(new), ntime: T }
store[ BMW384(new) ] = { credential: new_bytes }
```
creates an auditable chain: "this identity upgraded to new state at ntime T."
traceability is explicit, voluntary — the user chose a referencing network.
the chain can be followed forward: old → new → newer.

**mode B — without history** [ clean replacement ]:
```
delete store[ BMW384(old) ]
store[ BMW384(new) ] = { credential: new_bytes }
```
old entry vanishes, new entry appears. no link between them.
forensic view: one account ceased, one appeared — unprovably the same user.

**equally safe either way**: new credential's cryptographic strength is
independent of history. the signature validates regardless of whether the
chain exists. safety lives in the signature, not the lineage.

**network-configurable policy**:
```
require_upgrade_reference = yes   ## compliance / accountability network
allow_historyless_upgrade = yes   ## privacy-first network
```
different P7 nodes enforce different policies. the user presents the upgrade
on a network whose policy matches their desired traceability level.

**ntime as voluntary ordering**: `new_credential.ntime > old_credential.ntime`
— if the user voluntarily presents both credentials (e.g. during upgrade
window), sequencing is verifiable even in no-history mode. but the user
controls whether to present both — forced correlation is not possible.

---

## what this does not provide

- **anonymity from the user themselves**: the user knows their own credentials
- **protection against device seizure**: private key access = full reconstruction
- **forward secrecy on stored credentials**: if private key is compromised,
  all credentials signed with it are compromised (use key rotation)
- **resistance against the user's own voluntary disclosure**: privacy is a
  choice, not a constraint

#,,..,,,,,.,.,,..,,,.,,,.,,.,,,,,,.,.,,,,,,,,,..,,...,..,,.,.,...,...,,,,,,.,,
#XZXJ4FJ6UDZ7KMZH44XDR2IJO2EU7AVUBW4VJIQ4FDU4YOIQFU5RRDJ2XNYVNZPQDGQFQC5G5DVOS
#\\\|Q3GFNQAW7OMZ6YNKHFC5BCDUNYU5NTRCCMX4RGW4TC2QWOSHNTR \ / AMOS7 \ YOURUM ::
#\[7]F2EX6YDQ7ZYXLIDR4GZT6D6BABP4XTB43EOTRZLS3S665GMZ4CAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
