# devcmd permission axis + namespace-scoped wildcard permissions

design settled by the owner 2026-09-20; implemented same day. this doc
records the decisions as decided — no open options remain.

## the two problems this solves

1. reaching `devmod.cmd.*` commands today requires a wildcard in the user's
   REGULAR production mask (`access.cmd.usr.<user>`), because everything
   goes through one mask and one checker. production masks should stay
   tight — no wildcards ever needed there just for devmod access.
2. the existing wildcard grammar only knows bare `*` / `**` — nothing
   between "one exact command" and "everything, across all namespaces".

## what was decided

### 1. namespace-prefixed wildcard syntax

patterns of the form `<namespace>:*` (e.g. `base:*`, `coding:*`,
`devmod:*`) are now part of the pattern grammar compiled by
`src/base.parser.access_conf`, in the same `s|...|...|g` substitution
chain the file already uses.

**expansion rule (settled):** after the bracket/dot/caret escaping
steps and before the general `*` rules, a `:*` suffix is rewritten to
a literal dot plus `.+`:

```perl
$cmd =~ s|:\*|\\..+|g;
```

so `coding:*` compiles to `^coding\..+$` — any command whose
dot-namespace begins with `coding.` (`coding.cmd.foo`,
`coding.x.y`), but NOT `coding` itself and NOT anything in a
different namespace. multi-segment prefixes work too:
`foo.bar:*` -> `foo\.bar\..+`. a literal colon is not part of any
valid command name (see the `cmdrp` charset in `src/base.regex`), so
no existing literal pattern is disturbed. deliberately narrower than
bare `**` (`.+`, crosses namespaces), consistent with the module file
naming (`src/coding.*cmd.*` ↔ `coding.*` commands).

**interaction with `<system.access.wildcards.allow>` (settled):**
`<namespace>:*` patterns ARE still wildcards for the toggle's purpose.
when the toggle is off, the existing disallowed-pattern check
(`qr{(^\.\*\*|\*\*|\*|\%)}`) already matches the `*` in `coding:*` and
strips the whole pattern, logging it in the removal report like any
other disallowed wildcard. reasoning: the toggle exists because "when
wildcards allowed, placing a command file on disk would make it
available to the network" — a namespace wildcard has exactly that
property (any new file dropped into the namespace becomes reachable),
so it must be governed by the same switch. no special exemption.

**correction, found live-testing 2026-09-20 (see point 2b below):** the
"`coding:*` compiles to `^coding\..+$`" framing above is only true at
CUBE'S ROUTING layer (`cfg/zenki/cube/access.zenki`, where the string
being matched really is `<zenka-name>.<command>`, e.g.
`models.get_model_path`, because cube hasn't stripped the target
zenka's name yet). it is NOT true once a command lands on its target
zenka and `base.has_access`/this file's OWN compiled regex checks it —
there, `base.handler.command`'s `$cmd_usr_str` (line ~523) is already
the bare, zenka-name-stripped command (confirmed: `src/base.cmd.
commands` strips `^devmod\.cmd\.` off `%code` keys purely to classify
already-bare `<base.cmd>` entries for display — the bare form is what
actually gets dispatched and checked). `<ns>:*` therefore still works
correctly as designed for `access.cmd.usr.*` entries in cube's own
routing config, but is a no-op / never-matches for a target zenka's
own `access.cmd.usr.*`/`access.devcmd.usr.*` — which is exactly where
this doc's whole feature lives. `devmod:*` specifically is fixed in
point 2b; a general namespace-wildcard fix for other same-zenka cases
(`base:*` etc, as speculated in point 2 below) is NOT built and would
need the same live-`%code`-based treatment, not a regex tweak — flagged
in the sweep follow-up, not solved here.

### 2. new config axis `access.devcmd.usr.<user>`

same pattern grammar as `access.cmd.usr`, including the new
namespace-prefix wildcards. landed in the generic
`<access.devcmd.usr>` data hash by the normal config-key-to-hash
loader — no special parsing. a SEPARATE mask from the regular one;
its whole purpose is keeping `access.cmd.usr.*` tight.

semantics (settled):

- the devcmd mask is consulted ONLY when the devmod module is loaded
  in THIS zenka process — same sentinel `base.sig_NUM53` uses:
  `<[base.code.exists]>->(qw| devmod.dump |)`. on a devmod-less
  zenka the axis does not exist at all.
- the mere presence of an `access.devcmd.usr.<user>` entry is the
  per-zenka/per-user whitelist: a user with no devcmd entry gets
  nothing extra even on a devmod-loaded zenka.
- when both conditions hold, the devcmd patterns are compiled and
  UNIONED into the same `<access.cmd.regex.usr>->{$user}` regex the
  normal mask compiles into. `src/base.has_access` is NOT modified
  (byte-for-byte unchanged) — it keeps reading
  `<access.cmd.regex.usr>->{$user}` exactly as today and picks up the
  union with zero changes on its end.
- ~~a devcmd mask may legitimately be broader than `devmod:*` (e.g.
  also `base:*` for introspection) — expected and fine~~ — corrected
  2026-09-20, see point 2b: `base:*` would be exactly as broken as
  `devmod:*` was, and is NOT fixed by 2b's targeted patch. for now a
  devcmd mask should use `devmod:*` or exact bare devmod command names
  only; broader namespace grants are not functional yet (sweep
  follow-up).
- ~~wildcard-toggle stripping applies to devcmd patterns identically;
  removed devcmd patterns are reported in the disallowed-pattern
  report with a `devcmd:` prefix~~ — this was never true, no such
  prefix exists anywhere in the codebase (`grep -rn "devcmd:"
  src/`, no hits). corrected 2026-09-20: disallowed-pattern removal is
  logged per-user only, with no axis distinction, same as it always
  was for the cmd axis.
- the devcmd config hash itself is never rewritten in place (unlike
  the cmd axis, whose cleaned form feeds `show-access`).

### 2b. `devmod:*` fix — live alternation, not a prefix regex [ 2026-09-20 ]

found live-testing against the real `coding` zenka: `devmod:*` as
implemented in point 1 NEVER matched anything, because devmod commands
dispatch under bare, stripped names (`exec-sub`, `eval-code`, ... —
same convention `src/base.cmd.commands` uses: it strips `^devmod\.cmd\.`
off matching `%code` keys purely to classify already-bare `<base.cmd>`
entries). `devmod:*` compiled to `^devmod\..+$`, which no real
dispatched command string ever satisfies. the axis was inert from
`4c1ae7a3d` until this fix.

fix: `src/base.parser.access_conf` now computes `@devmod_cmd_names` up
front — the exact same `%code`-scanning + prefix-stripping `grep`/`map`
`base.cmd.commands` uses — and when a devcmd-mask token is literally
`devmod:*`, compiles it to a live alternation `(?:name1|name2|...)` of
those actual loaded command names instead of running the generic
namespace-wildcard substitution. empty case [ devmod present but
somehow zero `.cmd.` subs found ] compiles to `(?!)` [ matches nothing
], never falls open. exact bare-name devcmd patterns [ e.g.
`access.devcmd.usr.coding = exec-sub eval-code` ] were never affected
by this bug — only the `devmod:*` wildcard form was broken.

### 3. recompile hooks on devmod state changes

both devmod state transitions recompile the access masks so the
fold-in/fold-out takes effect immediately, through ONE shared
mechanism: a direct re-invocation of `<[base.parser.access_conf]>`,
the exact idiom `src/base.cmd.reload` (line 38) and `src/base.init_code`
(line 293) already use. both hook points run the same call — there is
no second code path and no wrapper module (a wrapper would add a new
file to the subroutines.load-early whitelists for zero behavioral
gain; the bare call is the established convention).

- `src/base.sig_NUM53` (devmod LOAD): in the branch that calls
  `load_runtime_modules`/`init_modules`, after `init_modules`, a bare
  `<[base.parser.access_conf]>;` recompiles this now-devmod-loaded
  zenka's masks with devcmd patterns folded in.
- `src/devmod.cmd.unload-devmod` (devmod UNLOAD — the unload path
  DOES exist; an earlier note claiming otherwise was wrong):
  `base.purge_code` removes `devmod.dump` from `%code`, flipping the
  `base.code.exists` sentinel back to false. in the success branch
  (`ref($code{'devmod.dump'}) ne 'CODE'` after the purge) the same
  `<[base.parser.access_conf]>;` call runs; the parser's conditional
  devcmd check then naturally drops devcmd patterns from the
  recompiled masks.

## explicitly not built

- no unload machinery beyond the existing purge path (nothing new
  invented; the recompile-on-unload hook only reacts to the existing
  `unload-devmod` command).
- `base.cmd.show-access` reads the raw `<access.cmd.usr>` config and
  therefore does not display the devcmd axis; the compiled union IS
  visible in the security log the parser emits (base32-encoded regex
  per user). extending show-access is a possible later follow-up.
- `cube.set-up.export_rules` exports `access.cmd.usr` to child zenka
  configs; `access.devcmd.usr` is not added to the export map — child
  zenka instances that need devcmd masks get them via their own
  `cfg/zenki/*/access.*` files.
- no `cfg/zenki/*/access.*` files were modified — no live permission
  changes ship with this work.

## files touched

- `src/base.parser.access_conf` — namespace wildcard substitution
  line (`<ns>:*` -> `<ns>\..+`); devmod-loaded sentinel
  (`$devmod_present`, same check as SIGNUM53); user iteration over
  the union of `access.cmd.usr` and (devmod-loaded)
  `access.devcmd.usr` keys; devcmd patterns folded into the same
  per-user pattern list and unioned into the same compiled
  `<access.cmd.regex.usr>->{$user}` regex; devcmd patterns never
  rewrite `<access.cmd.usr>` in place; adjusted skip condition for
  devcmd-only users.
- `src/base.sig_NUM53` — one addition: recompile after devmod load.
- `src/devmod.cmd.unload-devmod` — one addition: recompile after
  confirmed devmod unload.
- `src/base.has_access` — UNCHANGED (hard constraint).

#,,,.,,,.,.,,,.,.,,.,,,,,,,.,,.,.,.,,,...,..,,.,.,...,...,...,..,,...,.,.,...,
#CT6WFIK647SKNKERY2L5SNQFFNRFG5G5NQ4FR26WYKGQHYVU5TPDJYOK4A5UIGF4SOHDJLRSOBSZM
#\\\|C55QHJHVYBUHI4OCJSCAB237FYYFPRMDYUYZL4TQLOCO26FUBLT \ / AMOS7 \ YOURUM ::
#\[7]NQD7PY2UOXYLGHZT3CU6ITZ6MLTZNUQIHXVSBNIJW7WZ725JL4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
