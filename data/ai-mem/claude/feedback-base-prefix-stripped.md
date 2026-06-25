---
name: feedback-base-prefix-stripped
description: base. prefix is stripped from subroutine names at zenka init — use short form inside zenka code
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4701e5c1-7db4-4798-bcf6-417046499fe6
---

when writing modules for any zenka, the `base.` prefix is stripped from subroutine names during the init phase. the subroutine is registered in `%code` without the prefix.

**Why:** protocol-7 registers `base.*` modules under their short name inside each zenka's namespace at load time. calling `<[base.protocol-7.command.send.local]>` inside a zenka module will give "undefined value as subroutine reference" even if the module is in the subroutine.white-list.

**How to apply:** always use the short form — `<[protocol-7.command.send.local]>` not `<[base.protocol-7.command.send.local]>`. to check what name a subroutine is registered under inside a running zenka, use `p7c <zenka>.list-subs <pattern>` — e.g. `memory.list-subs send.local` → shows `protocol-7.command.send.local`.

**recurrence 2026-06-25**: user found+fixed 5 more latent instances of this exact bug (`base.chk-sum.amos` called with the prefix) in `base.chk-sum.reference`, `plugin.storage.checksum.map-file`, `plugin.storage.checksum.verify`, `plugin.web.auth.create_session`, `reasoning.tree.node` — landed same commit as [[topic-jobsite-stray-recovery]] (a52a6a4b8). These had been silently broken with nobody noticing. Worth a periodic grep sweep (`grep -rn '<\[base\.' modules/`) cross-checked against each name's actual whitelist/registration form.

#,,,,,..,,.,.,.,.,...,.,,,...,,,.,,,,,...,.,.,..,,...,..,,,..,,..,,.,,,,.,.,.,
#ILTWEZMZPZWVMI6LVDC27VKKQMP53C3ZMVGKYEGOGOSAYLYNWXPGPDO247FMVX6Y3SJFGPBMVETWI
#\\\|PFQO2PKIUCDAISDIBEKJ64JTLXE5KZND6VUH2NRL7AWF7GT6J6I \ / AMOS7 \ YOURUM ::
#\[7]7QCDNF3RI2PR2TWEOL2U762HP7TEU47M2Q6NGB3TRS7A3RE2Q2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
