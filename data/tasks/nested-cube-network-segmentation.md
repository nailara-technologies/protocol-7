# nested cube network segmentation [ from data/md/design/NESTED-CUBE-NETWORK-SEGMENTATION.md ]

isolated sub-networks with their own cube, bridged by a gateway zenka that
registers as `ext-cube` at the main cube and as `cube` at the inner one.
read `CLAUDE.md` and the design file first.

## state [ 2026-09-30 ]

- a second cube network exists already : `cube-13` [ zulum-13 entropy
  network, `system.zenka.type = cube`, own auth.users \ access.zenki \
  access.users, `base.calc_unix_path` ] -- the precedent for "a zenka
  running cube modules as its own network". start from it
- `ext-cube` : nowhere in src \ cfg yet
- decided 2026-10-09 : the gateway is the outer cube itself [ `ext-cube` at
  the core, a dmz segment ] ; `command-relay` [ `data/tasks/command-relay-zenka.md` ]
  is an optional adapter. first use : incoming links for remote hosts
  [ `data/md/design/HOST-SETUP.md` ]
- the access matching the design relies on [ `access.cmd.usr.cube.ext-cube.web`,
  hierarchical source chains ] is `data/tasks/needs-rewrite/base-has-access-source-sid-matching.md`
  -- needs its rewrite first, or the gateway can only filter by its own rules

## phase 1 : inventory [ read-only ]

1. how cube-13 differs from cube : socket path [ `base.calc_unix_path` ],
   name, config files, which cube.* modules it loads, how its zenki find
   it [ `PROTOCOL_7_UNIX_PATH`, p7c ]. what a third, inner cube would need
2. identity : can one zenka hold two cube sessions under two names today ?
   [ `base.net.connect`, `<user.*.session>`, `base.get_session_id` takes
   a usr_str -- first hint that more than one cube session was planned ]
   ANSWERED [ 2026-10-09 ] : yes -- `zulum` connects to `cube-13`
   [ `base.net.connect:'unix','13','127.0.0.1','cube-13'` ] and to the main cube,
   with one access list per side [ `access.cmd.usr.cube-13` \ `.cube` ]
3. source alias propagation : how the route chain [ `usr.cube.ext-cube.web` ]
   is built today, where a gateway would append its inner source
4. who starts inner zenki : the design says the inner cube or the gateway,
   not the main v7-zenki -- today only v7-zenki starts and supervises zenki.
   a second v7-zenki per network ? [ user 2026-09-30 : multiple v7-zenki \
   cube set-ups and parallelism are queued base features ]

## phase 2 : smallest slice [ after the user's go ]

a gateway that only forwards [ no filtering \ translation yet ] between the
main cube and an inner test cube with one test zenka [ mod-test style ],
with a cross-boundary command both ways and the route chain visible at the
receiver. then filtering by an allow-list at the gateway.

## open questions for the user

- inner zenki supervision : second v7-zenki, the gateway, or main v7-zenki
- whether cube-13 should become the model for inner cubes or stay separate
- order vs. `authorization-buffer.md` [ cross-boundary first connections ]

#,,,.,,,,,,,.,...,..,,,.,,,..,.,,,.,.,,,,,.,,,.,.,...,..,,,.,,,.,,,..,,,,,.,,,
#NEOIVAHGOLBHB2U5IIWLLYDP2GDN25VTJWNBXJ367S6CU7RY7VWDRQNU65F44HINAX2L4LBLXZG74
#\\\|TKMNSQL5OCDYA7WK6PBNB5KFB3NBSDEBEXWCJTVH374IQ4J4TRA \ / AMOS7 \ YOURUM ::
#\[7]J62GSKJFRG6Y24NFLIEFLTEP3GP3GHP7H3ERPHQ3NS2OQWITGQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
