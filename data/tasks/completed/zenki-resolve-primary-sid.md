# generic zenka-instance SID resolver: fix bare-name X-11 routing ambiguity

## context, read first

`data/ai-mem/claude/topic-x11-bare-name-routing-ambiguity.md` — full
diagnosis, read it before starting. Short version: `modules/base.handler.command.route_to_target`
routes a bare `X-11.foo` command (no `[subname]` qualifier) to *every*
session registered under user name `X-11` — the subname-less "desktop"
instance and every `xvfb-000N` instance alike — because its session-loop
only filters by subname when the caller specified one:

```perl
foreach my $target_sid ( keys $data{'user'}{$target_name}{'session'}->%* ) {
    next if $data{'session'}{$target_sid}{'mode'} ne qw| client |;
    next
        if defined $target_subname
        and ( not defined $data{'session'}{$target_sid}{'subname'}
        or $data{'session'}{$target_sid}{'subname'} ne $target_subname );
    push @send_sids, $target_sid;
}
```

Instance identity itself (SID + subname like `xvfb-0000`) already works and
is NOT what this task changes. Explicit subname-qualified addressing
(`X-11[xvfb-0002].foo`) already works via this same function and must keep
working exactly as today — do not touch that branch's logic.

**Chosen fix approach (do not re-derive):** instead of changing
`route_to_target`'s broadcast semantics (risky, central, used by every
zenki), every current *bare-name* caller of `X-11.*` commands should
resolve the specific target SID first via a new, generic, reusable helper,
then address that SID numerically (`"$sid.command"`, which
`route_to_target`'s `sid_str` branch already handles as a single,
unambiguous target). This sidesteps the ambiguous branch entirely rather
than changing it.

**Important — this is a cross-process problem, not a local hash lookup.**
The session table `route_to_target` reads (`$data{'session'}`) lives in
**cube's own process**. A resolver called from `tile`, `mpv`,
`web-browser`, etc. cannot read it directly — each zenka has its own
isolated `%data`. The resolver has to ask cube, over the network, the same
way any other cross-zenka command works. See part 2 below for exactly how.

## prerequisite: this is currently blocked at the config level

Before any of this routing logic even matters: `v7.start X-11[xvfb-0000]`
today fails outright with `"reached configured maximum concurrency for
zenka 'X-11'"`. `cfg/zenki/X-11/zenka-startup.v7` currently has
`max_concurrency = 1`, which caps `X-11` (all instances combined,
subname-less + every xvfb one) at exactly one running instance. Fix as
part of this task:

- raise `max_concurrency` in `cfg/zenki/X-11/zenka-startup.v7`
  to something that allows the host instance plus multiple concurrent
  xvfb instances (check `modules/v7.zenka.cmd.start` for how this value
  is enforced — read the "check max concurrency" block — and pick a
  reasonable number; ask in your summary if genuinely unsure rather than
  guessing something arbitrary like 10).
- add `max_subname_concurrency = 1` to the same file — this key already
  exists as a separate, finer-grained check in `v7.zenka.cmd.start`
  (search for `max_subname_concurrency` there), capping how many
  concurrent instances may share one specific subname (e.g. only one
  `X-11[xvfb-0000]` at a time, while still allowing `X-11[xvfb-0001]`
  concurrently under the raised `max_concurrency`).

This file has an AMOS7 signature footer — don't worry about re-signing it
yourself, just edit the content; the human handles signing afterward like
every other file in this task.

## p7 conventions — read before writing any code

- module files have NO `sub {}` wrapper — the filename IS the subroutine.
  code starts right after the `## [:< ##` header + `# name = ...` /
  `# descr = ...` comment block.
- call other modules with `<[module.name]>` (implicit `->()`, no args) or
  `<[module.name]>->( $arg )` (explicit `->()` only when passing args).
- data-hash access: `<a.b.c>` expands to `$data{a}{b}{c}`. use this for all
  config/state, never invent a raw `%data` access.
- logging: use `<[base.logs]>->( $level, $fmt, @args )` (printf-style,
  level 0=error..N=verbose), NOT `<[base.log]>->( $level, $string )` unless
  it's a single already-formatted message with no interpolation args.
- constants: `TRUE => 5`, `FALSE => 0`, `UNKNOWN => 2` — never bare `1`/`0`
  for these semantics.
- every new/modified module needs an entry in the `subroutine.white-list`
  of every zenka that will call it, AND `modules/base.list.subroutines`
  (both must match or signature verification fails).
- comments: lowercase, `[ word ]` brackets not `( word )`.
- do NOT hand-edit `data/md/documentation/module-dependency-graph.asc` —
  run `bin/dev/dep-graph` after your changes and stage its output as-is.
- do NOT write AMOS7 signature footers (the `#,,,...` block at the end of
  every file) — added by the human's signing pass. Leave new files without
  one. For existing signed files you edit (like the X-11 zenka-startup.v7
  above), just edit the content and leave the existing footer alone
  (it'll be stale until the human re-signs, that's expected/normal).
- do NOT run `git add`, `git commit`, or touch version files
  (`cfg/protocol-7.src-ver`, `read-me/md/README.md`,
  `read-me/project-identity/source-code-versions.md`).

## files to read for existing patterns

- `modules/base.handler.command.route_to_target` — the routing logic this
  task works around (read in full — understand the `sid_str`/`usr_str`/
  `usr_subn_str` branches, and confirm a bare command with no dot segments
  at all is treated as "execute here" by whichever zenka receives it,
  since that's the mechanism part 2 below relies on).
- `modules/base.regex` — `$re->{sid_str}`, `$re->{usr_str}`,
  `$re->{usr_subn_str}`, `$re->{subname}`.
- `modules/base.init_code` (~line 117-145) — existing `<list.users>` and
  `<list.sessions>` definitions, both sourced from `$data{'session'}`/
  `$data{'user'}`. This is the shared, base-loaded list-command system
  every zenka (including cube) already has. You're adding a sibling
  `<list.subnames>` here.
- `modules/v7.init_code` (~line 245) — v7's own `<list.subnames>`
  definition, sourced from `<v7.zenka.instance>` (v7's private instance-
  tracking hash, NOT the same data as cube's session table — v7 tracks
  its own managed zenki with fields like `root_sid`, `subname`, `status`).
  Use this as a *shape* reference (mask style, align style) but note it's
  a different data domain — don't source your new base-level definition
  from `<v7.zenka.instance>`, source it from `session` (see below). Also
  note: v7 already `delete <list.users>;` and defines its own
  `<list.subnames>` — meaning if you add a base-level `<list.subnames>`,
  v7's own copy (loaded after base's, per module load order) simply wins
  on the v7 zenka itself, same as it already does for `<list.users>`. No
  collision, this is expected/existing behavior — every OTHER zenka
  (cube included, since cube does not currently define its own
  `<list.subnames>`) gets the new base-level one.
- `modules/base.cmd.list` — the generic `list <name> [pattern]` command
  handler that reads `<list.$name>` definitions and formats a plain-text
  table via `base.parser.list` / `base.parser.list_filtered` (reply is
  `{ mode => 'size', data => "<header>\n<key1> <key2> ...\n---\n<row>\n<row>..." }`
  — a preformatted STRING, not structured data). Read `base.parser.list`
  and `base.parser.list_filtered` too, to understand exact table/column
  formatting (this determines how the resolver has to parse the reply).
- `modules/v7.callback.get_x11_display` — a live example of the exact gap
  this task fixes. It currently works around the missing resolver with a
  crude placeholder (`# take first one [ for now ]`, grabbing literally
  the first session of any kind) then sends `"$root_sid.X-11.get_display"`.
  Replace this placeholder with a real call to the new resolver.
- `modules/base.session.check.close` — session-teardown handler; you'll
  add a small cache-invalidation call here (see caching section below).
  Note this file lives in cube's process (sessions close on cube), so the
  invalidation you add here only matters for whichever zenka's own
  resolver cache this is — reread part 2 below, the caching happens
  client-side per calling zenka, not on cube. If cube doesn't itself call
  the resolver, this hook may not be reachable from cube's own
  `base.session.check.close` at all — figure out where cache invalidation
  actually needs to live (client-side TTL alone may be sufficient here,
  see caching section) and say what you decided in your summary.
- `modules/base.cmd.subname` — shows `<system.zenka.subname>`, the
  data-path already exposing a zenka's own subname. Used as the default
  `$caller_subname`.
- `modules/protocol-7.route-send`, `modules/protocol-7.command.send.local`
  — the two send helpers used by current bare-name `X-11.*` callers.
  Confirm which one is right for sending an *undotted* command (`list
  subnames X-11`) up to cube specifically, and how to attach a reply
  handler to receive cube's table-text reply.

## what to build

### 1. `<list.subnames>` in `modules/base.init_code`

Add, near the existing `<list.users>`/`<list.sessions>` definitions
(~line 117-145), sourced from `session` (same `var`/`key` as
`<list.sessions>`):

```perl
<list.subnames> = {
    'var'   => qw| data |,
    'key'   => qw| session |,
    'mask'  => '<key>:instance mode:status user:zenka subname',
    'align' => {
        'instance' => qw| left+1  |,
        'status'   => qw| center-2 |,
        'zenka'    => qw| right-2 |,
        'subname'  => qw| left+1 |
    },
    'descr' => "sessions with their 'subname' [ when available ]"
};
```

(adjust field names/filters if `mode`'s raw values don't read naturally as
a "status" column, or if `session`'s actual field name differs from what's
shown above — verify against `modules/base.handler.command.route_to_target`'s
usage of `$data{'session'}{$sid}{...}` for the authoritative field names.)

**Verify the rendered output, don't just write the `align` values and move
on.** Other `<list.*>` tables in this codebase needed iteration passes to
get column alignment clean (padding/width per column is easy to get
subtly wrong — off-by-one column widths, wrong justification for a given
field's typical value length, etc.). After adding this definition, a simple `p7c reload` already picks up the
new list (no restart needed) — `p7c list` shows the overview (confirms
`subnames` is now registered), then `p7c list subnames` and `p7c list
subnames X-11` show the actual rendered table. Actually look at the
output — compare formatting quality against the existing `list sessions`/
`list users` tables, iterate on `align` until it's clean, not just
"renders without crashing." Do this before moving on to the resolver
itself, since the resolver's table-parser in part 2 depends on the final
column layout.

Once this lands, `list subnames X-11` sent to any zenka that hasn't
overridden `<list.subnames>` (i.e. every zenka except v7) returns a table
whose `instance` column is the real, directly-routable cube SID — not an
indirect id needing further lookup.

### 2. `modules/base.zenki.resolve_primary_sid`

This is an **async, cross-zenka** operation, not a local synchronous
lookup — it sends `list subnames $user_name` (no dots — an undotted
command is executed directly by whichever zenka receives it, landing on
cube via the caller's default upstream connection) using
`protocol-7.route-send` (or whichever of the two send helpers you
confirmed is correct), with a reply handler that:

1. Parses cube's table-text reply into rows of `(sid, status, zenka,
   subname)`. Skip the header + separator lines (find the `---` line,
   same way `base.cmd.list`'s own `$apply_limit` sub does it, for
   consistency). Filter rows where `zenka` doesn't exactly equal
   `$user_name` (the `list` command's regex-pattern filtering is
   loose/any-field, so don't rely on it alone for exact matching).
2. Applies the **hybrid resolution logic** below over the parsed rows.
3. Caches the result (see caching below).
4. Invokes the caller's callback with the resolved sid (or `undef`).

Signature: `<[base.zenki.resolve_primary_sid]>->( $user_name, $callback, $caller_subname )`
— `$callback->($sid_or_undef)`. `$caller_subname` optional, defaults to
`<system.zenka.subname>`. On a cache hit, call `$callback->($sid)`
synchronously/immediately (still via the same callback shape, so callers
don't need two code paths for cache-hit vs cache-miss) — only a cache
miss triggers the actual `list subnames` round-trip.

**Design principle: subname is a group tag, not just a disambiguator.**
A subname like `xvfb-0000` identifies which virtual-desktop *stack* a
zenka belongs to, not just which X-11 instance. `tile[xvfb-0000]`,
`mpv[xvfb-0000]`, `web-browser[xvfb-0000]`, and `X-11[xvfb-0000]` all
belong to the same group and should resolve to each other automatically —
the caller's own subname is the primary signal for which target instance
it means. A subname-less caller (the host-desktop stack) means the
subname-less target.

**Hybrid resolution logic**, applied to the parsed rows for `$user_name`
(in this order):
1. If no rows: `undef`.
2. If exactly one row: return its sid, regardless of subname match —
   single-instance case always just works.
3. **Group-match (the default rule):** among rows, look for one whose
   subname equals the effective caller subname — compare "no subname" to
   "no subname" too, so a subname-less caller matches a subname-less row
   (today's implicit desktop-X-11 behavior falls out of this case
   naturally). If exactly one match: return it.
4. If no group-match found (e.g. caller is `tile[xvfb-0002]` but no
   `X-11[xvfb-0002]` row exists, or a subname-less caller but no
   subname-less row exists): check config `<zenki.$user_name.preferred_subname>`
   — if set and a row with that subname exists, return it. Otherwise fall
   back to the lowest sid numerically (deterministic) and log at level 1
   via `<[base.logs]>` that resolution fell back to an arbitrary/non-
   matching instance (include `$user_name`, effective caller subname, and
   chosen sid).

**Caching:** cache key is `($user_name, $caller_subname)` together (e.g.
`<zenki.resolve_cache>->{$user_name}->{$caller_subname // ''}`), storing
`{ sid => $sid, ts => <[base.time]>->() }`. On a call, if a cached entry
exists and its age is under `<zenki.resolve_cache_ttl> // 5` seconds,
call the callback with the cached sid immediately, no round-trip. Note:
since resolution now requires an actual network round-trip to verify a
sid is still live (unlike the original local-hash-scan design, this
resolver has no cheap way to verify liveness without asking cube again),
lean on the TTL as the primary staleness bound rather than trying to
verify liveness pre-callback — a stale cached sid pointing at a session
that just disconnected will simply fail whatever command the caller sends
next (existing offline/no-reply handling in that caller already covers
this, same as it does today for any target going offline mid-flight).
Keep the TTL default short (5s) precisely because of this.

Given the above, the `base.session.check.close` cache-invalidation hook
originally sketched for this task may not be reachable/meaningful (that
file runs on cube, but the cache lives client-side on whichever zenka
called the resolver) — evaluate this and either drop that hook entirely
in favor of the TTL alone, or find the right place if cube can push a
disconnect notification to interested callers (check if such a mechanism
already exists before inventing one; if not, don't invent one for this
task — TTL-only is an acceptable simplification, note this decision in
your summary).

### 3. convert existing bare-name `X-11.*` cross-zenka callers

Grep thoroughly for cross-zenka sends of `'command' => 'X-11....'` or
similar string-built commands (do your own grep — the list below is what
surfaced in an initial pass and may not be exhaustive; note any additional
ones you find in your summary):

- `modules/window.place.handler.wingeom_reply` (~line 32) — `'X-11.get_geometry'`
- `modules/window.place.cmd.place-for-window` (~line 72) — `'X-11.get_geometry'`
- `modules/mpv.handler.reposition_reply` (~line 41) — `'X-11.set_geometry'`
- `modules/storchencam.handler.reposition_reply` (~line 41) — `'X-11.set_geometry'`
- `modules/impressive.handler.reposition_reply` (~line 41) — `'X-11.set_geometry'`
- `modules/tile.handler.transition` (~lines 47, 102) — `'X-11.get_window_ids'`,
  `'X-11.fade_out'`
- `modules/coding.init_code` (~line 543) — `'X-11.gpu_load'`
- `modules/web-browser.handler.auto_slowdown` (~line 8) — `'X-11.gpu_load'`
- `modules/v7.callback.get_x11_display` — replace the `# take first one
  [ for now ]` placeholder entirely (see above)

For each: wrap the existing send in `<[base.zenki.resolve_primary_sid]>->( 'X-11', sub {
my $sid = shift; ... } )` and build the command string as
`"$sid.X-11.get_geometry"` (etc.) inside that callback instead of the
bare `'X-11.get_geometry'`. If the resolver callback receives `undef`
(X-11 not online), handle the same way the existing code already handles
an unreachable target (check what happens today if `X-11.*` is offline —
probably the reply handler already copes with a timeout/no-reply; don't
invent new error handling if an existing path already covers it).

Do NOT touch any in-zenka direct module calls like `<[X-11.get_geometry]>`
(no cross-zenka send involved, not affected by this bug at all) — only
convert calls that go through `protocol-7.route-send` /
`protocol-7.command.send.local` / equivalent cross-zenka send mechanisms.

### 4. config

Add, following existing config-key placement conventions (check where
similar per-feature keys are set):
- `zenki.resolve_cache_ttl` (seconds, default 5) — shared/generic, not
  X-11-specific
- `zenki.X-11.preferred_subname` — leave unset by default

### 5. after all edits

Run `bin/dev/dep-graph` to regenerate `module-dependency-graph.asc`. Add
`base.zenki.resolve_primary_sid` to the `subroutine.white-list` of every
zenka you modified in step 3 (window-place, mpv, storchencam, impressive,
tile, coding, web-browser, v7) plus `modules/base.list.subroutines`.

## what NOT to do

- don't change `route_to_target`'s bare-name broadcast behavior itself —
  that's used by every zenki in the system and changing its semantics is
  a much larger blast radius than this task's scope. This task routes
  *around* it, not through it.
- don't touch the existing `usr[subname]` bracket-addressing branch in
  `route_to_target` — it already works correctly and is out of scope.
- don't make the resolver X-11-specific — it must be generic
  (`base.zenki.resolve_primary_sid`, takes `$user_name` as a param) so the
  same helper covers any future zenka that grows multi-instance/subname
  behavior.
- don't try to make resolution synchronous — it fundamentally requires a
  network round-trip on a cache miss; every caller needs the
  callback-based signature, no exceptions.
- don't sign files, don't touch version files, don't commit.

## summary format when done

List: new files created, files modified (including the exact call-site
conversions), any additional bare-name `X-11.*` cross-zenka callers found
beyond the list above, the config-key placement you chose, the
`max_concurrency`/`max_subname_concurrency` values you picked for X-11
and why, the exact table-parsing approach you used for the `list
subnames` reply, and what you decided about the cache-invalidation
question (TTL-only vs. some disconnect-notification hook, and why).

#,,..,,,,,..,,,,,,.,.,,,.,...,,..,,.,,...,,,.,..,,...,...,..,,..,,,,,,,..,,.,,
#LMVW4QNKNAYVHSXBZ6X6GQOKSFH3RRKHRHL56BKXF3F5CDKM7IFQOGT4I5KXH7MHPEGJAMFVIRDTY
#\\\|P6CXP52O4VQJ5JTFYRTRFSSULKDRIE6DVGCVQ52THYOMIENGTNF \ / AMOS7 \ YOURUM ::
#\[7]GAEZZZVPQN6AS6HKSIOHF77D2LBL2IGLXSC2DYWYXLGR3IJZQQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
