## [:< ##

# name  = task: ticker — re-enable config reload command
# descr = remove disabling return and test ticker.cmd.reread_config

## context

`src/ticker.cmd.reread_config` begins with an unconditional return that
disables the command entirely:

```perl
return { 'mode' => qw| false |, 'data' => 'currently disabled! (buggy)' };
```

the rest of the module contains a full implementation: json config import, font
reloading, file re-read, and `base.init_modules`. it is unclear which bug caused
the disable, and no dedicated fix commit exists in the git log.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures` —
the human will run it manually. do not add or modify subroutine whitelists.

---

## fix 1: remove disabling return

file: `src/ticker.cmd.reread_config`

remove:
```perl
return { 'mode' => qw| false |, 'data' => 'currently disabled! (buggy)' };
```

keep the rest of the implementation.

## fix 2: test in isolated ticker instance

start a non-production ticker zenka and trigger the command:

```bash
./bin/Protocol-7 ticker cmd.reread_config
```

watch for:
- font path errors (missing `.ttf` after reload)
- cairo surface corruption
- memory leaks from repeated reloads
- json parsing errors if the config file changed format

## fix 3: address any surfaced bugs

if a bug appears, fix it before declaring the command stable. common candidates:
- `ticker.font.face` not being re-created correctly after reload
- `ticker.current_file` becoming undefined
- `ticker.content` or `ticker.draw` cache not cleared properly

## success criteria

- [ ] disabling return removed
- [ ] `cmd.reread_config` executes without fatal errors
- [ ] font reload succeeds (text renders with correct face)
- [ ] repeated reloads do not leak memory or crash
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,.,,..,,,,.,...,,.,,,..,...,,.,,,,,,,..,,..,..,,...,..,,..,,...,...,,,,,,..,
#QJNMQPTMHB5I2VJPJSCJKSL63WLAJKSCVRAQXFQDBFK7UVLNYH3FAHP562B2OWVJW7UHX4RGHMFC2
#\\\|AX3EJXVHMPOUPQGFGI54DZOF6CVTOYZ3LOO5RDWH626OXSNE6JB \ / AMOS7 \ YOURUM ::
#\[7]B4EC665W7KBROUL3TE2SSUNLCOC2PD4464BIYCZBIMCLPTX7YMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
