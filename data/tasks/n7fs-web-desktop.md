# n7fs web desktop : an amiga-feel tree view, written from scratch

status : brief, not dispatched [ owner 2026-11-21 ]. written new, not adopted :
TAWS [ the amiga workbench as a web desktop ] is the reference for feel and
interaction only -- no code is taken. the aim was always better than the original,
the way the owner's own amigas never quite looked stock.

builds on : data/tasks/n7fs-logical-trees-and-mount.md [ trees, views, the n7fs zenka ],
httpd-signed-files.md [ signed delivery ; serving n7fs paths through signed manifests ],
intent-and-pending-decisions.md [ the content abstraction layer, checked lookups ],
desktop-ui-surfaces.md [ theme tokens, povray icon set, pull-down stack, time-based
calm motion, keyboard first ], input-and-window-forwarding.md [ sending the
application : render logic once, then the zenka's state stream ],
data/md/design/WEB-BROWSER-VIEW-STACK.md [ the amiga screen-pull model ].

## what it shows

- n7fs trees and views as drawers [ windows ] with icons ; a tree's categories,
  copies, holders and lifecycle as icon state [ e.g. under-replicated visibly ]
- per entry : name, kind, size, age, data class and an abstract -- the content only
  through the checked lookup [ never the whole tree pushed to the client ]
- several trees \ hosts side by side ; the pull-down stack for switching

## how it is built

- plain javascript, no framework : windows, drawers, icons, menu bar, drag and drop,
  a few hundred to a thousand lines, every line signed and served through httpd
- lazy : the client loads the render logic once, then asks the n7fs zenka for
  listings as the user opens drawers [ a manifest of 270,000 entries is never
  shipped whole ; paging and abstracts ]
- the zenka's state stream keeps open drawers current [ placement progress,
  new trees ] without reloading
- look : the theme tokens and the povray icon set ; the amiga feel [ drawers,
  screen pull, the menu bar ] made better -- translucent blue, calm time-based motion,
  readable at any dpi
- fully keyboard driven [ arrows through icons, enter opens, a key for the menu,
  escape closes ] ; every action also reachable without the mouse

## drawers grow with their content [ owner 2026-11-21 ]

- a drawer starts as a plain listing and becomes gradually more context aware : it
  knows what it holds [ documents, media, a rescue tree, mail ] and offers the
  sub-features that kind of content needs -- a preview, a player, the document record
  and search, the placement view -- until it is everything required to work with
  that content
- each sub-feature is a module that any drawer of that kind loads [ one code base :
  improve the media drawer once, every media drawer gains ]
- the user is never limited to it : the plain listing, the raw entries and the
  restore path stay one key away in every drawer ; a feature-rich drawer is an
  offer, not a wall
- self-similar to the network : a drawer blurs the boundary between presenting
  container and application, the way the zenka network blurs the boundary between
  network and application [ presence, trust, placement are part of the application ].
  in both, function grows from content and context, not from a fixed category --
  which is why the same building blocks serve both scales
- the pattern exists already : in the jobsite page the tab is the channel and the
  result cards grew from plain results into small working objects [ notes,
  compaction, labels ]. drawers, cards and the network follow the same rule --
  elements gain sub-features where their content needs them, and those sub-features
  are shared modules [ a note or label feature written once serves cards and drawers ]
- the one structural distinction : ELEVATED elements [ cards, icons -- objects on a
  surface, carrying state and sub-features ] versus INWARD spaces [ frames, drawers --
  holding elements themselves, nestable ]. the transition is part of the design : an
  icon opens into a drawer, a card unfolds into a frame that holds its notes and
  attachments as elements. sub-feature modules work on both kinds
- the same holds in 3d [ data/md/concepts/CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md ] :
  elevated = objects in a scene, inward = rooms to step into ; recursion follows
  naturally [ a drawer holding a world that holds drawers ], zooming in is moving.
  only what is visible is rendered, to the visible depth [ placeholders and the tint
  transition ], so nesting stays cheap at any depth
- an elevated element can show the space it holds as a miniature in proportion :
  the size shares of its contents, copies against wanted copies, the mix of content
  kinds. proportions stay readable at very low resolution, so the miniature is cheap
  -- and opening it is no jump, the miniature grows into the space
- opening is zooming : the miniature grows until it IS the space, zooming out shrinks
  the space back into an object -- the same thing at two distances. every zoom is a
  step in a tree of zooms ; one key always returns to the session root, and the path
  back is the way you came [ each level re-shrinks in turn, calm and time-based ]
- depth carries specificity : towards the root views and applications are generic
  [ overview, search, placement ] ; using a more specific one pulls you inward into a
  dedicated desktop for that work, which holds any results it produces. returning
  outward brings those results along as objects in the more generic level
- nothing is lost : a full session stays where it happened, at its own scale -- the
  dedicated desktop remains in the zoom tree with its state, seen from outside as its
  miniature. zooming back in resumes it exactly ; only the user deletes a session,
  never leaving it
- one generic miniature form for every session, independent of how complex its
  application is : each session publishes the same small description [ its kind,
  proportions, a few key values, a low-resolution image, its state at a glance ].
  the parent layer lays out, sorts and searches miniatures without loading any
  session's complexity -- a heavy application and a simple listing cost the parent
  the same. povray is the natural minimizer : on idle, the live scene's own data
  [ proportions, angles, zoom, focal length ] is handed to povray, which renders a
  quality still of exactly that view as the session's miniature -- matching what was
  last seen, because it comes from the scene's data, not from a screenshot ; rendered
  in idle time [ the load signals ], cached by the scene parameters
- visual grouping in scale : miniatures group by kind, context, project or time, and
  a group is itself a miniature one level out -- thousands of sessions stay manageable
  at preview quality. rendering adapts to what the host has : the cheapest form on a
  weak device [ flat proportions, no image ], the best available on a strong one
  [ images, live state ], through the same load signals as the transitions --
  local load, and for remote sessions bandwidth and latency of the link : a slow or
  distant link gets proportions and key values first, images only as the link allows.
  hosts on fast links prepare for those behind slow ones : they render, compact and
  pre-assemble the miniatures and groups [ one composed image per group instead of
  many ], so the slow side only receives and places finished parts -- assembly gets
  cheaper where resources are scarce. at the far end : viewport-only devices
  [ light phones, e-ink, a small display ] that compose nothing at all -- they show
  the prepared view and send input back ; all logic stays with the zenki

## actions [ later stages ]

- read : browse, preview through the lookup, restore a tree or a path [ the n7fs
  restore path, with a target ]
- write, staged like the mount : add-only into the incoming pool ; anything that
  changes placement or deletes is an intent the user signs [ intent-and-pending-
  decisions.md ], never a drag-and-drop side effect

## stages

1. read-only : one tree, drawers and icons, lazy listings, keyboard
2. several trees \ views, icon state from placement, the state stream
3. pull-down stack, povray icons, sub-themes per tree category
4. restore actions ; add-only intake ; signed intents for placement changes

## rules

- written from scratch ; no third-party desktop code
- signed delivery through httpd ; fail closed on a missing or invalid signature
- p7 config style for settings, no json in our own formats [ the wire to the browser
  uses what the web zenka already speaks ] ; no sha internally ; perl floor 5.32
- dark violet \ blue, calm motion, keyboard first
- no host names or personal data in repo files or test trees

#,,,,,.,,,,,.,,..,,..,,..,,,.,,,,,,.,,..,,..,,..,,...,...,..,,..,,,.,,,,.,,,.,
#5BJKSIBUESWMRKM3FWUJ2QNAP3VMKY5UKBSJHIU7MU4L6F5RTVM62MLAOPOJAWIWSPT4L7ZBRDBG4
#\\\|C2CRSGX6IRTK3ZGJZVBKGWDEFFKXF35RAXRO5FR3I6G7DV7SDPX \ / AMOS7 \ YOURUM ::
#\[7]TJXKF276BJV4TFL4PPOZ6MSFTNWMZB7LO6K62TFVCKBNAJCIKMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
