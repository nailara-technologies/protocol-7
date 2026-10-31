# external access slice 1 inventory
# unknown key, host or user rejection points

summary:
  this document inventories every place in the codebase where an unknown
  key, host or user is currently rejected, refused or denied. for each
  finding, the file and line number is recorded, the current behavior is
  described, and a note is included describing how an authorization buffer
  entry would queue the request instead of failing immediately.

  the authorization buffer [ auth.authorization-buffer ] is the single
  place every channel delivers to. additions for key arrival are:
    - entry type `key_arrival`: key, full fingerprint, channel[s], source,
      first/last seen, the requested user/role
    - expiry, rate limit per source, duplicates merged [ channels appended ]
    - approval = a decision SIGNED by the owner key [ TRUST-CHAIN-STEP2
      owner root ], from any already trusted session, local or remote
    - the one automatic case: a key already certified by the owner key
      [ e.g. a new host of one's own ]. everything else waits for the owner
    - approve writes the host-local user/key mapping [ host cfg dir, never
      the repo ]; only public halves ever travel

review [ claude 2026-10-31, against the code ] :

  the table below lists every refusal, but most must STAY fail-closed :
  bad \ malformed signatures, replay, timestamp, packet type, invalid port \
  link name, failed tcp connect and missing nonce are attacks or errors,
  never a key to approve. only these rows are real queue points :

  | where | today | in the queue |
  |---|---|---|
  | plugin.auth.auth-keypair:48 | user not in the authorized registry -> denied | `key_arrival` [ user, master key, source ] -- the main case : a new remote user |
  | plugin.auth.auth-keypair:177 | tofu result 1 : pinned, awaiting authorization -> denied | already a pending state : make it a `key_arrival` entry, approve = authorize |
  | discover.process_host_packet:240 | host-root changed, not adoptable -> trust invalid, dropped | `key_rotation` entry [ the type exists in AUTHORIZATION-BUFFER.md ] |
  | plugin.auth.auth-keypair:192 | tofu mismatch -> denied | an ALERT entry only, never approvable as a key [ compromise suspected ] |
  | crypt.C25519.validate_remote_key_checksum:63 | pinned vs announced key MISMATCH -> refused | an ALERT entry only [ the tool reports it as mismatch, not unknown ] |

  discover host packets that verify but come from a host never seen are
  the zero-config channel : they belong in the queue as `key_arrival`
  offers [ HOST-SETUP.md : discover OFFERS, the verify step confirms ].

findings [ raw, from coding task-THGZLAY ] :

| file | line | current behavior | authorization buffer replacement |
|------|------|------------------|--------------------------------|
| src/crypt.C25519.validate_remote_key_checksum | 63 | returns FALSE when no pinned key exists for the remote key | queue a `key_arrival` entry of type `tofu_pin` with the remote key fingerprint, source (incoming connection), and requested user |
| src/discover.process_incoming_packet | 65 | returns FALSE when packet signature verification fails | queue a `key_arrival` entry with type `tofu_pin`, marking the host key as unverified pending admin review |
| src/discover.process_incoming_packet | 79 | returns FALSE when packet timestamp format is invalid | queue a `key_arrival` entry with type `tofu_pin`, marking the packet as malformed pending admin review |
| src/discover.process_incoming_packet | 91 | returns FALSE when packet timestamp delta exceeds the 777.777 second limit | queue a `key_arrival` entry with type `tofu_pin`, marking the packet as time-suspicious pending admin review |
| src/discover.process_incoming_packet | 109 | returns FALSE when packet ntime is behind the watermark (possible replay) | queue a `key_arrival` entry with type `tofu_pin`, marking the packet as replay-suspicious pending admin review |
| src/discover.process_incoming_packet | 122 | returns FALSE when packet type is not ANNOUNCE | queue a `key_arrival` entry with type `tofu_pin`, marking the packet as unsupported type pending admin review |
| src/discover.process_host_packet | 197 | returns FALSE when host-root delegation is invalid (drop_reason is set) | queue a `key_arrival` entry with type `tofu_pin`, marking the delegation chain as invalid pending admin review |
| src/discover.process_host_packet | 240 | returns FALSE when host-root changes and does not meet strict forward adoption criteria | queue a `key_arrival` entry with type `key_rotation` (existing identity changing key), pending admin review |
| src/plugin.auth.auth-keypair | 48 | returns 2 and drops binding when user is not in authorized-remote registry | queue a `key_arrival` entry with type `tofu_pin` for the incoming key, pending admin approval before access is granted |
| src/plugin.auth.auth-keypair | 62 | returns 2 and drops binding when master key format is invalid | queue a `key_arrival` entry with type `tofu_pin`, marking the key as malformed pending admin review |
| src/plugin.auth.auth-keypair | 80 | returns 2 and drops binding when session pubkey format is invalid | queue a `key_arrival` entry with type `tofu_pin`, marking the session key as malformed pending admin review |
| src/plugin.auth.auth-keypair | 93 | returns 2 and drops binding when signature format is invalid | queue a `key_arrival` entry with type `tofu_pin`, marking the signature as malformed pending admin review |
| src/plugin.auth.auth-keypair | 117 | returns 2 and drops binding when no server nonce is available for this session | queue a `key_arrival` entry with type `tofu_pin`, marking the session as incomplete pending admin review |
| src/plugin.auth.auth-keypair | 137 | returns 2 and drops binding when signature verification throws an error | queue a `key_arrival` entry with type `tofu_pin`, marking the signature as unverifiable pending admin review |
| src/plugin.auth.auth-keypair | 177 | returns 2 and drops binding when TOFU result is 1 (pinned but awaiting authorization) | queue a `key_arrival` entry with type `tofu_pin`, marking the key as pinned awaiting admin approval |
| src/plugin.auth.auth-keypair | 192 | returns 2 and drops binding when TOFU result is 2 (key mismatch, TOFU violation) | queue a `key_arrival` entry with type `tofu_pin`, marking the key as a potential compromise pending admin review |
| src/plugin.auth.auth-keypair | 201 | returns 2 and drops binding when TOFU result is 4 (TOFU processing error) | queue a `key_arrival` entry with type `tofu_pin`, marking the key as error-state pending admin review |
| src/plugin.auth.auth-keypair | 210 | returns 2 and drops binding for any other TOFU result | queue a `key_arrival` entry with type `tofu_pin`, marking the key as unknown-state pending admin review |
| src/plugin.auth.auth-keypair | 242 | returns 2 and drops binding when signature verification fails | queue a `key_arrival` entry with type `tofu_pin`, marking the key as signature-failed pending admin review |
| src/auth.auth_select | 182 | returns FALSE when server key or nonce is not available | queue a `key_arrival` entry with type `tofu_pin`, marking the server as unavailable pending admin review |
| src/auth.auth_select | 198 | returns FALSE when requested auth method is not available | queue a `key_arrival` entry with type `tofu_pin`, marking the requested auth method as unavailable pending admin review |
| src/external.link.open | 36 | returns false when port is not a valid integer | queue a `key_arrival` entry with type `tofu_pin`, marking the connection attempt as malformed pending admin review |
| src/external.link.open | 38 | returns false when link name is not a valid link name | queue a `key_arrival` entry with type `tofu_pin`, marking the link name as invalid pending admin review |
| src/external.link.open | 58 | returns false when no link identity is configured | queue a `key_arrival` entry with type `tofu_pin`, marking the link as unconfigured pending admin review |
| src/external.link.open | 64 | returns false when tcp connection to target cannot be established | queue a `key_arrival` entry with type `tofu_pin`, marking the connection attempt as failed pending admin review |

open questions [ deduplicated -- the model looped, see review ] :
  - one `key_arrival` type with a `reason` field, or separate types ?
  - expiry of a pending entry [ fixed, e.g. 24 h, or per channel ] ?
  - rate limit per source, per channel, or both ?
  - remembered approvals, revocation, approval expiry [ AUTHORIZATION-BUFFER.md already covers remember / revoke ]
  - notification hook on new entries [ notify zenka ]
  - a deny list of keys always refused

## [ AMOS7 signature block : added at signing -- never write one ] ##

#,,.,,.,,,,,.,,.,,.,,,,,.,,,.,.,.,..,,,..,.,,,..,,...,...,.,.,,..,.,,,.,.,,,.,
#IUS2M2GYGBCIUXORGVDGEM6G72VLDMXSFHU7WOVS7Y4HSM2A3CAN4CQU2B2KALOVOTRUJSBBIB6CQ
#\\\|ENGMP7ZIDEKU7UVT2NUXM3CA2ACUIRIAVG25PU3QG7RYUADNSBW \ / AMOS7 \ YOURUM ::
#\[7]EYPZYIJWG4HUC74SGZCYXGXJC7R4RFVUB6JC3RLBFOVFHEV2FUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
