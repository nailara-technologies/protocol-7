## task: debug v7 log prefix width sync — all zenki must track with v7

### context

the log prefix width (lpw) system keeps all zenki output visually aligned.
when a new zenka with a longer name goes online, `v7.calc_prefix_lengths` sends
SIGNUM55 signals to all running zenki to increase their prefix width by one step
at a time (staggered 0.13s timers). v7 adjusts itself directly via `<[base.sig_NUM55]>`.

### observed symptom

when `tile-groups` (long name) starts up, v7 correctly steps up its lpw 4 times:
```
. DESKTOP-FP4OP26.v7      . :: SIG NUM55 :. increasing zenka log prefix width
. DESKTOP-FP4OP26.v7       . :: SIG NUM55 :. increasing zenka log prefix width
. DESKTOP-FP4OP26.v7        . :: SIG NUM55 :. increasing zenka log prefix width
. DESKTOP-FP4OP26.v7         . :: SIG NUM55 :. increasing zenka log prefix width
```

but `cube`, `tile-groups`, `p7-log` do NOT show corresponding increases.
`cube` logs ":: SIG NUM55 :: zenka prefix width reached" — hitting max immediately.

partial fix already applied this session:
- `v7.calc_prefix_lengths` now includes `cube` in the hardcoded iteration (alongside `v7`)
  reason: cube uses `set-initialized` not `notify-online`, so never enters `v7.online-zenki`

### what to investigate

1. **why does cube hit max immediately?** — `base.sig_NUM55` uses `$event->w->hints`
   to count combined signal events. if 7 signals arrive before the event loop processes them,
   `hints = 7` and cube jumps 7 steps at once (hitting max 27). is this a timing issue?
   is the staggered 0.13s timer not enough separation for cube's event loop?

2. **why do tile-groups and p7-log not catch up?**
   - are their PIDs correctly stored in `<v7.zenka.instance>->{id}->{'process'}->{'id'}`?
   - does `v7.zenka-instances.get-ids('tile-groups')` return a valid instance ID?
   - do the zenki receive the kill signal but fail to process it (event loop blocked)?
   - are there any conditions in `base.init_zenka.install_signal_handlers` that would
     skip registering NUM55/NUM41 for these zenki?

3. **timing of calc_prefix_lengths calls** — the function is called from:
   - `v7.zenka.change_status` (line 36) — every time online-count changes
   - `v7.handler.zenka_status` (line 403)
   how many times is it called during tile-groups startup? does it send staggered
   signals to the same PID multiple times (adding up), while v7 only self-signals once per call?

### key files

- `modules/v7.calc_prefix_lengths` — main logic; sends staggered kill 55 to PIDs
- `modules/base.sig_NUM55` — signal handler; `$event->w->hints` for combined count
- `modules/base.sig_NUM41` — decrease handler (same pattern)
- `modules/base.init_zenka.install_signal_handlers` — registers NUM55/NUM41 handlers
- `modules/v7.zenka-instances.get-ids` — PID lookup by zenka name
- `modules/v7.zenka.change_status` — triggers calc_prefix_lengths

### expected fix

all online zenki should step up their lpw by the same delta as v7, in sync.
the stepping should be gradual (1 step per timer tick, 0.13s apart) not instant.

### notes

- signatures note: do not modify the 4-line checksum footer at end of module files
- module format: `## [:< ##` header, no `sub {}` wrappers, filename = module name
- `<[module.name]>->()` invocation syntax; `<data.key>` for data tree access
- `$ARG` is the loop variable (not `$_`); `@ARG` is args array

#,,..,.,.,.,,,,,.,.,,,..,,.,,,,,.,...,,.,,...,..,,...,...,.,,,.,,,.,.,,,,,,,,,
#RZQHYTHPP4S2YWALU36UZNA326SNLV3F4S7V5WS4RIH77K35PJRIZUB5MTCGU5IISSDKEDCC6UIQ2
#\\\|TV35QHD32NBBEAGPP36ALKZEJKS3EXEHMIH4P5PIMGGSCTGECQ3 \ / AMOS7 \ YOURUM ::
#\[7]66XHIJ6XZLCEZIN5ZLMKPJCJNBLVA75BUEASHRTYZ5FIGWIPDMAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
