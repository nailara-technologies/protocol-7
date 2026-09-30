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

#,,,.,,.,,,,,,...,,,,,..,,...,...,.,.,...,..,,.,.,...,...,...,,..,..,,,..,.,.,
#PXMKCR3NZRAGD65P5A3KVO6BEDPN2RO2PDD7LIYEVGAWI3Q5UFEDXUYDXRTQ4QDFNDOTXUCKFIIJE
#\\\|YNTPGKKBBI6RSN5TGSPKHVOPLLGQEAGSPZ3AME2TSPRSVEM772T \ / AMOS7 \ YOURUM ::
#\[7]VQC5U7NH5RDISH2NXZCGYPN5AD2YQ4FESE5ASMYJ6B6JSJOVGGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
