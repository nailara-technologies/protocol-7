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

**exact mechanism, traced 2026-07-11**: the rename happens via `<module>.pre_init` (or `.init_code`) files calling `<[base.swap_subs]>->( 'base.<family>', '<family>' )`. `base.swap_subs` does `$code{$new_sub} = delete $code{$sub_name}` — a real move, not an alias — so after that pre_init step runs, the `base.<family>.*` keys are gone from `%code` entirely, only `<family>.*` remains. Confirmed families with this swap today: `base.event`→`event`, `base.file`→`file`, `base.base32`→`base32`, `base.templates`→`templates`, `base.chk-sum.*`→`chk-sum.*`, `base.zenka.push`→`zenka.push`, `base.dependency`→`dependency`, `base.locales`→`locales`, `base.protocol-7`→`protocol-7`, `v7.zenka`→`zenka`, `fetch.file.huggingface`→`huggingface`, `event.anyevent`→`event`. Grep `<[base.swap_subs]>` across `modules/*.pre_init` / `*.init_code` for the current full list — it can grow.

**recurrence 2026-07-11, self-inflicted**: assistant reviewed kimi-written code using `<[event.add_timer]>`/`<[event.add_io]>` (correct, bare form), concluded from `ls modules/` alone (no literal file named `event.add_timer`) that it must be a bug, and instructed kimi to rename to `<[base.event.add_timer]>`/`<[base.event.add_io]>` — the actually-broken direction. Kimi complied; zenka crashed on next restart with "undefined value as subroutine reference" at the exact call sites. User found and fixed via a global `ncode replace` sweep, which also caught one pre-existing unrelated instance of the same wrong-direction bug in `modules/data.mount.shm.feedback.watch`. **Lesson: `ls modules/` only shows the file a sub is defined in, not what name it's registered under in `%code` after `pre_init` runs — never conclude a bare/short-namespace call is broken from file-listing alone.** Check this memory (or `p7c <zenka>.list-subs <pattern>`) before "fixing" any `<[...]>` call that looks unprefixed but works elsewhere in the codebase.

#,,,,,,,.,..,,,.,,,,,,,..,,,,,..,,.,.,...,..,,..,,...,...,,,.,.,.,.,.,...,,..,
#HUQITHK3SVZCCY7KSRB3SRI6YGIVPOYVJH3TDD2DAMKOCRU23GTDIBPDTRSQIDJOJGXXUSPDP623S
#\\\|7Q25EZZ23QDU6ICK53MSIXGSM7PPOJGK36WI6K7VO4P6ZSUNJXA \ / AMOS7 \ YOURUM ::
#\[7]NQCZMK2EJNKY5COE45D3GIVWIR5WMPSZNK6IBEOY5YMHXBMSXIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
