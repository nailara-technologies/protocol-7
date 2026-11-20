# billing watcher : inventory, balances, pattern-first extraction

status : brief, not dispatched [ 2026-11-19 ] ; after the rescue \ host prep.
builds on : src/smtpd.classify, data/yaml/pattern-registry/smtpd-classify.yaml,
data/ai-mem/claude/vision-shared-pattern-registry-ncode-smtpd-forensics.md,
data/md/coding-tasks/ncode-zenka-self-refining-regex.md

## why

two real cases [ 2026-09 .. 2026-11 ] were visible in mail alone, but only across mails :

- a vendor billed two accounts for three months -- each invoice looked normal ; one plan
  expected, two paid per month
- a new server was not paid automatically [ payment method without recurring support ] ;
  the invoice read like a payment confirmation until the reminder came
- a billing detail change nobody made knowingly [ browser auto-complete ] created the
  second account

latency is irrelevant here : a warning 15 minutes late is still early.

## shape

1. inventory [ p7 config style, hand-editable, never json ] : one entry per contract --
   vendor, plan \ item, expected amount, cycle, payment method, account \ customer number
2. input : smtpd routes mail with a billing intent [ invoice, payment, reminder,
   account-change ] to the watcher [ a route, no new parser ]
3. extraction, PATTERN FIRST :
   - per vendor \ mail form a registry pattern extracts vendor, amount, period, account,
     invoice number, kind [ invoice \ payment confirmation \ reminder \ change ]
   - full match : no inference at all
   - no match, partial match or an anomaly [ amount off the inventory, unknown account,
     field missing ] : ALWAYS escalate to inference -- task zenka, ':no_tools:', models
     zenki on the remote hosts ; mail content stays on own servers
   - the llm answer is the extraction AND a proposed pattern for that mail form ; the
     pattern enters the registry as a candidate, auto-apply after it reproduces the llm
     result on later mails [ confidence \ false-positive stats as in the registry format ]
   - the patterns and the llm see the FRAMED content only [ section below ]
4. matching [ deterministic, the llm never decides ] :
   - invoice open past N days without a payment -> warning
   - more paid than the inventory expects for a vendor \ period -> possible duplicate
   - reminder -> urgent at once
   - billing \ account detail change -> always reported, with the changed field
   - invoice from an unknown vendor or account number -> confirm : new contract ?
   - expected invoice missing -> quiet hint [ lapsed or moved subscription ]
5. balances : payment notifications per method [ card, paypal, bank ] give a running
   balance of outgoing payments against the inventory -- also payments without invoice mail
6. alerts to the owner's channel ; checks timed by base.interval.next [ human scale,
   13 \ 15 minutes ]

## validating frame [ before any pattern or llm sees the mail ]

a reader step, like a text browser or mail reader shows a mail : the frame VALIDATES the
envelope and strips it, the content goes on alone.

- validate : the mail must come from the channel's real infrastructure, not look made up
  or sent from foreign servers -- spf \ dkim \ dmarc results, received chain against the
  vendor's known relays, sender domain, reply-to \ link domains against the inventory
  entry. a failed check is itself an alert [ phishing shaped like an invoice ] and the
  mail never reaches extraction
- strip : headers, mime structure, html to text [ text browser rendering ], quoted
  replies, tracking links, signatures and static footers [ legal text, unsubscribe,
  address blocks ] -- per channel the footer is learned once : a block repeated
  unchanged in every mail of a channel is clutter
- result : channel id [ vendor + validated sender ] + the bare content. the channel is
  already known, so patterns need not re-detect it from clutter -> narrower, sharper
  patterns, and the llm gets a short clean text [ less tokens, less distraction ]
- the frame is generic smtpd work, not billing specific : every smtpd consumer
  [ classify, jobsite mail, forensics ] gains from it

## without an inventory : semantic tree, then weighted tags

- grouping : framed mails go into the dedup tree with its semantic core ; equal distance
  rules group them -- a stable cluster with a regular rhythm [ same vendor, structure,
  customer number, recurring amount ] is a proposed inventory entry, the owner confirms
  from the tree instead of writing the inventory
- payment side to account side : a card \ paypal \ bank line [ 'PAYPAL *VENDOR', amount,
  booking date ] and an invoice [ plan, period, customer number ] are not close in the
  semantic tree -- candidate pairs are scored with weighted tags :
  amount [ high ], reference \ invoice number in the payment text [ decides alone ],
  vendor alias [ learned ], booking date within N days [ falls with distance ],
  payment method as in the inventory [ low ]
- above the threshold : matched ; two close candidates : ambiguous -> inference, then owner
- weights learn from confirmed \ rejected matches [ as the registry's confidence and
  false-positive stats ] ; a duplicate shows as two payment lines matching one expected
  entry strongly
- the owner's step is a graph : clusters as nodes, matched payment \ invoice pairs and
  their tag weights as edges, in a flexible graph view [ dark theme ]. pre-editing there
  -- merge \ split clusters, drop a node, pin an alias, confirm a pair -- creates the
  inventory ; dropping is the last pruning of patterns that are not relevant, and the
  registry keeps it as a rejected pattern so the same noise does not come back
- the inventory is a LAYER over that graph, not a separate list : its nodes are always
  groups [ contracts ], superimposed cleanly on the whole generated layer below. items of
  the lower layer snap magnetically into an inventory group -- the attraction is the
  weighted tag score, a strong match snaps on its own, a weak one only when the owner drags
  it close. a snap is the group decision ; the generated layer stays intact underneath and
  can be regenerated without losing the owner's decisions
- several overlay layers on the same lower layer = several accounting perspectives :
  per contract [ the inventory ], per payment method [ balances ], per project \ host
  [ what a server or a zenka costs ], per tax year. each layer is its own relative view,
  the same item can sit in a group of every layer. items are never copied, only grouped
  -- so no perspective counts twice, and each layer can be checked on its own [ every
  item of the lower layer placed or explicitly left out ]

## infrastructure link

- payment \ advance payment status becomes an attribute of the host or service it pays
  for [ the project \ host layer ] : paid until, next due, auto-payment active, method
  - in technical dashboards it gives reasoning for an outage [ host gone : unpaid ? ]
  and advance warning before one [ due soon, auto-payment failed, reminder received ]
  - v7-zenki \ discover can show it next to heartbeat and uptime
- in reverse : where a provider allows advance payment, the balances decide when and how
  much to prepay, to smooth payments and keep a safety margin per host
- precautions when an outage is foreseeable and no resolution is detected despite the
  warning [ a degradation ladder, each step reversible, each one announced ] :
  framing : the ladder switches the optimization target from the generic default to one
  that knows two futures -- 'nothing happens' and 'the outage has just occurred' -- and
  picks the state that is cheap in the first and already prepared for the second ;
  the probability of the outage moves the weight between the two, step by step
  some chains are certain, only their timing is open : no payment -> no service [ after
  the provider's grace period ], laptop on battery without cable -> host down [ after the
  discharge time ]. for those the probability is 1 and the work is estimating the time
  window [ grace period from the provider's terms or past reminders, discharge rate from
  the battery readings ] -- the ladder then runs on a schedule, not on a guess
  between those, signals move the probability : a flapping state [ a loose power cable,
  charge \ discharge toggling, a link going up and down ] is counted -- toggle rate and its
  trend over time ; a rising rate means degrading, the weight moves toward the outage
  future. the aim is no surprise : when it finally stays off, both futures were already
  prepared, only which one came true is resolved
  no linear extrapolation : degradation often accelerates [ wear, a loosening contact ],
  so the trend is read as a curve and the time window is taken from its steep side --
  the ladder must not wait for the outage a straight line would predict
  feedback : for caused risks [ attacks, sabotage ] the preparation lowers the
  probability itself -- a disruption that clearly will not have its effect is less
  likely tried. so 'nothing happened' does not prove the preparation was wasted, it can
  be its result : the passive steps that are cheap stay as the default for known risk
  classes, they are not undone just because the event did not occur
  and the steps that are reverted still leave something : each episode is recorded
  [ trigger, signals, steps taken, timing, what was needed in the end ] so the next
  similar case starts from it. repeated episodes turn manual steps into built-in
  behaviour -- often implicitly, as a default that was improved or a margin that grew
  -- until the step is no longer a step
  the records are also a corpus : a manual step is itself a signal [ the need for manual
  steps has its own probability pattern ], and every later design can replay the recorded
  episodes against its model -- would it have seen it coming, which step would it have
  taken, when -- before it runs live
  so the best manual steps are taken from within the system, with its own tools
  [ p7c \ nshell commands, zenka commands ] : the records are then precise enough
  [ command, arguments, order, timing, result ] to become a workflow branch directly.
  a step done outside [ a hand edit over ssh, a provider's web portal ] leaves a gap the
  corpus can only describe, not replay -- a reason to give such steps a command first
  for that the system's tools must be the better choice, without outliers -- a step is
  only taken inside when inside is easier. usability counts as functionality : a clumsy
  command is a defect like a wrong result, fixed with the same priority. what still has to happen in outside tools
  runs inside an encompassing embedding that sees its payload : ssh through p-7-r \ the
  terminal zenka [ keystrokes and output recorded ], provider portals through the
  web-browser zenka [ capture \ replay \ waypoints ] -- the outside step becomes a
  recorded one, and the record can grow into a command later
  0. passive preparation, invisible to users, as soon as the risk is seen :
     hot standby of the data around the predicted outage zone [ n7fs copies complete and
     current outside it ], DNS TTLs lowered [ nameserv ] for the names the zone serves, so a
     redirection takes effect in minutes ; TTLs restored once the risk is gone
     -- the shorter TTLs raise the query load : hosts that are not nameservers all the
     time can join as extra nameserv instances [ outside the outage zone ] for that
     window, and leave again with the restored TTLs ; the lowering must lead the switch
     by at least one old TTL [ caches hold the old value until then ]
     -- this is predictive, not reactive scaling : a load threshold would start instances
     after the load arrives ; here the load is known before it exists, so placement is
     planned with no pressure : services reshuffled to the hosts that fit them best by the
     known statistics [ latency to the queriers, spare cpu \ memory, link quality, the
     host's own risk ] before any of the load arrives
  1. warn the owner, again with rising urgency [ base.interval rhythm ]
  2. move state and replicas off the host at risk [ n7fs copies, zenki with a fallback host ]
  3. shift inference : remote sources at risk -> other remotes -> local gpu, smaller models
  4. service minimization : keep the basics alive [ cube, keys, links, n7fs, mail intake ],
     pause the optional load [ assessments, batch work ]
  steps back up automatically once payment or the source returns ; the owner can pin
  any step. the trigger is a combination [ due date passed, no payment matched, reminder ],
  never one signal alone
- this is the external edge of the resource accounting work [ RESOURCE-ACCOUNTING-UNIFIED.md,
  read-me/documentation/dev/NRT.NRD.asc ] : a host's paid-until time is a resource
  balance like any other, money in from the owner's side, time of service out

## raw mail archive : incoming and outgoing [ owner 2026-11-20 ]

every received mail lands in an n7fs append-only store BEFORE any client touches it --
the frame, the patterns and every later tool read from there, never from an inbox.
sent mail goes there too : once sent it no longer changes either.

- outgoing : the bytes as handed to the relay [ after the client composed them, headers
  as sent ] -- not the client's sent folder, which it may rewrite or move
- capture on a postfix host : always_bcc [ or sender_bcc_maps \ recipient_bcc_maps per
  direction ] to an archive address, delivered by a pipe transport [ master.cf ] to the
  store command. postfix queues the copy itself : no latency on the real delivery, and
  a store that is briefly down only delays the copy [ postfix retries ]. later the
  smtpd zenka takes the same place
- the relay's answer is an event on the message : postfix log lines by queue id
  [ status=sent \ deferred \ bounced, the remote's reply text ]
- one store for both directions : a thread is then complete in one place [ our report,
  the provider's reply, our follow-up ], which is what an issue episode needs
- replicated : the other remotes and the local machines hold it as n7fs remote holders
  [ sealed replicas, data/md/design/N7FS-SEALED-REPLICAS.md ] -- the mail host is not
  the only copy ; append-only makes the sync a plain forward of new entries
- a pattern beyond mail : a task gets its own n7fs store [ the mail archive, a disk
  rescue's files, the stream-grab corpus ] -- written by one task, held by many hosts,
  never edited in place

- raw : the message bytes as received, addressed by checksum [ dedups repeated fetches ] ;
  never changed, so nothing is overwritten -- each arrival only appends
- client state is a second append-only layer of events about a message, not a change to
  it : seen, moved to <folder>, deleted, replied. a mail client [ mutt moves mail into
  archive files, sets flags ] is one producer of such events ; any view, its own
  included, is rebuilt from raw + events
- source, whichever comes first : the postfix bcc copy above [ both directions ], else
  an imap fetch that only reads and sets no flags -- later the smtpd
  zenka receives the mail itself. the target store stays the same, only the source
  changes
- the archive is the corpus for the tracking zenki : e.g. a provider support thread
  [ problem report, provider fix, fallback hint, our verification ] is one issue
  episode to learn from, see the episode corpus under "infrastructure link" above

## positioning

a thin layer on generic modules [ smtpd + frame, pattern registry, task \ models inference,
base.interval, p7 config, ledger ] -- only the inventory and the matching rules are billing
specific. not a reason to run protocol-7, a nice to have for those who already do :
opt-in, minimal set-up. without an inventory it still reports reminders, detail changes
and duplicate invoices, and proposes inventory entries from what it sees [ owner confirms ].
the data never leaves the owner's hosts.

## rules

- the pattern engine is the shared one [ vision file above ] -- this is its first real
  smtpd customer, not a separate store
- internal checksums BMW \ AMOS, no sha, no json internally
- no amounts, accounts or vendor names in repo files : inventory and state live outside
  the checkout [ /etc/protocol-7 or a data dir ]
- related : resource ledger [ vendor accounts and invoices are the same accounting shape ]

#,,..,,,,,,,.,,.,,.,,,,,.,,,.,...,,,,,.,.,,,.,..,,...,...,,.,,.,,,.,.,...,,..,
#5MKLQKOKU4HMNL3V6ZAYRESNZ6IDSNUD7VDVIWKTGQK74CV2M6WGEEQL4NTUFFSTR76YCUORYHG64
#\\\|CP5A7UMSNWQZRVPPEL4NFNCLPXN656THKTRWN3WZBALKLPOBHPU \ / AMOS7 \ YOURUM ::
#\[7]N2AJODSGCJCPEYF2NQMXVBM4A32CKQQ2SPPQRK2EYRTPO6INF6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
