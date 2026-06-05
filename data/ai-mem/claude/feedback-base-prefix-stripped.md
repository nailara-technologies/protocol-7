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

#,,,,,...,.,,,,,.,,,.,,..,,..,.,.,...,..,,..,,..,,...,...,..,,.,.,.,,,.,,,,,.,
#U3RGXXCU2CQL37WK4GKFVVFWDTGD6OXWP5VC232BPHXRFMZIKUTJENG5QKCM5XNU26BAG533KWR62
#\\\|6SOYRV6WBUM4ZCCGTO5LSR672EYIYBJZGO2K3JPGYBJNFGNURC4 \ / AMOS7 \ YOURUM ::
#\[7]S3FZCMTI5XIGAS7I7TEUX5VGE5FKYDMSOOXWODPDJZX2UNKGK4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
