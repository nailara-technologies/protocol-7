---
name: topic-decorative-footer-shaped-lines-not-auto-strippable
description: standalone footer-header-shaped comment lines (matching the octal header line exactly, length included) are sometimes intentional/functional -- real AMOS checksum, endline state, harmonization counter -- not just leftover debris, so source.extract_sig_body must not gain auto-strip detection for them; ncode-assisted manual cleanup is the right tool instead
metadata:
  type: reference
---

Surfaced 2026-08-02 while writing `base.prune_key`: a bare decorative
comma-line divider (mimicking a footer's opening octal-header-line shape)
was left in the file body, sitting immediately before the real signature
footer once the file got signed -- structurally the same "decorative line
in front of a real footer" shape as [[topic-fake-signature-footer-detection]]
and the over-long-fake-footer fix landed the same day (`2528fb353`).

## why this is NOT the same bug, and should NOT get an auto-strip rule

**Correction 2026-08-02**: only genuine, complete signature footers
currently encode real data (AMOS checksum, endline state, harmonization
counter). Other envisioned decorative/footer-shaped elements are NOT
currently functional -- when a model adds one, it's either inert (no
data encoded at all) or copied verbatim from elsewhere. The risk is
prospective, not present: these elements are *envisioned* to gain real
encoded data at some future point, and already mimic the real header
line's format exactly (length included) in preparation for that. So the
absence of a shape-based "is this real" signal is still the operative
problem -- a rule written today to auto-strip "empty" decorative lines
could not distinguish today's inert copy from tomorrow's functional one
without being rewritten anyway, and would need re-deriving once real
data starts landing in these elements. Treat as unsafe to automate now
AND unsafe to automate later without revisiting this note first.

Three placements observed, each with different intent:
- standalone at true EOF (file not yet fully signed)
- immediately before a real footer (the case that prompted this)
- mid-file, used in memory `.md` docs as a divider between old and
  newly-appended content -- a genuine organizational role, not decoration

Given a mid-file divider role exists and is intentional, any auto-strip
rule risks destroying real organizational content, not just cleaning up
junk -- the opposite failure mode from the bug just fixed. Building
detection into `source.extract_sig_body`'s strip path was considered and
explicitly rejected for this reason.

## the right tool instead

Case-by-case `ncode`-assisted cleanup (assess/suggest with confidence
scoring, human sign-off before apply) rather than automatic stripping --
matches the existing tier-A/tier-B model in
[[topic-ncode-pattern-learning-loop]] (auto-apply only for
high-confidence, unambiguous patterns; this is explicitly not one of
those). No action item currently queued; revisit only if/when an actual
cleanup pass is wanted, and always via `ncode`, never via
`source.extract_sig_body`.

## also: stop hand-adding these

Root cause of the specific instance that prompted this: I (claude)
hand-typed a decorative comma-line-divider at the end of a newly-written
module (`base.prune_key`) before the real signing tool ran, mimicking the
footer shape as a stylistic flourish with nothing under it. There is no
good reason to do this -- the real signing tool appends the genuine
footer on its own. Removed it from `base.prune_key` before signing.
Going forward: do not hand-add footer-shaped decorative lines when
writing new module files.

## related

[[topic-fake-signature-footer-detection]]

#,,.,,.,.,...,.,,,.,,,.,,,..,,,,.,.,,,...,...,..,,...,...,.,,,.,,,,..,..,,,,,,
#UD5QFCRCQRKJWYEVA6M5VE7JBV4GPE73VGTCLKUWU3OXTGJU7EJSPMV3WA5Y4BM46WZKKYLUEA2ZE
#\\\|J3WV76JYVPEI3IJ52RTZFD4S26MKD5NAUGPPAXNQSTJ2S63YG2O \ / AMOS7 \ YOURUM ::
#\[7]VKFOURZL6KCVZNY7BTCUH5NS5JKUEUMRW2B6IKIDZVROQBWZ7SAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
