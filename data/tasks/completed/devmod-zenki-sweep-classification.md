## archive: DONE ✓ — 2026-09-20
## commits: 8c7660cc8 (this doc + access-sweep-preview) — c58efd6a5 (category
## 3a) — d677dfd7e (category 3b + weather child.* fix + transport eval-code +
## zenka-own dev-command devcmd gating + channels test-strm/devmod bare-name
## collision fix+rename) — 8e1db3717 (category 5 wildcard narrowing, 10
## zenki) — plus cube-13's static devmod preload removed in the same pass
## that archived this doc [ subroutines.load-early no longer pre-compiles
## devmod.* into cube-13 at startup; devmod stays available there via the
## same universal SIGNUM53 dynamic-load path every other zenka uses ]
## notes: every category closed, including the owner-blocked ones. all nine
## category-3a zenki, all ten category-3b+3a candidates, all ten category-5
## wildcards, plus cube-13, transport, and weather's special findings.
## nothing from the original plan remains open.

# devmod zenki sweep — classification + migration plan

investigation-only pass, 2026-09-20. follow-up to
[[devcmd-namespace-wildcard-permissions]] and
[[v7-zenki-devmod-lifecycle-state]]. those landed the mechanism
[ `access.devcmd.usr.*` axis, `devmod:*` wildcard, per-instance
devmod lifecycle with `v7-zenki.devmod-enable` / `devmod-clear` ]
and migrated `coding` as the first real case [ commit `5c401f87f` ].
this doc is the sweep of every remaining `cfg/zenki/*/zenka.v7`
that mentions devmod [ 55 files, 84 grep hits ], classified into
mechanically-migratable vs owner-blocked buckets. ZERO config or
code was changed in this pass — doc only.

## ground truth established before classifying

- **real devmod command set today** — 39 files under
  `src/devmod.cmd.*`: add-env, b32-elf, change-log-verbosity,
  core-subs, current-umask, decode-harmonic-ref, del, del-env,
  deparse-code, dump, dump-env, dump-keys, eat-mem, echo, elf-b32,
  elf-num, eval-code, exec-sub, extract-line-map, free-mem, get,
  inline-subroutines, keep-devmod-loaded, list-subs, mem-allocated,
  permission-setup, receive-multiline, set, since, sleep,
  switch-user, test-strm, test-strm-size, true, true-int,
  unload-devmod, unload-unsafe, utf8-stream-test, utf8-test-buffer.
  the 14-name list used in the session notes was a subset; this is
  the full set, straight from the filesystem.
- **`keep-devmod-loaded` is NOT stale** — `src/devmod.cmd.keep-
  devmod-loaded` exists and sets `<base.devmod.keep_on_reload>` so
  devmod survives `reload`. every file granting it references a
  real, current command.
- **no name collisions anywhere** — `get`, `set`, `dump`, `del`,
  `echo`, `since`, `sleep` are defined ONLY by devmod across all
  of `src/`. no zenka has its own `<zenka>.cmd.<name>` for any of
  them, including module variants checked [ letsencr.base,
  weather.base, fetch.file ]. so every occurrence of those bare
  names in the access lists below IS a devmod grant, never a
  zenka's own command — migrations can move them wholesale with
  no risk of breaking a same-named native command.
- **which zenki actually load devmod** — 21 zenki have `devmod`
  as a real uncommented token in `modules.load`: channels,
  cred-mesh, credentials, fetch-files, httpd, index, index-mem,
  jobsite, kimi, kimi-web, lm-vision, memory, menu-commands,
  models, nshell, protocol-7-menu, proxy, reasoning, task,
  transport, vision-batch, web. the other 34 grep hits on
  `modules.load` lines are trailing `## devmod` comment markers
  only — devmod is NOT in those load lists.
- **`access.devcmd.usr.*` and the wildcard toggle** — per the
  design doc, `<ns>:*` patterns are still wildcards for
  `system.access.wildcards.allow`'s purpose. only one candidate
  zenka sets that toggle to 0: `weather` [ `zenka.v7:6` ]. for
  weather, `devmod:*` in a devcmd mask would be STRIPPED — exact
  bare names must be used there instead [ or the owner revisits
  the toggle ].
- **the devcmd axis is safe for non-loading zenki too** — devcmd
  patterns only fold into the compiled mask while devmod is loaded
  on that zenka [ sentinel: `base.code.exists devmod.dump` ]. a
  zenka that grants devmod commands but never loads devmod today
  keeps exactly the same default-off behavior after migration;
  the commands additionally become reachable via
  `v7-zenki.devmod-enable`, which is the intended mechanism.

## category 1 — false positives [ no devmod-module relevance ]

- **`udev/zenka.v7:12`** — `udev.devmod-stdout.show-events = no`.
  VERIFIED unrelated: real config key of the udev module itself,
  read by `src/udev.init_code:23` and `src/udev.handler.adm_stdout:
  12` [ "devmod-stdout" is udev's admin-stdout event-dump handler ].
  pure substring collision. [ udev's modules.load hit is the
  comment-only kind, see category 8. ]
- **`X-11/zenka.v7:92`** — `X-11.gpu_top.stat_log_level = 3
  # <-- for devmod ..,` — a gpu-stats logging verbosity kept high
  to support devmod debugging. a config knob, not a permission
  grant; nothing to migrate. [ if the owner later wants the knob
  at a quieter default once devmod is default-off, that's a
  separate cosmetic decision. ]
- **`web-browser/zenka.v7:102`** — `web-browser.open_gtk_inspector =
  0 # enable to start gtk-inspector [ devmod ]` — disabled config
  flag whose comment mentions devmod. currently 0 = inactive,
  not a permission. nothing to do.
- **`decoder/zenka.v7:10`** — `receive-entropy devmod ## <-- !`
  grants a command literally NAMED `devmod`. no bare `devmod`
  command exists anywhere [ `src/devmod.cmd.*` has no such file;
  `devmod.dump` is a module, not a dispatchable bare name ]. the
  token is stale and never matches anything today. action is
  simple cleanup [ delete the dead token ], not a devcmd
  migration — flagged for the implementation pass as such.
- **`cube/access.zenki:29`** — `v7-zenki.devmod-clear` in cube's
  catch-all mask. this is part of the NEW lifecycle mechanism
  itself [ settled in v7-zenki-devmod-lifecycle-state.md point 6 ],
  intentionally granted next to `restart_own-zenka`. not a
  migration target; listed only so the sweep is complete.

## category 2 — already inactive [ line itself commented out ]

nothing granted today; noted for completeness, no action implied.

- `mod-test/zenka.v7:12` — `## exec-sub eval-code # * # <-- devmod`
  fully commented; mod-test also does not load devmod
  [ comment-only marker on modules.load ].
- `graphics-matrix/zenka.v7:18` — `# del dump exec-sub ## <-- other
  devmod commands` commented — BUT line 17 above it is ACTIVE,
  see category 3b.
- `zulum/zenka.v7:15` — `stream-status show-access ## * ## <-- devmod`
  the trailing `*` is commented out. the active names before it
  [ stream-status, show-access ] are zulum's own / base commands,
  not devmod. zulum needs no devcmd migration at all.
- `reasoning/zenka.v7:8` — `# set del exec-sub eval-code ## <-- dev
  only` commented; the active part of that block is in category 3a.
- `decoder/zenka.v7:22` — `## * ## <-- devmod` commented.
- `coding/zenka.v7:82-83` — old `utf8-test-buffer utf8-stream-test
  test-strm` lines, commented "resolved =)". already-migrated
  reference case, nothing left to do.
- `vision-batch/zenka.v7:5` — `# system.access.wildcards.allow =
  false ## [ still uses * ]` — a commented-out toggle, noted
  because vision-batch IS a wildcard user [ category 5b ].

## category 3a — direct migration candidates, devmod actually loaded

exact bare devmod names granted on the regular `access.cmd.usr.*`
axis while the same file loads devmod by default — the precise
`coding`/`jobsite` shape. these are MECHANICAL: same edit as
commit `5c401f87f`, no owner decision needed beyond signing off
the batch. proposed shape per zenka [ showing only the changed
edges of the access block ]:

**credentials** — the most sensitive case in the whole sweep:
the credential-storage zenka both loads devmod permanently AND
grants `exec-sub eval-code` on the regular axis.
```
 access.cmd.usr.cube = heart subname name commands reload verify-instance \
                       list src-age src-ver show-buffer buffer-erase \
-                      buffer-erase-level \
-                      request_session add list authorize \
-                      dump set get del exec-sub eval-code
+                      buffer-erase-level \
+                      request_session add list authorize
+
+## devmod commands : only reachable while devmod is loaded on THIS zenka ##
+## [ v7-zenki.devmod-enable / devmod-clear ], not a permanent grant       ##
+access.devcmd.usr.cube = devmod:*
```
note: credentials' modules.load carries devmod with NO
dev-convenience comment — per the sweep rule that alone doesn't
make it a mechanical modules.load removal, but on THIS zenka
permanent devmod is a standing surface worth an explicit owner
decision [ see owner-flagged list ].

**jobsite** — the second real case, identical shape to coding:
```
                       report-build dossier-build set-export-time \
                       mark-exported unmark-exported \
-                      get set dump del exec-sub eval-code # <-- devmod cmds !!
+
+## devmod commands : only reachable while devmod is loaded on THIS zenka ##
+access.devcmd.usr.cube = devmod:*
```
jobsite's modules.load has devmod uncommented with no comment —
removal candidate for the owner batch [ category 9 ].

**memory** — `get set del dump exec-sub eval-code list-subs
deparse-code list-subs` [ list-subs appears twice — dedup while
moving ]. modules.load comment is `# <- !!`, i.e. flagged load.
**menu-commands** — `dump get set del exec-sub`; modules.load
`## <-- [LLL] ##` = dev-convenience flagged load.
**models** — devmod-only names in the big list: `core-subs get set
dump eval-code exec-sub list-subs permission-setup since
unload-unsafe unload-devmod` — KEEP `buffer-erase` on the regular
axis [ that one is base, not devmod ]. moving `unload-devmod` /
`unload-unsafe` onto the devcmd axis is semantically correct:
you can only unload devmod while devmod is loaded. modules.load
`## <-- dev.` flagged.
**protocol-7-menu** — `dump set get exec-sub`; modules.load has
`devmod #####`.
**kimi** — `exec-sub eval-code deparse-code list-subs`; modules.load
uncommented, no comment.
**kimi-web** — `eval-code deparse-code list-subs`; same.
**reasoning** — active line only: `list-subs deparse-code dump get`
[ the `set del exec-sub eval-code` continuation is already
commented, category 2 ]. modules.load uncommented, no comment.

all eight get the identical added block:
```
## devmod commands : only reachable while devmod is loaded on THIS zenka ##
## [ v7-zenki.devmod-enable / devmod-clear ], not a permanent grant       ##
access.devcmd.usr.cube = devmod:*
```
[ wording copied verbatim from the coding migration so the tree
stays uniform. ]

## category 3b — same shape, but devmod NOT currently loaded

exact bare devmod names granted on the regular axis, while the
file does NOT load devmod [ either never, or commented out ] —
so the grants are INERT today and become lifecycle-gated by the
same migration. still mechanical; the migration changes no
currently-working behavior, it only makes the existing intent
[ "requires loaded devmod module", as weather's own comment
says ] enforceable.

- **audio** — `get set # <-- devmod module test commands`; no
  devmod in modules.load.
- **weather** — `get dump echo ## <-- devmod` [ usr.parent ] and
  `get dump # <-- require loaded devmod module` [ usr.cube ].
  SPECIAL: `system.access.wildcards.allow = 0` is set in this
  file, so the devcmd mask MUST use exact names —
  `access.devcmd.usr.parent = get dump echo` and
  `access.devcmd.usr.cube = get dump` — `devmod:*` would be
  stripped by the toggle.
- **system** — `keep-devmod-loaded dump get set`; system does not
  load devmod. [ granting `keep-devmod-loaded` inertly is harmless
  either way; move with the rest. ]
- **nodes** — `get set del dump keep-devmod-loaded` + `list-subs`
  [ `cur-pid` stays — base command ]; comment-only modules.load.
- **powershell** — `list-subs ## <-- devmod commands`;
  modules.load has `# devmod` commented out.
- **site-yaml** — `dump set get del exec-sub eval-code`;
  modules.load carries `# devmod # <- <!>` — commented out, so
  this one is arguably a deliberate recent removal of the load;
  the access grant just never followed. migration completes that.
- **letsencr** — `dump echo ## <-- devmod commands` [ usr.cube ]
  and `dump get ## <-- 'devmod' module debug commands`
  [ usr.parent ]; modules.load `## devmod` is comment-only.
  note letsencr's config also has a forked child structure —
  the parent block's devmod names are debug grants on the child
  fork line; same migration shape applies per block.
- **graphics-matrix** — ACTIVE `eval-code get set # \` [ line 17 ]
  — all three are devmod-only names [ collision check above ];
  the `# \` continuation feeds the commented category-2 line.
  graphics-matrix has no devmod comment on modules.load at all
  [ devmod simply isn't loaded ].

## category 5 — broad `*` explicitly attributed to devmod — OWNER REVIEW

do NOT auto-migrate. a bare `*` on the regular axis covers every
single-segment command of every loaded module plus anything
dropped in later — narrowing it could silently break unrelated
functionality that only the owner can vouch for. per-zenka read
of whether the wildcard's only practical effect is devmod:

- **index** [ loads devmod ] — `* # <-- !! [devmod]` after a very
  long enumerated list. the `*` adds: all devmod commands, any
  base commands not enumerated, and every future command file.
  the modules.load comment `# <- !!` suggests the whole devmod
  load itself was a hack-day addition. owner must decide whether
  to enumerate or keep the wildcard; NOT mechanical.
- **index-mem** [ loads devmod ] — identical shape to index,
  same assessment.
- **nshell** [ loads devmod ] — `* # <-- all enabled temp. for
  devmod debug commands`. nshell is the interactive shell zenka;
  user-edit/vault-edit's comments [ category 6 ] explicitly cite
  "nshell's trailing '*' which enables everything for devmod
  debugging" — i.e. the wildcard may be load-bearing for the
  shell's role as the debugging front-end. prime owner-review
  candidate; the enumerated list before the `*` is short
  [ history/eval/execute/char-add ], so a narrowed mask needs a
  real decision about what the shell is for.
- **task** [ loads devmod ] — `* ## <- for debmod module
  [ development only ]` [ sic — typo "debmod" ]. large enumerated
  list before it; wildcard attributed to devmod but also covers
  task's other modules [ calc, format.yaml, reasoning.branch,
  valued ]. owner review.
- **channels** [ loads devmod ] — HYBRID: enumerated devmod names
  `get set del dump keep-devmod-loaded` PLUS `* # <-- development
  only`. migrating the names is moot while the `*` stands, and
  the `*` is a blanket. owner review [ the enumerated names move
  with the batch only if the `*` is simultaneously dealt with ].
- **amos-term** [ does NOT load devmod ] — `* ## <-- devmod`
  after window-management enumerations. currently inert for
  devmod purposes; the `*` still grants everything else today.
  owner review.
- **plan-9** [ not loaded ] — `* ## <-- devmod [ restrict later ]`.
  the "restrict later" comment is an explicit owner TODO; the
  enumerated list is short, so narrowing is plausible but is the
  owner's call.
- **storage** [ not loaded ] — same shape and same `[ restrict
  later ]` comment as plan-9 [ storage and plan-9 are paired
  zenki — same access block pattern, likely same edit session ].
- **radio** [ not loaded ] — `* ## devmod` after a complete radio
  command enumeration [ start/stop/status/listen/skip/keep/
  library/audio.* ]. the enumerated list looks functionally
  complete, making the `*` plausibly devmod-only in effect — but
  "plausibly" is exactly what owner review is for.
- **mpv** [ not loaded ] — `* ## <-- disable again [devmod]` —
  the comment itself says the wildcard is meant to be removed
  again; mpv's enumerated list is long and looks complete for
  player control. strong candidate for owner-approved narrowing,
  then the devmod names [ if any wanted ] go on the devcmd axis.

## category 5b — wildcards present but NOT devmod-attributed

the grep hit in these files is a modules.load comment or an
unrelated config line; the access `*` exists but its comment
doesn't tie it to devmod. no devmod-specific action; listed so
nobody re-discovers them. wildcard tightening here is a separate,
pre-existing owner concern, out of this sweep's scope:

- `events` [ `* ## <-- refine` ], `c-trade` [ bare `*` ],
  `acquire` [ `* # <-- <<< ! >>>` ], `discover` [ `* *.* # <-- LLL:
  dev, stricter later` ], `debian` [ `install-history *` ],
  `X-11` [ `* # [ LLL ]` ], `udev` [ `access.cmd.usr.cube = *` ],
  `lm-vision` [ `status info * ## <-- restrict some later` +
  `access.cmd.usr.parent = ... *`, loads devmod ],
  `web` [ `cmd.jobs-data cmd.jobs-sync *`, loads devmod ],
  `httpd` [ `access.cmd.usr.cube = *`, loads devmod ],
  `fetch-files` [ names + trailing `*`, loads devmod —
  the enumerated devmod names are redundant under the `*`; if the
  owner narrows the `*`, the names move per category 3a ],
  `proxy` [ `deparse-code dump core-subs change-log-verbosity *` —
  same redundancy note as fetch-files; the file's own comment
  documents the `*` as load-bearing for cred-rotated routing, so
  the enumerated devmod names can move to the devcmd axis
  mechanically WITHOUT touching the `*` — the `*` keeps covering
  them via the regular axis anyway until narrowed. cleaner to
  move the names and leave the wildcard question to the owner ],
  `vision-batch` [ loads devmod, no devmod names in access;
  commented-out `wildcards.allow = false` shows wildcard awareness ].

## category 6 — intentionally devmod-adjacent, out of scope

- **user-edit** [ line 29 ] and **vault-edit** [ line 7 ] — both
  files' comments say they DELIBERATELY do NOT have nshell's
  trailing `*`: "user-edit's/vault-edit's only reason to be
  reachable at all is [ char-add / heart / verify-instance ]",
  explicitly referencing "nshell's trailing '*' [ which enables
  everything for devmod debugging ]" as the negative example.
  these zenki are already the model of tight access; the devmod
  mention is explanatory prose, not a grant. NO action, and
  positively not migration candidates — recorded here so the
  sweep's "why is X missing" question is answered in advance.

## category 7 — p7-log's `devmod.subs` template variable

`cfg/zenki/p7-log/zenka.v7:16-17` defines
`devmod.subs = get since dump dump-env echo exec-sub list-subs
set del sleep keep-devmod-loaded unload-devmod`, used as
`<devmod.subs>` inside `access.cmd.usr.cube` [ line 24 ].
verified against the filesystem: all 10 names are real,
current `devmod.cmd.*` files — the list is accurate, nothing
stale in it [ it is a deliberately chosen subset, not the full
39 ]. p7-log does NOT load devmod [ modules.load is comment-clean ],
so the grant is inert today, like category 3b.

post-`5c401f87f`, `devmod:*` actually works, so the template var
COULD collapse to:
```
-access.cmd.usr.cube = append commands heart reload ... <devmod.subs>
+access.cmd.usr.cube = append commands heart reload ... [ without <devmod.subs> ]
+
+## devmod commands : only reachable while devmod is loaded on THIS zenka ##
+access.devcmd.usr.cube = devmod:*
```
two honest trade-offs, owner's pick: [ a ] `devmod:*` auto-tracks
future devmod commands — convenient but broader than the curated
subset; [ b ] keeping the 10 exact names on the devcmd axis
[ `access.devcmd.usr.cube = <devmod.subs>` works identically ]
preserves the curation. the enumeration is accurate either way,
so this is a preference call, not a correctness fix — bucketed
with the mechanical batch either way since p7-log's own intent
[ devmod-gated debug commands on a log zenka ] is unambiguous.

## special findings — owner sign-off required

- **cube-13 statically embeds the entire devmod module** —
  `cfg/zenki/cube-13/subroutines.load-early` lists `devmod.dump`,
  `devmod.pre_init`, `devmod.init_code`, and 9+ `devmod.cmd.*`
  files [ exec-sub, eval-code, list-subs, dump-env, dump-keys,
  core-subs, test-strm, true-int, free-mem, keep-devmod-loaded ].
  that whitelist pre-compiles devmod into cube-13 at startup, so
  the `base.code.exists devmod.dump` sentinel is PERMANENTLY true
  there: the devcmd axis is always live on cube-13 and the whole
  default-off lifecycle design does not apply to it. cube-13's
  access.zenki / access.users grant NO devmod commands today, so
  nothing is reachable — but the standing surface exists in
  `%code`. decision for the owner: does a cube instance need
  devmod compiled in at all, or should the load-early entries be
  dropped [ making cube-13 devmod-free like cube itself ]?
  NOT touched by the mechanical pass.
- **transport's `eval-code` is harness-documented** —
  `eval-code ## <-- dev only, harness scenarios 2/3 (F2/F8)`.
  transport LOADS devmod by default today, so `eval-code` works
  out of the box right now; migrating it to the devcmd axis makes
  the harness require `v7-zenki.devmod-enable` first. that is the
  intended end-state, but it changes how the F2/F8 harness
  scenarios run — owner confirms before this one moves.
- **weather's wildcard toggle** — see category 3b: exact names,
  not `devmod:*`.
- **credentials' permanent devmod load** — see category 3a: the
  access migration is mechanical and highest-priority; the
  separate question of whether the credential zenka should keep
  devmod in its static modules.load at all is the owner's.

## category 8 — comment-only `## devmod` markers on modules.load

these files carry a trailing `## devmod` [ or `# devmod` ] on the
modules.load line but devmod is NOT in the load list — the marker
is a leftover note, nothing is loaded, nothing is granted:

amos-term, events, c-trade, acquire, cube-13 [ see special
finding — its devmod comes via load-early instead ], letsencr,
cube, nodes, plan-9, storage, X-11, debian, decoder, discover,
mod-test, external, sourcecode, powershell, site-yaml, ticker,
web-browser, zulum.

optional cosmetic cleanup in the same pass [ deleting the stale
marker comments ], zero behavioral effect either way.

## category 9 — devmod loaded, no devmod grants [ modules.load posture only ]

zenki that load devmod by default but grant no devmod commands on
any axis [ access lists checked in zenka.v7 and, where present,
access.* files ]: httpd, kimi, kimi-web, cred-mesh, proxy,
vision-batch, web, lm-vision, task, index, index-mem, memory,
models, channels, credentials, fetch-files, jobsite,
menu-commands, nshell, protocol-7-menu, reasoning, transport.

for these the access-axis migration is either N/A or already
covered above; the remaining question is purely whether
`devmod` stays in static modules.load now that
`v7-zenki.devmod-enable` + auto re-enable across restarts covers
the convenience use case [ the whole point of
v7-zenki-devmod-lifecycle-state.md ]. the ones whose own comments
read as dev convenience — channels `## <-- development ##`,
lm-vision `## <-- development.., ##`, memory/index/index-mem
`# <- !!`, models `## <-- dev.`, menu-commands `## <-- [LLL] ##`,
nshell `## <-- development only .. ##`, vision-batch `## <--
developement only` — are the natural first removals; the
uncommented-no-comment ones [ credentials, fetch-files, httpd,
jobsite, kimi, kimi-web, cred-mesh, proxy, reasoning, task,
transport, web, protocol-7-menu ] each need a beat of owner
confirmation because "no comment" might mean "deliberate" as
easily as "forgotten". none of this is access-mask scope; it's
the load-posture half of the design.

## summary — mechanism vs owner-blocked

MECHANICAL [ clear-cut, same shape as `5c401f87f`, batch-able ]:

1. category 3a : credentials, jobsite, memory, menu-commands,
   models, protocol-7-menu, kimi, kimi-web, reasoning — remove
   devmod-only names from `access.cmd.usr.cube`, add
   `access.devcmd.usr.cube = devmod:*` with the standard comment.
2. category 3b : audio, system, nodes, powershell, site-yaml,
   letsencr, graphics-matrix — same shape; weather same but with
   exact names [ wildcard toggle ]. p7-log with the owner's
   preference on `devmod:*` vs `<devmod.subs>` [ both fine ].
3. category 1 cleanup : delete decoder's stale literal `devmod`
   access token.

OWNER-BLOCKED [ explicit sign-off before anything touches them ]:

4. category 5 wildcards : index, index-mem, nshell, task,
   channels, amos-term, plan-9, storage, radio, mpv — narrowing
   decision per zenka, THEN any resulting devmod names migrate.
5. category 5b wildcards not devmod-attributed : no devmod
   action; wildcard tightening is a separate owner track.
6. category 6 : user-edit, vault-edit — positively out of scope.
7. special : cube-13 load-early devmod embed; transport harness
   `eval-code`; credentials' permanent load; weather's toggle;
   modules.load posture batch [ category 9 ], dev-convenience
   ones first.

suggested implementation-pass order: batch 1 [ 3a credentials +
jobsite first — the two zenki where permanent devmod primitives
on the regular axis are most exposed ], then the rest of 3a/3b
mechanically, then hand the owner the category 5 + special list
as its own review round. no `access.*` file outside zenka.v7
needs editing for any of this — every migration target lives in
the zenka's own `zenka.v7`, matching how coding landed.

## verification notes for the follow-up pass

- after each edit, `devmod:*` compiles only on a devmod-loaded
  zenka — validate by enabling devmod on a test instance and
  confirming `show-access`-adjacent behavior via the parser's
  security log [ show-access itself does not display the devcmd
  axis, per the design doc's "explicitly not built" ].
- the 55 files above were read in full around every hit; the
  modules.load token analysis used comment-stripped statements,
  so "loads devmod" vs "comment-only" is statement-level truth,
  not grep guessing.
- one count note: the raw grep says "56 files"; the distinct-file
  count is 55 [ one file, likely coding, accounts for the extra
  line via its three-hit comment block ]. every distinct file
  appears in exactly one category above.

#,,,,,..,,,.,,,.,,,.,,,,,,,.,,..,,...,.,.,,,,,..,,...,...,.,,,,.,,,,.,,..,,.,,
#BBYTML54Y7VQXSL6IVQYG67PT4GDYITT475EGC3XWRM66JGLVUOUIJZ5P4IVRBU3XGGLHNYZ7XIHU
#\\\|SZUJQHMPLJXDN3CND3QACEFN6WWQKID6GFINXRKSWBRK5YGR6PA \ / AMOS7 \ YOURUM ::
#\[7]LDRV5XLIOKO5ODIP4JZCLLQBML7I3AEGGOMQQLGQZ7JIDDIBLSBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
