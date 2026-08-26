---
name: base.curve — generic parameter curve / animation system
description: generic timer-driven curve evaluator in base.* namespace; composable factors; used by mpv, radio relay, and any zenka needing smooth parameter transitions
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## motivation

mpv zenka has volume fade via a curve, but the logic is mpv-specific
and not reusable. any zenka wanting smooth parameter transitions
(volume, brightness, speed, rate limiting, opacity, zoom, scroll)
needs the same primitive: evaluate a curve type at normalized time
t ∈ [0,1], drive it from a timer, call back with the current value.

placing in base.* makes it available to all zenki with no dependency
on mpv or any specific consumer.

## core API

    base.curve.register( {
        id       => $name,           ## optional : auto-assigned if omitted
        from     => $start_val,
        to       => $end_val,
        duration => $seconds,
        type     => 'linear' | 'ease-in' | 'ease-out'
                  | 'ease-in-out' | 'step' | 'hold',
        callback => sub { my $val = shift; ... },
        on_done  => sub { ... },     ## optional : called at t=1
    } )

    base.curve.cancel( $id )         ## stop early
    base.curve.eval( $type, $t )     ## evaluate curve at t ∈ [0,1]

timer tick: event loop fires at configured resolution (e.g. 50ms for
smooth audio fades), advances all active curves, calls callbacks with
current interpolated value.

## composition — signal chain

multiple curves combined into a single output value per tick:

    base.curve.compose( {
        id      => $name,
        factors => [ $curve_id_A, $curve_id_B, ... ],
        mode    => 'product' | 'sum',
        clamp   => [ $min, $max ],   ## optional
        callback => sub { my $val = shift; ... },
    } )

each factor is an independently registered curve (or a slow-moving
ambient/daytime value). composition layer multiplies (or sums) their
current values each tick — no special-casing for timescale differences.

## example: volume signal chain

    daytime envelope   × ambient compensator × immediate fade = output

- daytime: slow sinusoidal curve over 24h, peak midday, floor at night
- ambient: updated externally (microphone level, light sensor, manual)
  held as a scalar factor; treated as a 'hold' curve
- immediate fade: fast curve (2-4s), triggered on track switch or skip
- compose with product + clamp [0, 100] → set mpv volume each tick

## curve types

- `linear`       — constant rate change
- `ease-in`      — slow start, fast finish  [ cubic ]
- `ease-out`     — fast start, slow finish  [ cubic ]
- `ease-in-out`  — slow at both ends        [ cubic ]
- `step`         — instant jump at t=0.5
- `hold`         — constant value (for external factors in compose)

## module outline

- `base.curve.register`  — create and start a named curve
- `base.curve.cancel`    — stop and remove a running curve
- `base.curve.eval`      — pure function: curve type × t → value
- `base.curve.compose`   — combine factor curves into output callback
- `base.curve.tick`      — internal: advance all curves, fire callbacks
- `base.curve.init`      — set up the shared tick timer at init time

## consumers

- **mpv zenka** — volume, speed, hue, contrast, gamma, brightness, zoom
  via `set_property` JSON IPC; immediate fade uses compose with daytime
  and ambient factors
- **radio relay** — crossfade between mpv-A and mpv-B; BPM speed ramp
- **future** — any zenka needing smooth transitions: rate limiting,
  UI animations, sensor-driven parameter adjustment

## relation to mpv.param.curve

`mpv.param.curve` becomes a thin wrapper: registers a base.curve,
wires callback to `mpv set_property <param> <val>`. the generic
compose and daytime/ambient factoring live in base.curve, not in mpv.

**How to apply:** implement base.curve.{register,cancel,eval,tick}
first; then refactor mpv volume fade to use it; then add compose for
the daytime/ambient chain. radio relay uses compose for crossfade.

#,,..,...,..,,,,.,..,,...,...,,..,.,.,..,,,,.,..,,...,...,.,,,...,,,.,,..,...,
#T2TSKM2SENY5WQEGNNA5PYRGBLL6LRTYOZQOTIOZ4PIKOKIP75NBBVHUMX5KVO2BDKEN7RY5ZTLIY
#\\\|KFK2CCYKU4ZVETUCX3K6MGAVYG6ZBDAL4YVYBNYX2HJJ36OLBAS \ / AMOS7 \ YOURUM ::
#\[7]USRUNWL5JZCG2WABG4QLC7USFX5WLWKHCRSV4NSAQLFFZCJJX2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
