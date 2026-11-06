# compton context intelligence

status : idea, parked 2026-11-01 [ not implemented ]

## why the zenka stays

an ext-bin entry only takes static `exec_args`. `compton.startup` builds the
command line at start from live context :

- display from X-11 [ `-d :13` on srv-16, chosen by X-11 ]
- shadow tint derived from the background colour [ `base.X-11.get_bg_color` ]
- vsync options by driver [ nvidia ] and mode [ xephyr ]
- already-running and no-composite handling, xclient error parsing

this note turns that one-shot derivation into a continuous one.

## goal

the compositor follows the desktop context, mainly dynamic backgrounds :

1. subscribe to background changes [ the tile zenka already polls tile
   colours : `tile.handler.poll_tile_color_reply` \ `bg_color_reply` ]
2. measure the new background : dominant hue, luminance, contrast, busyness
   [ per screen when several ]
3. derive :
   - shadow tint [ exists, start-only today ]
   - shadow strength scaled to luminance [ dark violet needs less ]
   - per-class opacity [ menu, ticker, xterm ] scaled to busyness
   - blur strength
   - tint hue \ value harmonics [ see `CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md` ]
4. apply the cheapest way :
   - live : dbus `opts_set` \ per-window calls where the option allows it
   - reload : write a config file + `SIGUSR1` [ picom ; check compton ]
   - restart : last resort only
5. rate-limit : a slideshow or animated background must not reload often ;
   apply only when the derived values move beyond a threshold

later : context profiles beyond the background [ video playing, presentation,
low power ] through the same apply path.

## first step before any code

check on the target which binary runs and what it supports :

    compton --version ; compton --help 2>&1 | grep -i -A1 dbus

the answer decides which options are live, which need the reload, and
whether the command line moves into a generated config file.

## slices

- s1 : config-file generation from the current startup logic [ same output ]
- s2 : background-change subscription + shadow tint recalculation + apply
  through the cheapest available path, rate-limited
- s3 : luminance \ busyness metrics -> shadow strength, opacity, blur
- s4 : harmonic tint templates, context profiles

#,,,.,,..,..,,,.,,.,,,.,.,,..,,,.,.,,,.,.,.,.,..,,...,...,.,,,,,,,..,,,,.,,.,,
#3N2NWYED7ZOIC7X3CKYAX2PJPHSIVFTY5DOEY46MHDLVYHRMPRNQ4IQK3MZAKFNSIN63L6ZZGZPWC
#\\\|KJ34OGOLUYSPLY3EYBWP2K7OINHC2D3G7MPBH3QEKJAK3H3G7ST \ / AMOS7 \ YOURUM ::
#\[7]JLGG74MOO4P57UHCSNMPQCNJX7VDDJKM723QQWG2QNOQTWOBEYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
