# lora trunk route : solar nodes along a road \ forest path

status : idea brief [ 2026-11-19 ] ; after the power layers. related :
data/tasks/power-driver-plugins.md [ power layers, off-grid ], data/tasks/billing-watcher-pattern-first.md
[ outage ladder, certain chains ]

## idea

a route of small solar + battery lora nodes on poles with sun access, along a road or a
forest path. it carries messages where there is no other network, and in protocol-7
style it has intelligence of its own instead of being a dumb relay chain.

## constraints

- bandwidth : a few hundred bit\s to a few kbit\s, depending on spreading factor
- duty cycle : eu 868 MHz sub-bands typically 1 % airtime per node
- energy : each node lives on its own panel and battery

## trunk : several nodes per hop

- each hop position holds a group of nodes [ e.g. 5 ] instead of one -- a trunk, not a chain
- airtime : the duty cycle limit is per node, so a group carries up to n times the airtime
  of one node -- only if the members do not collide : time slots inside the group, or
  different sub-bands \ spreading factors per member [ quasi-orthogonal sf ]
- reliability : any member can carry a packet to the next group ; a failed or shaded node
  only lowers capacity, the route stays up. a chain breaks at its weakest node, a trunk
  degrades gracefully
- energy : the group shares relaying by battery state -- the fullest member takes more

## intelligence per node

- store-and-forward with priorities [ alarms first, telemetry in spare airtime \ sun hours ]
- compact frames : AMOS7 compression, short checksum addresses
- signed messages, checked before forwarding -- foreign or forged frames are dropped, which
  also saves airtime
- local sensor evaluation [ temperature, humidity, smoke, water level, wildlife ], results
  sent instead of raw data ; combined rises form certain chains [ fire : smoke + heat +
  falling humidity ]
- power layers per node and per group, the outage ladder for a group running low

## pieces

existing : signatures, compression, base.interval timers, power layers, on-demand.
new : a lora transport zenka [ radio driver as a plugin, like the power drivers ], group
slot coordination, the trunk routing table.

#,,,.,.,,,,.,,,,.,...,.,.,.,,,,.,,...,,,,,...,..,,...,...,.,.,..,,.,.,,..,.,,,
#YX5B3AV6RUUVCXFZWTLQ3MDTJ7XHNHW2RH5XZZWLNILHTJREW5IYO6CXJEG2Y7RGQOFT7LB7R5CYY
#\\\|UNSQGWA6DUZURL52PAA3SXQPHVBQ5OBYJWI2BPLVRY5E74ZMAUH \ / AMOS7 \ YOURUM ::
#\[7]AINDEQWGJJQ3FBRJMHEE4DI47QICSG7MFKBL7FBO3TY3HEZZYCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
