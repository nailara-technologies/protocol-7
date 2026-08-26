## [:< ##

# name  = [ kimi-task ] nodes-orbital-init
# descr = implement nodes.orbital.* namespace — orbital position derivation + publishing

## objective

create the `nodes.orbital.*` namespace — a thin layer that derives a node's orbital
position from its IP address and session key, and publishes it as a time-derived
ADDR_B32 component in a P7REF suitable for pushing onto @INDEXCUBE.

this makes the internal @INDEXCUBE address space and the global orbital address space
the same coordinate system, enabling seamless private+public addressing superimposition.

## background

@INDEXCUBE (declared in bin/Protocol-7, modules base.indexcube.*) is a signed
traversal stack where each entry is a P7REF: TYPE:CHKSUM7:ADDR_B32

currently ADDR_B32 is a static cube coordinate. the orbital model makes it
time-derived: position = orbital_mechanics(seed, session_start_time, current_time)

the seed comes from the node's IP address (octets → orbital parameters):
  octet 1 → azimuth angle θ
  octet 2 → elevation angle φ
  octet 3 → orbital inclination ψ
  octet 4 → CCW angular velocity ω

session_start_time (high-res, tied to user key) gives the phase offset.
position at time T is computable by anyone with the seed — no shared secret needed.

## modules to create

### nodes.orbital.init_code
- load Net::IP::Lite (already loaded by nodes.init_code — confirm available)
- detect local IP address (prefer non-loopback, non-RFC1918 if available,
  else use LAN IP as seed — RFC1918 nodes form the 'inner galaxy' naturally)
- derive orbital parameters from IP octets (θ, φ, ψ, ω as above)
- store session start time in <nodes.orbital.session_start> (use base.time)
- store derived params in <nodes.orbital.params> hashref
- compute initial ADDR_B32 position and push NODE P7REF onto @INDEXCUBE
- set up repeating timer (interval 13 seconds, repeat TRUE) to call
  nodes.orbital.update_position — keeps the published position current
- log at level 2: orbital params derived, initial position pushed

### nodes.orbital.update_position
- called by timer every 13 seconds
- recompute current orbital position from stored params + current time
- encode position as ADDR_B32 (base32r encode the computed coordinate vector)
- update <nodes.orbital.current_p7ref> with fresh NODE:CHKSUM7:ADDR_B32
- do NOT push onto @INDEXCUBE every tick — only update the stored current ref
- log at level 3 (debug only)

### nodes.orbital.current_position
- command handler — returns current P7REF and orbital params
- used by nodes.handler.discover_details_reply extension (future)
- returns: { p7ref, theta, phi, psi, omega, session_start, computed_at }

### nodes.orbital.addr_b32
- utility: given (theta, phi, psi, omega, time_offset) → ADDR_B32 string
- encodes the 4 orbital angles + time offset into a base32r string
- use Crypt::Misc encode_b32r (already available in the system)
- keep it simple: pack the 4 angles as normalized 0-255 values + time component
- the ADDR_B32 format must be [2-9A-Z]{1,16} per existing P7REF conventions

## existing modules to reference

- base.indexcube.push — to push NODE P7REF onto stack
- base.indexcube.here — to read current position
- base.time — for session_start and current time (use precision 5 for microseconds)
- chk-sum.amos — for CHKSUM7 generation (use swap-boundary pattern:
  $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'} — see CRITICAL notes)
- nodes.init_code — already loads Net::IP::Lite, ip_validate, ip_transform available
- Crypt::Misc encode_b32r / decode_b32r — already used throughout

## CRITICAL style and technical notes

- use $ARG not $_ throughout
- lowercase comments only: ## derive orbital params from ip octets
- annotations use [ word ] not ( word )
- no inline subs — all logic in the module file itself
- event timer syntax: { 'interval' => 13, 'repeat' => TRUE } not just 'repeat' => N
- base.perlmod.autoload: one module per call, not a list
- swap-boundary dispatch for chk-sum: $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}
- do NOT add #,,.,,... stub signature — leave file clean for signing system
- file format header required:
    ## [:< ##
    # name  = nodes.orbital.init_code
    # descr = derive and publish orbital position from local ip + session key

## signatures note

do NOT attempt to add, verify, or modify AMOS7 signatures. leave all files
without a signature footer — the signing system adds the real 4-line footer
automatically. any stub or fake signature line will break the signing process.

## integration note

nodes.orbital.init_code should be added to the nodes zenka start file after
the existing nodes.init_code completes. do not modify nodes.init_code itself —
just note where the new init hook goes (cfg/zenki/nodes/zenka.v7).

## deliverables

1. src/nodes.orbital.init_code
2. src/nodes.orbital.update_position
3. src/nodes.orbital.current_position
4. src/nodes.orbital.addr_b32
5. brief note on the start file integration point

#,,..,,..,.,.,.,,,..,,,..,.,.,..,,,..,.,,,,.,,..,,...,...,.,.,,..,.,.,,..,...,
#BBT6CUPPQYYILMENOAOEKUMWEBIZUQHO7I7J3ZBTI43HAYMIM6M4YDSRKKJ7AZ2HCCEURJKV5R4UQ
#\\\|S5D5WGTOOMZ2JDOCAX4EJQ4FTCMSTSEMAQ5LWKE6BMMKHLESPXI \ / AMOS7 \ YOURUM ::
#\[7]KY2AOGMGLWME26XXZROJ6643RTNHVVWK67KORWAZGYWOKIO6ZGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
