# litter : a team of zenki, sent roaming

status : IDEAS 2026-11-26 [ owner + claude ] -- nothing designed in detail yet. split out of
data/tasks/v7-zenki-anchor.md [ naming block ], where `zenki` became the console command.

## what a litter is

a named GROUP of zenki. the simplest case : zenki started together -- start-set-up.base is
the base litter today, a desktop session another. THE REGULAR USE [ owner ] : a TEAM -- a
group of complementing zenki, prepared together and sent ROAMING with a task or on a mission.

## creating one -- three front ends, one record

- console : `zenki create-litter media mpv X-11 openbox dunst`, `zenki start-litter media`,
  `zenki litters`
- desktop context menu [ the owner's earlier idea ] : `create litter` -- the zenki running
  now saved as a group ; starting it restores that desktop session
- a regular menu command : a litter built FROM SCRATCH in an editor that loads zenka
  templates [ pick zenki, their start parameters, save the group ]

all three write the same litter records [ native format ].

## the record

more than a list of names, from the start, so roaming needs no redesign later :
- the zenki and their start parameters
- ROLES [ e.g. ground \ ring, see the formation ]
- a FORMATION TYPE
- the task or mission
- where it may go [ route constraints ]

## roaming

- the route : a type of ANCHOR ROUTE derived from a public key -- the lambda principle,
  "derived, not stored" [ data/md/design/SUBSTRATE-SYNTHESIS.md:91 ] : every host computes the
  same next anchor from the litter's key, no central record of where it is
- holding together : the DANCING ZENKI formation [ data/md/protocol-7-knowledge/03_FORMATIONS/
  dancing_kittens_formation.md -- "mobile base algorithm" : 7 zenki, 5 ground [ work ] + 2
  ring [ transport ], self-contained routing, shift rotation against saturation \ fatigue ]
- home : the HOME ZENKI RING [ a concept, not written down yet ; the image : the 7 zenki ring,
  data/md/protocol-7-knowledge/06_INTERFACE_PARADIGM/crystal_desktop.md:719 ]

the litter = the group sent with the mission ; the formation = how it holds together inside ;
the anchor route = where it goes.

## what it meets

- the task zenka [ the mission ]
- links \ transports [ how it travels ]
- signed sources \ templates [ verifiable where it arrives -- next list #15 : templates are
  code, signed approval before use ]
- watcher stage 2 [ reporting back as `<signal>@<host>` -- events.signals-since, c6c2d99b90 ]

## open

- the home zenki ring as a concept
- how a litter is admitted on a foreign host [ trust, resources, what it may run ]
- the record format in detail
- "anchor" is taken by the routing sense -- the top process is `v7` [ v7-zenki-anchor.md ]

#,,,.,,..,...,.,.,,,.,.,.,.,,,...,...,.,.,.,.,..,,...,...,.,.,,,,,,..,...,,..,
#MN7KTWLADOATS4CGTG7OPNK4TYENNLOY6P5YUR2Z4M4JAY2B5KCBG33RIIN23NTXTLOCW2RUUTVY6
#\\\|MCKK3GV6S5JOZLRO2WL7MMQODEWQHGT5ELPKKIRLH6I6ASXMPTD \ / AMOS7 \ YOURUM ::
#\[7]IJ6CKG5F6I2BAOC7WJDPJWROQMX44ASBIBO6JZ2TUGQIKGNIFCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
