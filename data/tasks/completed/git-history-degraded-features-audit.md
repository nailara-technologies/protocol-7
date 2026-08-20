# task: git history audit — degraded features and incomplete migrations

## context

the web-browser WebKit2 migration (2019) left proxy support broken, request
interception unwired, and deprecated settings silently doing nothing — for 6
years. the signals were visible in the git log: "incomplete but functional!",
"disabled a deprecated webkit setting", "repaired / ported [incomplete]".

this task systematically scans the full git history for similar patterns:
forced migrations, incomplete ports, disabled features, workarounds that were
meant to be temporary. for each candidate, assess whether it is still degraded
and whether it is easy to fix with LLM assistance.

produce a prioritized report and stub task files for the viable candidates.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## phase 1: git log pattern scan

scan the full git log for commit messages matching degradation signals:

```bash
## incomplete / partial work
git log --oneline --all | grep -iE \
  'incomplete|not complete|partial|wip|work.in.progress'

## forced migrations and ports
git log --oneline --all | grep -iE \
  'port|ported|migrat|upgrade|replac' | grep -iE \
  'incomplete|broken|workaround|hack|temporary|quick.fix|todo'

## explicit degradation markers
git log --oneline --all | grep -iE \
  '\[incomplete\]|!incomplete|broken|disabled.*deprecated|deprecated.*disabled'

## repair signals (often means something was broken first)
git log --oneline --all | grep -iE \
  'repair|workaround|hack|kludge|stopgap|temporary'

## "coming later" / deferred features
git log --oneline --all | grep -iE \
  'coming later|for later|TODO|LLL|fixme|stub'

## forced/emergency changes
git log --oneline --all | grep -iE \
  'force|emergency|urgent|quick|<!>|sudden|disappear|removed from.*repo'
```

for each matching commit: record the hash, date, message, and files changed.

---

## phase 2: module-level LLL / TODO scan

scan current module files for deferred work markers:

```bash
## LLL is this project's primary TODO marker
grep -rn '# LLL\|## LLL\|# \[ LLL \]\|#.*LLL' src/ | \
  grep -v '^Binary' | sort

## commented-out code blocks with explanatory context
grep -rn '# TODO\|# FIXME\|# todo\|# fixme' src/

## "coming later" patterns in comments
grep -rn 'coming later\|for later\|not yet\|not implemented\|stub' src/

## WebKit-style "seems to not work" comments
grep -rn 'seems to not work\|not working\|broken\|disabled\|workaround' src/ | \
  grep -v '^Binary' | head -60
```

cross-reference: for each LLL in a module, find the commit that introduced it
and check if the "later" ever came.

---

## phase 3: deep-check suspicious commits

for the most promising candidates from phases 1 and 2:

1. show the full diff: `git show <hash>`
2. check current state of affected files
3. look for TODO/LLL comments introduced in the commit that were never resolved
4. compare: what was removed/commented vs what was meant to replace it

pay special attention to:
- migrations from one library/API to another (like WebKit1→WebKit2)
- zenki that were "renamed" or "refactored" (often lose features in the process)
- commits with both additions and large deletions (incomplete port pattern)
- any commit message containing "<!>" (the developer's high-importance marker)

---

## phase 4: triage and prioritize

for each candidate found, assess:

| field | options |
|-------|---------|
| category | broken (silent failure) / degraded (partial) / missing (never ported) / deferred (LLL) |
| blast radius | single module / single zenka / cross-zenka |
| fix complexity | trivial (1-5 lines) / small (1 module) / medium (2-5 modules) / large |
| value | security / functionality / performance / code quality |
| blocker? | does anything currently depend on this being fixed first |

---

## output format

produce: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

structure:
```
# degraded features audit

## methodology
[brief: what patterns were searched, how many commits scanned]

## high priority candidates
[broken or security-relevant, fix complexity trivial-small]

### candidate: <short name>
- **commit**: <hash> <date> "<message>"
- **files**: list
- **what was lost**: description
- **current state**: what the code looks like now
- **fix**: what needs to change
- **complexity**: trivial / small / medium
- **suggested task file**: data/tasks/<name>.md

## medium priority candidates
[degraded functionality, fix complexity small-medium]

## low priority / deferred
[LLL markers, quality improvements, not urgent]

## not actionable
[things found but too complex, architectural, or already resolved]
```

for each high and medium priority candidate: also create a stub task file at
`data/tasks/<name>.md` with the context pre-filled from the audit findings.
use the same format as the existing web-browser fix task files.

---

## notes

- the `<!>` marker in commit messages is the developer's high-importance signal —
  check all `<!>` commits for follow-up that never happened
- the project has dual commits (each change committed twice in some eras) —
  de-duplicate by message when counting
- focus on src/ and cfg/zenki/ — bin/ and data/ are lower priority
- some LLL markers are intentional permanent notes (architecture decisions) —
  distinguish "this needs fixing" from "this is a known limitation"
- the web-browser case is the template: proxy broken silently, request interception
  disconnected, deprecated settings doing nothing — all findable from git + grep

## success criteria

- [ ] all git pattern searches completed and results recorded
- [ ] all LLL/TODO markers in src/ catalogued
- [ ] at least the top 5 high-priority candidates deep-checked with full diff review
- [ ] `DEGRADED-FEATURES-AUDIT.md` written with triage table
- [ ] stub task files created for all high-priority candidates
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,,.,,,.,,...,,..,,,.,,.,,,,.,,..,...,...,..,,...,...,...,.,,,,.,,,..,,.,,
#BUWATLP56LG5LEB4QUZ7SW43PTJ25CAM2LI4F7KEDZVJBACF5FCDZ42MEYDDY7MTKCKTJGX6AFBQW
#\\\|7QQIRSRE5RS2REL3FSHUQTGIVNBKFNOYR7VF6FZJH7ZVD2WCDGJ \ / AMOS7 \ YOURUM ::
#\[7]ZZDEGA3N3UPNX4BLFEBVGGFOPTZ4674YNKH23ZB3BWIZBNC656DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
