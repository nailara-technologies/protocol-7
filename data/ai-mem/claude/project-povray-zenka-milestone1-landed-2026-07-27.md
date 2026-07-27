---
name: project-povray-zenka-milestone1-landed-2026-07-27
description: "landed (Kimi K3 dispatch, second attempt after mcp-server-p7's alarm/timeout bug fix): povray zenka milestone 1 per data/tasks/povray-zenka-implementation.md -- povray.init_code, template.resolve, spawn_render, handler.render_output/render_timeout, finalize_render, cmd.render/template-resolve/status, cylinder.000.pov.template, live-verified end-to-end via p7c including confirmed non-blocking event loop during an active render"
metadata:
  node_type: memory
  type: project
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## what landed

full milestone 1 of `data/tasks/povray-zenka-implementation.md` — the
`povray` zenka went from a bare `0;` stub to a working async
POV-Ray rendering pipeline, structurally mirroring the `audio` zenka's
IPC::Open3/event.add_io/event.add_timer pattern throughout.

**new modules**: `povray.init_code` (config defaults, binary check,
lazy `~/.povray/3.7/povray.conf` provisioning), `povray.template.resolve`
(`{{key}}` substitution, refuses to render on any unsubstituted
placeholder), `povray.spawn_render` (async `-D` headless spawn),
`povray.handler.render_output` / `povray.handler.render_timeout`,
`povray.finalize_render`, and cube-exposed `povray.cmd.render` /
`povray.cmd.template-resolve` / `povray.cmd.status`.

**new template**: `data/povray-templates/cylinder.000.pov.template` —
the glass-cylinder scene from `audio-icon-povray-glass-cylinder-wrap.md`,
`image_map`-textured, `{{texture_image}}` + camera/light/geometry
placeholders.

**template dir corrected**: `data/povray-templates/` not
`data/yaml/povray-templates/` as `LIVING-BACKGROUND-SYSTEM.md`
originally specified — deliberate fix, the files are `.pov.template`
content, not YAML, decided before dispatch rather than inherited as an
oversight.

## dispatch took two attempts — the first genuinely never started

first `kimi_dispatch` attempt produced literally nothing (no session
directory under `~/.kimi/sessions/` ever created, confirmed via
`kimi -r <uuid>` directly by the user on the *prior* dispatch, which
turned out to be the unrelated already-completed `crop_wide.v1` task).
root cause turned out to be a real bug in `bin/mcp-server-p7` itself
(see `feedback-session-catchup-round-buffer-grounded-but-mislabeled.md`'s
"sharper case" section and the `mcp-server-p7` commit fixing it):
`alarm()` is one global process-wide timer, and `_tree_query`/
`_tree_notify`'s own short alarms were silently destroying
`_do_summarize`'s outer timeout, leaving a stuck summarization
reprocessing an already-finished session indefinitely — and since
`mcp-server-p7` is single-threaded (one blocking STDIN read loop), that
stuck call blocked the *entire server*, so the new povray dispatch
request just sat unprocessed until the outer 1800s client-side idle
timeout gave up on a response the server had never even started
generating.

after the mcp-server-p7 fix (alarm save/restore + missing timeout
added + rolling-summary token cap raised 600→3000) and a live MCP
reconnect, the *same* dispatch prompt was reissued and this time
genuinely ran (`~/.kimi/sessions/.../53f91aa0-...`, `turn_ended` /
`reason=completed`, ~21 minutes) and produced all 9 expected files —
confirming the fix, not just theorizing it.

## live verification, done independently (not just trusting kimi's own report)

the MCP wrapper's own "no response for 1800s" notification fired again
on this second attempt too — but this time for a benign reason
(~21min dispatch + up to ~590s bounded summarize can combine to exceed
the outer 1800s window on a task this size), confirmed via
`turn_ended`/`reason=completed` telemetry rather than assumed.

reviewed every new file directly: no fake/placeholder signature
footers this time (explicit instruction followed). tested personally,
not from kimi's own claimed test output:

- `p7c povray.render cylinder.000 '<json context>'` against a real
  audio-icon PNG as `texture_image` → returned a real path,
  `/var/protocol-7/povray/<id>.png`, confirmed on disk: genuine
  1024x1024 PNG, ~21KB, not empty/corrupt. visually shows the
  audio-icon's blue lattice pattern faintly mapped onto the cylinder
  with a real glass reflection sheen — geometry/framing rough (quick
  placeholder camera values, not tuned), exactly the milestone-1 bar
  ("prove the pipeline works," not aesthetics).
- **non-blocking confirmed directly**: fired a render in the
  background (`&`), immediately called `povray.status <unrelated-id>`
  and `povray.commands` — both returned instantly while the render was
  still running, with the actual render's own PNG path only appearing
  after `wait`. this is the core async requirement from the plan,
  verified live, not asserted.
- `povray.cmd.template-resolve` tested standalone too — correctly
  returns the fully-substituted `.pov` scene text.

## permission gap found and fixed live

`cube` logged `no perm. [ src 'povray' cmd|usr 'v7.register_child' ]`
during the first live render — the exact same gap Kimi hit building
the `audio` zenka originally (per
`project-audio-waveform-visualization-landed-2026-07-26.md`).
fixed by adding `access.cmd.usr.povray = v7.register_child` to
`configuration/zenki/cube/access.zenki`, mirroring the existing
`access.cmd.usr.audio` line, then `p7c reload config` (bare cube
command, not dotted `cube.reload` — that returned "client not
present"). re-tested clean afterward.

## hardcoded output_dir fixed (user's own catch)

`povray.init_code` had `<povray.cfg.output_dir> //= '/var/protocol-7/povray/'`
hardcoded — user pointed out this is already available via the
zenka-dirs registration (`base.path-set-up.check-zenka-paths`'s own
pattern: `catdir( <system.path.zenka-dirs.var_P7>, <system.zenka.name> )`).
fixed to derive it the same way rather than duplicate the literal
path. re-tested live after the fix — output_dir still correctly
resolves to `/var/protocol-7/povray/`, render still works end-to-end.

user noted more hardcoded-path instances exist elsewhere, including in
`base.*` modules — deliberately deferred to a separate future coding-
zenka sweep using the existing `data/yaml/context-templates/
n-hardcoded-paths.yaml` template, not fixed ad-hoc here.

## status

milestone 1 complete and live-verified. NOT yet wired into the `audio`
zenka (deliberately out of scope for this dispatch — a separate future
integration step). explicitly deferred per the plan doc: distributed/
slice rendering, checksum-cached results, data-driven scene generation,
depth/normal/edge map outputs, STRM push of the PNG.

#,,.,,,,.,,,.,,,.,.,.,,.,,..,,.,,,,..,,,.,,,,,..,,...,...,.,.,,..,.,.,.,.,...,
#G36WOFIK2ARYONE3RLAFRPYUD4T6T3YGPXY6OJTJCQ6TSRGM4JJRV3OJLANLELU3XT45XEC7HFJHO
#\\\|BOL24GWUTEHTFLS7J7RADAIMSXPMKMDW3DRBLINIUPC5F3NTCBW \ / AMOS7 \ YOURUM ::
#\[7]UPWOZSCZRYCIJA7HJ4R73SULRDLN3QHPNBNBJTLAHQRJ6MIQ6ABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
