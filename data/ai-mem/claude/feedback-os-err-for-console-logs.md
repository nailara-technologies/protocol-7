---
name: feedback-os-err-for-console-logs
description: in src/* log lines use <[base.str.os_err]> instead of raw $OS_ERROR -- a cleaned up form for console logging
metadata:
  type: feedback
---

in `src/*` modules, error text in log \ warn lines uses `<[base.str.os_err]>`,
not raw `$OS_ERROR` [ it wraps `base.format_error( $OS_ERROR, -1 )` : cleaned
up, no caller info ]. e.g. `<[base.logs]>->( 0, ': cannot run %s [ %s ]',
$path, <[base.str.os_err]> )`.

**Why:** user 2026-10-29 -- the raw form is not suitable for console output.

**How to apply:** any new zenka-side log line that reports a failed system
call. standalone scripts [ bin/* without the zenka loader ] keep `$OS_ERROR`.

#,,.,,,..,,,.,,,,,..,,,,,,..,,,,.,.,.,.,,,,.,,..,,...,...,...,.,,,,.,,.,,,,..,
#PTTIR2ATTLBWBYIKVXKQWLESUKQ4EBXPBGBU3RXYPIYPTZGAK35NZQNTBICCR4EXPDSXLKEWBXGNO
#\\\|HXL23QPT5XXR2M3QWSPPKBSOWBQRI7XGZBJBZWNBI53QYQRAJTK \ / AMOS7 \ YOURUM ::
#\[7]JIESI5LPFU3JOX66CSELY6BGAZLA4YCEHAFF4YWETNOQAXXMYOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
