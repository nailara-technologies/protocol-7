## [:< ##

# name  = task: mpv — remove stale xephyr video output override
# descr = test gpu/xv under xephyr and remove SDL override from 2019

## context

commit `0c22a313c` (2019-12-03) forced `mpv.xmode.xephyr.vo = xv` because
"SDL is suddenly broken". later the config was changed to `sdl` (current state).
the override lives in `cfg/zenki/mpv/start` and `src/mpv.init_code`.

in 2026, SDL on Debian unstable is likely stable. forcing `sdl` (or `xv`)
instead of `gpu` loses hardware decoding and performance in nested X sessions.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: test gpu under xephyr

file: `cfg/zenki/mpv/start`

comment out or temporarily change:
```
mpv.xmode.xephyr.vo = sdl
```

to:
```
mpv.xmode.xephyr.vo = gpu
```

start the mpv zenka in xephyr mode and play a video. verify:
- no crash on startup
- hardware decoding works (check `mpv.current-hwdec`)
- frame drops are acceptable

## fix 2: test xv fallback if gpu fails

if `gpu` fails under xephyr, try `xv`:
```
mpv.xmode.xephyr.vo = xv
```

`xv` is older but more compatible with nested X11.

## fix 3: commit the change

once a stable vo is confirmed, remove the override entirely and let
`mpv.vo_backend` propagate naturally, or update the comment to reflect the
current state.

if `gpu` works, delete the line from `cfg/zenki/mpv/start` and update
`src/mpv.init_code` to default to `gpu` for xephyr:
```perl
<mpv.xmode.xephyr.vo> //= qw| gpu |;
```

## success criteria

- [ ] mpv plays video under xephyr without the SDL override
- [ ] stable video output confirmed (gpu preferred, xv acceptable)
- [ ] override removed from `cfg/zenki/mpv/start`
- [ ] default updated in `src/mpv.init_code`
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,.,,,..,,.,,,.,,,,.,,,.,..,,,,.,,,.,...,.,,,..,,...,...,...,,,.,,,.,,..,,,.,
#PB4YJC2XDV4U5SN7AUDUSQZRMAPBWWJG5TQOBVD7AQZRSY6LIBUTGKSWVY5WR3NTBJVTAR2RMNZWU
#\\\|6SJD3SANZHRW7ZPKTNFRRC757PQAIHFYBMCUBYSBPYNYAOAWEAO \ / AMOS7 \ YOURUM ::
#\[7]NLWZKQ2A6GPE6WTYB55FYH73INXA2RGHVYVYPSMQFYEEJXQ4VMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
