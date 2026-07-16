## task: wire jobsite.store.prune into the scan cycle

### context

`modules/jobsite.store.prune` exists (created session 67 by kimi) but is
not called from anywhere. it implements two-phase cleanup:
1. `blocked/<epoch>/` → `deleted/<epoch>/` when epoch distance > 0
2. `deleted/<epoch>/` → gone when epoch distance > 1

it also verifies/backfills title+url checksums into the checksum store
before moving blocked stubs to deleted.

### where to call it

call from `jobsite.handler.rescan-timer` BEFORE triggering the fetch/assess
cycle. this ensures cleanup happens once per scan cycle, not on every restart.

```perl
## in jobsite.handler.rescan-timer, before <[jobsite.stage.fetch]> ##
<[jobsite.store.prune]>;
```

also call from `jobsite.cmd.scan` (manual trigger) for the same reason:

```perl
## in jobsite.cmd.scan, near the top ##
<[jobsite.store.prune]>;
```

### verify jobsite.store.prune implementation

before wiring, read the current module and verify:

1. it uses `<[base.ntime.epoch_timestamp]>->($ep_dir)` to decode epoch dir
   names to integers — confirm this returns a number, not the encoded string
   (the module decodes V7XXXXX → integer epoch number).

2. it calls `<[jobsite.checksum.index]>->( 'add', $stub_job )` for each
   blocked stub before moving to deleted — where `$stub_job` is a minimal
   hash with at least `title` and `url` fields. verify blocked stubs contain
   these fields (they should from `dispatch.assessments`).

3. epoch distance calculation uses `int( <[base.ntime.epoch_dec]> )` for
   current epoch — verify this matches the encoding in the dir names.

4. the `rename` from `blocked/<ep>/<id>.yaml` to `deleted/<ep>/<id>.yaml`
   creates the `deleted/<ep>/` dir if needed — use `file.zenka_dir.write`
   or verify the rename target dir exists first.

### add prune to access whitelist

`jobsite.store.prune` should already be in the jobsite subroutine whitelist
from the kimi dispatch. verify with:

```bash
grep "store.prune" configuration/zenki/jobsite/subroutine.white-list
```

if missing, run `./bin/dev/gen-sub-whitelist jobsite` to regenerate.

### signatures note

do NOT manually write or edit signature lines. do not add stubs to new files.

## dispatch

#,,..,..,,,,.,,,,,,..,..,,...,,,,,,,,,.,.,,..,..,,...,.,,,,,,,,..,...,..,,...,
#VX5DUOK2DAF5M7YMUUYFMOW3EBX6KZPVHFFW3JWORS7UWVPNQQRITATV56QDMJQVOYV2BFOWGDZVU
#\\\|YOOKLPNZHPTB4ZEWOALEHROF7KAB7IVG2RYOUTSZWRTIGPY4TCA \ / AMOS7 \ YOURUM ::
#\[7]6LXRNRD5NGNTSRIYGBE6EENUT6YBI3FWXNRJJ475BMIEZFQJGGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
