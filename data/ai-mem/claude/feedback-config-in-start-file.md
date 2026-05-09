---
name: config belongs in zenka start file not modules
description: coding.cfg.* config keys live in configuration/zenki/coding/start, not in a modules/ file
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
Never create a `modules/coding.cfg` or similar file for configuration. The module loader treats every file in `modules/` as a Perl subroutine — a config-style file will fail to compile or be silently wrong.

**Why:** local LLM created `modules/coding.cfg` with key=value lines, which the loader tried to compile as Perl.

**How to apply:** all `coding.cfg.*` keys go in `configuration/zenki/coding/start`. Commented-out defaults (not empty assignments) are safe to add there. Never set a key to empty string in the start file — it actively sets the variable, overriding any `// 'default'` fallback in the handler.

#,,.,,,,,,...,,,,,.,,,...,..,,...,.,.,,.,,,,,,..,,...,...,.,.,.,,,,..,...,,.,,
#CYDJ72VYR3EKLH7TJYXZE2V5OIORCPPDBGVRIWBZAEGPWL2PUPAO5NDL6TJTXHSVXIE3T3ZPFOULU
#\\\|XPVG5FGSLQRA6TIKOYDZIK47SPYDB27UUNINOGH7YFCBUE5S55L \ / AMOS7 \ YOURUM ::
#\[7]C6C4M5PBPPPLM56IQAETI7M3D52PPPSP6VIAO54LLUV3WZ7M4KCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
