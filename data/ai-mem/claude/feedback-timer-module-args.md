---
name: feedback-timer-module-args
description: Timer-called modules receive event object as first @ARG — never use @_ ? shift for extra params in such modules
metadata:
  node_type: memory
  type: feedback
  originSessionId: 56461443-76ee-4bbf-9976-ee5713dd7c8d
---

Modules that are called both from timer watchers AND explicitly with extra args receive the event object as `$ARG[0]` / `$ARG[1]` from the timer call. Using `@_ ? shift : 0` to detect an explicit arg will always trigger (timer passes the event object), making the extra param meaningless.

**Why:** `jobsite.sync.push` is wired to a timer watcher AND called explicitly as `<[jobsite.sync.push]>->(undef, TRUE)` for manual sync. The event object is always `$ARG[0]`.

**How to apply:** Use `@ARG > 1` (or check `defined $ARG[1]`) to detect a second explicit param. Access it as `$ARG[1]`, not `shift`. Pattern: `my $force = ( @ARG > 1 ) ? <[base.cfg_bool]>->( $ARG[1] ) : FALSE;`

See also: [[feedback-arg-calling-convention]]

#,,..,..,,.,,,,,.,,..,,,,,,.,,.,,,,.,,,.,,.,,,..,,...,...,...,,,.,...,...,,.,,
#EWPH5RKZSX2DGAKYEPE37WW7PBPH4U55A5D447OFSD5UC56SSFMPUXQPBV47MJGR4UTWSFPY2W6NY
#\\\|7GIJPSPZIJO4GC3B4HO6JZ5VYZ5JROCX4NCO7RIFWEA53FFKLIG \ / AMOS7 \ YOURUM ::
#\[7]MERAB5SRY3VAJPWSFOD5WGCKR4HCBUTVOJ6BPIPUCDFPQVDV54CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
