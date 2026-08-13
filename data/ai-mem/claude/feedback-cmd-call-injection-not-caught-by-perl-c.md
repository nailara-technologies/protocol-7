---
name: feedback-cmd-call-injection-not-caught-by-perl-c
description: "modules using $call->{'args'} MUST have a literal .cmd. segment (not .console. — that gets registered the same way but never gets $call) in their on-disk filename, or $call is never declared and boot fails at runtime — perl -c on the raw file will NOT catch this"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ec493de1-0c22-45e7-9e10-17221dfc7c84
  modified: 2026-07-29T07:39:37.861Z
---

`bin/Protocol-7` (~line 1875-1950) matches a module's on-disk filename
against `\.(cmd|console)\.(.+)$` — i.e. a literal `.cmd.` or `.console.`
segment — to decide it's a dispatchable command rather than a plain
subroutine, and registers it as `$data{'base'}{$cmd_type}{$cmd_name}`
(`$cmd_type` = `cmd` or `console`, `$cmd_name` = everything after the
segment; see [[feedback-cmd-segment-stripped]] — this on-disk marker is
stripped from the *routed*/console-invoked name but is what the
*filename* must contain for registration to happen at all). This
registration mechanic is identical for both `cmd` and `console`.

**Only `cmd_type eq 'cmd'` also gets the auto-injected `$call` header**
(`my $call = {}; ... if (ref($ARG[0]) eq 'HASH') {$call = $ARG[0]} else
{$call->{'args'} = $ARG[0]}`) — the surrounding code literally comments
`## not for console commands ##`. `.console.` modules do NOT receive
`$call`; they read args positionally instead (`my $name = shift // ...`,
see `modules/keys.console.create`). Using `$call->{'args'}` in a
`.console.`-named module would hit the exact same "Global symbol '$call'
requires explicit package name" failure as a plain module with no
`.cmd.`/`.console.` marker at all — the filename segment alone isn't
enough, it must specifically be `.cmd.` for `$call` to exist.

Confirmed at the invocation site, `modules/base.call.console_command`:
it splits the raw console input line into `($console_cmd,
$console_params) = split(/ +/, shift, 2)`, looks up
`$data{'base'}{'console'}{$console_cmd}` for the handler sub name, then
calls `$code{$command_handler}->($console_params)` — a single positional
string, the leftover text after the command word. So `.console.` modules
receive one plain scalar (which they then further `split`/`shift`
themselves for sub-parameters, e.g. `keys.console.create`'s `[-U]
[key-name]`), never a hashref, never `$call`. This is the console-input
path (interactive nshell/legacy `bin/nshell`), separate from the `cmd`
path's cube/network dispatch that builds the `$call` hashref from a
routed message.

**This is a distinct convention from `access.cmd.usr.<who>` config
keys.** The `.cmd.` module-filename marker is a *loader* convention
(`bin/Protocol-7`'s compile step) that separates command-type subs from
regular subs. `access.cmd.usr.<who> = <space-separated patterns>` is an
unrelated *access-control* convention, parsed by
`modules/base.parser.access_conf` — the `cmd` there just labels "this
mask governs command-type access," not a reference to the `.cmd.`
filename mechanism. `access_conf` compiles each whitespace-separated
value into a regex and does a strict `^pattern$` match against whatever
command name is actually invoked; it doesn't know or care whether that
name came from a `.cmd.`-marked module, a hardcoded console command
(`reload`, `heart`, `commands`, `show-buffer`, …), or cross-zenka
routing (e.g. weather's `access.cmd.usr.child = cube.v7.notify_online`).
The two conventions only interact in that *when* a command's routable
name does come from a `.cmd.`-marked module, whatever access.zenki
grants it must list that exact resulting name — but the grant syntax
itself, and most of any given zenka's grant list, has nothing to do with
`.cmd.` filenames.

A module that references `$call->{'args'}` but is named without a
`.cmd.` segment (e.g. `build.recipe-run`, `ext-pkg.package.ensure`,
`openvas.scan.run` — all three hit this in the same session, 2026-07-29)
fails to boot with `Global symbol '$call' requires explicit package name`.
**`perl -Idata/lib-path/pm -c <file>` on the raw file passes clean** —
the header injection is a runtime/compile-time-in-P7-loader concern, not
a standalone Perl syntax issue, so static syntax-checking gives false
confidence. The actual failure only shows up as `"N broken"` in the
zenka boot log's `"success on N subs, M broken"` line, or as a `Global
symbol '$call'` error visible when the target zenka is actually booted
(`timeout 15 ./bin/Protocol-7 <zenka> 2>&1 | grep -i 'broken\|call'`).

**How to apply:**
- if a new/renamed module body uses `$call->{'args'}` (or any bare
  `$call`/`$reply` reference relying on the auto header), its filename
  MUST contain `.cmd.` — rename don't patch-around
- after writing such a module, boot-test the owning zenka directly;
  never trust `perl -c` alone as sufficient verification for `.cmd.`
  modules
- a module renamed to add `.cmd.` also picks up an auto-injected local
  `my $reply = {...}` — if the module body separately declares its own
  `my $reply`, rename the local one (e.g. `$reply_text`) to avoid a
  "masks earlier declaration" warning
- when this is fixed by renaming, also check the owning zenka's
  `access.zenki`/`start` file for a manual
  `$data{'base'}{'cmd'}{'<name>'} = '<old-filename>'` registration line
  in its `init_code` — remove it, the loader auto-registers `.cmd.`
  modules and a stale manual mapping will point at the now-nonexistent
  old filename
- [[reference-p7-module-syntax-check-tool]] is a better default check than
  raw `perl -c` for most edits — it translates P7 macro syntax first, so
  it doesn't false-positive on bare `<name>{...}` data-slot reads the way
  raw `perl -c` does — but it does NOT close this specific gap either: it
  never injects `$call`, so a `.cmd.` module still needs a real boot test
- `bin/dev/gen-sub-whitelist <zenka>` regenerates that zenka's
  `subroutines.load-early` after a module rename; a module is only
  force-compiled/exercised by boot if reachable via an access grant —
  an unreachable renamed module (no access.zenki grant yet, e.g. phase-1
  `openvas.cmd.scan.run` before phase 2 exposes it) won't surface the
  bug in a normal boot even if still broken; force it temporarily into
  `subroutines.load-early` to verify, then revert the whitelist to the
  tool-generated state

#,,,.,...,,,,,.,.,,,.,.,.,,.,,,,,,..,,...,,,,,..,,...,...,,..,,,,,,,.,.,.,,,,,
#BJKBHXYUK2GCTCNS4YGP7MXCFFCIAYHIBGGQT7JRTCRPL73M25BK5E7GODXTWXDNP754HBZNRM5F6
#\\\|ZZMWN4XPGXXH53ZB2G7GZC5PBOT62O4HGRAY27UZLPB7TQ6DU7R \ / AMOS7 \ YOURUM ::
#\[7]GUYVGHDHDFEOWJFSC7XXQAJQNUDQD7L25DGH2UPAIQQUGNZ3AUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
