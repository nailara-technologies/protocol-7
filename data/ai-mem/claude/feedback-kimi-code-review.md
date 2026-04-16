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

**Why:** kimi doesn't have deep P7 runtime knowledge (namespace swaps, compilation context,
preprocessor transforms).
**How to apply:** always review + live-test kimi-generated P7 code before considering it done.
Expect 2-3 iterative fix rounds for non-trivial modules.

#,,..,..,,,.,,,,,,...,,,.,,.,,,,,,,,,,,,.,,,.,..,,...,...,..,,,..,.,.,,,,,...,
#Z6JK5JVBFDK2AYFX2UQ5VO5VOEWOXFWURZ6HAGUTACWHL6X3I4LDXOL6Z5SJPVLCCYUVN6SKJGBJ2
#\\\|2GAKX7RANESDKXZHKCDDOIUDDYYVOXR3DKN3YSC6I7LBQRUEDH7 \ / AMOS7 \ YOURUM ::
#\[7]MZ2VCQMMTQWTEJY5JQSXUULNVEC52JYI6EQ5RSR3RYGHLGIYJGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
