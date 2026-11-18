# AMOS7 src adapter : src/ routines for external scripts

status : direction, not designed [ owner 2026-11-18 ]

## idea

an AMOS7 module adapter lets a plain perl script use regular src/ routines the way
bin/Protocol-7 uses its inline subroutines : the script names what it needs, the
adapter loads exactly that set plus its dependency closure -- a tight profile, no
unused routines. a script using it gets nearly a zenka's capabilities without being
one [ install scripts, p7-deps, p7-install, the image zenka's offline steps ].

AMOS7 is essential already : no new dependency.

## pieces that exist

- dependency data : data/md/documentation/module-dependency-graph.asc,
  bin/dev/gen-sub-whitelist [ per zenka closure ], bin/dev/p7-commit-plan
- the `<[name]>` syntax translation and `%code` \ `%data` conventions [ base.syntax.translate ]
- the inline loader's decode + verify [ p7_inline_decode_entry, b2b3772e5 ]
- AMOS7::Config [ a9cbcec19 ] : first AMOS7 module sharing zenka logic

## sources [ same interface as the config reader ]

disk src/ < inline bundle < remote [ p7 link, signed entries ] ; signatures checked
for every routine that does not come from the local tree.

## open questions

- where %code \ %data live for a script [ the adapter's package, or main:: like zenki ]
- routines that expect zenka state [ event loop, cube link ] : refuse, stub, or mark
  them outside the profile
- a profile as a named, reusable list [ cfg/appliances style ] or computed per call

#,,,.,,.,,...,,.,,...,..,,,..,,..,.,.,,.,,,.,,..,,...,...,...,.,,,..,,,,.,.,,,
#AUAWHATVO77Q3MQXPOYT75ZOPJRPPJWMNCKTPEV6CTZM2GBYHMGEHF5U6PJ5JCJGHXAJNMHRC2JUU
#\\\|5I6IPGOMHKY5AZ6FEBNQ7FIGNVCOBNFBO4IJQU6C47MEEFISK6E \ / AMOS7 \ YOURUM ::
#\[7]3B33ZA65VXJVDOPNIZQGQ57CICB6F7NU7GF4ZXM4W2WQVAHFM4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
