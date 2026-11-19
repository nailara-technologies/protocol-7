# mail migration appliance profile : out of hosted ms mail

status : brief, not dispatched [ 2026-11-19 ] ; candidate after the billing watcher.
related : data/tasks/billing-watcher-pattern-first.md [ frame, pattern registry ],
cfg/appliances/, smtpd zenka, n7fs

## why

large hosted mail outages make 'what if my mail is gone tomorrow' a real question. an
appliance profile that takes a mailbox over and runs it under the owner's control from then
on is a natural answer.

## shape

- import sources :
  - files : pst \ ost via libpff [ pffexport ] or libpst [ readpst ], both debian packages ;
    msg via Email::Outlook::Message [ perl ] ; eml \ mbox directly
  - live mailboxes : imap, or the graph api where imap is disabled
- every imported mail goes through the smtpd frame [ validate, strip ] and into the store ;
  calendar \ contacts as their own categories
- validation of the import is a step of its own : counts per folder, attachments, embedded
  items, encodings, calendar \ contact entries against the source -- the places where open
  tools tend to lose things
- after the import : smtpd receives, the billing watcher and classify run on it, n7fs keeps
  the copies

## lessons from a real round trip

a company moved from hosted ms mail to an on-premise appliance that was bad, then back to
hosted -- each move company-wide, with all the coordination it took. so :

- the appliance must be clearly better in daily use, not only in principle [ usability is
  functionality ] -- a bad appliance pushes people back and burns the trust for the next try
- export as good as import : the way out [ to imap, mbox, pst ] is a first-class, tested
  path. no lock-in, also not our own -- it is what makes the step in a low-risk one
- gradual, not a big-bang : both systems run in parallel, mail mirrored, users and
  mailboxes move one by one, each can step back on its own ; the coordination load stays
  small because no day has to work for everyone at once
- both ways out of that round trip needed deep scraping of the company's data from
  undocumented container formats, with no vendor support for getting it out. so our own
  storage is documented and plain : the store format is described in the repo, readable
  with standard tools [ maildir \ mbox-like text, p7 config style metadata ], and the
  export never needs a running appliance -- the data on disk alone is enough
- export into whatever the owner wants, also partially and mapped : a subset [ folders,
  senders, time ranges, categories ] into a target with its own structure -- mail into a
  ticket system, contacts into a crm, invoices into accounting, attachments into a file
  tree. the mapping is a small editable recipe [ p7 config style ] built on the same
  frame \ pattern \ category data the store already has ; a mapping can be previewed and
  run again, it is never a one-shot conversion
- kept live, the mapping makes leaving unnecessary : whatever else the owner runs, the
  appliance stays in sync with it [ continuous mapping both ways where the target allows ]
  and becomes the backup they would rather not turn off -- the place that still works
  when the other system fails, with all data current and in a readable format
- the product of a migration is a command : every manual step taken during it [ inside
  the system, recorded ] ends as part of one recipe that produces a complete and current
  export \ conversion of that data on demand. the migration is then not an event that
  happened once but a capability that stays -- and running it continuously is the live
  mapping above
- beyond the one command : on-demand rendering, as with the cached nested templates. the
  target form is a template over the store, rendered when it is asked for and cached by
  its parts -- an export does not have to exist as files at all ; a pst, a ticket view or
  a crm feed is a rendering of the current data, only the parts that changed are rendered
  again
- a file it becomes only at a mobile storage boundary -- and even there the stick can carry
  the appliance itself [ image + store snapshot ] instead of a dead export : it renders
  offline, from the state of its last sync. its validity is a curve over the time since
  that sync [ full if nothing changed meanwhile, falling with the expected change rate of
  that data ], shown with every rendering ; on the next contact it syncs and is current
  again
- because the medium carries its own renderer, it can hold formats nobody else supports
  yet [ 'holographic' : one data set, viewed dynamically from many perspectives ] -- the
  renderer picks its backend by what the host offers : partly browser based, fully native
  with gpu, or software only spread over the cores. the plain, documented store stays
  underneath, so the new format never locks the data in
- the further the native rendering goes, the more a target platform export becomes a
  static snapshot of a calculated state -- whole feature categories have no counterpart
  there. every such export names what it could not carry [ an export report : dropped
  views, flattened layers, links turned into text ], so a snapshot is never mistaken for
  the full thing ; the data itself stays complete in the plain store
- each dropped part names the way back : a short checksum address [ AMOS \ BMW based,
  the reference tree's addressing ] of the full state it came from -- anyone holding the
  snapshot can ask the network for that address and get the live, complete rendering
  again, access rules permitting
- or the difference travels with the export, tightly packed : the snapshot plus the part
  the target could not hold [ layers, views, links, as compact data ]. then the network
  needs to remember nothing -- re-submitting the package reminds it of a prior state it
  can recreate completely. the package is signed and its parts checksum-addressed, so a
  re-submitted state is verified, not trusted ; the address form above stays the light
  variant when the network does keep the state
- signing its own export costs the network nothing : the key it signs with is the one it
  has anyway, nothing new to remember. and the signature is the first filter on the way
  back : a package without a valid signature of this network is dropped before anything
  in it is parsed -- the decoders never see foreign input on this path

## rules

- open tools only : no commercial format library [ owner experience with one : high work
  cost, bug fixes stalled on the vendor's support priorities -- a migration tool must not
  depend on a vendor's queue ]
- format knowledge from that work goes into the validation, not into a dependency
- p7 config style for the profile ; no json internally

#,,..,.,,,,,.,,,,,..,,,.,,,.,,...,..,,,,,,...,..,,...,...,,..,.,,,...,..,,.,.,
#CNRDBPHG2UORK7JGRGY77NV65R32EZD3AIDV3IOY5GWRGK3IKY427T3N5F3R3J6TBEKJVYYCWSE64
#\\\|Y2A4SNBP4KPVYJTK7DRSTKMEG7BX2EV23YVXPWKNUFV4N64YW5Q \ / AMOS7 \ YOURUM ::
#\[7]N2XMYDUVHRHM575MBWV3ZJFTVVNFEM6DLIVKQG4N6MURNZXN5WAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
