---
name: feedback-no-per-call-perlmod-autoload
description: never call base.perlmod.autoload in a module that runs per call \ per tick -- every call logs 'skipping already present' and floods the console ; load in init_code or guard with `if not defined &Pkg::sub`
metadata:
  type: feedback
---

`<[base.perlmod.autoload]>->('Module')` logs a "skipping already present"
line each time it is called for an already loaded module. in a module that
runs per call, per timer tick or per item it floods the console.

happened twice on 2026-09-29 : DBI in `invoke-web.queue.db` [ interactive
queue watch, every 3s ] and Imager \ List::Util in `image.analyze.file`
[ per image while indexing ~50k images ] -- the user caught it both times.

**Why:** the console is the user's live view of the system ; repeated noise
hides real events and cost two fix-and-reload rounds the same day.
**How to apply:** in any module that is called repeatedly, either load the
perl module once in the zenka's `init_code` [ the
`map { <[base.perlmod.autoload]>->($ARG) } qw| .. |` line ], or guard the call
: `<[base.perlmod.autoload]>->('Imager') if not defined &Imager::new;` [ the
guard form for shared modules cross-loaded into several zenki ]. check new
hot-path modules for this before loading them live.

#,,,,,.,,,,,.,,.,,.,,,,,,,.,,,,,.,.,,,,,.,,,,,..,,...,...,,.,,,..,.,.,.,,,.,.,
#ESWND65YPZXLPSWWDYPQLUKCDCQRFV7X23LX5AWKIHQAZZPYIJXQCCDK7YEPH6QYVB42MIBDGH2N4
#\\\|5HX7C624EUWDAPDYFTROGXABG633V4NW4TSDSXSM3CI2DY2BJ2Q \ / AMOS7 \ YOURUM ::
#\[7]47BKZGXEOCHUAAZZIXAQQOHO5XAJHNVZ24X5YXAAAZHTGLVWOMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
