---
name: topic-fake-signature-footer-detection
description: "found+fixed a new LLM-hallucinated fake-footer disguise in source.extract_sig_body: sequential letter+digit checksum line, undetected by the existing PLACEHOLDER-text and size-mismatch fake-stub checks -- was sitting in front of a real, valid footer in ticker.cmd.next-monitor, invalidating its checksum. related but distinct from the still-open session-37 'YOURUM stub 1 char too long' bug"
metadata:
  type: project
---

Landed 2026-07-24, commit `c5b78611a`-adjacent (`fabafec2d`).

## what was found

`bin/format-code`'s dogfood pass on the `ticker` zenka surfaced a real
line-width violation in `ticker.cmd.next-monitor` that traced back to a
**fake, hand-written signature footer sitting in front of a real one**:

```
#,,,.,,,..,..,,,.,,..,.,,.,,,.,,..,,,..,,...,..,,.,.,,..,,,..,,.,,,,.,,,.,,,,.,
#C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4A5B6C7D8E9F0G1H2I3J4K5L6M7N8O9P0Q1R2S3T4
#\\\\\|X1Y2Z3A4B5...  \/ AMOS7 \\ YOURUM ::          <-- 4 backslashes, not 3
#\\[7]E1F2G3G4H5...  7  DATA SIGNATURE ::            <-- 2 backslashes, not 1

#,,,,,,,,,...,,.,,...,.,.,..,,.,,,,,.,,,.,,,.,..,,...,..,,,,,,,..,,,.,..,,,.,,
#CMCGII6NRLTKV2TLZ5DAYUV2G7GU6P2YSUKZPXYAEELWCBJBUOEAPEZYE6FNAGK2GMT26JDODYUS2
#\\\|N64WIEY44OK3OT6ES33A6Q7RGDWD32HI6II4V3Q7BCKMQZ2BHK3 \ / AMOS7 \ YOURUM :: <-- real, valid
#\[7]ZCBP7K3DRT5RSSTCYD6ZRZZVFN3IFTCXGL3O5MD7WPAVYUM25CAA 7  DATA SIGNATURE ::
```

`source.extract_sig_body` already strips known PLACEHOLDER-text stub
footers before attempting real-signature extraction (three separate
regex patterns for old/new/AMOS7-perl-module stub formats — this was
added for a reason: "Stubs look like real footers but contain PLACEHOLDER
text ... by removing them upfront, we prevent them from being matched
before real signatures"). This fake footer used a **different disguise**:
a sequential letter+digit checksum line (`C1D2E3F4G5H6..`) instead of
literal "PLACEHOLDER" text, so it slipped past every existing check
undetected.

## why it broke silently instead of loudly

`v7.sourcecode strip-signature-footer` on the affected file reported
`files stripped: 0, files with errors: 1` — but a naive first re-run
attempt (before the fix) actually **did** mutate the file on disk despite
that report: the main extraction regex correctly matches the trailing
REAL footer (the fake one's own match attempt fails because a blank line
inside it breaks the required contiguous `(?:#[^\n]+\n)+$` run before
reaching true end-of-string), and the substitution that removes matched
text from `$$src_ref` happens *before* downstream checksum validation —
so if validation then fails, the file has still been partially mutated in
memory/on disk even though the tool reports zero files stripped. **Always
verify via `git diff` after any partial/erroring tool run, not just the
tool's own summary line** — caught this only by checking `git diff`
after a supposedly-no-op invocation and finding the real footer gone,
the fake one still present. Reverted via `git checkout --` before
proceeding.

Root cause of the validation failure itself: the real footer's checksum
is computed over "everything before it" — which now includes the injected
fake block as extra bytes that didn't exist when the real signature was
originally generated. The checksum genuinely no longer matches the
(corrupted-by-injection) content. The tool wasn't confused; the file's
real signature was genuinely invalidated by the fake block sitting in
front of it.

## the fix

New unconditional pre-strip regex in `source.extract_sig_body`, same
placement/pattern as the existing PLACEHOLDER-stub strips: detects a
footer-shaped block whose checksum line matches `(?:[A-Z]\d){15,}`
(15+ consecutive letter-digit pairs — essentially impossible to occur by
chance in real BMW/checksum output, verified against all 4948 files in
`modules/` with zero false positives at this threshold). Strips
unconditionally before real-footer extraction runs, so the real footer
behind it becomes extractable and valid again. Verified via standalone
regex equivalence tests AND a live `v7.sourcecode strip-signature-footer`
run against the real file, then reformatted with `/x` mode for
readability (mechanical whitespace-only change, re-verified byte-for-byte
equivalent behavior against the compact form before landing).

Also brought the two pre-existing PLACEHOLDER-stub regexes in the same
function to the same `/x`-formatted, within-`LINE_MAX` style while in the
area, rather than leaving a stylistic split between old and new code.

## related but NOT the same bug

`topic-next-steps.md` (session 37) already tracked: "source.extract_sig_body:
YOURUM fake stubs 1 char too long → size mismatch → error instead of
strip" — that's the EXISTING size-mismatch-based fake-detection path
(`$footer_body =~ /YOURUM/` after a length check fails) misfiring on a
near-real stub that's merely the wrong size. Still open, not touched by
this fix. The bug found and fixed here is a structurally different fake
that never triggers the size-mismatch path at all, because — per the
earlier trace — the SUBSTITUTION happens before the size check is even
reached for the wrong footer (the real one gets matched/removed first,
the fake one never gets far enough into the pipeline to hit that check).

## related

[[topic-format-code-bugs-fixed]]

#,,,.,,,.,,,,,,,.,,,,,,..,..,,.,,,.,.,.,,,.,,,.,.,...,...,.,,,.,,,.,,,,,,,,,,,
#XLSKQTH3SARAES6D4VNP2IBNM7MD5RVYD45VLHZ7RPA6FRQEQGWQBHIWR7WZY5SNIINOXKMMMXR7A
#\\\|D2EWXYXJXTYUERKCYLAZI2UBKO2VELZCHSVMCJS736YRUMMIJJ2 \ / AMOS7 \ YOURUM ::
#\[7]4ZT4QBH5DAKQ43BXRBRU5GMT5PB5IQ4L366QM3LU2YXG3DK2GCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
