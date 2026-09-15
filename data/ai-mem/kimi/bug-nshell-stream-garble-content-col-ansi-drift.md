---
name: bug-nshell-stream-garble-content-col-ansi-drift
description: coding-session (split-mode) streaming garbles output at random screen positions because nshell.render.content_print counts ANSI escape bytes as visible columns; introduced by the per-chunk color wrapper in commit c313be443
metadata:
  type: bug
---

Diagnosed 2026-09-15. Symptom: in nshell coding-session mode (split mode), live STRM
streaming prints token chunks at garbled, interleaved screen positions
("The Kim i beencountsstat,s e hasnd t.p ..."), while rewind/redo replay prints
correctly.

## Root cause chain

1. Split-mode `nshell.render.content_print` (src/nshell.render.content_print) positions
   every call with DECSC + `CUP(content_row, content_col)` + print + DECRC, tracking
   `content_col` between calls via raw `length($text)` (lines 92-106). The math is
   NOT ANSI-aware.
2. `src/nshell.handler.strm_reply` chunk branch (lines 144-146) wraps EVERY chunk in
   `$colors{'p7_fg_0004'} . $chunk_data . "\e[0m" . $colors{'p7_fg_0004'}` — added by
   commit c313be443 ("nshell: Esc/Ctrl+C redesign ... wrap-loss fix") as the bare-reset
   color-loss fix. That is ~24 non-printing bytes per chunk.
3. Token-sized chunks: `content_col` over-advances by ~24 columns per chunk. After a
   few chunks the tracked column is far right of the real cursor; the next chunk's CUP
   lands mid-row or past the right edge (soft-wrapping into a row the tracker doesn't
   know), printing over earlier text. Character-level interleave of two sentences at
   staggered offsets is the signature.
4. Rewind/redo look fine because replay (`src/nshell.display.cycle` lines 93-95) prints
   the whole accumulated buffer in ONE plain print — no per-chunk CUP, so drift never
   manifests; only the final tail-column estimate is off (visually absorbed).
5. Regression timeline: before c313be443 the chunk branch was a bare
   `content_print->($chunk_data)` — no ANSI in measured text, tracking exact. Plain
   shell mode (non-split) also unaffected because content_print short-circuits to plain
   print there. So the bug only shows in split/coding-session mode.

## Fix (applied 2026-09-15, LIVE-CONFIRMED same day)

Column math made ANSI-aware in BOTH places (deliberately kept in sync):
- `src/nshell.render.content_print` — copy `$text`, `<[base.strip_ansi]>->(\$copy)`,
  run the tail/col regex+length math on the stripped copy
- `src/nshell.display.cycle` — same for the replay-buffer tail math
`base.strip_ansi` is a CORE subroutine (not in src/ — query with
`Protocol-7 -core-subs base.strip_ansi`): strips `$data{base}{ansi_re}` in place on a
scalarref; early-returns if `!$data{'system'}{'ansi_color'}` (harmless — with colors
off, `%colors` values are empty so no ANSI exists to miscount). Both files pass
`bin/format-code -c`. Pre-existing separate inaccuracy, not part of this bug: wide
chars/emoji count bytes in the tail math.

Verified live: rewind/redo replay, manual subscribe+restream on a completed task,
AND fresh live inference streaming in coding-session mode all render correctly
(markers right-aligned, payload left-heavy, exact-width rows no longer lost).
One transient observed on the very first post-fix run (task-ZGLYELA): markers
displayed but live payload didn't — never reproduced; a re-test on a fresh task
worked perfectly. Lurking hazard worth remembering if it ever resurfaces:
`base.handler.command.process_reply` ~line 1052 unknown-route INCOMPLETE chunk path
silently discards the chunk's data, fires !TRM! at the producer, and marks the
stream cancelled — under live bursts (payload split across socket reads) this can
eat chunks while quiet-period round markers survive. Net/cube runs at log verbosity
1, so STRM level-2 logs are invisible in the NIW7OAQ console.

## Ruled out

- `base.s_read` recent change (c0187d751, fork/tls :utf8 handle fix) — a sysread
  transport-layer change; garbling signature is positional (cursor CUP drift), not
  data corruption. Wire-level corruption would garble characters, not interleave two
  sentences at staggered screen offsets.
- round-marker restyle substitution — marker chunks end in \n so tail resets; its
  padding is computed from visible text correctly.

#,,,,,,..,,.,,.,.,,.,,,..,,,.,..,,,..,.,,,,.,,..,,...,...,...,..,,..,,.,,,,..,
#ENFEXHRKD4OYO3HGKZTJRKGYID6ITR7TVFP4BOANBWE2FILWQTYJQDU3QGM5CE7YBIDXG4CIQIJMO
#\\\|66CCZD5OBY7AJRPN2JNZNK34QL2RZOITRDN4Q25N5YVOIAG56ML \ / AMOS7 \ YOURUM ::
#\[7]OXW3L244GY7WBPE4WOZ6GVFOZNPUBP3BPFR65NC7B7ZBQWKU5IBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
