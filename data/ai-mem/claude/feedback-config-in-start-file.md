---
name: config belongs in zenka start file not modules
description: coding.cfg.* config keys live in cfg/zenki/coding/start, not in a src/ file
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
Never create a `src/coding.cfg` or similar file for configuration. The module loader treats every file in `src/` as a Perl subroutine — a config-style file will fail to compile or be silently wrong.

**Why:** local LLM created `src/coding.cfg` with key=value lines, which the loader tried to compile as Perl.

**How to apply:** all `coding.cfg.*` keys go in `cfg/zenki/coding/start`. Commented-out defaults (not empty assignments) are safe to add there. Never set a key to empty string in the start file — it actively sets the variable, overriding any `// 'default'` fallback in the handler.

#,,..,,,,,,,.,,,,,,.,,...,.,.,.,.,.,,,.,,,,,,,..,,...,...,,..,.,,,,,.,,.,,..,,
#ZGJXU5VVCGM5FKAENYSUIM3QXSLRBV4KPDRWFZCQ2CUK564F2V5W6AHYU26BDOPTON6O7XHQZWPDE
#\\\|ERFKC3YIL7XXR3S3SZTB52QWI6MX2QOGZMPJOAFE4OLGS6JJKPQ \ / AMOS7 \ YOURUM ::
#\[7]EJJH67MVL37UZ2ESJOV6QDCCQJDYOGU7IHJABZWSTDG6WF4PFOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
