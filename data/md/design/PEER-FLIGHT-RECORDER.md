# peer flight recorder and self-repair [ draft ]

design [ 2026-10-29, user ]. forensics that survives the host it
describes, and repairs that zenki may make while the owner is away --
without ever letting them change the project's course.

## the recorder

- **paired hardened processes** : a small writer on each host and a
  reader on 2-3 peers, separate from the main zenki ; they hold only
  the admin's public key and their peer link
- **an encrypted, heartbeat-monitored link** between writer and readers
- **logs go into a RAM ring buffer on the peer**, encrypted to the network
  admin's vault key [ sealed boxes ] -- readers hold ciphertext they
  cannot read ; older updates are dropped while the host stays reachable
- **entries are hash-chained** : each carries the previous entry's hash ->
  a host compromised before it goes dark cannot quietly rewrite or omit
  its recent history ; a gap is evidence too
- **per-epoch keys** : one leaked key exposes one window [ a signed end per
  epoch, immutable capability reduction ]
- **minimal content** : what forensics needs, not every log line [ logs
  can carry personal data ]

## the capture

- the moment an anomaly makes a host unreachable, its readers write the
  most recent state to disk [ still encrypted ] and move it towards the
  next admin user session or the forensics zenka
- capture is cheap -> it happens on every loss ; a host that comes back
  makes it droppable. classification [ outage \ restart \ anomaly ] uses
  context : announced restarts, whether other hosts lost the same link
- the forensics zenka can hold and move a capture it cannot read, and asks
  the admin for access per incident [ the HX4 approval tiers : click \
  PIN \ passphrase ]

## self-repair while the owner is away

- zenki on trusted local hardware may read the events for bug-fix purposes
  and dispatch repairs -- once group consensus and edits work
- **non-llm zenki verify before and after** : a repair is accepted only if
  deterministic checks show the fault state before and the fixed state
  after [ tests, signature verify, service up ]
- the goal : with one somewhat trusted host still online, code-caused
  outages get repaired during a vacation

## the asymmetry [ the core rule ]

- **the repair direction is easy to attain** for any contributor [ zenka,
  model, user ] : restoring a known-good state, reverting to a signed
  version, restarting a service, applying a fix that verifiably returns
  the previous behaviour
- **degrading or redirecting is hard** : anything that changes the
  project's course [ new features, removed checks, changed trust, wider
  grants, altered goals ] needs the owner's approval, never consensus of
  zenki alone
- a repair proves itself against a reference that already exists [ the
  last signed version, the declared intent -- ai-mem
  declared-intent-survives-breakage ] ; a change of course has no such
  reference, which is how the two are told apart

## related

- HX4 [ approval tiers, review hosts, switchable posture ], OLM [ ideas are
  suggestions, the owner decides ], VERSION-BRANCHES.md [ revocation,
  signed ends ], the forensics zenka, p7-log, links + heartbeats

#,,,.,.,,,...,,,.,,,.,,,.,,.,,.,,,.,,,..,,,..,..,,...,...,...,...,,,,,,,,,,,,,
#SIRMIMFLBCBAFWN2KF4BSG6ZBAOMI6BURVGEHBLDOMTIC5YLJ45WRPQ2Z2GOTWYOVOBHNZ3JTDO7I
#\\\|IBV5NREN6CF7WRVHBRAOBYQL6YVTLBJCHEOR3ZCKMJ4UIVQQGJ4 \ / AMOS7 \ YOURUM ::
#\[7]3DA4BFKNXZ65UDAN23VPIBNHMNC4YXFLZZARQGL6GKUMIX73ICCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
