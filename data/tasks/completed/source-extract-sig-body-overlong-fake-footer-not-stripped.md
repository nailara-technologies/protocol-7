## [:< ##

# name  = task: source.extract_sig_body fails to strip over-long fake footers
# descr = hand-typed/hallucinated fake footers with lines longer than the
#         hard-coded length ceilings bypass every strip regex, including
#         the real-signature extraction pattern, and are left in the file

## background

`data/ai-mem/claude/topic-fake-signature-footer-detection.md` and
`data/ai-mem/claude/project-2026-07-30-gap-audit.md` previously tracked a
"YOURUM fake stubs 1 char too long -> size mismatch -> error instead of
strip" bug. That specific path was investigated 2026-08-01 and ruled out:
a footer that's merely 1 character off from `<source.sign_template>`'s
length still matches every extraction regex fine, gets stripped
unconditionally before the size check even runs, and every live caller
(`strip-signature-footer`, `verify-p7-signatures`, `update-signatures`)
already handles the resulting `yourum-fake-signature` flag correctly.

But the user's actual recollection of what triggered that report was
different: fake footers with lines *longer than the tolerance the regexes
allow* failed to be stripped at all. Reproduced 2026-08-01 with a
standalone regex-equivalence test (not yet against the live zenka) -- see
below.

## root cause, reproduced 2026-08-01

Every footer-recognizing regex in `src/source.extract_sig_body`
caps how long the comma-line / colon-line of a footer may be:

- `$footer_start_regex = qr|#[\.,]{70,85}|` (line 49) -- also reused as
  the START marker for the generic REAL-signature extraction pattern at
  line 154 (`qr/(\n)?(# _{78}|$footer_start_regex)\n((?:#[^\n]+\n)+)$/s`)
- PLACEHOLDER old-format stub strip: `#[\.,]{70,85}` ... `#[:]{70,80}`
  (lines 70-71)
- PLACEHOLDER new-format stub strip: checksum line `[A-Z0-9]{60,100}`
  (line 81)
- sequential-fake-checksum ("LLM-hallucinated") stub strip: comma-line
  `[,\.]{70,90}`, colon-line `:{70,90}` (lines 117, 122)

A hand-typed/hallucinated footer whose comma-line or colon-line runs
longer than these ceilings (tested with 95 `.`/`:` characters, vs. the
85/90 max any regex here allows) matches **none** of the stub-strip
patterns, and -- critically -- also fails to match the generic
real-signature pattern, because that pattern reuses the same
`$footer_start_regex` for its start marker. With no regex matching at
all, execution falls through to the "no footer extracted, but content
has signature-like markers" branch (`source.extract_sig_body` ~line
451-487), which sets `extraction_failed_with_markers => TRUE`,
`was-present => 1`, and returns *without ever stripping anything*.

Downstream, `sourcecode.console.strip-signature-footer` only special-cases
the `yourum-fake-signature` flag (which is never set on this path --
the function returns long before reaching that check). It falls into the
generic `else` branch, logs `invalid signature structure`, and skips the
file -- leaving the fake footer in place untouched. This matches the
originally reported symptom ("failed to be stripped") exactly.

Standalone reproduction script used during investigation (regex-only,
not run against the live zenka) is described in this session's
transcript; re-derive or ask for it if useful as a starting point, but
verify against the real module/zenka per the acceptance checks below,
not just the standalone regex.

## the fix

Per the user's guidance: don't just raise the numeric ceilings (that
just moves the bypass further out and something built to be recognized
as *approximately real* will always be craftable one character past
whatever fixed number is chosen). Instead, make footer recognition
tolerant of length on the right while still requiring a strong enough
match on the left:

- Recognize a footer block by its **left-anchored structural markers**
  (the leading `#`, the run of `.`/`,` characters establishing "this is
  a footer-start line", the `\\\|`/`\[7]` prefixes on the signature
  lines, the `AMOS7`/`YOURUM`/`DATA-SIGNATURE` marker tokens) rather than
  requiring the *entire* line to fall within a narrow character-count
  window.
- Tolerate inconsistent/over-long trailing runs of `.`/`,`/`:` on the
  right of those marker lines instead of rejecting the whole block --
  i.e. change fixed ranges like `{70,85}` / `{70,90}` to open-ended
  minimums (`{70,}`) where the risk of false-positiving on ordinary code
  comments is low, or to a much larger sane ceiling if an open bound is
  judged unsafe (explain your reasoning either way).
- Apply the same left-anchored/right-tolerant logic consistently across
  *all* the footer-recognizing regexes in this file (stub strips AND the
  generic real-signature pattern), not just one of them -- a fix that
  only widens the fake-detector but leaves the real-signature pattern's
  own start-marker regex narrow would just relocate the bug.
- Do not weaken the checks in a way that would let genuinely unrelated
  comment blocks (not footers at all) get misdetected as footers -- the
  existing marker tokens (`AMOS7`, `YOURUM`, `DATA-SIGNATURE`, the
  `\\\|` / `\[7]` prefixes) are what should carry the recognition
  confidence, not the character count.

## acceptance checks

1. `ptd -c` clean on every touched file.
2. Reproduce the original bug live: construct a test file with a
   hand-typed fake footer whose comma-line and/or colon-line exceeds the
   current ceilings (95+ characters, matching the investigation's
   reproduction), run it through the real `source.extract_sig_body` (via
   `p7c` / the `sourcecode` zenka, not a standalone regex script), and
   confirm it currently returns `extraction_failed_with_markers` without
   stripping -- i.e. reproduce the bug for real before fixing it.
3. After the fix, confirm the same test file's fake footer is now
   recognized and stripped (or correctly classified as fake and stripped
   anyway, matching the `yourum-fake-signature` handling already in
   place for the other fake-footer variants).
4. Run a **real, valid, currently-signed file** through the same path
   before and after the fix and confirm its genuine signature is still
   extracted/stripped/restored identically -- no regression on the
   common case. Pick at least one real file from `src/`.
5. Run `v7.sourcecode strip-signature-footer` (or the live zenka
   equivalent) against a small batch of real files under `src/` to
   confirm no false-positive footer detection on ordinary trailing
   comment blocks that aren't signature footers.
6. Quote real command output for all of the above -- don't just
   self-report success.
7. Don't stage/sign/commit -- leave for human review.

## notes

- Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
  first per this project's convention.
- Live-verify via real command output per this project's dispatch
  convention -- don't trust your own self-summary without it.
- Suggested model: kimi K3-256k, for token efficiency on this file's
  size/complexity while keeping full reasoning quality.
- Related, already resolved/ruled-out memory: `data/ai-mem/claude/
  topic-fake-signature-footer-detection.md`, `data/ai-mem/claude/
  project-2026-07-30-gap-audit.md`. Update those (or ask for them to be
  updated) once this lands, since the "still open" line there needs
  replacing with the real root cause and fix.

#,,,.,,.,,,,,,.,,,...,..,,,,,,.,,,,.,,...,,,,,..,,...,...,.,,,.,.,.,.,,..,..,,
#FQHBDQLAKBPP4MNBJ2LHQOF5WBT7H4ZOLNZL6BG3MBSRIGXYHU52Q63KWZD3V7KP2B2U4PXSMWWEC
#\\\|EB3JCYVESJFTSIRVTXDERY7RXSFNCQAZC42AWG6GCHNXFOUTFQ2 \ / AMOS7 \ YOURUM ::
#\[7]O6SDQU2IQWPQMSJVEHP2EIDVLIDZ4ECVGHSIW73SQCJJFC22VGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
