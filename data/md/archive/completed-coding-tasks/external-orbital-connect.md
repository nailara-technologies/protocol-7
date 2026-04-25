## [:< ##

# name  = [ kimi-task ] external-orbital-connect
# descr = extend external zenka to establish encrypted trunc connections to
#         orbitally discovered nodes via link-upgrade handshake

## objective

extend the external zenka to wire together the orbital discovery layer
(nodes.orbital.*), the trunc connection system (nodes.cmd.add-trunc), and the
encrypted link handshake (base.handler.link-upgrade.*) into a single
connect-by-orbital-address command. a node discovered via discover.orbital or
nameserv DNS can be connected to with one command, resulting in a fully encrypted
persistent trunc connection.

## background

the pieces already exist:
- nodes.cmd.add-trunc: adds a named remote P7 node with IP + public key (TOFU)
- base.handler.link-upgrade.*: implements the ephemeral key handshake for
  encrypted link establishment (Curve25519 ECDH)
- external.init_code: initializes transport registry skeleton
- discover.orbital.known: stores { hostname, pkey, p7ref } for discovered nodes
- nodes.orbital.current_p7ref: our own orbital address

the external zenka needs to orchestrate these into a connection flow:
  orbital address → resolve IP → add-trunc → link-upgrade → encrypted channel

## modules to create

### external.cmd.connect-orbital
- command: connect-orbital <p7ref_or_hostname> [name]
- looks up the target in <discover.orbital.known> by p7ref or hostname
- extracts: ip address (from nodes.local-network.online-hosts or orbital data),
  public key (pkey from discover.orbital.known)
- if not found locally, optionally queries nameserv.cmd.discover-nodes
- derives a connection name from hostname or the CHKSUM7 part of the p7ref
- calls nodes.cmd.add-trunc with name + ip + pkey
- then initiates link-upgrade on the new connection
- stores connection state in <external.connections>->{$name}
- logs at level 2: "connecting to orbital node $name at $ip via $p7ref"
- returns { mode => true, data => "connecting to $name" } (async — connection
  completes via handler)

### external.handler.orbital_connect_reply
- reply handler for the add-trunc + link-upgrade sequence
- receives confirmation that trunc is established
- updates <external.connections>->{$name}->{'status'} = 'connected'
- updates <external.connections>->{$name}->{'encrypted'} = TRUE if link-upgrade
  succeeded
- logs at level 2: "orbital connection to $name established [ encrypted ]"

### external.cmd.list-connections
- command: list-connections
- lists all connections in <external.connections>
- shows: name | orbital p7ref | ip | status | encrypted
- uses existing list infrastructure pattern

### external.cmd.orbital-status
- command: orbital-status
- shows our own orbital P7REF from <nodes.orbital.current_p7ref>
- shows count of known orbital nodes from <discover.orbital.known>
- shows count of active connections from <external.connections>
- shows transport registry state from <external.transports>
- useful as a quick health check for the orbital layer

### external.orbital.sync_grid_fragment
- called after a successful orbital connection is established
- requests the connected node's known orbital addresses via their
  discover.cmd.list-orbital command
- merges received addresses into <discover.orbital.known>
- this propagates the relay cascade: connecting to one node gives us their
  entire known orbital neighbourhood
- log at level 2: "synced $count orbital addresses from $name"

## modules to modify

### external.init_code
- add: <external.connections> //= {} (already has transports/bridges/stats)
- add: <external.cfg.auto_connect> //= 0 (number of nodes to auto-connect
  to on startup from discover.orbital.known, 0 = disabled)
- if auto_connect > 0: set up a one-shot timer (after => 13) to call
  external.cmd.connect-orbital for the N strongest orbital neighbours

## existing infrastructure to use

- <discover.orbital.known> — discovered orbital nodes from discover zenka
- <nodes.orbital.current_p7ref> — our own orbital address
- nodes.cmd.add-trunc — existing trunc connection command
- base.handler.link-upgrade.* — existing encrypted handshake
- <external.transports>, <external.connections> — the registry skeleton
- <[protocol-7.route-send]> for routing to nodes and discover zenki
  use call_args => { args => $string }, NOT param => { hashref }
- <[event.add_timer]>->({ 'after' => 13, 'handler' => '...' }) for one-shot

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code —
it contains essential P7 module conventions that prevent common mistakes.

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- route-send returns count (0 or 1) NOT reply — replies arrive via handler
- the link-upgrade handshake is async — external.handler.orbital_connect_reply
  handles the completion, not the initiating command
- one-shot timer: use 'after' => N with no 'interval' key
- do NOT add fake signature stubs — leave files clean

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave new files clean.

## deliverables

1. modules/external.cmd.connect-orbital
2. modules/external.handler.orbital_connect_reply
3. modules/external.cmd.list-connections
4. modules/external.cmd.orbital-status
5. modules/external.orbital.sync_grid_fragment
6. modified modules/external.init_code (connections hash + auto_connect)

#,,..,.,,,,,,,..,,,,,,.,.,...,,,,,.,.,,..,,,,,..,,...,...,.,,,,,,,,..,...,,,.,
#A4BKBD6HXJ2PH23Y34C2KBNIBQDUB4DTRJ3AXTBKMZMJYO6M54XJRVS7VEEYP4VU7ROGMALTUO7H4
#\\\|Y2QX7CAWK6LVWVCTQEEKV3QV4ZAYFV5E26NC4DOGCTG72L7ZFQD \ / AMOS7 \ YOURUM ::
#\[7]4VXGYAI766JKJEPSMKMJHKBFPFSEXB4HBRRQRUQPYVZ4V35LYMAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
