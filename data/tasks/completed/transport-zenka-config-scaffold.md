# task: transport zenka — create missing configuration directory

## dispatch
read `data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md` first —
specifically "additional findings" item **b** ("transport zenka has no
configuration directory") and open-issues table row **#4**. that doc is
a manual verification report against the landed credential-fabric
wiring (commit `21f4edfa5`), which built `transport.select`,
`transport.profile.load`, `transport.handle.direct-tcp`,
`transport.handle.hysteria-socks5`, `transport.handle.udt-tunnel`,
`transport.handle.quic-hysteria` etc — but never gave the zenka a
configuration directory to actually boot from. this task creates that
scaffolding — read-write, not read-only.

## problem
`cfg/zenki/transport/` does not exist at all:
- no `start` file (defines `modules.load`, config, execution flow)
- no `start.cfg` (runtime parameters)
- no `subroutine.white-list`
- no `access.zenki`
- no `auth.zenki` entry for `transport` in `cube/access.zenki` /
  `cube/auth.zenki`

`v7.list available` does not list `transport` as a result. additionally:
**`transport.init_code` depends on `<external.transports>` being
initialized by the `external` zenka, and `external` is currently listed
as "gone" in `list virtual`** — so even with a complete config dir,
transport may not fully initialize until that dependency is satisfied.
investigate this dependency and document what you find; do not assume
you need to fix `external` too unless it's trivial — flag it instead.

## changes — model on an existing comparable on-demand zenka
the cleanest path is to copy the structure from `proxy/` (a sibling
infrastructure zenka created in the same wiring effort, also
currently boot-blocked but config-complete) or another comparable
on-demand zenka, and adapt zenka-specific values:

1. **`cfg/zenki/transport/zenka.v7`** — list
   `modules.load = ...` covering at minimum the modules named above
   (`transport.select`, `transport.profile.load`,
   `transport.handle.*`), plus whatever shared/base modules a
   comparable zenka loads (check `proxy/start` and a couple of others
   for the common base set). add any zenka-specific config keys
   `transport.cfg.*` that `transport.init_code` / `transport.profile.
   load` reference (grep the modules for `<transport.cfg.` to find
   what's expected).

2. **`cfg/zenki/transport/start.cfg`** — runtime
   params. since this is on-demand infrastructure (started when first
   accessed, not always-on), follow the pattern in CLAUDE.md's
   "On-demand Management" section: likely `restart.disabled = 1`,
   `heartbeat.disabled = 1`, an idle timeout via
   `[base.zenki.set_ondemand_timeout:seconds]`, and — per open issue
   #13 found for `proxy` (same class of "binds shared resource, must
   not run concurrently" risk if transport handles hold persistent
   connections) — consider whether `max_concurrency = 1` applies here
   too; use your judgement and document the reasoning either way.

3. **`cfg/zenki/transport/subroutine.white-list`** — list
   the modules' callable subroutines per the convention used by
   `proxy/subroutine.white-list` or similar.

4. **`cfg/zenki/transport/access.zenki`** — intra-zenka
   command access, mirroring the `credential_fabric/access.zenki`
   pattern (note: per finding (d) in the doc, that file currently
   isn't loaded by its zenka's start config — don't repeat that
   mistake; make sure `transport/start` actually loads this file if
   the convention requires it).

5. **cube wiring** — add `auth.setup.usr.transport = :zenka:` to
   `cube/auth.zenki` (same fix that unblocked `proxy`'s auth
   handshake), and confirm `cube/access.zenki` already grants
   `transport` the cross-zenka edges it needs to call
   `credential_fabric.resolve` etc (the findings doc says this grant
   already exists for `transport` — verify it's actually wired
   end-to-end, not just present in one file).

## constraints
- model closely on existing working zenki — this is scaffolding work,
  not design work; deviation from established patterns should have a
  clear reason
- do not touch signatures, lowercase comments / `[ word ]` bracket
  annotations
- after creating the config dir, if you can exercise the live system,
  confirm `v7.list available` now lists `transport`, and attempt to
  start it (`p7c v7.reload`, `p7c reload`, then a routed command or
  `p7c v7.restart transport`) — record what happens, including any
  remaining init failures (especially anything related to
  `<external.transports>` / the `external` zenka dependency noted
  above)
- if you cannot exercise the live system, say so plainly and note
  which parts are unverified

## acceptance
- `cfg/zenki/transport/` exists with `start`,
  `start.cfg`, `subroutine.white-list`, `access.zenki`, modeled
  on an existing comparable zenka
- `cube/auth.zenki` grants `transport` zenka auth
- `v7.list available` lists `transport` (verified or explicitly marked
  unverified with reason)
- summary documents the `<external.transports>` / `external`-zenka
  dependency status — does transport fully init, partially init, or
  fail at that specific point? — without attempting to fix `external`
  itself unless the fix is trivial (flag it as a separate follow-up
  otherwise)

## signatures note
do not add the `#,,..` stub to any new file — the signing system
writes it.

#,,..,,.,,,..,.,.,.,,,,.,,,,,,,,,,..,,.,.,..,,..,,...,...,.,,,,,.,.,,,,,.,,,,,
#3PEBBYBTRYTPQKPRVMK5JWZ5D7ULQJFUZK4BY6S3H6TDKVJYNL3HOMTFGKAU3VTJL64WSZQGYOMHO
#\\\|JHXRGOC7RAUB6SYDHT5D52BE7PWMVOPPNOMEAYX3T7UDOJFM45O \ / AMOS7 \ YOURUM ::
#\[7]R5CCZSRUTM2J5C5VNAOTOXOVHOELV7UO7LR6ABFDGGZYSMKQY4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
