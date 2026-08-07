---
name: feedback-comp-regex-qr-delimiter-escaping
description: qr'...' delimiter escaping gotcha in base.eval.comp_regex — escape only the delimiter, never backslash
metadata:
  type: feedback
---

`base.eval.comp_regex` compiles a user-supplied pattern by splicing it into a
`qr'...'`-delimited Perl source string and `Safe->reval`-ing it. Any raw pattern
containing a literal `'` broke out of the delimiter early, producing garbage source
and confusing downstream errors (a malformed `qr'' 2 ''` once even surfaced as an
unrelated `Math::BigFloat`/`accuracy` error from stray tokens hitting bignum
autoboxing in the Safe compartment — a red herring, not a separate bug).

**Why:** fixed by escaping only the delimiter (`s|'|\\'|g`) before embedding. A first
attempt also escaped backslash (`s|\\|\\\\|g`), which seemed safer but was wrong:
`qr'...'` is a regex quote-like operator, not a string literal like `q()` — it hands
`\`-escapes (`\d`, `\s`, `\\`, ...) straight to the regex engine rather than
pre-collapsing them the way `q'...'` does. Doubling backslashes broke `\d`/`\s`
shorthand for every existing caller (`base.cmd.list`, `base.file.match_files`,
`base.parser.pattern_split`) — verified empirically: `qr'\\d+'` does NOT match digits,
`qr'\d+'` does.

**How to apply:** any future code that splices a raw string into a Perl quote-like
operator (`qr'...'`, `m'...'`, `s'''...'''`, etc.) only needs to escape the delimiter
character itself. Do not add backslash-doubling by reflex — verify empirically with a
real regex-shorthand case (`\d`, `\s`) before assuming a stringy-escaping fix is
correct for a regex-context operator.

See [[reference-show-buffer-command]] for where this surfaced (`show-buffer`'s new
`[pattern]` param), fixed in commit `121abccff`.

#,,..,..,,,,,,..,,..,,,,,,.,,,,,.,,,,,,..,...,..,,...,...,...,,,.,.,.,,,.,.,.,
#FWZMP4DG4UYJB2ILDNGUDM5VIMFWW6FND64AQZYAVR6XYGEH24TPAEBH6DRBSXVZ5GVALKV57VRYO
#\\\|BYLEKZ2EOOVEHKE7ZDOAVFEWVDG7CSBVSSFMR6KOP3TNMUHS7W7 \ / AMOS7 \ YOURUM ::
#\[7]P77T4LBUSUCQA3V4WR3RR7AF27IPPNWQCJP2EC6ORHYJULMF7ODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
