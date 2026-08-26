---
name: bug-calc-undef-subs-mixed-findings
description: calc.show-buffer undef-subs flagged 3 "missing" subroutines -- 2 are false positives (module exists, just not in calc's own modules.load), 1 (locales.load_file) looks like a genuine dormant naming bug worth a closer look, possibly related to how the undef-subs scanner itself reports cross-zenka reachability
metadata:
  node_type: memory
  type: project
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-31
---

Surfaced 2026-07-31 while testing after the `build.cmd.recipe.run`
rename — `calc.show-buffer undef-subs` reported 3 "non-existing
subroutines":

```
'devmod.dump'              -- base.init_code [line 88]
'locales.load_file'         -- base.locales.init_code [line 52, 47]
'crypt.C25519.gen_keys'      -- protocol.protocol-7.link-upgrade.handshake [line 29]
```

**2 of 3 are `calc`-specific false positives, not real bugs**: `calc`'s
own `modules.load` is `auth.client net protocol io.unix ui calc` — no
`devmod`, no `crypt.C25519`. Both modules genuinely exist on disk
(`src/devmod.dump`, `src/crypt.C25519.gen_keys`) and are used
correctly by real callers elsewhere (`devmod.cmd.unload-devmod` for the
former; `crypt.C25519.post_init`/`generate_session_keypair`/
`load_keypair` for the latter — the flagged caller,
`protocol.protocol-7.link-upgrade.handshake`, is only wired into
`test-link-upgrade`'s `start`, which DOES load `crypt.C25519`). The
scanner is (likely) checking reachability from the scanning zenka's own
loaded-module set, so anything outside `calc`'s own `modules.load` reads
as "undefined" even though it's real, live code elsewhere.

**1 of 3 doesn't fit that explanation, worth a closer look later**:
`locales.load_file` is called bare (`<[locales.load_file]>->($path)`,
`base.locales.init_code` lines 47/52) but the only file that actually
defines it is `src/base.locales.load_file` (with the `base.`
prefix) — no plain `locales.load_file` file exists anywhere, and no
alias/promotion mechanism was found for it (unlike the `<locales.string>`/
`<locales.text_dir>`/`<locales.fallback_language>` *data*-tree keys in
the same file, which consistently and deliberately drop the `base.`
prefix — that's a real, working convention for `%data`, just not
necessarily one that extends to `%code` sub-lookups). Possibly dormant:
the call only fires when a zenka's own `data/locales/<zenka_name>/`
directory exists (checked via `-d <locales.text_dir>`) — as of this
scan, only `browser`/`image2html`/`pdf2html`/`playlist`/`weather` have
locale directories, so it may simply never have been exercised by any
zenka that also has locale data. **Not yet root-caused or fixed** — user
suspects it may be related to how the undef-subs scanner itself reports
(reachability/aliasing edge case) rather than a genuine broken call;
deferred for later investigation, don't assume either explanation yet.

## related

Same general class of scanner-caveat this project already knows about:
`feedback-*` notes on undef-subs scanner verification (guards/eval-wrapping/
dynamic-sprintf-dispatch needing manual confirmation before acting on a
flagged name) — add "not-loaded-in-scanning-zenka" as another confirmed
false-positive shape alongside those.

#,,..,,,,,,.,,,,,,..,,,.,,,.,,.,,,.,,,.,.,..,,.,.,...,...,...,...,,..,,.,,,,.,
#7HBCHTHI52NVHBP72SZEMJQNELBHONU2BCP3PCIWJR2XGL47Y2B4IQ4EZJJC3UTIM3PI74O2B25LW
#\\\|42ZPJS4EHPAZJFPUQIFDBSYZKYQHXCKPB5V2Q5S7EEU34RYE466 \ / AMOS7 \ YOURUM ::
#\[7]EW775H2DX5GJROYKFNMIAAU4BUXD33HJNVFISTOONIGB6PF5VKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
