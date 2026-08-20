## [:< ##

# name  = task: X-11 wait_visible — skip blocking wait when enumeration unavailable
# descr = on WSL/Wayland host mode, X-11.get_window_ids returns empty so
#         wait_visible always blocks for full timeout — detect and skip early

## context

`X-11.cmd.wait_visible` is called by `base.X-11.wait_for_window` which is used
by these zenki during startup:
  - web-browser.wait_for_window
  - mpv.await_window_presence
  - impressive.open_window
  - start-anim.wait_for_window
  - remote-cam.sdl_loop
  - storchencam.sdl_loop

on kiosk hardware: X-11 enumerates windows correctly, the pattern works.
on WSL/Wayland host mode: `X-11.get_window_ids` returns empty because the
compositor doesn't expose the window tree. every `wait_visible` call spins
a poll timer and blocks for the full timeout (default 7 seconds) before
giving up and continuing. multiple zenki starting together = 7×N seconds
of unnecessary startup delay.

the callers already handle the FALSE/undef return (they log a warning and
continue) — so returning immediately is safe. the window will be visible or
not, but the X-11 zenka has no way to know either way in this mode.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat src/X-11.cmd.wait_visible         ## the full wait logic
cat src/X-11.init_code                ## where to set capability flag
cat src/X-11.get_window_ids           ## returns empty on WSL
cat src/base.X-11.wait_for_window     ## caller — handles FALSE gracefully
```

---

## fix 1: detect window enumeration capability during init

file: `src/X-11.init_code`

after X-11 connects to the display (in post_init or at end of init_code),
add a capability probe:

```perl
## test if window enumeration works
my @test_ids = eval { <[X-11.get_window_ids]> };
<X-11.window_enumeration> = ( !$@ && @test_ids ) ? TRUE : FALSE;

if ( <X-11.window_enumeration> ) {
    <[base.log]>->( 2, 'window enumeration: available' );
} else {
    <[base.log]>->( 1, 'window enumeration: unavailable [ host/wayland mode ]' );
}
```

if `init_code` runs before the display connection is established, move this
probe to `X-11.post_init` instead — check where `get_window_ids` first becomes
callable.

## fix 2: early return in wait_visible when enumeration unavailable

file: `src/X-11.cmd.wait_visible`

add an early return after argument parsing, before the `get_window_ids` scan:

```perl
## in host mode without window enumeration, skip the wait entirely
## callers handle FALSE gracefully — they proceed without the window id
if ( not <X-11.window_enumeration> ) {
    <[base.log]>->(
        1, "wait_visible: skipping [ window enumeration unavailable ]"
    );
    return {
        'mode' => qw| false |,
        'data' => 'window enumeration unavailable — skipping wait'
    };
}
```

place this check after the argument validation block and before the
`foreach my $window_id (<[X-11.get_window_ids]>)` scan.

## fix 3: reduce log noise in callers (optional)

file: `src/base.X-11.wait_for_window`

the current timeout message is:
```perl
<[base.log]>->( 0, ": window startup timed out after $timeout seconds.," );
```

when enumeration is unavailable the message will be:
```
: window startup timed out ...
```
which is misleading (it didn't time out, it was skipped).

check the reply string for the new 'unavailable' message and log at level 2
(not level 0) to reduce noise:

```perl
if ( $reply_string =~ m|unavailable| ) {
    <[base.log]>->( 2, ": window wait skipped [ enumeration unavailable ]" );
} elsif ( $reply_string =~ m|timed out| ) {
    <[base.log]>->( 0, ": window startup timed out after $timeout seconds.," );
}
```

---

## test sequence

```bash
## with X-11 in host mode on WSL, start a zenka that uses wait_for_window:
p7c v7.restart web-browser

## timing: should start in < 2 seconds, not 7+
## log should show: "wait_visible: skipping [ window enumeration unavailable ]"
## NOT: "window startup timed out after 7 seconds"

## verify capability flag is set:
## check X-11 startup log for:
## "window enumeration: unavailable [ host/wayland mode ]"
```

## success criteria

- [ ] `<X-11.window_enumeration>` flag set during X-11 init/post_init
- [ ] flag is TRUE when `get_window_ids` returns results
- [ ] flag is FALSE in WSL host mode (empty window list)
- [ ] `wait_visible` returns immediately when flag is FALSE
- [ ] zenka startup no longer delays 7s per window wait on WSL
- [ ] log message distinguishes "skipped" from "timed out"
- [ ] kiosk behavior (wait_visible working) completely unchanged
- [ ] no signature stubs added, no subroutine whitelist changes made

## dispatch

model: kimi
reasoning: medium

prompt: |
  Implement the task at data/tasks/x11-wait-visible-host-mode-skip.md

  Read the task file first, then read the 4 modules listed in "what to read first".
  The fix is: (1) probe window enumeration capability during X-11 init and set a flag,
  (2) add an early return in wait_visible when the flag is FALSE, (3) optionally reduce
  log noise in base.X-11.wait_for_window to distinguish "skipped" from "timed out".
  No signature stubs, no whitelist changes.

#,,,.,,,,,,,,,..,,.,,,,.,,...,,..,,,.,..,,,,,,..,,...,...,.,,,,,,,,,,,.,,,.,,,
#JBK3A5YBLAYZ3QGGSP5UZ35MKM2Q2CVK27NJ77WIFSQZ6JTKV7BCJ2LXVUFP4XNL7KDSQSVVQZSJE
#\\\|XITXXZZZOBGSQ5RVSEVKAW352CH55WITADVDNX7RWNV276MQLSN \ / AMOS7 \ YOURUM ::
#\[7]G6PJX6YDTRHUVDWFY2ZAAQ6JAZFVODQJYIO2SNJ75KUK2WBN7MBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
