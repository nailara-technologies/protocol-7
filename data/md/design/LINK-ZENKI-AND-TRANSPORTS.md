# link zenki and transports

draft 2026-10-22 [ owner + claude ]. design only -- nothing here is built
yet. it turns the by-hand link pri -> delta into a managed one : the link
becomes a zenka of the local cube, named after the host, and the way
its bytes travel becomes a property of the host-edit record. this is the
permanent-link supervisor of todo 3W5.

builds on [ HOST-SETUP.md ] [ records, transports, 'pins name the HOST' ],
[ AUTH-LINK-BINDING.md ] [ auth-keypair v2 + link-upgrade ],
[ ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md ], the transport stack of
[ data/md/documentation/PROTOCOL7_TRANSPORT_HIERARCHY.md ] and todo HS4
[ the same link as the proxy-exit carrier ].

## where it stands [ 2026-10-22 ]

the working path, end to end :

1. delta, once : `external.authorize-link remote-fetch <cube-b32>
   ssh-ed25519 <key>` writes the restricted ssh line
   [ `restrict,port-forwarding,permitopen="127.0.0.1:42",command="/bin/false"`,
   tagged `p7-link:<label>` ] and the cube key pin + authorizing symlink.
   refused unless `cfg/zenki/cube/access.users` already carries a narrow
   `access.cmd.usr.remote-fetch` [ no '*' ].
2. pri, by hand, as the protocol-7 user : `ssh -4 -N -L
   127.0.0.1:4243:127.0.0.1:42 delta`.
3. pri : `external.connect delta 127.0.0.1:4243 remote-fetch` ->
   `external.link.open` : tcp connect, auth-keypair as `remote-fetch`
   with `<user>.base`, server pin check, link-upgrade bound to the auth,
   then a client session NAMED `delta` inside the external zenka.
4. callers route `external.delta.site-yaml.<cmd>` : the cube hands
   `delta.site-yaml.<cmd>` to external, external's route_to_target finds
   its client session `delta` and sends `site-yaml.<cmd>` over it.

access is checked three times : pri cube per caller [ e.g.
`access.cmd.usr.jobsite` ], external's own `access.cmd.usr.cube`
[ `*.site-yaml.import` .. `*.site-yaml.outbox-confirm` ], delta's cube per
link identity [ `access.cmd.usr.remote-fetch` ].

what it lacks :

- **nothing survives a restart** : the forward is a by-hand process ;
  external is `start.on-demand = 1` and opens nothing at init ; after a
  restart the first `external.delta.*` call starts external, finds no
  `delta` session and gets the client-not-present FALSE.
- **no reconnect** for named links [ only orbital has
  `external.orbital.schedule_retry` ] and no liveness check beyond the tcp
  socket.
- **the pin is named after the dial address** : `external.link.open`
  hands its own `host` + `port` to `auth.client.auth-keypair.authenticate`
  -> `auth.client.server_pin.check`, so the live link pins
  `servers/127.0.0.1_4243.public`, not `delta_42`. a supervisor that takes
  a free local port per start would re-TOFU on every restart and two
  hosts could share one pin file over time. HOST-SETUP.md already rules :
  the transport passes the record's name + remote cube port, never the
  forward [ `p-7-r -host` does exactly that ].
- **ipv6 between some hosts is broken** : ssh hung on the v6 address,
  `-4` fixed it by hand. `host-edit.transport.ssh_forward_start` sets
  neither `-4` nor `ConnectTimeout` nor `ServerAliveInterval`.

## idea 1 : the link as a zenka

### what changes for a caller

```
today    external.delta.site-yaml.queue-depth
then     delta.site-yaml.queue-depth
```

`delta` shows in `list sessions`, works through `p7c` \ nshell, and is
granted with the normal `access.cmd.usr.<caller> = delta.site-yaml.*`
lines. inside a select the existing '..' escape reaches it too.

### one process per host record

one link-zenka instance per host-edit record with a link role, managed
by v7-zenki like any zenka : start [ always-on or on-demand ], heartbeat,
restart with backoff, `v7-zenki.terminate` \ `restart`. this instance IS
the 3W5 supervisor. reasons for a process per link, not one process for
all :

- a blocking setup [ Net::SSH2 connect + auth, the bounded auth-keypair
  reads ] stalls only its own link
- restart, drain and logs per host ; one link crashing takes no other
  with it
- v7-zenki's instance machinery [ instance ids, subnames, restart
  timers, dependency gates ] already does the bookkeeping

cost : one perl process per link [ worth measuring on the 512 mb us
nodes ; a hub with a handful of links is fine ].

### how it appears in the local cube

the zenka key is registered under the name the start.cfg passes to
`v7-zenki.callback.setup_zenka_key` [ `'<zenka_name>'` today ] -- the
cube session user IS that name. two ways :

- **A : instance `link[delta]` + a cube alias** -- the config dir is
  `cfg/zenki/link`, the session user is `link` with subname `delta`.
  route_to_target already handles `link[delta].<cmd>` and the on-demand
  start passes the subname [ `$start_name .= '[delta]'` ]. `delta.<cmd>`
  needs a new alias table in the cube [ name -> `link[delta]` ].
  subnames are limited to 17 characters [ `sn_str_re` ].
- **B : the instance registers under the record name** -- config dir
  `cfg/zenki/link`, but the session key goes in under `delta`
  [ v7-zenki passes the link name instead of the config name for link
  instances ]. `delta.<cmd>` routes with no cube change at all. risk :
  the process carries two names -- `link` for its config, `delta` in the
  cube. to verify one by one :
  - v7-zenki code that finds instances by session user name [ heartbeat,
    notify_online, sid-lookup, subname-sids ]
  - the zenka side : what is keyed on `<system.zenka.name>` [ config
    loading from `cfg/zenki/<name>/`, pid \ temp paths, log prefixes ]
    must keep `link`, while the cube login uses `delta`

**recommended : B**, because the cube stays untouched and `list
sessions` shows the host by its name. if the v7-zenki name lookups turn
out invasive, fall back to A with a ONE-line alias rule, never a general
alias system.

### what the link zenka forwards

inside the link zenka, everything not its own goes over the remote
session :

- its own commands stay local : the base set [ `heart`,
  `verify-instance`, `reload`, `cur-pid`, .. ] plus `link-status`,
  `reconnect`
- everything else is forwarded verbatim to the remote cube [ `delta.
  site-yaml.queue-depth` arrives as `site-yaml.queue-depth`, leaves as
  `site-yaml.queue-depth` ]
- the remote cube's own commands are reached as `delta.cube.<cmd>`
  [ the `cube.<cmd>` form zenki already use, e.g. `cube.get-config-names`
  in set-up.cmd.list-exportable -- that it passes the remote access check
  unchanged is to verify ] : a local `heart` must never shadow the remote
  one silently

mechanism : the remote session is the zenka's default route -- the same
idea as select's `base_path` [ a prefix the session carries ], applied
in the link zenka's command handler for every command it does not
define itself. no change to route_to_target in the cube.

### the access points stay three

1. local cube, per caller : `access.cmd.usr.jobsite = delta.site-yaml.*`
   [ unchanged meaning, shorter path ]
2. the link zenka's own `access.cmd.usr.cube` : what may be forwarded
   over THIS link -- generated from the record's roles [ role `fetch` ->
   the site-yaml set ] or written by hand ; '*' is one dotted segment
   [ base.parser.access_conf ]
3. remote cube, per link identity : `access.cmd.usr.remote-fetch`
   [ unchanged ; authorize-link keeps refusing a wildcard grant ]

### commands from the remote side

today a command from delta over the link meets external's access rules
for user `delta` [ none -> refused ]. in a link zenka the cube identity
[ `delta` under B ] is NOT a usable boundary for remote commands : the
zenka itself needs cube grants [ v7-zenki notifications, `nodes`
status reports ], and every session already gets the global
`access.cmd.usr.*` set of `cfg/zenki/cube/access.zenki` [ `p7-log.append`,
`whoami`, `*.subname`, .. ]. a remote command passed on into the cube
would inherit all of that.

rule : **the link zenka filters remote-originated commands itself,
before anything reaches the cube**, against a per-link inbound list
[ default EMPTY -> FALSE to the remote ]. the cube grant for the link
name covers only the zenka's own needs. stage 1 needs no inbound list :
jobsite's `site-yaml.subscribe-fetched` is a stream REPLY on pri's
request, not a call from delta.

### the name problem

four name rules meet here :

| rule | where | allows |
|---|---|---|
| zenka \ user name | `base.regex` `usr_str` | `[0-9A-Za-z][0-9A-Za-z_-]{0,31}`, optional `unix-` prefix, no dots |
| host record name | `host-edit.record.name_valid` | `[a-z0-9][a-z0-9._-]{0,62}` -- dots allowed |
| authorize-link label | `external.cmd.authorize-link` | `[a-z0-9][a-z0-9-]{2,31}` |
| subname | `base.regex` `sn_str_re` | 1 .. 17 characters incl. `.` `:` `+` |

and two traps : an all-digit name matches `sid_str` [ route_to_target
tries the session-id form FIRST ], and a record named `pri.v7.ax` [ it
exists since 2026-10-20 ] can never be a zenka name -- `external.link.open`
already refuses it.

**link name rule** [ the intersection, lowercase ] :

```
^[a-z][a-z0-9-]{0,30}[a-z0-9]$      2 .. 32 characters, no dots, starts with a letter
```

reserved, refused as link names :

- every `cfg/zenki/*` directory name [ `cube`, `external`, `v7-zenki`,
  .. ] and the planned `link` [ `src/link.*` and `cfg/zenki/link` are
  free today ]
- every user name the local cube knows [ access.users, unix- users ] --
  users and zenki share `$data{'user'}`, a collision would put a link and
  a user into one group [ route_to_target sends to ALL sessions of a name ]
- the `unix-` prefix

checked both ways :

- host-edit refuses to save a record with a link role whose name breaks
  the rule or is reserved, and says which zenka \ user it shadows
- v7-zenki refuses to start a link instance whose name is a configured
  zenka, and refuses to start a zenka whose name is a running link
  [ one place holds both lists -- no race between two checkers ]

the local link name and the remote identity stay separate : record
`name` = what callers type [ `delta` ], record `link_user` = what delta's
cube authorizes [ `remote-fetch` ]. one remote label can serve several
hubs.

a reserved prefix instead [ `h-delta.site-yaml..` ] would make the
collision impossible by construction but puts noise into every path --
offered below as an open question, validation recommended.

### '..' : stays select's escape

inside a select, base.handler.command strips a leading '..' BEFORE
route_to_target runs [ single-line commands :
`s,^(\($re->{cmd_id}\) *| *)\.\.($re->{cmdrp}|),$1$2,` ] : `..delta.x`
becomes `delta.x`. once the link is a local zenka, that already reaches
it -- the two meanings converge with no work.

found while reading : the MULTI-line branch [ base.handler.command
around line 184 ] prepends `base_path` with no '..' strip -- inside a
select, a multi-line `..delta.x+` becomes `<base_path>...delta.x`. a
separate small fix, not part of this design.

the `..<nexthop>.` branch of route_to_target answers `FALSE not
implemented yet` and its body after the return is dead [ it checks a
user `mode` of `link` ; no other place in src/ compares or sets that
mode ]. decision proposed :

- '..' stays the select escape [ = the local cube's root ], unchanged
- the nexthop branch is removed when the link zenka lands -- host links
  never use '..'
- 'up one cube' for nested cubes [ NESTED-CUBE-NETWORK-SEGMENTATION.md ]
  gets its own syntax when that design is built, not this leftover

### `external.<link>.` during the move

kept as a thin alias until every caller moved : external forwards
`external.delta.<rest>` to `delta.<rest>` through the local cube
[ the caller's cube-side check already ran ]. jobsite's
`jobsite.cfg.fetch_zenka` [ host.cfg on pri ] moves from
`external.delta.site-yaml` to `delta.site-yaml` in the stage that makes
`delta` routable. the alias goes when nothing configures it any more.

### nodes and add-tronk

three layers, as 3W5 put them : host-edit = what a host IS, the link
zenka = the live link, nodes = whether it is UP. the link zenka reports
`online` \ `offline` to nodes with source `link` [ host-status today
speaks for the lan \ discover only ; the fetch failover reads it ].

`nodes.cmd.add-tronk` only appends `{ name, addr, pkey }` to
`nodes.trunc` -- no connection is ever opened, its status parser returns
'not implemented'. it is retired : host records replace it, no third
path.

## idea 2 : transports

### one interface : a transport yields a stream

every transport ends in ONE connected byte stream to the remote cube's
protocol port. the link layer on top is the same for all : auth-keypair
v2 -> link-upgrade -> session -> heartbeat. so `external.link.open`
splits in two :

```
link.transport.<type>.open( record )  -> fd        [ or undef + why ]
link.session.open( fd, pin_host, pin_port, as_user ) -> session id
```

- `pin_host` + `pin_port` are the record name + the REMOTE cube port
  [ `delta`, 42 ] for every transport -- the pin file never depends on how
  the bytes travel
- a transport whose stream is not a real fd [ the Net::SSH2 channel ]
  hands over one end of a socketpair and pumps the other -- the shape
  p-7-r's ':::' already uses for `ssh -W`

### the record carries the list

`transports` [ ordered, first that works wins ] from HOST-SETUP.md,
values :

| value | meaning |
|---|---|
| `tcp` | direct tcp to an address of `addresses` [ a cube ip socket ] |
| `ssh-w` | `ssh -W 127.0.0.1:<cube port>` on a socketpair |
| `ssh-l` | `ssh -N -L 127.0.0.1:<free>:127.0.0.1:<cube port>` + tcp [ today ] |
| `ssh2` | in-process Net::SSH2 channel [ the ssh zenka's way ] |
| `udt` | later [ HS4, transport.handle.udt-tunnel ] |

plus one new record field : `af` = `auto` | `4` | `6` [ default auto ].
the record keeps `ssh` [ `[user@]host` ] and `ssh_port` as today.

[ the draft atom record said `tcp` though ssh was set -- Q7O's defaults
work makes `ssh-w` the default when `ssh` is filled ]

### the ssh zenka, read fully

`src/ssh.*` + `cfg/zenki/ssh` : a working transport candidate, its
strength the heartbeat-based fast recovery [ owner 2026-10-22 ].
history : deleted in 561cf8e9a [ 2021-09-16, 'deleted ssh zenka',
connection resets ], recovered in acc6cb94b [ 2026-02-23 ]. the recovery
message names the cause : blocking socket writes stalling the event loop,
fixed in '2D64177A' -- that hash exists in no ref, so the cause is
UNVERIFIED and this design does not count it as fixed. [ this clone is
shallow : the two hashes were not looked at here either ]. the test
plan therefore runs the ssh zenka's bridge under load before `ssh2`
builds on it. what it does :

- **connect** : IO::Socket::IP to `ssh.addr:ssh.port` [ timeout
  `connections.timeout`, default 10 s ], Net::SSH2 over that socket
- **host key** : its own pin -- ELF7 + BMW-224 of the remote host key,
  compared with `ssh.hostkey.elf` \ `.bmw` from the profile ; mismatch ->
  disconnect, log level 0
- **auth** : publickey only [ refuses when the server offers no
  publickey, notes when password is enabled ]
- **channel** : `$ssh->tcpip( proto-7.remote.addr, proto-7.remote.port )`
  = a direct-tcpip channel, the same request `ssh -L` and `ssh -W` make
- **remote p7 auth** : waits for the `[:<` banner, sends `auth <user>
  <password>` [ PASSWORD, inside ssh ]
- **local leg** : on AUTH_TRUE it opens a second tcp connection to the
  LOCAL cube [ `protocol-7.network.internal.addr` \ `.port` ] and logs in
  there with a password as `nailara.local.user`
- **bridge** : from then on a byte pump [ `ssh_io` : channel -> local
  cube, `nailara_io` : local cube -> channel ]
- **heartbeat** : every 4.7 s `cube.<local_user>.heart` through the LOCAL
  cube -> into the bridge session -> over the channel -> answered by the
  REMOTE cube. a reply proves the whole path ; no reply within
  `connections.timeout` -> `connection.stop`
- **reconnect** : `connection.stop` re-arms `connection_retry` while the
  profile is enabled -- delay 0.5 s, doubling, capped at 30 s, reset on
  the next successful connect

how it appears in the local cube : as a session of the password user
`nailara.local.user` -- so `<local_user>.<cmd>` in the local cube already
routes to the remote cube. it is idea 1 in an earlier form : a named
remote, routable by name, with end-to-end liveness.

can its bridge carry `external.link.open`'s auth + link-upgrade ? not as
it is, yes as a transport :

- as it is, it speaks the remote auth itself [ password ] and then pumps
  plaintext p7 lines between two cubes -- there is no client session on
  its side that could run auth-keypair or hold the link-upgrade keys
- as the `ssh2` transport : drop the password auth and the local cube
  leg ; the channel becomes the stream [ socketpair pump ] and
  `link.session.open` runs auth-keypair + link-upgrade through it. the
  link-upgrade encryption then runs end to end, link zenka <-> remote
  cube, inside ssh
- its heartbeat and backoff move UP into the link layer and serve every
  transport [ below ]

facts found while reading [ no judgement on the design, things to settle
when it becomes `ssh2` ] :

- `link-setup.example` names `proto-7.local.user` \ `.pass` \ `.addr` \
  `.port`, the code reads `nailara.local.user` \ `.pass` and
  `protocol-7.network.internal.addr` \ `.port`
- its cube grant is still `access.cmd.usr.cube = .. list * *.* #<-FIX`
- it runs as its own unix user `p7-ssh` ; a link zenka runs as the
  protocol-7 user [ its `<user>.base` key + pins live there ]
- connect and auth block the process for up to `connections.timeout` --
  fine for one link per process, the reason the ssh zenka must not carry
  many hosts in one loop
- the ssh host key pin lives in the profile ; for `ssh2` it should come
  from the protocol-7 user's `known_hosts` [ Net::SSH2 `known_hosts` ]
  so `ssh-w`, `ssh-l` and `ssh2` agree on one host key per host

### the comparison

| | `tcp` | `ssh-l` [ today ] | `ssh-w` | `ssh2` [ in-process ] | `udt` [ later ] |
|---|---|---|---|---|---|
| remote exposes | a cube ip socket | ssh only | ssh only | ssh only | a udt port |
| extra process | none | ssh child + a local listener | ssh child on a socketpair | none | none |
| when the link zenka dies | socket closes | ssh child ORPHANED, port stays open | child gets eof, exits | channel closes | socket closes |
| who else can use it | -- | any local user can dial the forward port | nobody | nobody | -- |
| ssh host key | -- | known_hosts | known_hosts | today its own pin ; then known_hosts | -- |
| liveness [ ssh layer ] | -- | ServerAliveInterval [ ssh hop only ] | ServerAliveInterval [ ssh hop only ] | none of its own | its own |
| liveness [ link layer ] | link heartbeat | link heartbeat | link heartbeat | link heartbeat [ the ssh zenka's model ] | link heartbeat |
| reconnect | link backoff | link backoff + port re-pick | link backoff | link backoff | link backoff |
| v4 \ v6 | `Family` of IO::Socket::IP | `-4` \ `-6` | `-4` \ `-6` | `Family` of its socket | its own |
| remote authorizes | cube grant only | authorize-link | authorize-link | authorize-link | cube grant + udt port |

the weighing the owner asked for :

- **ServerAliveInterval** answers 'is the ssh server there'. it does not
  see a remote cube that hangs or restarts behind a live sshd, and it does
  not see a channel the sshd dropped. on its own it only kills ssh, the
  link layer still has to notice the dead stream.
- **the ssh zenka's heartbeat** answers 'does the remote CUBE answer
  through this exact path', every 4.7 s, and starts a reconnect at 0.5 s.
  that is the property to keep -- and it is independent of the
  transport, so it belongs to the link layer, not to `ssh2` alone.
- so : every transport gets the link heartbeat [ the ssh zenka's
  numbers as defaults ], ssh transports additionally get
  `ServerAliveInterval` \ `ServerAliveCountMax` so a dead ssh hop also
  frees its fd fast.
- **`ssh-w` over `ssh-l`** for the managed link : no free-port race, no
  listener another local user can dial, no orphan when the zenka dies
  [ the child's stdio IS the link ], and it is what p-7-r already does.
  `ssh-l` stays for the host-edit enrollment flow and for debugging with
  plain tools.
- **`ssh2` over `ssh-w`** where no ssh binary is wanted or the extra
  process counts [ the small nodes ] ; the price is a perl ssh stack and
  a blocking connect -- one link per process makes that acceptable.

### liveness, reconnect, failure classes

per link, inside the link zenka :

- heartbeat : a bare `heart` to the remote cube over the remote session
  every 4.7 s [ what arrives there from the ssh zenka's
  `cube.<local_user>.heart` too ]
  [ configurable ], timeout `link.timeout` [ default 10 s ] -> close
  the session AND the transport, then reconnect
- backoff : 0.5 s doubling to 30 s, reset after a connect that held one
  full heartbeat ; small jitter so several hubs do not hit one node in
  step
- **transport failures retry, trust failures stop** :
  - connect refused \ timeout, ssh exit, eof, heartbeat timeout ->
    backoff and retry
  - server pin mismatch, delegation refused, AUTH refused, link-upgrade
    binding failed -> state `refused`, log level 0, retry only at the
    30 s cap and never re-pin [ fail closed -- `revoke-link` on the
    remote must look exactly like this ]
- v7-zenki's own heartbeat watches the PROCESS ; the link heartbeat
  watches the PATH. a link that is down is not a process to restart.
- `link-status` reports : transport in use, af used, connected since,
  last heartbeat rtt, retry count, state [ `up` \ `connecting` \ `down`
  \ `refused` ]

the remote's grant must allow what the heartbeat sends : whether a bare
`heart` passes `access.cmd.usr.remote-fetch` without being listed is to
verify ; if not, `heart` joins the narrow list [ harmless ].

### ipv4 \ ipv6

the delta hang : ssh connected to the v6 address and hung. a
`ConnectTimeout` catches a v6 path that drops packets ; it does not catch
one that connects and then stalls [ an mtu black hole ] -- only the link
heartbeat sees that.

- `af = 4` \ `6` : forced, per record [ `-4` \ `-6` for ssh, `Family =>
  AF_INET` \ `AF_INET6` for IO::Socket::IP ]
- `af = auto` : both, with a bounded connect [ ssh `ConnectTimeout`,
  IO::Socket::IP `Timeout` ] ; a family that fails twice in a row
  [ connect or first heartbeat ] is skipped for that record until the
  next zenka start, logged once at level 0 [ 'v6 to delta failing,
  using v4' ] -- runtime state only, the record is never rewritten
  silently
- for delta today : the record says `af = 4` until the v6 path is fixed
- p-7-r's direct tcp uses `AF_UNSPEC` with no connect timeout -- the same
  field applies there

### what the remote authorizes

one `external.authorize-link <label> <cube-b32> <ssh key>` covers
`ssh-l`, `ssh-w` and `ssh2` alike : all three open a direct-tcpip
channel, which `permitopen="127.0.0.1:42"` limits, and none needs a
session channel [ `command="/bin/false"` never runs ]. to verify in the
test plan : `-W` against `restrict,port-forwarding,permitopen` on the
OpenSSH versions in use, and that permitopen matches the exact string
`127.0.0.1:42` [ `localhost:42` would be refused ].

`tcp` needs no ssh line, only the cube grant -- and a cube listening
publicly, which today none does [ HOST-SETUP.md 'incoming, later' ].

the hub side keeps an unattended ssh key for the protocol-7 user [ 3W5 :
its own key + known_hosts, never the owner's ].

### p-7-r on the same record

`p-7-r` is the standalone cli path -- `ssh -W` stays its ssh transport
[ no ssh library in the C client ]. it learns the record :

- `p-7-r <record-name> <command>` : when a readable record of that name
  exists, its `transports` decide [ `ssh-w` -> the existing ':::' code
  with the record's `ssh` + `ssh_port` instead of an alias, `tcp` -> the
  addresses ], `af` sets `-4` \ `AF_INET`, and the pin name is the record
  name + cube port [ what `-host` does today, implied ]
- ':::' with a `~/.ssh/config` alias keeps working unchanged
- open : the records live in host-edit's VAR dir under the protocol-7
  user -- whether a normal user may read them, or p-7-r asks the local
  cube [ `host-edit.record-get` ] instead
- with a local cube running, `:: delta.<cmd>` through the link zenka is
  the short way ; p-7-r is for hosts without one, or to test a path

## staged plan

### stage 1 : the jobsite fetch link pri -> delta survives a restart

smallest step, no cube change, no new zenka yet -- the link modules land
under their final namespace and are loaded by external for now :

1. `link.session.open( fd, pin_host, pin_port, as_user )` : the auth +
   link-upgrade half of `external.link.open`, the pin named after the
   record [ `delta_42` ]. `external.link.open` becomes a thin caller of it
   [ `tcp` transport ], so `external.connect` keeps working
2. `link.transport.ssh-w.open` : fork `ssh -W 127.0.0.1:<port>` on a
   socketpair as in p-7-r, argv checked like `ssh_forward_start`, with
   `BatchMode=yes`, `ConnectTimeout`, `ServerAliveInterval`, `-4` per `af`
3. the supervisor in external : at init, for every host record with
   role `link` : transport -> `link.session.open` -> heartbeat ->
   backoff, failure classes as above
4. external always-on on pri [ host profile, `start-set-up` ] -- or its
   init opens the links before the on-demand queue is flushed [ to
   check which is less code ]
5. the delta record on pri : transports `ssh-w`, af `4`, ssh + ssh_port,
   link_user `remote-fetch`, roles `link fetch`
6. the pin : keep the trust already established. by the code path the
   by-hand link pinned `servers/127.0.0.1_4243.public` [ derived from
   external.link.open, not looked at on pri ] -- it holds delta's
   host-root key id, leaf `delta.cube`, first contacted through ssh.
   move it to `delta_42.public` once when no such file exists [ no new
   TOFU ] ; where a `delta_42` pin exists [ e.g. p-7-r's, under the
   owner's user ] the key ids must be equal, else stop and ask

routing unchanged : `external.delta.site-yaml.*`, jobsite's host.cfg
untouched.

### stage 2 : the link zenka

- `cfg/zenki/link` + `start.cfg`, one instance per record, the name
  registration [ B, or A as fallback ]
- the default route [ forward everything not local ]
- link name rule + reserved names, checked by host-edit and v7-zenki
- `external.<link>.` becomes the thin alias ; `jobsite.cfg.fetch_zenka`
  -> `delta.site-yaml`
- the supervisor modules move from external into the link zenka
  unchanged
- nodes gets `online` \ `offline` with source `link`

### stage 3 : more transports, cleanup

- `ssh2` : the ssh zenka's channel code as a link transport [ socketpair
  pump, host key from known_hosts ] ; the ssh zenka's password bridge
  retires once nothing uses its profiles
- `af = auto` with the per-record skip
- p-7-r reads records
- remove : `nodes.cmd.add-tronk` + `nodes.trunc`, the nexthop branch in
  route_to_target, the `external.<link>.` alias when unused
- remote-originated commands through the per-link inbound list, when a
  use appears
- retire `nodes.add-tronk` from `access.cmd.usr.external` in
  `cfg/zenki/cube/access.zenki` together with the command

### later

- `udt` [ HS4 ] under the same `link.session.open`
- the outer cube for incoming links [ HOST-SETUP.md 'incoming, later' ]
- the HS4 proxy exit over the same links [ one node set, two uses ]

## test plan

two local cubes [ different users \ ports ] stand in for pri and delta
where no second host is needed ; a real `delta` for the ssh and v6 parts.

- **names** : refused -- `pri.v7.ax`, `123`, `cube`, `external`, `link`,
  a configured zenka name, a cube user name, `unix-x`, a 33 char name ;
  accepted -- `delta`, `us-east-1`. v7-zenki refuses a zenka start whose
  name is a running link, and the other way round
- **pin naming** : two link starts on different local forward ports ->
  ONE pin `delta_42`, no second TOFU ; a changed server key -> `refused`,
  no re-pin
- **restart** : restart v7-zenki \ the link holder on pri ->
  `external.delta.site-yaml.queue-depth` [ stage 1 ] \ `delta.site-yaml.
  queue-depth` [ stage 2 ] answers within one backoff cycle, no by-hand
  step
- **remote cube restart** : restart delta's cube -> heartbeat timeout,
  reconnect within 0.5 s + backoff, rtt in `link-status`
- **dead path** : drop packets to delta [ nft on the test host ] -> the
  heartbeat closes the link within `link.timeout`, retries at the 30 s
  cap, recovers when the rule goes
- **v6** : a record with `af = 4` never dials v6 ; `af = auto` against a
  host whose v6 drops packets -> v4 after two failures, one log line
- **no orphans** : `kill -9` of the link holder -> no ssh child left
  [ `ssh-w` ] ; the same test against `ssh-l` documents the orphan
- **revoke** : `external.revoke-link remote-fetch` on delta -> the next
  connect fails as a trust failure, state `refused`, retries only at the
  cap ; re-authorize -> recovers
- **authorization** : `ssh -W` and `ssh -L` both pass the authorize-link
  line, `ssh delta` [ a shell ] and a forward to any other port fail
- **the three access points** : a caller without `delta.site-yaml.*` is
  refused at pri's cube ; a command outside the link's forward list is
  refused by the link zenka ; a command outside `remote-fetch`'s grant
  is refused by delta's cube
- **remote-originated** : a command sent from delta over the link
  [ `p7-log.append`, `whoami` -- the global cube set included ] is
  refused BY THE LINK ZENKA while its inbound list is empty, and never
  shows up in the local cube's log as routed
- **ssh2 under load** [ before stage 3 ] : the ssh zenka's bridge with
  large STRM replies and a slow local reader -- the unverified 'blocking
  writes stall the event loop' cause must not come back
- **streams** : `site-yaml.subscribe-fetched` across a reconnect -- the
  stream ends with the link ; jobsite re-subscribes [ to verify that it
  does ]
- **heartbeat grant** : `heart` passes delta's cube for `remote-fetch`
  [ or is added to the grant ]
- **perl floor** : every new module compiles under the 5.32 floor
  [ `bin/format-code -c` \ `bin/dev/ptd -c` ]

## open questions for the owner

1. **cube name** : B [ the instance registers as `delta` ] or A
   [ `link[delta]` + an alias ] ? recommended B.
2. **collisions** : validation both ways [ recommended ] or a reserved
   prefix for link names [ `h-delta.` ] ?
3. **dotted records** : `pri.v7.ax` cannot be a link name. rename the
   record to `pri` with `pri.v7.ax` in `addresses` [ recommended : the
   record name stays the link name and the pin stem ], or a separate
   `link_name` field ?
4. **default transport** : `ssh-w` for managed links [ recommended ], or
   stay on `ssh-l` because it is the path that ran live ?
5. **`ssh2` host key** : the profile's ELF7 + BMW-224 pin, or the
   protocol-7 user's known_hosts shared with `ssh-w` \ `ssh-l` ?
6. **always-on or on-demand** : on pri the link is wanted at boot ;
   should an on-demand link zenka hold queued commands until the remote
   session is up [ the cube's 'initialized' gate ] instead ?
7. **'..'** : agree that '..' stays select-only and the nexthop branch
   goes ?
8. **p-7-r and records** : read the record file directly, or ask the
   local cube ?
9. **ssh zenka** : once `ssh2` exists, retire the password bridge and its
   profiles, or keep both ?

#,,.,,,,,,.,.,,..,,,,,...,.,.,,,,,,.,,,,.,..,,..,,...,..,,.,.,...,,,.,,,,,,,.,
#N2WK2X6H77MINJEQZRGDC25GPXK7N6O4IA6JDZEZMJ4OI7P4PT6C7LBWF4MX527AXT2LMAXRZZBYW
#\\\|ZPYG3W6CC6DMG4S3VVVDRSTKFRMYKCHTIZBL32Y3E3J2GQLBAS7 \ / AMOS7 \ YOURUM ::
#\[7]664SJAPYX5JLFM2WWG7QV2SMXBCVSCNZFLFY6Z34MRDVRPPIRQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
