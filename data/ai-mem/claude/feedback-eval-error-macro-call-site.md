---
name: feedback-eval-error-macro-call-site
description: "reading $EVAL_ERROR inline as an arg at a <[...]> macro call site can come back empty -- use <[base.str.eval_error]> or capture into a lexical immediately after eval instead"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 595555b6-24d1-4413-a879-05d05128d8ab
  modified: 2026-07-22T22:55:28.813Z
---

Pattern `<[base.logs]>->( 0, 'X failed : %s', $EVAL_ERROR )` placed right
after an `eval { ... }` block that actually died can log an EMPTY string
for `%s`, even though `$ok`/`not $ok` correctly detected the failure.
Confirmed live in `p7-log.anon.transform` (log-anonymization phase 1,
`dbd7ca8ba`): the log line rendered as `p7-log.anon.transform failed : `
with nothing after the colon, even for a real die (`Can't use an
undefined value as a subroutine reference at ... line 19.`).

**Why:** `$EVAL_ERROR` (aliased `$@`) is fragile — evaluating the
`<[base.logs]>` macro call itself (or any nested sub call among the
args) can clear it as a side effect before the arg list is actually
built, since any successful `eval` anywhere in that path resets `$@` to
`''`. Confirmed by adding a debug capture: `my $err_capture =
$EVAL_ERROR;` read immediately after the failing `eval` block (before
calling `<[base.logs]>`) DID contain the real message; reading
`$EVAL_ERROR` inline as an argument at the `<[base.logs]>->()` call site
did not.

**How to apply:** never read `$EVAL_ERROR`/`$@` as an inline argument at
a macro/sub call site placed after the `eval` block. Either (a) capture
it into a lexical immediately after `eval` and pass the lexical, or
(b) prefer the project's existing `<[base.str.eval_error]>` helper
(`modules/base.str.eval_error`, wraps `base.format_error`) called
immediately — it reads `$EVAL_ERROR` inside its own sub body before any
other macro expansion gets a chance to clear it. Confirmed the fix live:
after switching to `<[base.str.eval_error]>`, later real errors on the
same failure path (`transform failed : ...`) rendered with a real
message. See [[feedback-swap-subs-not-fragile]] for the same session's
other subtle-but-real bugs (swapped-name mismatches) caught only by
pushing new code through a live round-trip, not by syntax-check alone.

#,,..,,..,,.,,,,,,,,,,,,.,..,,...,.,.,...,,,,,..,,...,...,.,,,,,.,,,.,,,,,...,
#BAQ6IFWWW4CDWCFYRI2W52GRK5LBHOFPJKJFYWHA6O7BDY7C7ZKKIDPTJ4MTQIKMHWJGXC4HUVJLY
#\\\|6YAPT6DBPPZUBUY5WNVZ7JD7Z4EQFBLSQ3WC46Z352GMBMIVH5T \ / AMOS7 \ YOURUM ::
#\[7]7MZIHXQKDO6BSMBTC22JHKFSVV5AHTCFNFDB3HLMQB5GIAXDSIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
