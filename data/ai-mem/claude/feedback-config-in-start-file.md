---
name: config belongs in zenka start file not modules
description: coding.cfg.* config keys live in cfg/zenki/coding/start, not in a modules/ file
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
Never create a `modules/coding.cfg` or similar file for configuration. The module loader treats every file in `modules/` as a Perl subroutine — a config-style file will fail to compile or be silently wrong.

**Why:** local LLM created `modules/coding.cfg` with key=value lines, which the loader tried to compile as Perl.

**How to apply:** all `coding.cfg.*` keys go in `cfg/zenki/coding/start`. Commented-out defaults (not empty assignments) are safe to add there. Never set a key to empty string in the start file — it actively sets the variable, overriding any `// 'default'` fallback in the handler.

#,,..,.,,,.,.,,,.,...,.,.,,.,,..,,,,.,,,,,..,,..,,...,.,.,...,..,,,.,,,,.,,.,,
#TPHLUKNDD5RRMJN5F6L3BFSMH3AIMN2G5X4JX5OQ7B4HKW42VH5D6CZVXB3J4QQFH5SZ4MB6MC6VO
#\\\|DWPRR2IXXRBBASKYHWJDCYVXM7GFDYNDWBMRIQWXKTWGRK5H7L3 \ / AMOS7 \ YOURUM ::
#\[7]7HSCAW6AVF74PKQ7FDYHTOXFYCEYXSLIJEI3EZLLJDWBLOLOYEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
