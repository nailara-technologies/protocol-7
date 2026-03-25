---
name: kimi code review patterns
description: common issues in kimi-generated P7 code that need review before deployment
type: feedback
---

Kimi (Claude via kimi-web) generates functional P7 modules but consistently hits these issues:

1. **SUPER:: doesn't work in P7 modules** — P7 modules compile in main/P7 namespace,
   not the class namespace. Use explicit class dispatch: `$obj->IO::Socket::accept()`
   not `$obj->SUPER::accept()`.

2. **Namespace swap boundaries** — `base.event.*` swaps to `event.*` during pre_init.
   Runtime handlers must use post-swap names (`event.add_io`, `event.add_timer`).
   Same applies to `base.file.*` → `file.*`. See CLAUDE.md swap-boundary section.

3. **IO::Socket::SSL internals** — don't reach into `${*$fd}{'_SSL_ctx'}` with
   guessed hash keys. `SSL_reuse_ctx` accepts an IO::Socket::SSL instance directly.

4. **Missing log levels** — `base.logs` requires numeric log level as first arg.
   Kimi sometimes omits it.

5. **Uppercase comments** — kimi defaults to capitalized comments; P7 style is lowercase.

6. **Fake signatures** — kimi generates placeholder signature blocks that look real but
   aren't. Always remove them and leave files clean for `update-signatures`.

7. **Whitelist entries** — new modules need to be added to relevant zenka whitelists.

**Why:** kimi doesn't have deep P7 runtime knowledge (namespace swaps, compilation context).
**How to apply:** always review + live-test kimi-generated P7 code before considering it done.
Expect 2-3 iterative fix rounds for non-trivial modules.

#,,.,,,..,,,,,,.,,,,,,,..,,,.,,.,,..,,,..,,,,,..,,...,...,..,,.,,,,.,,,..,.,,,
#K7MPILRRMU2VFWP4Y6GWQXEC5X3O42MZJU3IMSAKICGR65S6WFZUDS2PLZ2UNOZLHD2RTEZS5TQ2C
#\\\|HZLA3V4JUSYSYPO53RMHWZRX7YMPQQEONNRTFSUXSFQWU6IVT4A \ / AMOS7 \ YOURUM ::
#\[7]TRMYKLL43LBX5AXLL4ZBGITUZJTCGUZXXH5NFTR6LOINBXAQOGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
