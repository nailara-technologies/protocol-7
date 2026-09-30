# authorization buffer [ from data/md/design/AUTHORIZATION-BUFFER.md ]

an inspectable queue of pending authorizations [ tofu_pin, key_rotation,
cmd_elevation, route_access ] : a request that cannot cross an
authorization boundary waits there instead of failing, an admin inspects
and approves \ denies, approvals are remembered. read `CLAUDE.md` and the
design file first.

## depends on

`data/tasks/signed-command-interface.md` -- its open decisions [ key
location, TOFU yes \ no, command tiers ] come first ; tofu_pin and
cmd_elevation entries only exist once those are decided. also related :
`data/tasks/credentials-zenka.md` [ buffer as credential release gate ],
NESTED-CUBE-NETWORK-SEGMENTATION.md [ cross-boundary first connections ].

## corrections to the design file before building

- the design names the zenka `auth` [ `auth.list`, `auth.approve` .. ].
  `auth.*` is already a module namespace in src/ [ `auth.auth_list`,
  `auth.client.*`, `auth.callback.cap-neg.*` -- loaded by most zenki ].
  a zenka named `auth` would route `auth.<cmd>` into that space -- pick a
  different zenka name [ user's choice ] or confirm the routing cannot
  collide
- remembered approvals are security state : where they are stored, who
  can write them, and that a hand-edit is detected [ signature like the
  src files ] must be decided, not defaulted

## phase 1 : inventory [ read-only ]

1. every place today where an authorization is refused outright [ cube
   access checks, unix \ zenka \ keypair auth in auth.client.* and
   plugin.auth.*, unknown keys ] -- which of them could park a request
   instead, and which must stay a hard refusal
2. what exists already : `cred-mesh.request-authorization` [ a dialog
   based approval ], the credentials zenka task -- reuse or replace ?
3. the buffer format : the design wants the p7-log column layout [ ntime
   B32 first ] -- check `base.buffer.*` \ ring buffers for a fit instead
   of a new store
4. expiry : who expires pending entries, what the requester sees while
   pending [ blocked ? retried ? ]

## output

findings with file:line, a proposed zenka name, the list of refusal
points split into "may park" \ "must refuse", open questions for the
user. no src changes in phase 1.

#,,.,,...,,.,,,,,,,..,,.,,,.,,...,,,,,...,...,.,.,...,..,,,,.,.,,,...,.,,,...,
#6KO6VCJFVPZZXMBLBUCOAKHCF4EHIIBLEX6W4XIOF5SXUF7UPP3SJUBBDIVXLKUWUOR7OR5CDC6T4
#\\\|7FYNSTM3J2HF7TSM2XHRGJMYTYEWRQJTF3FPWHGDRS57PSVSRHM \ / AMOS7 \ YOURUM ::
#\[7]6X6RKHYENFIXT7JZ2OTDFIZ25IM2GEDJAJI5OVU25UFGR5GW7YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
