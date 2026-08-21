---
name: config belongs in zenka start file not modules
description: coding.cfg.* config keys live in cfg/zenki/coding/zenka.v7, not in a src/ file
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
Never create a `src/coding.cfg` or similar file for configuration. The module loader treats every file in `src/` as a Perl subroutine — a config-style file will fail to compile or be silently wrong.

**Why:** local LLM created `src/coding.cfg` with key=value lines, which the loader tried to compile as Perl.

**How to apply:** all `coding.cfg.*` keys go in `cfg/zenki/coding/zenka.v7`. Commented-out defaults (not empty assignments) are safe to add there. Never set a key to empty string in the start file — it actively sets the variable, overriding any `// 'default'` fallback in the handler.

#,,,,,..,,,.,,...,,.,,,..,,..,..,,,..,.,,,.,.,..,,...,.,.,...,,.,,,.,,,..,,,.,
#6SP4QJABJ57TAOQTIAZ5EROSLNCUQMTRPTNPZUENZY23OIIHKA22YFULKXZPAUL6XQILNN7ZB2OCK
#\\\|55FMVXX7EAWN2JGRXJLSUDFQFD57R5VRPJCQPMQIM7H7F7LM7YQ \ / AMOS7 \ YOURUM ::
#\[7]KDCJHR5PAA5EIKV6OFDUH66SK2VYV7UUCCZDZEPDMROBOHRVCEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
