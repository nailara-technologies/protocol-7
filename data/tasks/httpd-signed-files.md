# httpd : serve signed files -- verify, strip the signature, refuse invalid ones

status : brief, not dispatched [ owner 2026-11-21 ]. found in a live test : the jobsite
page's signature footer [ `#,,,` lines after `</html>` ] is rendered as visible text
at the bottom of the page, and a signing run once put a footer into a generated css
file, which browsers read as broken rules.

## problem

- repo files served by httpd \ httpsd carry the AMOS7 data signature footer ; for html
  [ and css \ js ] the footer is visible or breaks the file
- nothing checks the signature at serve time : a modified or corrupted signed file is
  served like any other

## shape

1. at serve time httpd recognises a signed file [ the footer form the sourcecode
   zenka writes ] and verifies it with the existing verification code [ the same as
   `sourcecode verify-signatures`, through a shared module, not a copy ]
2. valid : the footer [ and an envelope header if present ] is stripped before
   sending ; the client gets the plain html \ css \ js. content-length and range
   requests use the stripped size
3. invalid : not served -- an error page and one log line [ path, which check failed ].
   fail closed : a file that looks signed but does not verify is never sent
4. unsigned files are served as today ; a per-vhost option may require signatures for
   every file of a given type [ e.g. all html ]
5. verification results are cached by file identity [ inode, size, mtime ] so a hot
   file is verified once, not per request
6. generated files are signed by the zenka that GENERATES them [ owner 2026-11-21 ],
   not by the source signing run [ which must not touch them : an exclude list for
   generated output ] :
   - a multi-server application can hand its generating zenka the key it signs with
   - preferred : the key reaches httpd as a signed delegation over the authenticated
     zenka network [ pinned host keys, host-root signed delegations -- the network is
     the trusted key channel ], so delegation works at any distance, across hosts
   - fallback without a delegation : httpd pins the generating zenka's key on first use and accepts
     its files until a valid key rotation [ a rotation signed by the old key, or by
     the host-root delegation ] -- the generator may even run on another host
   - an attacker then has to extract a key from a zenka's memory or make a zenka sign
     something it did not intend -- a much harder attack surface than editing a file
     on disk ; editing alone only produces a file httpd refuses to serve

## later : serving n7fs trees through their signed manifests [ owner 2026-11-21 ]

- a signed n7fs tree manifest is already a signed list : every path with its content
  address, signed as a whole. httpd can serve a tree [ or a view, via the n7fs mount ]
  by checking the manifest signature once and each file's bytes against its address --
  no per-file footer needed
- a path appears on the web as soon as it is in a signed list, and disappears when a
  new signed manifest drops it ; anything not listed or not matching does not exist
  for httpd

## later : a slow path for exploit scanners [ owner 2026-11-21 ]

- scanners show themselves : probes for paths no site of ours has [ /.env,
  /wp-admin, /phpmyadmin, ../ sequences ], many in quick succession. a source that
  matches is moved onto a slow path instead of a fast 404 -- bytes trickle out, the
  connection is held, each further probe is slower
- it must cost us almost nothing : handled in the event loop, no process per
  connection, a hard cap on held connections and on bytes sent, so the slow path
  can never become a denial of service against ourselves. the real cost is the
  connection count ; tarpitted connections are the FIRST to be dropped when the
  system approaches its limits [ file descriptors, memory, the load signals ] --
  real clients never wait behind a held scanner
- escalation to the packet filter : a scanner that keeps returning is dropped in the
  kernel [ nftables set with a timeout per source ] -- no connection is made at all.
  per host the owner chooses the default : the tarpit [ scanners waste their time ]
  or quiet [ filter early, the server stays silent ]. entries expire by themselves,
  the set has a size cap, and the owner's own ranges and the ring's hosts are never
  added
- known users are not scanners : a source authenticated as one of the ring's users
  [ a valid session or lease, a pinned host ] experimenting with their own
  applications -- odd paths, bursts of 404s from a buggy client -- stays out of the
  slow path and the filter until it is clearly justified [ sustained, harmful ]. if it
  does get blocked, the user is told over a native channel [ presence : the host they
  are at, the menu's pending questions ] with the reason and an unblock action ; the
  unblock is a small signed intent, no shell session needed. for users the first
  countermeasure is a gentle slowdown [ a lower rate class, not the tarpit ], which
  a buggy client survives and the user may not even notice ; a block comes only
  after it, and with the notification. in the normal case this is not protection at
  all but load balancing : a rate class smooths one client's burst and shares the
  capacity fairly -- compensation, the same as the load signals elsewhere
- statistics come either way : from the requests until a filter block triggers, and
  after it from the filter's own counters [ dropped packets per source ]. what the
  tarpit adds is samples : the exploit requests themselves -- kept in a quarantined archive [ an
  n7fs tree of its own category, inert data : never served, never executed, never
  parsed by anything but the analysis ]. the samples feed the scan signal list and,
  with the work-and-private-contexts provenance, show which routes are being tried
- built on the existing admission gate [ plugin.web.auth.admit.* : fair queue, 429 ]
  as a very slow class ; the source class is remembered for a while [ hysteresis, as
  with the load signals ] and shared with the other hosts of the ring
- a signed-list server [ above ] has no unlisted paths at all : every probe for one
  is a scan signal by definition

## rules

- reuse the sourcecode zenka's verification and strip logic ; no second signature parser
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- never block the event loop : verification of a large file runs in the existing
  async file path or a child

#,,.,,...,...,...,.,,,.,.,.,.,,,,,,,.,.,.,,,.,..,,...,..,,..,,,,,,,..,,.,,,..,
#IXKSSK52PTM5KTVUUHFOU74H3JMP7SAINJOGM2VETN6CZD7R42MIPMD455UE2PJGIZ34QVGUELQ5I
#\\\|WH7LJD56KDFOBYO3TRK4NGXFHWPRP2JPRKVHZESYZ4QZG52X7XP \ / AMOS7 \ YOURUM ::
#\[7]KIUROVSRWUVBKOO7I46WULH2W2WTJR43P6VA3VQ6OJOWRUGZPCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
