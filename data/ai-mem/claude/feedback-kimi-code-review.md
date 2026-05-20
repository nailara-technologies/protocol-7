---
name: kimi code review patterns
description: common issues in kimi-generated P7 code that need review before deployment
type: feedback
originSessionId: d12ef49f-b2ae-4584-ae96-93ed3448509e
---
Kimi (Claude via kimi-web) generates functional P7 modules but consistently hits these issues:

1. **SUPER:: doesn't work in P7 modules** — P7 modules compile in main/P7 namespace,
   not the class namespace. Use explicit class dispatch: `$obj->IO::Socket::accept()`
   not `$obj->SUPER::accept()`.

2. **Namespace swap boundaries** — `base.event.*` swaps to `event.*` during pre_init.
   Runtime handlers must use post-swap names (`event.add_io`, `event.add_timer`).
   Same applies to `base.file.*` → `file.*`. See CLAUDE.md swap-boundary section.

3. **IO::Socket::SSL internals** — don't reach into `${*$fd}{'_SSL_ctx'}` with
   guessed hash keys. `SSL_reuse_ctx` accepts an IO::Socket::SSL instance directly.

4. **Missing log levels** — `base.logs` requires numeric log level as first arg.
   Kimi sometimes omits it.

5. **Uppercase comments** — kimi defaults to capitalized comments; P7 style is lowercase.

6. **Fake signatures** — kimi generates placeholder signature blocks that look real but
   aren't. Always remove them and leave files clean for `update-signatures`.

7. **Whitelist entries** — new modules need to be added to relevant zenka whitelists.

8. **base.swap_subs renamed modules** — `base.chk-sum.amos` is moved to `chk-sum.amos`
   by `base.swap_subs` during init. After init, `$code{'base.chk-sum.amos'}` is undefined.
   Use `<[chk-sum.amos]>` not `<[base.chk-sum.amos]>`. Same applies to `base.file.*` → `file.*`,
   `base.event.*` → `event.*`, and any other swapped namespace. Check existing callers
   in the codebase for the correct post-swap name.

9. **Angle brackets in strings** — P7's preprocessor transforms `<...>` into `$data{...}`
   references. Avoid `<` and `>` in string literals (e.g. `'usage: base <0.0-1.0>'`
   breaks compilation). Use `[0.0-1.0]` or prose instead.

10. **`#` in qw() lists** — `qw| #000000 |` triggers Perl's "comments in qw() list"
    warning because `#` starts a comment. Use regular string quoting for hex colors.

11. **Fabricated methodology stats in analysis tasks** — when kimi reports grep/git
    counts ("51 matches", "58 matches") or patterns ("dual commits in this era"),
    treat these as unverified. The actual file-level findings (reading specific modules)
    are reliable; aggregate counts and historical patterns are often confabulated.
    Verify any statistical claim with a direct command before relying on it.
    Note: "dual commits" is structurally impossible in git (each commit is a unique
    SHA over content+parent+timestamp). Any kimi claim about duplicate commit patterns
    is fabricated. The only duplicate you can get is an empty merge message line.

**Why:** kimi doesn't have deep P7 runtime knowledge (namespace swaps, compilation context,
preprocessor transforms).
**How to apply:** always review + live-test kimi-generated P7 code before considering it done.
Expect 2-3 iterative fix rounds for non-trivial modules.

#,,,,,..,,,,.,,.,,,..,,.,,,..,,.,,,..,..,,.,.,..,,...,...,.,,,,,.,,..,,,.,.,.,
#XQC7RD6EGVPE6OJ2XJR3HZERILDYV4ZMCSV6XGCVOOHQV4XM6EKWXE6ZWT7EOWE7CZ3XC4XW7XWOI
#\\\|4VCRLA5WCBIFXWHM24UUOTQVNILK2RD5BQLXAEXJDSVM4QX6SV4 \ / AMOS7 \ YOURUM ::
#\[7]IAHQT6KSHS2ZYT26EM6GYPVGUMESQA7AOPZU3D4OVU4AAHPVV6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
