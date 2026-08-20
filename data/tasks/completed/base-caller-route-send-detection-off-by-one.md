# fixed: base.protocol-7.command.send.local's route-send detection was silently wrong from event callbacks

## found & fixed 2026-07-18, while adding diagnostic logging for the
cred-mesh-rotation-subscription-cross-zenka.md investigation

## the bug

`src/base.protocol-7.command.send.local` determines whether it was
called directly or via `base.protocol-7.route-send` (to pick the right
frame depth for its `<{CN}>` warn annotations) with:

```perl
my $caller_level
    = [ <[base.caller]>->(1) ]->[0] eq qw| base.protocol-7.route-send |
    ? 2
    : 1;
```

`(1)` was one level too deep. This didn't show up for ordinary
(non-callback) call chains — apparently coincidental, not verified why —
but broke completely for calls originating inside an event-loop callback
(e.g. an idle-watcher's `->cb`): confirmed live via debug output that
`$caller_level` came out as `1` **regardless of whether the real caller
was `route-send` or a direct call**, for a case where it genuinely was
`route-send`. The detection wasn't just off by a fixed offset — it was
blind to the distinction entirely in that context, because the extra
frame the callback-dispatch machinery inserts sits exactly where the
check was looking, masking the real frame.

`p7_caller` itself (`bin/Protocol-7:3044-3056`, aliased as `base.caller`)
already accounts for its own frame internally (`$c_lvl++` before calling
Perl's `caller($c_lvl)`), and returns different shapes by context:
`wantarray` → `($filename, $line, $package, $subroutine)`; scalar →
pre-formatted `"[$filename:$line]"`. `$filename` here is the module's own
dotted name (this project's custom module-compilation gives each module a
synthetic "filename" matching its name), not an OS path — so comparing
`->[0]` (list context) against a literal module name string like
`'base.protocol-7.route-send'` is the correct approach in principle, the
bug was purely the frame-count argument.

## the fix

`(1)` → `(0)`:

```perl
my $caller_level
    = [ <[base.caller]>->(0) ]->[0] eq qw| base.protocol-7.route-send |
    ? 2
    : 1;
```

**Verified live**: both a `route-send`-based call and a direct
`send.local` call (same underlying trigger — the `base.log.send-buffer`
race documented separately, toggled between the two call shapes for this
specific test) now correctly resolve to the same, real originating call
site (`base.log.send-buffer.send-idle-callback:66`) via the new diagnostic
log line (`scalar <[base.caller]>->( $caller_level - 1 )`, added alongside
this fix — the `-1` there accounts for the same event-callback frame
insertion, on top of the now-correct `$caller_level` base value).

## why this matters beyond this one log line

This wasn't a bug in the new diagnostic logging — it was in the
pre-existing route-send-detection check that the file's own original
`<{C$caller_level}>` warn annotations (lines 15-18: `expected <command>
parameter`, `command string contained endlines`) already depended on.
Any warning from those two lines, fired from a call chain originating
inside an event-loop callback, was likely misreporting its `<{CN}>` frame
before this fix — silently, since a wrong frame number just points the
warning at a plausible-looking but incorrect location rather than
erroring. Not verified how many call sites are actually affected in
practice (this file is core/shared, used by every cross-zenka command
send), but worth keeping in mind: **any code using the pattern "check
`base.caller(1)` to detect whether a specific wrapper subroutine was the
immediate caller" has the same class of exposure when it can be reached
from an event callback**, not just this one file. Worth a broader grep
(`ncode s src '<\[base\.caller\]>->\(1\)'` or similar) if this pattern
turns out to be used elsewhere for the same kind of detection, but not
done as part of this investigation — scope was this one file.

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,..,..,,,.,,,..,,,.,...,.,.,...,.,,,,,,,,..,..,,...,...,,,.,,..,,,.,..,,,..,
#JXAKJ2HONMBYA7OEOWRKO4PW44P5JKVW526ZPYAAJVD5KTKNW2INTQWVSO7ZXPOV65HWP4JNVZJWI
#\\\|4XLZC4XEZ2D25WPCZR2MEC7TIJ7U3QNROR6N4UIUWGN3E4UX6EP \ / AMOS7 \ YOURUM ::
#\[7]BKJAOW3YZF42C7QSX2S62QQPADPMUPG73K73CWGEI4TB3BL2GEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
