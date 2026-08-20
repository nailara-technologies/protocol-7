---
name: topic-mpv-x11-dependency-cascade-restart
description: "X-11 crash cascaded a SIGKILL restart to mpv[audio-0]/radio via v7's blanket zenka-level dependency graph; instance-level exemption mechanism designed and partially implemented, config directive shape still undecided"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac11470d-39ce-43c4-b6a1-2a8f6b20ef2d
  modified: 2026-08-01T01:44:58.280Z
---

**Incident (2026-08-01):** X-11 zenka went `online -> error` (compositor/mouse-event related).
v7's cascade-restart logic in `v7.handler.zenka_status:457-474` walked reverse dependents and
force-restarted (SIGTERM then SIGKILL) every instance of every zenka declared dependent on X-11
— including `mpv[audio-0]`, which was just piping the radio zenka's stream to PulseAudio and
never touches a display. `openbox` also depends on X-11 and `mpv` also depends on `openbox`, so
even removing `X-11` from mpv's own dependency line would not have prevented the cascade — the
openbox hop re-triggers it (`v7.handler.zenka_status` fires again when openbox's own status
transitions through `restart`).

**Root cause:** `cfg/zenki/mpv/zenka-startup.v7:6` declares
`dependencies = cube X-11 openbox` at the zenka-*type* level. `v7.set_up_zenka_dependencies` and
`v7.zenka.instance.get_ids` have no subname/instance granularity at all — restart cascades hit
every instance of a dependent zenka type regardless of whether that specific instance (e.g. an
audio-only subname) actually needs the failed dependency.

**Design landed on (mechanism, not yet the config syntax):**
- Per-instance `$instance->{'dependency_exempt'}->{$dep_zenka_name}` hash, seeded at
  `v7.zenka.start` (after `$zenka_subname` is resolved) from a config directive, matched via
  regex against the instance's own subname.
- Enforcement: `v7.handler.zenka_status`'s restart loop skips `zenka.instance.restart($ARG)` when
  `<v7.zenka.instance>->{$ARG}->{'dependency_exempt'}->{$zenka_name}` is true — `$zenka_name`
  there is whichever dependency just changed status, so this one check covers both the direct
  X-11 hop and the openbox hop without hop-counting.
- Confirmed sufficient: `v7.zenka.instance.restart`'s own separate `dependency.ok` check (lines
  70-74) only gates the restart-timeout retry timer *after* a restart is already committed, not
  whether restart happens — so blocking the call site in `zenka_status` is the correct, sole
  chokepoint.
- IMPLEMENTED already (code side): `v7.zenka.start` seeding logic, `v7.handler.zenka_status`
  enforcement check, and a new `src/mpv.startup.resolve_x11_info` module (replaces the
  previously-unconditional `[base.X-11.get_mode]`/`[base.X-11.get_display]` in
  `cfg/zenki/mpv/start`, skipped for `^audio(?:-\d+)?$` subnames — matches the existing
  `<mpv.audio_only>` convention already used in `mpv.open_player`/`mpv.startup.init`).

**OPEN — config directive syntax, not yet finalized (user said "not sure" as of last check-in):**
Rejected shapes and why:
- `exempt-dependency.by-subname = <regex>  <dep-names>` (one combined value) — rejected: naive
  `split(m| +|, ...)` assumes the first token is the whole pattern, breaks if a legitimate regex
  contains a literal space.
- Regex embedded in the *key* (e.g. `exempt-dependency.^audio(?:-\d+)?$ = X-11 openbox`) —
  rejected: confirmed by direct testing that literal dots in config-file key names are NOT safely
  escapable (see [[project-ncfg-parser-known-limitations]]); only works if the pattern happens to
  contain zero dots, which isn't a safe general assumption.
- Two-key single-pattern (`exempt-dependency.by-subname.pattern` / `.deps`) — solves the space and
  dot problems but caps at one rule per zenka; ncfg has no array/repeated-key syntax (duplicate
  keys just overwrite, confirmed in `base.parser.config`'s `$seen_keys` dedup-warning logic).
- Indexed multi-rule (`exempt-dependency.by-subname.0.pattern` / `.0.deps`, `.1.*`, ...) — solves
  everything above but user dislikes the namespace getting long, and is separately frustrated
  that the underlying parser is this primitive 14 years in (see
  [[project-ncfg-parser-known-limitations]] — do not conflate fixing that parser with this fix;
  user explicitly does not want the two bundled).

**Next step when resumed:** either land the indexed multi-rule directive as the pragmatic minimum
viable syntax (mpv only needs one rule today, so this is not urgent to perfect), or wait for the
user to propose a shorter naming convention. The mechanism/code side does not need to change
regardless of which directive syntax wins.

#,,,,,...,.,.,,.,,.,.,...,,.,,,.,,,..,.,.,,..,..,,...,...,...,,,.,...,,..,,.,,
#7XHHKR5FZIIV5TTMMPWZQK42RUOBKUFXV6NAOEO6O2WNR67SPPDWJZK5C7Y2HWFI7YHEUMTHF6I4A
#\\\|TYNZPLM2VFFBTNO3XR5BNRFMHXWZ7SUHGHPLLE7E5WN7EWNUJ7G \ / AMOS7 \ YOURUM ::
#\[7]QVM7V4WWUZPCHNT5S2XRCPW7LYXNY34HHLXHU36HJ6KXBUGWU4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
