---
name: config belongs in zenka start file not modules
description: coding.cfg.* config keys live in cfg/zenki/coding/zenka.v7, not in a src/ file
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
Never create a `src/coding.cfg` or similar file for configuration. The module loader treats every file in `src/` as a Perl subroutine — a config-style file will fail to compile or be silently wrong.

**Why:** local LLM created `src/coding.cfg` with key=value lines, which the loader tried to compile as Perl.

**How to apply:** all `coding.cfg.*` keys go in `cfg/zenki/coding/zenka.v7`. Commented-out defaults (not empty assignments) are safe to add there. Never set a key to empty string in the start file — it actively sets the variable, overriding any `// 'default'` fallback in the handler.

#,,.,,,.,,...,...,.,,,.,.,,.,,.,,,..,,,,.,..,,..,,...,...,..,,..,,,,.,,,,,,..,
#VOJUSTVWVFMUDFC3Q4DJ6SYLTA42UYWFWXSHJ6FRXCHFNR3FPTQGHDQDNOSGNP3CUE5OFHNLU6KJ4
#\\\|NK3J2WBODIIFFMDNRF2GTA6GYT4TV7ULXW55TD7NXKZPJ6KV5DF \ / AMOS7 \ YOURUM ::
#\[7]YOJ7CCFSLG53LV3JCTVBQS6OY7BVMX2H56LQMNCIV46MIEUUU2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
