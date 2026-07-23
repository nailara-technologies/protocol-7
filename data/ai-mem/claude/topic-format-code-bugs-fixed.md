---
name: topic-format-code-bugs-fixed
description: "five real bugs found and fixed in bin/format-code (comment-loss, unbalanced string splits, missing multi-line ## block alignment, trailing-marker width-budget miscalc, UTF-8 byte-vs-char length) via dogfooding on real files, not synthetic tests"
metadata:
  type: project
---

**Landed 2026-07-24.** `bin/format-code` is a PPI-based preprocessing pass
(quote-splitting, comment reflow) that runs before perltidy. All five bugs
below were found by the user running it destructively on real zenka module
sets (`jobsite`, then `web-browser` — picked deliberately for having several
`##` blocks but fewer routines than `coding`, as a manageable test sample),
not by writing tests up front. Pattern worth repeating: ship a fix, ask the
user to dogfood on a real file, fix what that surfaces, repeat.

## The five bugs (commits `5a1d3ae7f`, `f9954e3cf`, `5de8c6b2f`, `88369cd59`, `1be569b06`)

1. **Comment silently dropped** (`step3_relocate_trailing_comment`): when
   relocating a trailing `##  comment  ##` above an over-78-col code line
   didn't actually help (code portion alone still over budget), the function
   returned just the code line, discarding the comment. Fixed: falls back to
   leaving the original line untouched.

2. **Unbalanced string splits** (`step1_split_long_string`): picked the
   greedy-maximal split point (largest position fitting line 1's budget),
   which often left a tiny leftover fragment on line 2. Fixed: computes line
   2's budget too and picks the split closest to the string's midpoint among
   positions satisfying both budgets.

3. **Missing feature entirely**: no mechanism existed to keep the right-hand
   `##` bars of a multi-line comment paragraph aligned to a common column —
   exactly what LLM-generated code gets wrong most often, per the user. New
   `step4_align_comment_block`: detects a maximal contiguous run of
   same-indent `##`-prefixed lines, reflows their joined content as one
   Text::Wrap paragraph, right-pads every line to match. **Two rounds of
   getting the detection wrong before landing on the right rule** (see
   commit `88369cd59`): requiring every line in the run to be individually
   `## ... ##` closed broke on paragraphs where only the LAST line closes
   (a first/interior line missing its own trailing `##` is a common
   authoring slip, human or LLM); then "stop the run at the first closed
   line" broke on a *properly-closed first line that's still the start of a
   larger paragraph* — the real rule is: collect the maximal run first,
   THEN check only whether the run's last line is closed. Known accepted
   gap: two genuinely separate closed paragraphs sitting back-to-back with
   no blank line between them would still get merged into one reflow — no
   reliable syntactic signal distinguishes that from one long paragraph;
   left as accepted risk (cosmetic, not corruption) pending an actual
   real-world hit.

4. **Trailing-marker width-budget miscalculation** (`step2_reflow_comment`):
   wrap width was computed BEFORE stripping the trailing `##` marker aside
   for reattachment, so it never accounted for that marker's length coming
   back on the last wrapped line — a line could look like it fit and skip
   wrapping, then land over 78 once the marker was reattached. Found via a
   real line in `jobsite.dispatch.assessments` that was silently left at 80
   cols.

5. **UTF-8 bytes vs characters** (`slurp_file` + tmpfile write path):
   `decode_utf8`/`encode_utf8` were imported at the top but never actually
   called anywhere — both read and write used raw `:raw` binmode. Every
   `length()`/`substr()` throughout steps 1-4 was counting BYTES not
   CHARACTERS, so any multi-byte UTF-8 char (em-dash, arrows) in a comment
   made that line look 2-3 columns wider than its true display width,
   corrupting wrap decisions on any line containing one. Found on a real
   em-dash in `web-browser.open_window` — an otherwise-uniform 6-line block
   was reflowing to 7 uneven lines. This is the SAME class of bug the user
   flagged by instinct earlier in the session (mid-turn, unprompted:
   "that might be actually CORE::length vs bytes::length unicode") before
   this specific instance was found — the hunch was right, just about a
   different file than the one that prompted it. Fix respects the existing
   `-noutf8:` opt-out flag.

## Verification pattern used throughout

Every fix was tested against BOTH a synthetic regression suite (covering
all prior cases together) AND the real file that surfaced the bug (dry-run
via `-n`, scratch-copied, diffed against original) before commit — never
trusted a fix from reasoning alone. Caught the two wrong-on-first-try
detection rules for bug #3 this way.

## Still open / not investigated

Last check-only scan (`format-code -c modules/web-browser.*`) after all
five fixes landed showed 13 files in `web-browser` still pending reformat
— not yet applied to real files, pending user go-ahead. Re-run the scan
fresh before applying broadly, since fix #5 in particular changes which
files "need" reflowing.

## related

[[topic-p7-text-formats-landed]]

#,,,,,..,,.,,,,,,,,..,.,,,,..,.,,,...,,,,,,.,,..,,...,...,,,,,.,.,,.,,,.,,...,
#MCJ5XCUDOVWKCWRNOYXLMTYXKEN6ABZXWRBQPVOJMBYS7Z27P3T2Z5SAI2G3JETITAS347DMGWBMW
#\\\|JCFISDNSKOUXKE6FWQAABGCXFH7VHAYK4YGKIMEQFBYSSIGGNJ5 \ / AMOS7 \ YOURUM ::
#\[7]CO64D4V2HXKWUVSCO4RT5A57M63P4L3VEXBISSUL25JYLUZCDIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
