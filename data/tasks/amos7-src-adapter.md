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
- the inline loader's decode + verify [ p7_inline_decode_entry, 18e8409f1 ]
- AMOS7::Config [ 68993003f ] : first AMOS7 module sharing zenka logic

## sources [ same interface as the config reader ]

disk src/ < inline bundle < remote [ p7 link, signed entries ] ; signatures checked
for every routine that does not come from the local tree.

## open questions

- where %code \ %data live for a script [ the adapter's package, or main:: like zenki ]
- routines that expect zenka state [ event loop, cube link ] : refuse, stub, or mark
  them outside the profile
- a profile as a named, reusable list [ cfg/appliances style ] or computed per call

#,,.,,..,,..,,,.,,.,,,..,,.,.,.,,,...,.,.,,,,,..,,...,.,.,...,.,.,,.,,...,,,,,
#7X7UEEPYVIQLFG6MHJVP3ARGEZHRGUV6WBBFX7PBTAFZLDJJ3IJH7NJRVP4MWQ75HAAJFR6TAKDH4
#\\\|SSX2C3HB577Z5D5UQZKDV6AIIDJMIZCN752IEWVQT3N53ISSV3Z \ / AMOS7 \ YOURUM ::
#\[7]CIWVCMUWJTIY4Z3D5FGP5EP6SINTBTHC6DCDBC34ECYJBIPV7QBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
