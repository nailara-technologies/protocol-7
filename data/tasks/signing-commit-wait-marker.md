# signing \ pre-commit : wait for a running signing pass instead of racing it

brief [ 2026-10-03 ]. a commit can go through while signing is still in
progress [ user switches tabs, says "staged" ; `80c7f4a5d` only came out
complete because the signing zenka finished first ]. the pre-commit hook
already refuses bad signatures — it should **pause until signing is really
complete, then proceed**. interim guard : memory note in
`feedback-request-signed-version-before-each-batch-commit.md`.

## what exists

- `sourcecode.console.update-signatures` [ sourcecode console zenka ] :
  regenerates signature sections ; `:stage:` re-stages exactly the files
  it signed [ git add ] ; parallel workers with a run tag
  `<pid>-<time>` ; aborts cleanly with nothing staged if a worker crashes
- `bin/dev/git-hooks/pre-commit` [ symlinked from `.git/hooks/` ] :
  stages version files [ ": [ staging version files ]" ], checks version
  numbers and signatures, exits 1 on failure

## change

1. **marker, one per run** [ parallelism safe ] : several signing runs can
   overlap, so a single lock file would be cleared by whichever run ends
   first while another is still signing. instead each run creates its OWN
   marker file in a directory, e.g. `.git/p7-signing.d/<run_tag>`
   [ created with O_EXCL, content : pid, start time, file count ] and
   removes only that file on every exit path [ success, abort, worker
   crash ]. no run ever touches another run's marker
2. **hook waits** : while the marker directory holds any live marker, the
   hook prints one line per run [ ": [ waiting for signing run <tag> .. ]" ]
   and polls [ ~0.5 s ] until none is left, then continues with its
   existing steps [ stage version files, verify signatures ]
3. **stale marker** : judged per marker -- if a marker's pid is gone
   [ `kill 0` fails ] or a timeout passes [ e.g. 120 s, configurable ], stop waiting, report the
   stale marker, and let the existing signature check decide [ refuse if
   anything is unsigned ] — a crashed run can never block commits forever
   and never lets unsigned files through
4. **after waiting** : re-read the index, so files the signing run just
   staged are part of the commit [ the existing verification then covers
   them ]

## later : a counter in shared memory [ user ]

count the parallel signing runs ; 0 or gone = all completed. memory
mapped [ `/dev/shm/.7/…`, see `topic-tool-shm-architecture.md` ], a zenka
variable watcher on it, and the commit becomes one more job in the
dependency queues that only releases when the counter reaches 0.

one caveat decides the shape : a bare counter cannot recover from a
crash [ a run that dies never decrements, the count stays above 0
forever, and nothing tells which run is gone ]. so the counter is the
fast signal, the per-run entries are the truth :
- the shared region holds a small table of run slots [ pid, start time,
  tag ] plus the count of occupied slots
- increment = claim a slot, decrement = free it [ under a lock : flock on
  the mapped file around each read-modify-write ]
- the watcher [ or the hook ] that sees count > 0 for too long checks the
  slots' pids and frees dead ones -> self-healing, the count is always
  derivable from live slots
- the marker directory above is the same idea on disk ; the shm table is
  its faster form once the shm layer exists

## context : passphrase today, a detached signing agent later [ user ]

today every signing run asks for the passphrase again, so a crashed run
cannot silently restart on its own. planned : a detaching signing process
with reattach features -- the only place that keeps the key material in
memory [ like ssh-agent \ gpg-agent ]. that agent is the natural owner of
the run table above : runs register with it, it knows its own workers, so
the count and crash detection live in one authority instead of a shared
file. for the agent itself : key material locked in ram [ mlock, never
swapped -- this host does swap ], reachable only through an authenticated
local socket, and a lock \ timeout after which the passphrase is needed
again.

already designed [ read before building the agent ] :
- `data/ai-mem/claude/vision-sessions-zenka-key-holding-children.md` :
  one minimal key-holding child per decrypted key [ chmod_child pattern,
  `IPC::Open2`, local pipes only, zero network surface, closed command
  vocabulary ] ; detach \ reattach across a manager restart
- `credential_fabric.*` : a detached key-holder child already partially
  built [ `CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md`, `key-holder-status.yaml` ]
- `V7-HOT-SELF-RESTART.md` [ seed ] : fd handoff [ SCM_RIGHTS ] to resume
  instead of cold-init
-> the signing agent is one instance of that key-holding child, not a new
mechanism.

unlock without constant passphrase re-entry : the optional pin logic
[ `topic-write-access-security-infrastructure.md` : pin auth as the fast
alternative to the full passphrase for many small approvals, explicitly
naming batches of code-signing requests ; plus a styled diff image of what
is being signed before approval ] and passphrase+pin-derived keys
[ `topic-latency-algorithmic-authority-entropy-toll.md` ]. the security is
in the agent's contract : what may be signed [ the signed corpus only,
closed vocabulary ], who may ask [ sourcecode zenka, local pipe ], every
signature logged, lock after timeout \ session end.
the ui for it exists in `protocol-7-menu` : `input-password` [ masked
dialog -> passphrase unlock and pin entry ], `input-choice` [ one button
per option -> approve \ deny ], and the pending-question queue with its
ambient indicator [ `pending-question-add` \ `-answer` \ `-open` ] ->
a batch of signing requests waits there as pending questions instead of
interrupting.

## test

- start `update-signatures :stage:` on a large file set, commit right
  away -> hook waits, commit contains the signed versions
- kill the signing run mid-way -> marker stale, hook stops waiting, the
  signature check refuses the unsigned files
- two overlapping signing runs, the shorter one ends first -> hook keeps
  waiting for the longer one [ its marker is untouched ]
- no marker -> hook behaves exactly as today

#,,,,,..,,.,.,..,,,,,,,,,,.,.,..,,,,,,,,,,...,..,,...,...,..,,,,.,...,...,...,
#GFGHO7YY74SLTNWGBR6IAP4TLK6OBN7MIXHG5GP3BQBUS5BXEOGWFDKYZSDUOFJSULCDTWNLYF2PU
#\\\|MTBL737YZBKMVRQLG6HZQQL5FOMJZOMNU5FGASUXNNIUZ26V5P3 \ / AMOS7 \ YOURUM ::
#\[7]4GIQJXLGMLOT6QRG6KL27TYACQZGVGB7YJX5TKJMVTMXNTHYMECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
