## [:< ##

# name  = task: format-code code-marker false-positive + block-truncation fix
# descr = two distinct root causes for the same visible symptom (a
#         box-comment line kept its original, unharmonized padding) --
#         both cause a block to never be touched at all, not a padding
#         math error

## background

Read `data/ai-mem/claude/topic-format-code-bugs-fixed.md`'s "open bug,
root-caused 2026-07-31" section in full first — it has the complete
investigation trail, both confirmed root causes, and a debugging-
methodology note about a real Perl gotcha (postfix `return ... if COND;`
exits before any `warn` placed textually after it) that cost real time
to work around. Don't repeat that mistake.

**Both bugs live in `bin/format-code`.** Confirmed via direct
instrumentation (add a `warn` immediately BEFORE the return/check you're
observing, or unconditionally, not after):

### Bug A — `code_marker_re` false-triggers on ordinary prose

`step4_align_comment_block`'s very first early-return (~line 529-530):

```perl
my $code_marker_re = qr{
    [;{}]\s*$
  | ^(?:if|elsif|else|unless|while|until|for|foreach|sub
    |my|our|local|return|package)\b
  | \$\w+\s*(?:->|=>|\{|\[)
  | ->\s*\w+\s*\(
}x;
my $code_line_count = grep { $ARG =~ $code_marker_re } @content_parts;
return [ @{$lines}[ $start_lnum - 1 .. $start_lnum + $block_len - 2 ] ]
    if $code_line_count >= 2;
```

The `\$\w+\s*(?:->|=>|\{|\[)` alternative allows arbitrary whitespace
(`\s*`) between the sigil-variable and the following bracket/arrow. Two
ordinary prose sentences in `modules/context.pattern.extract_from_change`
(lines ~103, ~110 as currently written) match it purely because they
reference a variable name immediately followed (after a space) by an
English bracket annotation — e.g. `"the capture groups of $pattern [ the
later..."` — not real Perl subscript/dereference code (which in this
codebase's actual style is always written tight: `$var->{key}`,
`$var[0]`, never `$var [0]`). Two such false matches cross the `>= 2`
threshold, so the entire 10-line block is classified as "commented-out
code" and passed through **completely untouched** — including whatever
padding the block's last line happened to have.

**Fix**: split the dereference alternative so the bracket/brace variants
require immediate adjacency (no whitespace), while `->`/`=>` keep the
current looser match (this codebase does sometimes write `$key => $val`
with a space). Something like:

```perl
| \$\w+\s*(?:->|=>)
| \$\w+(?:\{|\[)
```

Verify this still catches real dereference code (grep the codebase for
genuine `$var->{`/`$var->[`/`$var{`/`$var[` shapes and confirm they still
match) and no longer matches the two false-positive lines above.

### Bug B — atomic bracket-remark protection wrongly applied during block-extension scan

`comment_block_line_parts` (~line 442-444) deliberately protects a
standalone one-line bracket remark (`## [ short note ] ##`) from ever
being touched:

```perl
return undef
    if $content =~ m{^\[.*\]$}
    and length_no_nl($line) <= LINE_MAX;
```

`comment_block_length` (~line 468-489) walks forward from a block's
first line calling `comment_block_line_parts` on each subsequent line
and does `last if not $parts;` to stop extending the block. So when the
**3rd line of an otherwise-ordinary 3-line paragraph** happens to be
entirely bracket-wrapped (e.g. `modules/ncode.regex.apply:42`,
`"[ legacy single-string namespace handled inside scope_match ]"`), the
scan silently stops at line 2 (confirmed: `comment_block_length` returns
2, not 3, for that block) — the 3rd line is excluded from the block
entirely and keeps whatever padding it originally had, 2 chars short of
what lines 1-2 got harmonized to.

**Fix**: `comment_block_length`'s forward-scan needs a way to check "is
this line a same-indent `##`-prefixed continuation" without invoking the
atomic-single-line-remark suppression — that suppression is only
supposed to gate whether a *lone* standalone bracket line ever gets
reflowed at all, not whether it counts as a continuation of an
already-multi-line block that started elsewhere. Options, your call
which is cleanest given the actual code shape once you're in there:
- add a parameter to `comment_block_line_parts` (e.g. `$as_continuation`)
  that skips the atomic-bracket check when true, and have
  `comment_block_length`'s loop pass it while `step4_align_comment_block`'s
  own initial `comment_block_length($lines, $start_lnum-1, ...)`-style
  first-line check (if any) does not, or
- do a simpler raw regex check in `comment_block_length`'s loop (same
  indent, `##`-prefixed, not the module-header exclusion) instead of
  calling the full `comment_block_line_parts` for the continuation check,
  reserving the full parse (with its bracket protection) for the actual
  first line of a block and for genuinely standalone lines.

Don't just delete the atomic-bracket protection — it exists for a real
reason (a standalone one-liner remark like `## [ note ] ##` shouldn't get
folded into paragraph reflow). The fix is narrowing *when* it applies,
not removing it.

## acceptance checks

1. `ptd -c` clean on `bin/format-code`.
2. Reproduce both bugs pre-fix if you want a before/after (or trust this
   task file's already-confirmed evidence and go straight to verifying
   post-fix) — then confirm post-fix:
   - Running `bin/format-code` on a copy of
     `modules/context.pattern.extract_from_change` now actually reformats
     the block in question (no longer byte-identical to the original for
     that region), and the two previously-false-positive lines are
     confirmed NOT flagged by the tightened `code_marker_re` (test it
     directly against those two lines' content, quote the result).
   - Running `bin/format-code` on a copy of `modules/ncode.regex.apply`
     now includes line 42 in the same block as lines 40-41, and all
     three end up padded to the same width (quote the actual before/after
     line lengths).
3. Confirm no regression: grep the codebase for real `$var->{`/`$var->[`/
   `$var{`/`$var[` dereference shapes and confirm `code_marker_re` still
   flags files/blocks containing genuine commented-out code as
   untouched (the whole point of Bug A's detector, which must keep
   working for its real cases).
4. Run `bin/format-code` across a broader real sample (e.g. everything
   under `modules/` touched in the last few commits, or a reasonably
   large sample) and confirm nothing gets mangled — this touches a
   widely-used dev tool, so a broad sanity pass matters more here than
   for a narrow application-code fix.
5. Don't stage/sign/commit — leave for human review.

## notes

- Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
  first per this project's convention.
- This tool (`bin/format-code`) has its own history of subtle bugs found
  via careful dogfooding (see `topic-format-code-bugs-fixed.md`'s full
  arc) — apply the same standard of live verification here, not just
  code review.

#,,,.,,..,,,,,,,.,..,,..,,,.,,,,,,,..,.,.,,..,.,.,...,...,..,,,,.,,,.,,,.,...,
#36ZX6MJFGCZMYND27CR7FY3XCXFN4W6EMFVWH2IVA6ZQLJ4Y3G7DQ6XCGZY2547OTUYLN4WISPIF2
#\\\|JUMRMZ6WEXENGJ6LW2K3BOC5PYIIYWOWDKMUMX6243KHAFN7B5I \ / AMOS7 \ YOURUM ::
#\[7]5MAUVHHXCTWLYQ3NBRSCGYJZR5SIY2TBXZREAKKJY2HXF36G44BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
