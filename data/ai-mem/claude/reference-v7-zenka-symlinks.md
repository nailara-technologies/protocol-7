---
name: v7-zenka-symlinks
description: "v7.<zenka> symlinks (e.g. v7.work, v7.sourcecode) give console-only zenki a standalone-binary invocation, auto-installed by v7.install_zenka_symlinks"
metadata:
  type: reference
---

`v7.<zenka-name>` commands (e.g. `v7.work`, `v7.sourcecode`) seen in this session's shell prompt are **not a network/cube route** — they're symlinks to `bin/Protocol-7` itself:

```
$ which v7.work
/usr/local/bin/v7.work
$ ls -l /usr/local/bin/v7.work
lrwxrwxrwx ... v7.work -> /data/projects/protocol-7/bin/Protocol-7
```

`bin/Protocol-7`'s own arg-parsing detects the `v7.` prefix in `$PROGRAM_NAME` and strips it to derive the zenka name (`elsif ( $PROGRAM_NAME =~ m|^.*v7\.|i ) { ... s|^.*v7\.||ig }`), so `v7.work commands` is equivalent to `./bin/Protocol-7 work commands` — still a local direct execution, same process, not routed through `cube`.

**Installed by:** `modules/v7.install_zenka_symlinks`, called from `v7.init_code` (`cfg/zenki/v7/start` sets `v7.cfg.install_zenka_symlinks = yes`) — runs as part of the `v7` zenka's own startup every time v7 starts, checking and refreshing the symlinks so they're kept globally available system-wide, not a one-time manual setup step. Auto-creates one symlink per zenka that has its own `.console.*` commands (matched from `modules/<zenka>.*.cmd.*` naming), plus a manual extra-alias list (`nshell`, since it *is* the console rather than being administered via one) for zenki with no `.console.*` module of their own. Target dir defaults to `/usr/local/bin`, config key `v7.cfg.zenka_symlink_dir`; toggle via `v7.cfg.install_zenka_symlinks`. Unrelated to `sourcecode.console.regen-checksum-symlinks`/`undo-checksum-symlinks` (those are checksum-addressed file symlinks, a different mechanism — don't conflate the two just because both are "symlinks").

**How to apply:** if a `v7.<zenka>` symlink is referenced or behaves oddly, remember it's just `bin/Protocol-7` under a different argv[0] — same startup/module-load path as any other invocation, same [[reference-add-new-ondemand-zenka]]-style caveats apply, nothing zenka-symlink-specific to debug beyond confirming the symlink target and that the zenka's own `.console.*` commands exist.

#,,,.,,,,,,.,,..,,,,.,...,,,,,,..,.,.,,,,,,.,,..,,...,...,.,.,,,,,..,,.,.,.,,,
#HJSMG2JY74XTAZP37IR3MRFV3DYAMVBMFI4TJB2D7ZEKB7P4ITCVEZZBAL54XHY5EC4W23FQAI2P4
#\\\|MWLZP24KIWIAOLPM7C42PV5KDE3OCFRTTB3SA752N5VIXWHP6YP \ / AMOS7 \ YOURUM ::
#\[7]HMLRQQMXDTXH4B76IOS5BY7HCPRKS27AQ7M6WTPTXLSLY6PWAIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
