---
name: topic-ncode-access-gap
description: "a zenka only ever sees its direct neighbor as caller identity (e.g. ncode always sees 'cube', never the human/mcp session behind it) — grant access.cmd.usr.cube, let cube's own access-control filter further"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17.** `ncode`'s task file (`data/tasks/ncode-zenka-modules.md`)
said step 4 was "add access entries to cube/access.zenki for taeki" —
wrong file, and my first attempt to fix this live was **also wrong** in
a more fundamental way, corrected directly by the user mid-session.

## the corrected model (user's own words, authoritative)

Sessions are only "named" between direct neighbors — the entity you
connected to, or that connected to you. A zenka like `ncode` never
connects to a human console session or to `mcp-server-p7` directly; it
only ever connects to **cube**. So from `ncode`'s own
`base.handler.command`, `<[base.session.user]>->($id)` will **always**
resolve to `'cube'`, regardless of who originally issued the dot-routed
command (`taeki`, `unix-taeki`, another zenka, anything) — **unless**
`cfg/zenki/cube/command_aliases` explicitly aliases that
specific command via `setup.aliases.source_zenka` /
`setup.aliases.source_zenka_sid`, which makes cube prefix the relayed
command with the originating zenka name and/or sid so the destination
can see past the anonymization. Neither `search` nor any `ncode.*`
command is in that alias list, so `ncode` genuinely cannot distinguish
callers today — anonymizing to `'cube'` is deliberate, not a gap: it's
what stops any client from spoofing another session's identity. (The
user's own framing: the C25519 upgrades are what will eventually let a
user start a session *inside* a zenka such that provenance stops
mattering at all — see [[topic-write-access-security-infrastructure]].)

**My first fix was therefore backwards**: I added
`access.cmd.usr.taeki` / `access.cmd.usr.unix-taeki` directly to
`ncode`'s start file. Those keys can never match, because `ncode` never
sees those unames as `$user` — only `'cube'`. **Corrected fix**: grant
the commands to the existing `access.cmd.usr.cube` group instead (the
one entity `ncode` actually talks to). Cube itself is then the real
trust boundary: it filters *its own* callers via its own config —
`cfg/zenki/cube/access.users` already has
`access.cmd.usr.<admin-user> = ** ..*.**` and
`access.cmd.usr.<unix-admin> = ** ..*.**`, a pre-existing wildcard that
covers `taeki`/`unix-taeki` (since `taeki` is `<system.admin-user>`)
with zero new cube-side config needed. A non-admin zenka (e.g. `coding`)
wanting the same access would need an *explicit* grant added to cube's
own `access.zenki`, since it has no such wildcard.

**Resolved and verified live**: after the corrected `access.cmd.usr.cube`
grant, `ncode.commands` lists all 11 commands and `search`/`diff`/
`diff-staged` all work end-to-end for `taeki`. The earlier "success" with
the wrong `taeki`/`unix-taeki` keys was never re-investigated and should
still be treated as unexplained/coincidental, not evidence either model
was right at the time.

## general mechanism (still accurate from the original trace)

- `<[base.has_access]>->($user, $cmd)` (`src/base.has_access`) looks
  up `<access.cmd.regex.usr>->{$user}` or the wildcard-**key** `->{'*'}`
  and regex-matches `$cmd` against whichever mask is found.
- `<access.cmd.regex.usr>` is compiled per-zenka from **that zenka's
  own start file's** `access.cmd.usr.<key> = <commands>` entries
  (`src/base.parser.access_conf`) — entirely local to the
  destination zenka, unrelated to `cube/access.zenki` (that file is a
  *different* mechanism: cube's own record of which zenki may route
  which commands *through* cube).
- `system.access.wildcards.allow = 0/false` only forbids wildcard
  *characters* (`*`, `**`, `%`) inside a mask's command-pattern
  **value** — a literal `*` as the **key** is unaffected by this and
  still means "any caller `cube` reports."
- Zenki that never set `wildcards.allow=false` (`task`, `coding`) have
  no such restriction and default-allow any caller; `ncode` opted into
  strict mode deliberately (own comment: "should be disabled for
  network command security... placing a command file on disk would
  make it available to the network").

**How to apply:** when a zenka reports "no permission" for a command a
human/mcp caller sent, grant it to `access.cmd.usr.cube` in *that
zenka's own* start file (cube is the only caller it will ever see) —
never to the human's own uname. Then check whether cube's own
`access.users` admin wildcard already covers the human (it does, for
`taeki`/`unix-admin`) before adding anything to `cube/access.zenki`.

[[topic-write-access-security-infrastructure]]

#,,,,,.,.,..,,..,,...,,,.,,..,...,.,,,...,.,,,..,,...,...,..,,...,..,,...,..,,
#UGSK5HY6UHFC6ESUU2D2LLZWKVLLHQHYUPB3LY5MLQVU4LJCY2XGX37RNZDRDCKI7GQ464USZJCAA
#\\\|PEDQDPCPB6YKG6OYIL2XL2YBRG3WNVO7V5VZ6V6WW333CZ253NH \ / AMOS7 \ YOURUM ::
#\[7]L3TEX4XSBQGWEXJRIGRJQRRR2JQW6ZIIPFZM7HR4XQH7LADOTGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
