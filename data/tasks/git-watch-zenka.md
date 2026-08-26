# task: git-watch zenka — deduplicated force-push backup

## what it solves

git force pushes rewrite history — the old commits become unreachable and are
eventually garbage collected. this zenka preserves them automatically, before
GC can remove them, using git's own content-addressing for zero-redundancy storage.

two use cases, one zenka, two modes:

```
mode 1 — local guardian:
  runs on the development machine alongside normal git workflow
  intercepts fetch operations, detects force push in incoming refs
  snapshots current state BEFORE applying the new refs
  the snapshot is the rescue copy — everything the force push would erase

mode 2 — remote watcher:
  runs on a backup/redundancy server
  polls watched remote repositories via git ls-remote
  on force push detected: clones the pre-force-push state before fetching new
  no local development — pure backup and redundancy function
  multiple repositories watched simultaneously
```

---

## the deduplication mechanism

git objects are immutable and content-addressed (SHA identity).
a force push doesn't delete objects — it makes them unreachable from branch refs.
GC is what actually removes them. snapshot before GC = complete preservation.

**primary strategy — git alternates chain:**

```
backup-0/   full bare mirror clone (first backup)
backup-1/   bare clone with --reference backup-0 (shares all objects from backup-0)
            only stores objects that are new since backup-0
backup-N/   bare clone with --reference backup-(N-1)
            only stores objects unique to this snapshot
```

each backup in the chain only pays for its own unique objects.
the force-pushed-away commits live in backup-(N-1), referenced but not in backup-N.
no redundancy penalty — same as git's native packfile deduplication.

**fallback strategy — btrfs reflinks:**

```
if filesystem supports reflinks (btrfs, xfs, ocfs2):
  cp --reflink=always .git/ .git-backup-<ntime>/
  instant copy, zero cost until repos diverge
  then fetch proceeds — only diverging objects are stored twice
```

test reflink support: `cp --reflink=always /dev/null /dev/null 2>/dev/null`

**last resort — git bundle:**

```
git bundle create backup-<ntime>.bundle --all
portable single-file backup, no dedup but self-contained
use when neither alternates nor reflinks are viable
```

---

## force push detection

the core check — runs in both modes:

```perl
## compare old ref SHA to new ref SHA
## a force push is: new SHA is NOT a descendant of old SHA

my $old_sha = $cached_refs->{ $ref };
my $new_sha = $remote_refs->{ $ref };

next if not defined $old_sha;    ## new ref, not a force push
next if $old_sha eq $new_sha;    ## no change

## check ancestry: is old_sha an ancestor of new_sha?
my $result = qx( git -C $repo_path merge-base
                 --is-ancestor $old_sha $new_sha 2>/dev/null );
my $is_ancestor = ( $? == 0 );

if ( not $is_ancestor ) {
    ## force push detected on $ref
    ## old: $old_sha → new: $new_sha
    ## trigger snapshot NOW before fetching new state
}
```

---

## mode 1 — local guardian

### the timing problem

git has no native `pre-fetch` hook. the reference-transaction hook fires during
the ref update itself — too late to snapshot the old state cleanly.

**solution: fetch wrapper**

the zenka provides a `git-watch.fetch` command that wraps the native fetch:

```
1. git ls-remote <remote> → get incoming ref states
2. compare to current local refs (git show-ref)
3. if any ref is a force push:
   a. snapshot current .git/ state (alternates or reflink)
   b. record: backup-<ntime>/ → { ref, old_sha, new_sha, reason: force-push }
4. proceed with normal git fetch
5. if no force push: discard snapshot (or keep briefly for safety window)
```

the p7 binary makes this usable from the shell:

```bash
p7 git-watch.fetch origin main    ## instead of: git fetch origin main
```

or via a git alias in `.gitconfig`:

```
[alias]
  safe-fetch = "!p7 git-watch.fetch"
```

### local config

```yaml
## cfg/zenki/git-watch/start.cfg
cfg.mode = local
cfg.repo_path = /data/projects/protocol-7
cfg.backup_dir = /data/projects/protocol-7/.git-backups
cfg.backup_strategy = alternates   ## alternates | reflink | bundle
cfg.safety_window_seconds = 300    ## keep non-force-push snapshots this long
cfg.max_backups = 13               ## keep last 13 force-push backups per repo
```

---

## mode 2 — remote watcher

### polling loop

```perl
## timer: every cfg.poll_interval seconds (default 60)
## for each watched repo:
##   1. git ls-remote <url> → current remote refs
##   2. compare to cached refs (stored in %data{watched}{$url}{refs})
##   3. for each changed ref: run force-push check
##   4. on force push: snapshot then fetch
##   5. update cached refs
```

### snapshot on force push (mode 2)

```
detected: force push on <url> ref <branch> old:<sha> new:<sha>

1. if no local mirror exists yet:
   git clone --bare --mirror <url> <backup_dir>/<repo>-backup-0/

2. if mirror exists (backup-N):
   git clone --bare --mirror --reference <backup_dir>/<repo>-backup-N/ \
             <url> <backup_dir>/<repo>-backup-(N+1)/

   ## backup-N is now the rescue copy (has the superseded objects)
   ## backup-(N+1) is the new current state
   ## shared objects stored once via alternates

3. disable GC in rescue copy:
   git -C <backup_dir>/<repo>-backup-N/ config gc.auto 0

4. record in backup index:
   <backup_dir>/<repo>-backup-N/.git-watch-meta.yaml:
     ntime: <timestamp>
     reason: force-push
     ref: <branch>
     old_sha: <sha>
     new_sha: <sha>
     refcount: 1               ## starts at 1 (the rescue purpose)
     directional_ref: >        ## always ≥ 1 (entropy transformation rule)
       future restoration if force push needs to be reversed
```

### watched repos config

```yaml
## cfg/zenki/git-watch/watched-repos.yaml
repos:
  - url: git@github.com:org/protocol-7.git
    local_mirror: /data/backups/git/protocol-7/
    poll_interval: 60
    branches: [main, base, dev/*]
    notify: p7 chat-send git-watch "force push on protocol-7: {ref} {old}→{new}"

  - url: git@github.com:org/other-repo.git
    local_mirror: /data/backups/git/other-repo/
    poll_interval: 120
    branches: [main]
```

---

## backup lifecycle — entropy transformation applied

backups are not kept forever. they follow the entropy transformation model:

```
refcount calculation per backup:
  up_refs:      does any current branch still reference commits only in this backup?
  directional:  is this backup within the safety window? (always ≥ 1 if yes)
  visual_ref:   always ≥ 1 (backup is listed in git-watch.list output — visible)

refcount = 0:   all commits in this backup are reachable from current HEAD
                the force push has been fully integrated or reverted
                → transform: write transformation record, remove backup dir
                  (the commits are still in the current mirror — not lost)

transformation record (kept permanently, tiny):
  <backup_dir>/transformed/<ntime>-<old_sha>.yaml:
    original_backup: protocol-7-backup-3/
    reason: force-push
    ref: main
    old_sha: abc123...
    new_sha: def456...
    commits_count: 7
    commits_recovered: false   ## or true if someone restored from this
    removed_at: <ntime>
    note: all 7 commits reachable from current HEAD via merge — no loss
```

the transformation record IS the entropy preserved after the backup is removed.
the old commits existed, they were preserved, they were verified — that history
is now in the transformation record, not in a full backup directory.

---

## modules to implement

```
git-watch.init_code
  load watched-repos config
  set up poll timers (one per repo, staggered)
  restore cached ref state from persist
  register fetch-intercept handler (mode 1 only)

git-watch.handler.poll-refs
  git ls-remote for one watched repo
  compare to %data{watched}{url}{refs}
  call detect.force-push for each changed ref
  update cached refs on completion

git-watch.detect.force-push
  args: repo_path, ref, old_sha, new_sha
  runs git merge-base --is-ancestor check
  returns: 1 (force push) | 0 (fast-forward) | undef (new ref)

git-watch.snapshot.create
  args: { repo, backup_dir, strategy, reason, ref, old_sha, new_sha }
  tries: alternates → reflink → bundle (in order)
  writes .git-watch-meta.yaml into backup
  disables GC in backup
  returns: backup path

git-watch.snapshot.list
  args: { repo }
  reads all backup dirs + transformation records
  returns formatted table:
    backup-0  2026-05-19  main  abc123→def456  force-push  LIVE
    backup-1  2026-05-19  base  111aaa→222bbb  force-push  LIVE
    [transformed 2026-05-18 main 000fff→abc123 — 3 commits, all recovered]

git-watch.snapshot.restore
  args: { backup_path, target_path }
  git clone --reference backup_path <url> target_path
  or: git fetch into existing repo from backup
  confirms: all commits from backup now reachable in target

git-watch.snapshot.gc
  sweep all backups
  compute refcount for each
  refcount = 0: write transformation record, remove backup dir
  log removals at level 1

git-watch.fetch
  mode 1 entry point — the fetch wrapper
  args: { remote, branch }
  ls-remote → detect force push → snapshot if needed → git fetch → cleanup
```

---

## zenka configuration

```
## cfg/zenki/git-watch/zenka.v7
[load_modules:git-watch.init_code git-watch.handler.poll-refs
              git-watch.detect.force-push git-watch.snapshot.create
              git-watch.snapshot.list git-watch.snapshot.restore
              git-watch.snapshot.gc git-watch.fetch]
[init_modules]
[zenka.loop]
```

```
## cfg/zenki/git-watch/start.cfg
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1
```

---

## p7 command interface

```bash
## list all backups across all watched repos
p7 git-watch.snapshot.list

## create manual snapshot of current state
p7 git-watch.snapshot.create '{"reason":"manual","ref":"main"}'

## restore from specific backup
p7 git-watch.snapshot.restore '{"backup":"protocol-7-backup-3","target":"/tmp/rescue"}'

## run GC pass (remove fully-covered backups, write transformation records)
p7 git-watch.snapshot.gc

## force-poll all watched repos now (don't wait for timer)
p7 git-watch.poll-now

## add repo to watch list
p7 git-watch.add '{"url":"git@github.com:org/repo.git","mirror":"/data/backups/git/repo"}'

## mode 1: safe fetch wrapper
p7 git-watch.fetch '{"remote":"origin","branch":"main"}'
```

---

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

## success criteria

- [ ] mode 2: polls watched repos on timer, detects force pushes correctly
- [ ] mode 1: `git-watch.fetch` snapshots before fetch, only on actual force push
- [ ] alternates chain: backup-N shares objects with backup-(N-1), verified by du
- [ ] reflink fallback: tested on btrfs, instant copy confirmed
- [ ] GC disabled in rescue backups: `gc.auto = 0` verified
- [ ] refcount=0 detection: backup removed when all its commits reachable in current
- [ ] transformation record written before backup removal — permanent tiny record
- [ ] `git-watch.snapshot.list` shows live + transformed backups clearly
- [ ] `git-watch.snapshot.restore` produces repo with all rescued commits reachable
- [ ] zenka starts on-demand cleanly, poll timers staggered to avoid simultaneous ls-remote

#,,,,,.,,,,..,...,.,,,,,,,..,,.,,,,..,.,.,..,,..,,...,...,..,,.,,,.,.,.,,,...,
#OLK3H3CZZZ5TQEPDDNDIFH7EBXECANNX72MACVYWYDG6XBOR7P5MXUHRXFN3Y2MDVDPEIBZZOA4NI
#\\\|AHEB3SSK2R2KWG7LOY5VP2R74GHE3RRZ2ZQ5TCTXXQFZLS4ZQIM \ / AMOS7 \ YOURUM ::
#\[7]JRUPVOXPEZ22KCAESXFVRG3GUWLLMFMOW7OCFW24G5C53U4WX2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
