# task: prototype a minimal Perl Wayland client for native screen capture

## context

X-11/screenshot capture is structurally broken in this WSLg/Xwayland environment.
extensive investigation (not guesswork) established:

- `Imager::Screenshot`'s X11 backend (plain `XGetImage` on the root window) fails
  with `BadMatch` — confirmed by running the module's OWN `make test` suite, which
  fails identically even on the simplest case (`screenshot(id => 0)`, full root
  capture). this is not a packaging defect or our code's fault.
- `scrot` (Imlib2-based) does NOT actually work either — it exits 0 and writes a
  file, but the file is uniformly transparent (`0,0,0,0` RGBA every pixel). a
  silent failure, not a real capture.
- GTK/GDK `pixbuf_get_from_window` on the X11 backend root window: same silent
  blank-image failure.
- root cause: WSLg's XWayland runs **rootless** — the X11 "root window" has no
  real composited backing pixmap. each top-level X11 window is its own separate
  Wayland surface. any approach that tries to read pixels off the X11 root
  window is structurally doomed in this environment, regardless of library.
- the WSLg compositor DOES advertise a native, working capture mechanism:
  `weston_screenshooter` (confirmed via `wayland-info`: version 1, name 18,
  present in the global registry). it does NOT advertise `wlr-screencopy` or
  `ext-image-copy-capture-v1`, so `grim`/`slurp`/sway tooling won't work here.
- the packaged `weston-screenshooter` CLI binary (from weston 15.0.1, built
  against the *modern* `weston_capture_v1`/output-capture protocol) segfaults
  against WSLg's compositor — NULL deref in `wl_proxy_get_version()`, consistent
  with a protocol/interface mismatch. modern weston dev packages no longer ship
  the legacy protocol XML at all; WSLg's bundled compositor is evidently an
  older Weston build that still speaks the legacy `weston_screenshooter`
  protocol (matches the version 1 advertised live).
- there is no existing high-level Perl Wayland binding (`ncpan search Wayland`
  → only `Clipboard::WaylandClipboard`, unrelated). `FFI::Platypus` is also not
  currently installed. this means going through libwayland-client via FFI is
  not a zero-setup option either.

conclusion: the only environment-correct path is a **minimal, pure-Perl, raw
Wayland wire-protocol client** that speaks the legacy `weston_screenshooter`
protocol directly over the Unix domain socket. no libwayland, no GTK, no
external capture binary.

## the protocol (authoritative, fetched from weston's own source tree)

this is the COMPLETE protocol — one request, one event, nothing else:

```xml
<protocol name="weston_screenshooter">
  <interface name="weston_screenshooter" version="1">
    <request name="shoot">
      <arg name="output" type="object" interface="wl_output"/>
      <arg name="buffer" type="object" interface="wl_buffer"/>
    </request>
    <event name="done">
    </event>
  </interface>
</protocol>
```

confirmed live via `wayland-info` against this exact environment: interface
name `weston_screenshooter`, version 1. matches the XML above exactly.

## wire protocol basics needed (core Wayland, not weston-specific)

every Wayland message on the wire is:
```
[ object_id: u32 ] [ opcode: u16 | size: u16 ] [ args... ] [ optional fds via SCM_RIGHTS ]
```
- object_id: u32, target object
- opcode: u16 (low 16 bits of second word), size: u16 (high 16 bits, total
  message length in bytes including the 8-byte header)
- arg encoding: `int`/`uint` = 4 bytes; `object`/`new_id` = 4 bytes (id);
  `string`/`array` = u32 length + bytes + NUL + padding to 4-byte boundary;
  `fd` = NOT in the byte stream — passed out-of-band via `SCM_RIGHTS` ancillary
  data on the same `sendmsg()` call that sends the message containing it
- byte order: native (host) byte order, no network byte order conversion
- all objects are referenced by client-assigned `new_id` (client picks the next
  free id) or server-assigned ids announced via registry events

## required client flow

1. connect to `$ENV{XDG_RUNTIME_DIR}/$ENV{WAYLAND_DISPLAY}`
   (this environment: `/run/user/1000/wayland-0`) via a Unix domain socket.
2. `wl_display` is always object id 1 (implicit, no bind needed).
3. send `wl_display.get_registry(new_id)` — assign the registry the next id
   (2). this triggers a stream of `wl_registry.global(name, interface, version)`
   events — read and collect them all (one display roundtrip; use
   `wl_display.sync` + wait for the corresponding `wl_callback.done`, or simply
   read until a short idle/timeout window — see `data/lib-path/pm` for any
   existing low-level socket helpers before writing new ones).
4. from the collected globals, find and `wl_registry.bind()`:
   - `wl_shm` (need its global name + version)
   - `wl_output` — WSLg advertises **three** (names 11, 27, 28 in earlier
     investigation this session; re-discover live, don't hardcode) — bind
     the one corresponding to the monitor you want to capture (start with
     just binding the first one for the prototype)
   - `weston_screenshooter` (global name 18 in earlier investigation; name may
     differ across compositor restarts — discover live)
5. create an anonymous backing file for shared memory (`memfd_create` via
   direct syscall, or `File::Temp` + immediately `unlink` while keeping the fd
   open works too as a portable fallback), sized `width * height * 4` bytes
   (one `wl_output.geometry`/`wl_output.mode` event from step 3 gives you the
   output's pixel dimensions — capture those events when parsing the registry
   roundtrip).
6. `wl_shm.create_pool(new_id, fd, size)` — this is the one request that needs
   `fd` passed via `SCM_RIGHTS`. Perl's core `Socket` already exposes
   `SCM_RIGHTS`; sending ancillary data needs `sendmsg()` with a control
   message, which is not exposed by core `Socket.pm`'s buffer-only `send()`.
   check `ncpan search MsgHdr` / `ncpan search Socket` for a usable
   `sendmsg`-with-ancillary-data module (e.g. `Socket::MsgHdr` if installable)
   before writing raw XS/syscall glue — prefer an existing CPAN module if one
   installs cleanly.
7. `wl_shm_pool.create_buffer(new_id, offset=0, width, height, stride=width*4,
   format=WL_SHM_FORMAT_XRGB8888 (value 1) or ARGB8888 (value 0))`.
8. `weston_screenshooter.shoot(output_object_id, buffer_object_id)`.
9. read events until `weston_screenshooter`'s `done` event (opcode 0, no args)
   arrives on that object id.
10. `mmap()` the same backing fd (or just read the bytes back from it via the
    filehandle — no need for true mmap if a plain read works since nothing
    else is writing to it after `done`) and convert the raw BGRX/ARGB pixel
    bytes into a PNG via `Imager` (`Imager->new('xsize'=>$w,'ysize'=>$h,
    'channels'=>4,'raw_data'=>$bytes,'data_layout'=>'rgba')` or equivalent —
    check `Imager`'s `read_raw`/`new(raw_data=>...)` interface and watch out
    for the BGRX vs RGBA channel order from `wl_shm` formats).

## scope for this prototype

this is explicitly a **standalone prototype script**, not yet integrated into
the screenshot or X-11 zenka. write it as a plain script under `/tmp/` or a
scratch location, runnable directly with `perl script.pl output.png` —
do NOT touch `modules/screenshot.*` or `modules/X-11.*` in this task.

## acceptance

- running the script against this live environment produces a PNG file
- the PNG is NOT uniformly blank/transparent (verify by checking pixel value
  variance with `Imager`, the same way the scrot false-positive was caught
  earlier — do not trust "no error + file exists" as success)
- report back: which CPAN module (if any) you used for `sendmsg`+`SCM_RIGHTS`,
  whether it needed installing, and the exact `wl_shm` pixel format /
  channel order that worked
- if you get stuck on a specific step, report exactly which step and what
  error/behavior you saw — do not paper over a failure by silently switching
  approach (e.g. falling back to scrot) without flagging it explicitly

## dispatch

## kimi: implement the prototype described above. read this whole file first.
## the protocol is tiny (one request, one event) — the work is entirely in the
## raw Wayland wire marshaling and SCM_RIGHTS fd passing, not protocol design.
## test live against $WAYLAND_DISPLAY in this environment (do not assume a
## different display). report results, including the channel-order/format
## finding, even if the prototype fails — a precise failure report is still
## useful here.

#,,,,,,.,,.,,,.,.,.,.,..,,.,.,.,.,.,,,.,.,,,,,..,,...,...,..,,.,,,..,,,,.,,,,,
#VELIJHQDNPKVTAWNEGSKMO76WJ7254VQVHQBC6S5PFZTPN5RTEIZWJXVDXPE35DZEPHBVYMWLL7Q6
#\\\|BXGX5ZEWJ6PXDTB27OURNTOLUHVZ7QW7U3OD3EUNGXLXA2TOCVV \ / AMOS7 \ YOURUM ::
#\[7]VM6CNDPNYCUJZXQQD3OWYO6M5NR453K76T2IBA52ACO4EYMASGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
