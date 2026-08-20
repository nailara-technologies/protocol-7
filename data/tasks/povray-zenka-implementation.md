# povray zenka : implementation plan

## status

**this file is the implementation plan for the `povray` zenka, not a
requirement doc.** the driving requirements it serves are collected
across several existing files [ see references below ]; this file
translates them into concrete first steps.

current state on disk:

- `modules/povray.init_code` — stub, `0;` and nothing else
- `cfg/zenki/povray/{start,zenka-startup.v7,os-dep,pm-dep,
  source,subroutines.load-early}` — scaffolding already wired up
  [ auth.client, net, protocol, io.unix, ui, povray loaded ; wildcard
  `filter` command access already granted from cube ]
- `data/pov/` — three hand-authored test scenes
  [ `water.000.pov`, `water.000.1.pov`, `water.001.pov` ]
  demonstrating scene-file conventions [ POV-Ray 3.6/3.7,
  `#include "colors.inc"`/`"textures.inc"`, `#declare Cam0 = camera{…}`,
  a sky sphere, a chrome water plane ] but not yet parameterized and
  not yet wired into any zenka command
- `/usr/bin/povray` present [ POV-Ray 3.7.0.10.unofficial ], no user
  config yet [ `~/.povray/3.7/povray.conf` missing — flagged on stderr,
  see § invocation ]

so the scaffolding compiles and connects, but nothing in the zenka
actually invokes povray on anything. this plan describes the smallest
useful zenka that does.

## references

read these before signing off on this plan — several of them make
architectural commitments this plan defers to rather than re-decides.

**driving use cases and design docs:**

- `data/tasks/audio-icon-povray-glass-cylinder-wrap.md` — concrete
  first-real-user use case : wrap the audio-icon composite around a
  translucent glass cylinder. this plan treats that as milestone 1.
- `data/md/design/LIVING-BACKGROUND-SYSTEM.md` § "povray as rendering
  layer" — defines `p7c povray.render <template-name> <context>` as
  the command surface, `data/yaml/povray-templates/*.pov.template`
  as the template location, `{{variable}}` as the substitution
  syntax, and `povray.template.resolve` as the templating step.
  **this plan follows those names.**
- `data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md` —
  povray as "precision skeleton" [ depth / normal / edge maps as
  ControlNet conditioning for T2I ]. not milestone 1, but the
  render command's output-type parameter needs to leave room for
  depth / normal / edge outputs, not just RGB.
- `data/md/design/VISUAL-GENERATION-NATIVE-ZENKA.md` and
  `data/md/design/IMAGE-ZENKA-NATIVE-ARCHITECTURE.md` — position
  povray as one of several rendering paths [ terminal, canvas,
  povray, composite ] and identify povray as a `image.povray-bridge.*`
  consumer down the line. no direct action for milestone 1.
- `data/md/design/CONTEXT-TREE-DATA-ZENKA-INTEGRATION.md` and
  `data/md/data-zenka/DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md` — the
  eventual data-driven scene generator [ `data.visual.povray.
  generate_scene` : camera from user perspective, channel CSG from
  visible nodes ]. out of scope for milestone 1 but shapes the
  templating API : parameters must be flat enough that a scene
  generator can fill them programmatically.
- `data/md/design/VISUAL-SIMILARITY-CUBIC-SORT.md` — cache-key
  addressing style [ checksum of scene content → cached render ].
- `data/md/INITIATIVE-MAP.md` § "initiative P — povray zenka" —
  the north-star statement of the initiative ; distributed slice
  rendering and checksum-cached results are milestone-N goals, not
  milestone 1.

**structural precedents inside the repo:**

- `modules/audio.init_code`, `modules/audio.decode_to_pcm`,
  `modules/audio.handler.pcm_data`, `modules/audio.handler.
  decode_timeout` — the cleanest existing precedent for async
  external-process spawning : `IPC::Open3`, non-blocking pipes,
  `event.add_io` watchers, `event.add_timer` timeout, per-run state
  dict keyed by run id. this plan mirrors that pattern almost
  verbatim.
- `cfg/zenki/audio/start` — precedent for setting
  `<zenka>.cfg.output_dir` at zenka-start time from the start file.
- `CLAUDE.md` § on-demand deployment [ `restart.disabled = 1`,
  `heartbeat.disabled = 1`, `[base.zenki.set_ondemand_timeout:secs]` ]
  — povray renders are cold-start-cheap and per-request expensive,
  and the zenka is not needed continuously, so on-demand is the
  right posture. `data/ai-mem/claude/feedback-ondemand-timeout-
  tiering.md` currently lists povray at the 142s tier — this plan
  does not touch that value ; it lives in the ondemand tier config
  and can be re-tuned once real render times are measured.

## non-goals for milestone 1

everything below is documented as a target the zenka must not
foreclose, but is not attempted in milestone 1:

- distributed / slice rendering across nodes [ INITIATIVE-MAP § P ]
- checksum-cached result store [ LIVING-BACKGROUND-SYSTEM.md ]
- data-driven scene generation from namespace tree [
  DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md ]
- depth / normal / edge map output for ControlNet [ VISUAL-INPUT-
  PIPELINE-AND-LIVING-TEMPLATES.md ]
- STRM push of the rendered PNG back to the requester

milestone 1 is : parameterize one scene file, spawn povray on it
without blocking the event loop, write the PNG to a known directory,
return the path.

## proposed command surface

three commands, mapping cleanly onto three responsibilities. names
follow the LIVING-BACKGROUND-SYSTEM.md precedent.

```
povray.render <template-name> <json-or-yaml-context>
  ## the primary user-facing command                                   ##
  ## resolves the template, spawns povray, returns { id, path } async  ##

povray.template.resolve <template-name> <json-or-yaml-context>
  ## exposed on its own so callers can inspect the resolved .pov       ##
  ## before rendering [ debugging, dry-runs, cache-key computation ]   ##

povray.status <id>
  ## poll render state : queued / running / done / error, path if done ##
```

open : do we want `povray.cmd.*` [ command-oriented ] or
`povray.render.*` [ pipeline-oriented ] as the internal module
namespace ? audio uses `audio.cmd.*` for cube-exposed commands and
`audio.render_standing_wave.*` / `audio.post_process.*` /
`audio.overlay.*` for pipeline stages. suggested mirror :
`povray.cmd.render`, `povray.cmd.template-resolve`, `povray.cmd.
status` for the cube-exposed side ; `povray.spawn_render`,
`povray.finalize_render`, `povray.handler.render_output`,
`povray.handler.render_timeout`, `povray.template.resolve` for the
pipeline side.

## what `povray.init_code` needs to do

modelled on `modules/audio.init_code`. concretely :

```perl
## [:< ##

# name = povray.init_code

<[base.perlmod.load]>->(qw| IPC::Open3 |);
<[base.perlmod.load]>->(qw| Symbol |);
<[base.perlmod.load]>->(qw| Fcntl |);
<[base.perlmod.load]>->(qw| POSIX |);
<[base.perlmod.load]>->( 'File::Path', qw| make_path | );

## config defaults [ overridable in cfg/zenki/povray/start ] ##
<povray.cfg.output_dir>     //= '/var/protocol-7/povray/';
<povray.cfg.template_dir>   //= 'data/yaml/povray-templates/';
<povray.cfg.scene_dir>      //= 'data/pov/';
<povray.cfg.render_timeout> //= 300;    ## per-render kill deadline    ##
<povray.cfg.image_width>    //= 1024;
<povray.cfg.image_height>   //= 1024;
<povray.cfg.quality>        //= 9;      ## povray +Q flag              ##
<povray.cfg.antialias>      //= 1;      ## povray +A flag              ##

<povray.path.povray_bin> //= <[base.required_bin_path]>->('povray');

if ( not -x <povray.path.povray_bin> ) {
    <[base.log]>->( 0, "[!] 'povray' binary not found, shutting down..," );
    exit(2);
}

## per-render state, keyed by render id, mirroring audio.decode ##
<povray.render> //= {};

## on-demand posture : idle timeout matches feedback-ondemand-timeout-tiering ##
<[base.zenki.set_ondemand_timeout:142]>;

0;
```

the on-demand call may already be set globally via zenka config
[ `start.on-demand = 1` in `cfg/zenki/povray/zenka-startup.v7`,
plus `restart.disabled = 1` / `heartbeat.disabled = 1` ] rather than
in init_code — decide once, put it in one place. audio does not set
its own timeout ; if povray follows the same pattern the ondemand-
timeout line belongs in config, not init.

## async spawn : mirror of `audio.decode_to_pcm`

`povray.spawn_render` is structurally the same problem : long-running
external binary, output on stdout+stderr, must not block the event
loop, must be killable on timeout, must be tracked per-run. sketch :

```perl
## [:< ##

# name  = povray.spawn_render
# descr = spawn async povray render [ non-blocking, io watchers ]
# param = $render_id, $pov_path, $out_png, $reply_id ; returns err or undef

my ( $id, $pov_path, $out_png, $reply_id ) = @ARG;

my ( $out_fh, $err_fh );
$err_fh = Symbol::gensym;

my @cmd = (
    <povray.path.povray_bin>, '-D',                    ## no display     ##
    sprintf( '+I%s', $pov_path ),
    sprintf( '+O%s', $out_png ),
    sprintf( '+W%d', <povray.cfg.image_width>  ),
    sprintf( '+H%d', <povray.cfg.image_height> ),
    sprintf( '+Q%d', <povray.cfg.quality>      ),
    <povray.cfg.antialias> ? ( '+A' ) : (),
);

my $pid = eval { IPC::Open3::open3( undef, $out_fh, $err_fh, @cmd ) };
## …identical non-blocking / setpgid / report_child_pid / event.add_io /
## event.add_timer sequence as audio.decode_to_pcm ; handlers are
## povray.handler.render_output and povray.handler.render_timeout
```

the audio decode handler [ `audio.handler.pcm_data` ] collects bytes
into a buffer and finalizes on eof ; povray's handler collects
stderr progress lines and finalizes on the child exiting, at which
point `$out_png` should exist on disk. we do not stream the PNG
through the pipe — povray writes it directly to `+O`.

**why povray's pattern is not exactly audio's :** audio.decode_to_pcm
needs the PCM *bytes* off the child's stdout ; povray writes its
output file itself and stdout is just chatter. the io watcher on
stdout is therefore not carrying the payload — it exists only to
detect eof and drain the pipe so the child does not block on a full
write buffer. this is worth noting because it is the one place the
mirror breaks.

**why `-D` matters :** without it, povray 3.7 tries to open an X11
preview window and, on a headless invocation from a zenka, either
warns or fails. the water scene files in `data/pov/` do not set
this ; the zenka must supply it on the command line.

**povray user config :** the current `/usr/bin/povray` complains
about `~/.povray/3.7/povray.conf` missing. this file gates povray's
i/o permissions [ read-only-in / write-only-out paths ]. os-dep /
one-time setup responsibility — a `cfg/zenki/povray/os-dep`
step, or a lazy self-provisioning check in init_code, that writes a
minimal povray.conf permitting reads under `data/pov/`,
`data/yaml/povray-templates/`, and writes under
`<povray.cfg.output_dir>`. open : which of those two lives is
cleaner in this repo — check how audio handled its ffmpeg config
[ it did not need one, so no precedent ].

## scene templating

**the problem :** the three existing `data/pov/water.*.pov` scenes
are hand-authored. hardcoding a scene per render call would be
unmaintainable and would defeat the "template → data injection →
render" model the design docs commit to.

**the model :** LIVING-BACKGROUND-SYSTEM.md fixes `{{variable}}`
substitution as the syntax, `data/yaml/povray-templates/*.pov.
template` as the location, and `povray.template.resolve` as the
step. this plan adopts that verbatim.

**resolution rules :**

- template file lives at `<povray.cfg.template_dir><name>.pov.template`
- context is a flat hash-of-scalars [ deep values allowed but must
  serialize to a povray literal — vectors as `<x,y,z>`, colors as
  `rgb<r,g,b>`, images as absolute path strings ]
- every `{{key}}` in the template is replaced by `context->{key}`
- resolver refuses to render if any `{{…}}` remains after
  substitution — silent under-substitution is the failure mode most
  likely to waste a full render
- resolved output is written to a scratch `.pov` under
  `<povray.cfg.output_dir>scenes/<render_id>.pov` — kept alongside
  the PNG for debugging, not deleted on success

**example template shape** [ this is the cylinder-wrap milestone-1
target, not committed until § milestone 1 signs off ] :

```povray
// cylinder.000.pov.template
// wrap {{texture_image}} around a horizontal translucent glass cylinder

#version 3.7;
#global_settings { assumed_gamma 1.0 }
#include "colors.inc"
#include "textures.inc"

camera { perspective angle {{camera_angle}}
         location  {{camera_location}}
         right     x*image_width/image_height
         look_at   {{camera_look_at}} }

light_source { {{light_position}} color rgb {{light_color}} }

cylinder { {{cyl_start}}, {{cyl_end}}, {{cyl_radius}}
    texture {
        pigment { image_map { png "{{texture_image}}" once
                              interpolate 2 }
                  scale {{texture_scale}}
                  translate {{texture_translate}} }
        finish { ambient 0.1 diffuse 0.7
                 reflection {{glass_reflection}}
                 specular 0.8 roughness 0.005 }
    }
    interior { ior {{glass_ior}} }
}
```

context for the audio-icon call would then look like [ pseudo-yaml
for readability ] :

```yaml
camera_angle: 40
camera_location: '< 0.0, 0.0, -8.0 >'
camera_look_at:  '< 0.0, 0.0,  0.0 >'
light_position:  '< 500, 500, -500 >'
light_color:     '< 1.0, 1.0, 1.0 >'
cyl_start:       '< -3, 0, 0 >'
cyl_end:         '<  3, 0, 0 >'
cyl_radius:      1.0
texture_image:   '/var/protocol-7/audio/icon_ac.png'
texture_scale:     '<2, 1, 1>'
texture_translate: '<0, 0, 0>'
glass_reflection: 0.05
glass_ior:        1.5
```

**vs generating .pov from perl in-memory :** rejected. templating
means the template is inspectable and hand-editable ; a designer
who does not know perl can tweak `cylinder.000.pov.template`
directly without touching zenka code. it also matches the "same
namespace substitution pattern as site-yaml zenka" note in LIVING-
BACKGROUND-SYSTEM.md — one substitution engine, not two.

**existing water scenes :** leave the three `water.*.pov` files
where they are as hand-authored scaffolding. they are useful as
integration-test inputs [ "render this exact file, verify PNG
lands where expected" ] without needing the templating engine at
all. milestone 0 = "can we spawn povray on a static file", template
resolution is milestone 1.

## output handling

follow the audio-zenka precedent :

- default output dir : `<povray.cfg.output_dir>` = `/var/protocol-7/povray/`
- set in `cfg/zenki/povray/start` [ mirroring the
  `audio.cfg.output_dir = /var/protocol-7/audio/` line ] so it can
  be overridden per deployment without editing init_code
- ownership : `[root.drop_privs:<system.amos-zenka-user>]` happens
  in the start file *after* modules load, so the output dir must
  be pre-created and owned by that user [ same story as audio ]
- filename : `<output_dir><render_id>.png`, with `render_id` a
  short random id [ same style as audio's `$decode_id` ]. resolved
  scene beside it as `<output_dir>scenes/<render_id>.pov`
- return value from `povray.render` : `{ id: <id>, path: <png_path> }`
  once the render finishes ; the reply mode is deferred and posted
  via the same reply_id / mode contract audio uses

open : do we also want a stable, checksum-addressed path
[ `<output_dir>by-chk/<checksum>.png` ] alongside the id-keyed one,
to support the LIVING-BACKGROUND-SYSTEM.md caching model on day 1 ?
tentatively yes, but only if it costs one extra symlink at the end
of `povray.finalize_render` and not a whole cache subsystem. if it
grows, defer to milestone 2.

## on-demand / timeout / lifecycle

- `cfg/zenki/povray/zenka-startup.v7` should carry
  `start.on-demand = 1`, `restart.disabled = 1`, `heartbeat.
  disabled = 1` [ same as other on-demand zenki per CLAUDE.md ]
- idle timeout : 142s tier per feedback-ondemand-timeout-tiering.md
  [ light but episodic tool ]. set via
  `[base.zenki.set_ondemand_timeout:142]` in start or init_code —
  pick one location, do not duplicate
- per-render kill deadline : `<povray.cfg.render_timeout>`, default
  300s. handler kills the process group [ `POSIX::setpgid` was
  called on spawn so `kill 'TERM', -$pid` cleans up cleanly ]
- child pid tracked via `<[base.zenki.report_child_pid]>->($pid)`
  so the parent zenka can be reaped without orphaning renders

## milestone 1 : cylinder-wrap proof of concept

the concrete first working end-to-end path :

1. **create** `data/yaml/povray-templates/cylinder.000.pov.template`
   with the shape sketched in § scene templating above. commit
   separately so the template can be reviewed as a scene file, not
   as a code change
2. **implement** `povray.init_code` per the sketch in § init_code,
   plus `povray.template.resolve`, `povray.spawn_render`,
   `povray.handler.render_output`, `povray.handler.render_timeout`,
   `povray.finalize_render`, and cube-exposed
   `povray.cmd.render` / `povray.cmd.template-resolve` /
   `povray.cmd.status`
3. **update** `cfg/zenki/povray/start` : add
   `povray.cfg.output_dir = /var/protocol-7/povray/` and any other
   deploy-time overrides ; add the new commands to
   `access.cmd.usr.cube = ...` explicitly [ the current `filter *`
   wildcard already covers them but naming them makes the surface
   auditable ]
4. **pre-create** `/var/protocol-7/povray/` and `scenes/`
   subdirectory owned by `<system.amos-zenka-user>`
5. **provision** `~/.povray/3.7/povray.conf` [ or wherever the
   zenka user's home resolves ] with read/write allowances covering
   the template + scene + output paths — os-dep or lazy check,
   pick one
6. **integrate** with the audio-icon pipeline : audio-icon produces
   a 512x512 PNG at a known path ; a caller invokes
   `povray.cmd.render cylinder.000 { texture_image: <that-path>, … }`
   ; the returned PNG is the wrapped-cylinder version. no changes
   to audio zenka needed — this is purely a downstream consumer

**definition of done for milestone 1 :** invoking
`p7c povray.cmd.render cylinder.000 <ctx-with-a-real-icon-png>`
from the shell returns [ within `render_timeout` ] a path to a
readable PNG showing the icon wrapped around a translucent glass
cylinder. the event loop of the povray zenka remains responsive
during the render [ a concurrent `povray.cmd.status <id>` returns
in-progress state, not a stall ].

## open questions

collected here rather than forcing decisions prematurely :

1. **`povray.cmd.*` vs `povray.render.*`** for the module namespace
   — see § command surface. suggest `.cmd.*` for cube-exposed
   commands, unprefixed pipeline modules otherwise, mirroring
   audio.
2. **on-demand-timeout location** — start file vs init_code. one
   or the other, not both.
3. **povray.conf provisioning** — os-dep script vs lazy self-check
   in init_code. no existing precedent in this repo for either.
4. **checksum-addressed output symlink from day 1** — cheap if it
   works with one extra symlink, defer if it turns into a cache
   subsystem. see § output handling.
5. **png return path** — return the filesystem path only, or push
   the file bytes back via STRM ? the audio icon consumer is
   local-fs today, so path is enough for milestone 1 ; STRM push
   is called out for post-milestone-1 [ INITIATIVE-MAP § P mentions
   "PNG returned via STRM" ].
6. **waveform-only vs full-composite texture source** [ carried
   over from `audio-icon-povray-glass-cylinder-wrap.md` § "known
   dependency : color-to-alpha" ] — decide before finalizing the
   cylinder.000 template's `image_map` block ; if waveform-only,
   the `graphics-matrix.filter.alpha` extraction step feeds into
   povray as a separate upstream and the template stays the same.
7. **image_map vs uv_mapping** — texturing a cylinder with an
   image in povray has two idioms ; `image_map` with `once` and
   a `scale`/`translate` [ the sketch above ] is the simpler one
   but wraps the image cylindrically only if the cylinder is
   oriented right. `uv_mapping` gives cleaner control but requires
   the cylinder to be defined with uv coordinates. pick during
   milestone 1 by trying both against a real audio-icon.
8. **template dir : `data/yaml/povray-templates/`** as spec'd in
   LIVING-BACKGROUND-SYSTEM.md is slightly odd [ .pov templates
   under `yaml/` ]. worth asking whether that path should stay or
   be renamed to `data/povray-templates/` before we materialize
   files there. defer to a one-line user decision.

## rejection log

things this plan considered and rejected :

- **generating .pov scenes fully from perl in-memory** : rejected,
  see § scene templating. templates are inspectable ; perl-strings
  are not.
- **synchronous `system('povray …')` in the render command** :
  rejected. povray renders are seconds-to-minutes ; blocking the
  event loop stalls the whole zenka. this is exactly the audio
  decode's problem and the solution [ IPC::Open3 + non-blocking
  io + event watchers ] is the same.
- **child-forking the render into a nested child zenka** [ weather-
  style ] : rejected for milestone 1. the audio precedent is
  cleaner and does not need a second network hop. reconsider if
  we ever want to keep the parent responsive to inbound commands
  while N renders run in parallel — but even then a per-render
  child process [ not a full child zenka ] is enough, we already
  have that via IPC::Open3.
- **a full checksum-cache subsystem in milestone 1** : deferred
  to milestone 2+. one symlink at finalize is fine ; a real cache
  index is not.

#,,,,,...,,..,.,,,..,,.,,,.,,,.,,,,,.,,,,,.,,,..,,...,...,...,..,,.,,,,..,...,
#PWO7IXN6D3XBH2ECQ22EX4PIDPKZ6GEBDYEINFHN2IFROIWNYIIRSTV7BTU764IGUWWOSIYCGYBIO
#\\\|AUKCP7XDKZVTLAQCNRGHTRMPZF5XVBGOXLPNBYLT6QDC55QBX5P \ / AMOS7 \ YOURUM ::
#\[7]OCT27AJ4SH6FBOIMJNWG2WX76XRFURJWBMR6MZPMSODP2RZYVECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
