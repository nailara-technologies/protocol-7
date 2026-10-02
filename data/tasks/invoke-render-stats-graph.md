# invoke-web : render statistics graph

brief [ 2026-10-02 ]. collection built, graph not. read `CLAUDE.md` first.

## what exists

every finished render [ done \ failed \ suspicious ] writes one row into
`<zenka data dir>/state/render-stats.db`, table `renders`, keyed by install +
session [ `invoke-web.handler.stats_record`, armed from
`invoke-web.render.report` ]. `p7c invoke-web.render-stats [ count ] [ install ]`
prints a table.

per row : install, model, size, steps, scheduler, passes [ 2 for heun \
dpmpp_2s \ dpmpp_sde ], cfg, lora \ ip-adapter \ ref counts, fingerprint
[ like-for-like key ], seconds per node kind [ encode, denoise, decode ] +
all nodes as json, process RAM + its delta [ cold vs warm ], model cache
hits \ misses, storage bytes read by invoke.ai during the render, gpu
temperature n \ avg \ max [ X-11 `gpu_metric temp` STRM, started through
`v7-zenki.notify_online :start: X-11` ], available memory start \ min \ end,
page cache, swap used + swap in \ out pages, psi 'full' stall seconds
[ memory, io ], wsl uptime, windows host memory % start \ end
[ `powershell.mem-used`, only with wsl interop -- null on native linux ],
the models directory's disk [ `invoke-web.stats.models_disk` ] with MB
read, busy seconds, MB/s while busy, ms per read, plus a json of every
whole disk's deltas [ /proc/diskstats ].

## why

renders degrade 2-6x over days of uptime [ see
`data/ai-mem/claude/project-2026-10-02-invoke-render-degradation-baseline.md`
]. strongest suspect : the model RAM cache [ 5.79 GB ] is smaller than a
heavy graph's models [ 9.67 GB ] -> every render reloads ~12-13 GB from
storage ; fast while the page cache holds the files, slow once evicted.
the graph should make that visible : s/pass over time against read GB,
available memory, swap, stall seconds, temperature, uptime.

## options [ undecided -- the user wants to see data first ]

1. live : a page exposing the current render's values as `window.*`,
   watched through `web-browser.graph-params` [ existing dark canvas
   overlay, templates in `web-browser.graph_template.*` ].
2. history : a second `graph_template` drawing stored rows instead of live
   samples, fed by an httpd json endpoint or a file invoke-web writes.
3. both : 2 for trends, 1 while watching a render.

disk : a stacked bar per render [ denoise split into disk busy vs rest ]
and MB/s + ms per read over time [ a degrading disk drops here at the same
GB read ]. s/pass against GB read : points on one line = reload cost.

normalize when drawing, not when storing : s/pass = secs_denoise \ ( steps
x passes ) ; compare only rows with the same fingerprint for absolute
numbers, s/pass is comparable across step counts only.

## notes

- the X-11 subscription keeps X-11 from its idle shutdown while invoke-web
  lives [ invoke-web idles out 300s after invoke.ai stopped ].
- the move to a native linux desktop is planned : nothing here may require
  windows ; the powershell fields stay optional.

#,,,,,..,,.,.,,..,..,,,..,...,...,,.,,,..,..,,..,,...,...,..,,,.,,,,,,..,,..,,
#2A3PMBZXIB75O6ZW7M7GSXRNM7FCRALW7HX45AZY3R24GM5UOPFNT4R3D56D363FHBFXJVQLVG3KG
#\\\|VO37HRTCHVERDLZ5J5EBRC6YTM55HSKCTJYO7BNLF22JCWCAHTK \ / AMOS7 \ YOURUM ::
#\[7]LAYNEBSKI24SAAIYTBQR4T7EBPMXGS3BUJM5LKDMX7LPQXM32QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
