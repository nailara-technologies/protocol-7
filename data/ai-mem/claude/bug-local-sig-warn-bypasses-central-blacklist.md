---
name: bug-local-sig-warn-bypasses-central-blacklist
description: base.perlmod.autoload's local $SIG{__WARN__} override silently bypassed bin/Protocol-7's entire central warning pipeline (deep-recursion emergency-exit safety net included) for the whole duration of every autoload call -- removed entirely, per the user; the correct mechanism is $data{'sig_warn_blacklist'}, currently single-slot only (a pre-existing, pre-LLM-era TODO to array-ify)
metadata:
  type: feedback
---

Found 2026-09-10 while chasing a recurring `Prototype mismatch: sub
main::decode_json: none vs ($)` warning during the LoRA/HF-fetch work
(see [[bug-fetch-files-huggingface-four-real-bugs-2026-09-10]]). Tried
extending `base.perlmod.autoload`'s existing `local $SIG{__WARN__} =
sub {...}` block (which already suppressed a known List::MoreUtils
`qsort`/`bsearch` prototype mismatch) to also cover `decode_json`. The
user rejected this and had me remove the ENTIRE block, both
occurrences, not just my addition -- then explained why via `ncode s
bin:Pro warn.+list`.

**The real mechanism**: `bin/Protocol-7` (~line 4234) installs the
actual, central `$SIG{__WARN__}` handler for the whole process. It does
substantial work per warning -- deep-recursion detection with an
emergency-exit safety net (`kill(15, $pid)` on child zenki + `exit`),
caller-chain cleanup, filename shortening, a `<{C[level]}>`-style
parent-caller redirect -- and, as part of that, checks a declarative
blacklist: `$data{'sig_warn_blacklist'}{'package'}` (exact package
match) or `{'pattern'}` (regex against the warning text) to decide
whether to suppress a warning entirely.

**Why the local override was wrong**: any `local $SIG{__WARN__} = sub
{...}` INSIDE a function (like `base.perlmod.autoload`'s) completely
SHADOWS the central handler above for the lexical/dynamic scope where
it's active -- not just for the one warning pattern it was trying to
filter. Every warning of ANY kind fired during that scope (a
`Module::Load::autoload` call) bypassed the entire pipeline: no
deep-recursion tracking, no emergency-exit safety net, no
caller-cleanup formatting. This was a real latent risk independent of
the specific qsort/bsearch or decode_json patterns it was aiming to
quiet -- a local override is the wrong tool even when the filtering
INTENT is legitimate.

**Known limitation of the correct mechanism**: `$data{'sig_warn_blacklist'}`
is a single hash (one package + one pattern slot), not an array --
confirmed by a `# <-- use array [LLL]` comment already sitting at that
exact line, predating this session (user: "the comment is from
pre-LLM times"). This means it can't currently support multiple
concurrent suppressions safely; whoever wrote `base.perlmod.autoload`'s
local override almost certainly reached for it BECAUSE the single-slot
blacklist couldn't cleanly coexist with other blacklist users, not out
of unfamiliarity with the proper mechanism.

**Current state, 2026-09-10**: `base.perlmod.autoload` has NO warning
suppression at all now (both blocks removed). The decode_json warning
that prompted this whole investigation turned out to be fully
root-caused after all, precisely BECAUSE removing the override let it
surface loudly instead of being silently eaten -- a real JSON::XS vs
JSON::PP `decode_json` symbol collision (see [[bug-fetch-files-huggingface-four-real-bugs-2026-09-10]]),
fixed by not loading JSON::PP at all. The qsort/bsearch List::MoreUtils
warning still has no suppression and will surface uncaught until either
its actual cause is found and fixed, or `data/tasks/sig-warn-blacklist-
arrayify.md` lands and it gets registered through the proper declarative
mechanism instead.

**How to apply**: never reach for a local `$SIG{__WARN__}` override
in this codebase to suppress a specific warning pattern -- always use
`<sig_warn_blacklist>` (once it supports multiple entries) or, if it
must be used single-slot today, understand that setting it will BLOCK
suppressing anything else for as long as that slot is occupied. Prefer
root-causing the actual warning source first; suppression (via the
correct mechanism, once available) is the fallback, not the default.

## related

[[bug-fetch-files-huggingface-four-real-bugs-2026-09-10]]

#,,,.,..,,,.,,...,,,.,..,,...,.,,,,..,,,.,,,.,..,,...,...,,,,,,,,,,..,,.,,.,.,
#G3VODBCECMJ4AEUKT3UR5NVWUDNATWFLWKL6FYC5PQZFW4OJ5FY6MJJXX6OVVNGJ7KGGOILH57ZJW
#\\\|ZKYESIEV4GNRLHB4EDRGUW33QQ62OJNIAP3Y6X3OSGUYIA2LOZ7 \ / AMOS7 \ YOURUM ::
#\[7]BITPKQOKHEIHGGL5LUTVDWTOP4OUXX46UB3ISAZ6VU6LRLAIU2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
