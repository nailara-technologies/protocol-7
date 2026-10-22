---
name: perl-self-signal-and-pty-test-traps
description: re-raising a signal from inside its own perl handler does nothing [ blocked ] ; pty test harnesses hide TSTP, EIO and drain-timing — use STOP, treat EIO as eof, keep waiting after closing the master
metadata:
  type: feedback
---

found 2026-10-21 while hardening AMOS7::TERM::Editor [ 19d1e54dc ] :

- **perl blocks a signal while its own handler runs** : `local $SIG{TSTP} = 'DEFAULT'; kill TSTP => $$` inside the TSTP handler only queues it -- it re-enters the handler after return [ loop, never stops ]. stop with `kill STOP => $$` [ cannot be blocked ] ; a CONT handler re-applies raw mode. HUP \ TERM handlers that set a NON-local `'DEFAULT'` then re-raise do work [ pending signal fires after return with default action ]
- **a lost tty reads as EIO, not eof** : `sysread` on a pty slave whose master closed usually returns undef + EIO, only sometimes 0 -- an eof check on `$n == 0` alone passes once and spins the next time [ race ]. treat any error except EINTR \ EAGAIN as input gone
- **pty harness traps** :
  - a `setsid` child is an orphaned process group : the kernel DISCARDS default-action TSTP there [ state stays `S` ] -- only a caught TSTP or STOP is testable that way
  - after closing the master, a drain loop gated on `fileno` returns instantly -- a "wait for exit" loop built on it waits 0 s and reports a false hang
  - pasted control bytes land in the text literally and are invisible when printed -- compare exact strings \ hex, not by eye
  - `pgrep -f <pattern>` from backticks can match the backtick shell itself : have the child write its own pid file

**Why:** each of these produced a wrong verdict in one session [ false pass, false hang, a fix that looked broken ]. **How to apply:** for any terminal \ signal code [ Editor.pm, nshell, p7-vault ], test on a real pty with `bin/test-scripts/test-term-editor-pty.pl` as the template ; related : [[never-touch-sig-under-event-watcher]]

#,,,.,,,.,...,..,,...,,.,,,..,..,,.,.,,,,,,.,,..,,...,...,.,.,..,,.,,,.,,,,,.,
#4W2DRWLM4IYEO4ZZIJE67HVEAM5CWQZQCVSX2Z7IY6LTAC74ZXU3LTEJKURQKZ36JLLLXZ3QDAIQ4
#\\\|HN2LZU56FEKXESYMHBTJZID3XO4XA76PCFN4HZUFLHIZEHWBAB7 \ / AMOS7 \ YOURUM ::
#\[7]GUGBDHISHNEE3JG2VEP3ORD2WII7OKKSGQJOHUQ3FEO5VYRIJQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
