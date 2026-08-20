---
name: feedback-stream-repetition-homogeneous-false-positive
description: "coding.detect_stream_repetition's degenerate-loop check (8-60 char unit repeated 4+ times) false-positives on legitimate homogeneous single-character runs -- ascii.frame border fills, AMOS7 signature terminators, '----'/'====' dividers -- fixed 2026-08-10 (c39873f93) by requiring a much longer run for single-character units specifically"
metadata:
  type: feedback
---

Found live via a real abort: task 2570277 (a context-compaction
summarization call, model `ZDMAPAY:AR3OCKQ`) failed with `abort: pattern
matched`, log line `async.http_io: degenerate repetition detected for
task 2570277 [unit=8 chars]`. The content it was summarizing was a
description of `editor.ui.ascii_frame.render_form` (see
[[topic-user-edit-console-zenka-status]]) that quoted a rendered
`ascii.frame` table, including its bottom border:
`:..................................................:` — roughly fifty
literal `.` characters. `coding.detect_stream_repetition`'s regex,
`(.{8,60}?)\1{4,}`, matches an 8-60 char unit repeated 4+ times — an
8-period unit repeated 4 times is only 32 characters, so a ~50-char run
of a single character trips it easily. Same mechanism would fire on an
AMOS7 signature footer's trailing `#::::::...` line (verified separately,
~78 colons), or any `----`/`====` divider of reasonable length — none of
these are the actual failure mode the check exists to catch (a model
looping on a real multi-character phrase/token).

**Fix** (`c39873f93`, `src/coding.detect_stream_repetition`): after a
match, check whether the matched unit is homogeneous
(`$matched_unit =~ m|^(.)\1*$|s` — all one character). If so, require the
full matched span (`$+[0] - $-[0]`, not `$&` — avoids the classic Perl
global performance penalty of touching that special var anywhere in the
program) to exceed a much higher threshold
(`<coding.cfg.stream_repetition_homogeneous_min_len>`, default 200)
before flagging it as degenerate. Genuine multi-character phrase
repetition is unaffected — still flagged at the original 4-repeat
threshold. Verified standalone (not just via `ptd -c`) against four
cases before signing: the real ~50-char dot-border false positive (now
correctly NOT flagged), a synthetic ~78-char colon signature line (not
flagged), a genuine repeated-phrase degenerate loop (still flagged
immediately), and pathological single-character spam at 500 chars (still
flagged, since it exceeds the 200-char homogeneous threshold).

**How to apply:** if a coding-zenka task aborts with `degenerate
repetition detected`, check the log line's `unit=N chars` — if `N` is
small (near `stream_repetition_unit_min`, default 8) and the task's
content plausibly included repo file content (signature footers,
`ascii.frame`-rendered tables, comment dividers), suspect this false-
positive class before assuming the model actually looped. This fix
landed 2026-08-10; if the false positive recurs after that commit,
the `homogeneous_min_len` threshold (200) itself may need tuning, or a
new class of legitimate repeated content has shown up that the fix
didn't anticipate — don't assume the fix fully closed the false-positive
surface, only the two specific cases it was verified against.

#,,,,,,.,,,,.,,.,,,,,,..,,...,,..,..,,.,.,.,,,..,,...,...,...,..,,...,,.,,.,.,
#GX2VPNI24D7DOUMG2XIPQ6MVQU6VGKZUC6F5SB7BWP7CORU55Q2XNVFSTJKTBSADRN5LMEDIZFE3O
#\\\|USL4N6OAGOJRFBMJIRYHKNKO6DMNLYSTFDUD3KEWN2E7LYSEZPG \ / AMOS7 \ YOURUM ::
#\[7]CPWA5U6YTTXSYHVDWTMNW55NYK7ZOVY6FEO5UFVZY7FUICGWGWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
