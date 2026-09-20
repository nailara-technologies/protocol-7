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
- a devcmd mask may legitimately be broader than `devmod:*` (e.g.
  also `base:*` for introspection) — expected and fine.
- wildcard-toggle stripping applies to devcmd patterns identically;
  removed devcmd patterns are reported in the disallowed-pattern
  report with a `devcmd:` prefix on the pattern name so the two axes
  are distinguishable in the log.
- the devcmd config hash itself is never rewritten in place (unlike
  the cmd axis, whose cleaned form feeds `show-access`).

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

#,,,,,..,,,.,,.,,,,..,,..,...,...,.,,,.,.,,,,,.,.,...,...,.,.,,..,,,.,.,.,.,,,
#B5ROLZM5HI3BCB3ERZSEM4D56KABPWBKJB4N34F2T57AXCC4D2ZQEUAT6E5PZWAEK36VZOEDWBHC2
#\\\|J6ZEM5OFYESJW63WD2VCTS723IUXB4FD7PEVWT4YGGLNI7M24CJ \ / AMOS7 \ YOURUM ::
#\[7]KBZNY62NKXJMUUJZ6XU4RVVZCSPZP6ZDZ32NMHQCKV6OA33BRWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
