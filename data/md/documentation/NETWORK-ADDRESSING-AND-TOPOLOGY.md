# Network Addressing and Topology Reference

**Date**: 2026-02-28
**Status**: REFERENCE — production-proven features

> These capabilities have powered public-facing display appliances and internal
> dashboards in production environments for over a decade. They are stable,
> configurable, and fully operational in the current codebase.

---

## Addressing Layers

Protocol-7 supports multiple orthogonal addressing mechanisms that can be
composed freely within a route.

### Name Addressing (group mode)

The default. A name like `weather` or `mpv` matches all sessions registered
under that name. Commands route to one matching session (or can broadcast).

```
weather.desc
mpv.pause
```

### Subname Addressing (narrowing group or specific instance)

Any zenka can be started with an appended `[subname]`:

```
v7.start mpv[top-right]
v7.start weather[hometown]
v7.start mpv[audio]
```

The subname becomes part of the network address and can be used anywhere in a
route, narrowing the target to sessions with that specific subname:

```
v7.restart mpv[top-right]
weather[hometown].desc
```

`list sessions` in cube shows only base names. Subnames are intentionally not
exposed at the cube session table level — regular routing is unaffected by
whether subnamed instances exist.

To inspect subnames:
- `v7.list subnames` — all subnamed instances across the network
- `weather.subname` — query a specific zenka's own subname

**Multiple concurrent instances** of the same zenka are managed via subnames
without requiring separate zenka definitions or config files.

### Session ID Addressing (point-to-point)

Numerical session IDs address a single specific session, bypassing group
resolution entirely. Session IDs can appear as the target or at any hop in a
route:

```
<session_id>.command
weather.<session_id>.command
```

Session IDs are ephemeral and scoped to the current cube session table.

### Composing Addresses in Routes

All three mechanisms are valid at any position in a route path, not only as
the final target:

```
parent.cube.p7-log.append
weather[hometown].child.command
mpv[top-right].status
```

---

## Routing Fundamentals

Routing in Protocol-7 is **relative**. A route describes hops from the current
zenka outward:

- `weather.desc` — route to zenka named `weather`, call `desc`
- `parent.cube.p7-log.append` — go via the `parent` session, then via `cube`,
  then to `p7-log`, call `append`

The `cube` zenka is the central message router. All networked zenki connect to
it. Routes may pass through cube at any hop.

`<protocol-7.network.parent_route>` tracks the routing path back toward the
network root from the current zenka's perspective, as an array from nearest to
farthest. In a forked child zenka this is `['parent', 'cube']`; in a directly
connected zenka it is `['cube']`.

---

## Child Zenki

A zenka can fork a child process for blocking operations. The child remains
fully network-accessible, routed through the parent:

```
weather.child.command
letsencr.child.status
```

Nesting is unlimited — a child can itself fork children, extending the route
accordingly. Children communicate with the parent over a Unix socket pair using
the Protocol-7 protocol, with session aliases `parent` (from child's
perspective) and `child` (from parent's perspective).

The parent's `<protocol-7.network.parent_route>` is inherited and extended with
`unshift` on the child side before the parent session is initialized.

---

## Access Control

All command routing in cube is **whitelist-only**. Access is configured per
zenka in `cfg/zenki/cube/access.zenki`.

**Wildcards** serve two distinct roles:
- *Convenience shortcut* — during development when command surfaces are not yet
  stable. Generates a level 1 startup warning:
  `:.  <zenka> : << wildcard access pattern configured >>`
- *Structural necessity* — relay and routing zenki that forward commands beyond
  their own hop cannot enumerate downstream commands. Wildcards are correct and
  expected in this case.

### devmod — Signal-Based Module Loading

Development and diagnostic commands live in the `devmod` namespace, loadable
on demand without any filesystem access or reinit phase:

- **Enable**: `v7.devmod-enable <zenka>` — looks up the zenka PID and sends
  SIGNUM53; the signal handler loads the devmod module and its commands
- **Disable**: `devmod.cmd.unload-devmod` — unloads the module again cleanly
- **Access gate**: who can call `v7.devmod-enable` is controlled by the
  standard cube access config, not by any devmod-specific mechanism
- **Unix permissions**: manually sending SIGNUM53 requires the same Unix
  permissions as the target process — no privilege escalation vector

Commands in the devmod namespace (e.g., `devmod.cmd.parent-route`) are
available only while the module is loaded, and only to callers permitted by
the access config.

---

## Network Topologies

All of the following topologies are supported in the current codebase via
configuration only — no code changes required.

### Single Cube (standard)

All zenki connect to one cube instance. The cube routes all inter-zenka
communication.

```
v7 ── cube ── weather
               ├── httpd
               ├── mpv
               └── p7-log
```

### Multi-Cube (isolated networks)

Multiple cube instances run simultaneously, each serving a logical network
segment. Example: a `web-cube` for HTTP and HTML parsing zenki, isolated from
the main cube serving core system zenki.

```
main-cube ── v7
          ── system
          ── p7-log

web-cube  ── httpd
          ── web-browser
          ── html-parser
```

Segments are interconnected by **filtering relay zenki** — zenki that connect
to both cubes and selectively forward commands between them, acting as policy
enforcement points without baking access logic into either cube.

### Filtering Relay Zenka

A relay zenka connects to two or more network segments and controls which
commands and which zenki can communicate across the boundary. This allows:

- Access policy enforcement at segment boundaries
- Selective command forwarding with logging or transformation
- v7 itself reachable through a relay with restricted command access

### On-Demand Zenki

Zenki can be configured to start only when first accessed and shut down after
an idle timeout:

```
start.on-demand    = 1
restart.disabled   = 1
heartbeat.disabled = 1
```

Examples: `calc` (4200s timeout), `image2html` (420s timeout), `coding`
(3600s), `models` (1800s).

---

## X11 Zenki and Display Canvas

The following zenki use `[base.X-11.get_display]` and participate in the X11
display layer:

| Zenka           | Role                                      |
|-----------------|-------------------------------------------|
| `X-11`          | Core X11 connection and display management|
| `X-11-pointer`  | Mouse/pointer control                     |
| `openbox`       | Window manager                            |
| `compton`       | Compositor                                |
| `tile-groups`   | Tile layout and window geometry management|
| `mpv`           | Video/audio playback                      |
| `web-browser`   | WebKit GTK3 web-browser with autoscroll   |
| `impressive`    | Presentation display                      |
| `ticker`        | Scrolling text display                    |
| `osd-logo`      | On-screen display / logo overlay          |
| `notify`        | Notification system                       |
| `notify-osd`    | OSD-style notifications                   |
| `auto-hide`     | Automatic mouse cursor hiding             |
| `screenshot`    | Screen capture                            |
| `start-anim`    | Startup animation                         |
| `content`       | Nailara content management zenka — manages content lists across all content types with single-command update propagation to the relevant display zenki |
| `universal`     | Generic universal content player — hosts other display zenki as children (web-browser, mpv, etc.), sequencing between them with configurable translucency fade transitions |
| `reenc-msg`     | GTK overlay zenka displaying a blinking translucent corner indicator while an ffmpeg reencoding zenka is active; shuts down automatically when pings from the encoder stop |
| `remote-cam`    | Remote camera feed display                |
| `storchencam`   | Storch camera feed display                |
| `dbus`          | D-Bus bridge for desktop integration      |

### tile-groups and Subname Geometry

The `tile-groups` zenka maps tile names to window geometry (position and
dimensions). Any X11-capable zenka started with a subname matching a tile name
inherits that tile's geometry automatically — no per-zenka configuration
required.

```
v7.start mpv[top-right]       # opens mpv sized and positioned to the top-right tile
v7.stop  mpv[top-right]
v7.start web-browser[top-right]  # browser opens at exactly the same position and size
```

The tile name is simultaneously:
- the subname for network addressing (`mpv[top-right]`)
- the geometry lookup key in tile-groups
- the routing address for management commands (`v7.restart mpv[top-right]`)

This extends the Protocol-7 network addressing model into the display canvas —
screen positions become first-class network addresses. No mapping table, no
per-zenka config, no coordination beyond the tile-groups configuration.

Multiple concurrent display instances at different positions are natural:

```
v7.start mpv[top-left]
v7.start mpv[top-right]
v7.start mpv[bottom-left]

mpv.pause           # pauses all three
mpv[top-right].pause  # pauses only top-right
```

---

## Summary: Addressing Dimensions

| Mechanism       | Scope           | Persistence  | Use case                          |
|-----------------|-----------------|--------------|-----------------------------------|
| Name            | group           | session      | normal routing, broadcast         |
| Subname         | narrower group  | session      | concurrent instances, specialization, display tiles |
| Session ID      | single session  | ephemeral    | precise point-to-point targeting  |
| Composition     | any of above    | —            | multi-hop routes, cross-segment   |

#,,.,,.,,,,.,,,..,,..,...,.,.,,.,,,,.,,..,,,,,..,,...,...,.,,,.,,,.,.,.,,,...,
#I4DELE7LDS73VQAGBBI4E7L2AA7VAQVV7BK467MR5X4U3QDHOZ4EK7FHHL237ZBHQ664KUV2EP4HS
#\\\|K6GBKSTXRHGXO2NLZX3MABOVA7ZXXTM4XC6CQG7AFZEQJ5RKIX6 \ / AMOS7 \ YOURUM ::
#\[7]Z2HUY3HBRXJPMY52BSLULHDJRE7MKCOKKT6WLWDVJ46IP5KFVEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
