# space \ route : deterministic deconfliction for counter-directional high-speed routes

brief [ 2026-10-02 ]. design collected in conversation, nothing built yet.
read `data/md/design/SPACE-ENGINE-MASTER.md` [ space.grid-* , space.route-* ,
space.travel-* ] first.

## goal [ user ]

map high-speed routes in countering directions through the network so that
traveling entities need fewer corrections in time. avoidance by a margin
becomes a guarantee, and the guarantee homogenizes into freedom for the
traveling entity : it does not have to think or care about conflicts.

## principle

no negotiation between entities. every participant applies the same
deterministic rule to the same shared state at the same agreed time slice,
so all of them choose complementary maneuvers independently.

1. **candidate set** : compute a larger set of potential exit routes
   [ precomputed maneuver library per octant ]
2. **narrow by present parameters** : pick one candidate by a margin ; the
   others fall into place within the remaining margin
3. **shared time slice** : precision of agreed time = precision of agreed
   state [ position error = speed × time error ; 250 m/s × 100 ns = 0.025 mm ]
   -> the time precision is the margin for the margins
4. **5 of 7 confirms the shared state only** ; the decision follows
   deterministically from it [ BFT : 7 tolerate 2 faulty \ lying, quorum 5 ;
   2-of-3 voting fails on correlated faults, see Lufthansa 1829 ]

## building blocks already in the design

- **polarity** : checkerboard split of the cubic grid [ x+y+z even \ odd,
  the 45° \ FCC sublattices ] -> adjacent cells always have opposite
  polarity -> adjacent entities get opposite evasion sense with no exchange
- **declared intent** : octant bits of the inverted 3D plus
  [ `space.grid.intent`, 3 bits = one 3+1 frame ] travel ahead of the entity
- **pre-provisioning** : sectors on the declared path prepare before arrival
  [ make-before-break handover, like ATC sector handoff ]
- **paths** : few waypoints + Catmull-Rom \ B-spline -> every sector computes
  the high-resolution path itself [ dead reckoning, no position streaming ]
- **bounded search** : max-hops h covers N(h) = (2h+1)(2h²+2h+3)/3 cells
  [ h=50 -> 171801 ]
- **entropy feed** : deterministic pseudo-random tie-break from
  position + time + shared key -> computable for participants,
  unpredictable for outsiders [ a fully public rule lets attackers forecast ]

## prior art to compare against

- TCAS \ ACAS X : pairwise coordination, Mode S address tie-break ;
  weak on multi-aircraft encounters [ Überlingen 2002 : two decision sources ]
- ORCA [ optimal reciprocal collision avoidance ] : each agent takes half
  the responsibility, same rule, no communication -- but no agreed time slice
- live VM migration pre-copy, ETCS movement authority : destination prepared
  before arrival

## first step : simulator

nodes as data structures on the cubic grid, entities on counter-directional
high-speed lanes, pluggable rules [ pairwise baseline vs checkerboard
polarity + shared time slice + 5-of-7 ]. measure :

- corrections per route [ the goal metric : fewer ]
- minimum separation reached [ the guarantee ]
- throughput per lane under density
- behavior with 1 and 2 faulty \ lying participants
- sensitivity to time error [ where does the margin break ]

## attack cases for the simulator [ consensus layer, not bandwidth ]

- **sybil** : one attacker, many identities -> 3 of 7 in one group wins the
  quorum. defense : position = checksum of the key, so placement cannot be
  chosen -> attacker must grind keys until enough land in one group ;
  calculate that cost, do not assume it
- **eclipse** : surround one target so all its neighbors are the attacker's.
  same defense [ unchoosable placement ]
- **coordination across groups** : latency grouping + geographic spread +
  agreed time slices -> an attack must hit several groups inside one slice
  and inside each group's living handshake sequence [ session-specific
  depth, like rolling codes \ nonces ] ; injected traffic outside the
  sequence fails
- **latency is a one-sided bound** : round-trip time proves "not closer
  than" [ distance bounding, speed of light ] but an attacker can always
  add delay -> latency grouping resists pretending to be near, not
  pretending to be far ; check what pretending to be far could gain

hook into `data/web-root/vhosts/space.v7.ax/visualization.html` later
[ `setCurveSet`, `toggleTrails`, `project()` ] -- calm animation defaults.

#,,.,,..,,.,,,.,,,.,.,,..,,,,,,..,.,,,...,,.,,..,,...,...,..,,,,,,.,,,...,...,
#ZHVLCOSZ6SSU7WOCNTDUGLHMJTBCMXTWNKDJ5ZFFUIJXPCDI5S3EFVJDKCIZ7OV44LDDV3VR5RZUM
#\\\|4UG34FU7GPYUWP5DNLMDRK5VYVOP6LWKHMBAK456BEE4R5WSDAJ \ / AMOS7 \ YOURUM ::
#\[7]MV4AVA2JYIZDWMTPEZRL2LECESC44QTLPET3SON6IBR6KWVBFGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
