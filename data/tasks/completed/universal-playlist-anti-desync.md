## [:< ##

# name  = task: universal — remove playlist anti-desync self-restart workaround
# descr = synchronize playlist changes without universal zenka restart

## context

`src/universal.handler.get_list_reply` contains a temporary workaround from
2016:

```perl
if (...) {    # temporary [anti-desync] workaround
    <[universal.self_restart]>;
}
```

when the playlist changes during rescale operations, the universal zenka
self-restarts to avoid desynchronization. this is unnecessary overhead and
causes visible interruptions.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: understand the desync mechanism

read `src/mpv.handler.rescale_video_reply` (line 27 references the
quick-fix). understand:
- when does rescale finish relative to playlist updates?
- what state becomes inconsistent if the playlist changes mid-rescale?
- is the issue in `universal` or `mpv`?

## fix 2: add synchronization instead of restart

options:
- queue playlist changes while rescale is active, apply after rescale completes
- emit a `rescale-done` event that `universal` waits for before processing playlist changes
- use a state flag (`<universal.rescale_in_progress>`) to defer playlist processing

## fix 3: test with rapid playlist changes

trigger multiple playlist updates while rescaling is active:
```bash
./bin/Protocol-7 universal cmd.update_playlist /path/to/new/files
```

verify that:
- no restart occurs
- rescale completes successfully
- playlist ends in the correct final state

## success criteria

- [ ] self-restart workaround removed from `universal.handler.get_list_reply`
- [ ] playlist changes synchronize correctly with rescale completion
- [ ] rapid playlist updates do not corrupt state
- [ ] no visible interruption from zenka restart
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,..,,,,,.,.,,,.,,,,,..,,...,...,,..,...,.,,,..,,...,...,.,,,..,,...,..,,.,.,
#6IMP6IFXOA3X6W3TNX22XW7YXTCKBFY4MUJFJER7TMZBGQ263A47FQQJMOW3CPDVKEWX4C5MNX5QA
#\\\|74DFRHC77QV6E7VGWQLWKXAFUY6CFT4V7SKN3N6NUFG62ZBALVC \ / AMOS7 \ YOURUM ::
#\[7]JRUAL3FTGKFRQGRTM5CWFKTUUTWV7XGNAKHML64UERN2KOWRP2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
