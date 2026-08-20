---
name: topic-zenka-push
description: base.zenka.push — well-behaved offline-aware push helper; reference pattern for fire-and-forget to potentially offline zenki
metadata:
  node_type: memory
  type: project
  originSessionId: 666d4dc1-21c4-4bf4-b502-caa56dad8014
---

## base.zenka.push (session 45/46)

harmonically TRUE namespace. 4 modules live, committed.

### reference pattern for offline-aware push

```perl
<[zenka.push]>->(
    {   qw| command |  => qw| discover.orbital-p7ref-update |,
        qw| args |     => { qw| args | => $p7ref },
        qw| queue_max | => 1,   ## only latest matters
    }
);
```

behavior:
- target online → send immediately, zero overhead
- offline reply ("client not present") → `v7.notify_online target`, queue, stop
- notify_online reply → dequeue and resend
- v7 unavailable → exponential backoff (1→2→4→...→60s cap)
- queue_max=1 → only latest payload kept (correct for position updates)

### key lessons learned

**swap_subs moves, not copies**: after `base.swap_subs( qw| base.zenka.push zenka.push | )`,
`base.zenka.push` no longer exists in `%code` — only `zenka.push`. All internal
callbacks must use `<[zenka.push]>`, not `<[base.zenka.push]>`. But DATA namespace
`<base.zenka.push.state>` is unaffected — data is not swapped, keep canonical name.

**target prefix extraction**: `( my $prefix = $command ) =~ s|\..*$||` — NO space
before `.*`. The buggy form `s|\. .*$||` (dot-SPACE-star) fails to strip for
commands like `discover.orbital-p7ref-update`.

**offline detection**: check `$reply_str =~ m|^client\b|i` — "client not present"
is the offline signal. "command does not exist", permission errors etc. should
log and return, NOT trigger notify_online.

**runtime-resolved callbacks**: `sub { <[zenka.push]>->($target) }` in timer
closures resolves `zenka.push` at call time, not closure creation. Module reloads
automatically picked up without re-registering timers. =)

**reply handlers and swap**: when swap moves `base.zenka.push.reply-handler.*`
to `zenka.push.reply-handler.*`, the `qw| handler |` strings in the push module
must use the swapped names (`zenka.push.reply-handler.offline` etc.).

**deferred compile**: reply handlers referenced as strings aren't deferred-compiled
on first use. Ensure modules load at startup or whitelist regeneration includes them.

### ncode restore-backup fix (session 45/46)

`ncode restore-backup` only restored cfg/ — missing src/ restore.
Fixed: both branches now conditional on directory existence:
```perl
system("cp -r $temp_dir/cfg/* ...") if -d "$temp_dir/configuration";
system("cp -r $temp_dir/src/* ...")       if -d "$temp_dir/src";
```
Also: validation check changed from `!-d configuration` to
`!-d configuration AND !-d modules` to accept modules-only backups.

### nodes.orbital double timer (session 45/46)

`init_modules` iterates ALL `%code` entries, so `nodes.orbital.init_code` was
called by `init_modules` (nodes.* loaded) AND explicitly in the start file.
Guard added: `return if defined <nodes.orbital.session_start>`.

### related

- task file: `data/tasks/base-zenka-push-helper.md`
- nodes.orbital.update_position — immediate fix applied (first consumer)
- [[topic-base32-namespace]] — same session, swap_subs lessons apply here too

#,,..,...,,,.,...,..,,,,,,,..,..,,...,,,.,.,.,..,,...,...,,..,,,,,,,.,.,.,,..,
#2XE3OHLBE5E7OQALY4PFRO44U54ICJ7FL675RBYN2UJRGBVNZDN6X3DODPIOZD7RL37ENRXN5RVHO
#\\\|FMTMOQJBI5V7I4NBFMQHJGN62ZFUTQVSCMPFQRL7VN6SEXGAHBE \ / AMOS7 \ YOURUM ::
#\[7]7FQ2QITF7ZUF47NN6QZLEK3GZU3MXPZZFG63UZNOSWRFQOGLTKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
