---
name: feedback-log-string-hygiene
description: small recurring style corrections for log/error strings — use base.str.eval_error not raw $EVAL_ERROR, base.parser.ellipse_center not substr, descr<=55 chars only for .cmd. routines
metadata:
  type: feedback
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

Three small corrections from one review pass, all about not hand-rolling
things that already exist:

- **`<[base.str.eval_error]>` not raw `$EVAL_ERROR`** in any log call.
  It wraps `base.format_error` — cleans file:line clutter and sanitizes
  paths, not just a passthrough. Why this matters concretely: an earlier
  bug in this session (`$mode` vs `$cmd` confusion, see
  [[topic-jobsite-stray-recovery]]) dumped an entire job record's content
  to console because the failure branch logged raw `$EVAL_ERROR`/raw
  payload with no cap at all.
- **`<[base.parser.ellipse_center]>->( $string, $len )` not manual
  `substr(...) . '...[truncated]'`** for bounding a log detail string.
  Center-ellipsis is more readable than a hard tail-cut for paths/ids.
- **`# descr =` must fit ~55 chars, only for `.cmd.` modules** (the
  command-listing UI has a fixed column). Non-`.cmd.` modules (handlers,
  internal routines) don't have this constraint. Move anything beyond a
  one-line descr into a separate `# notes =` field (own paragraph, blank
  line between `descr` and `notes`), matching existing convention (e.g.
  `bench.key-32-iterations`).

**How to apply:** apply all three preemptively when writing or reviewing
any new module header / log call, don't wait for correction.

#,,,,,,..,..,,.,,,..,,,.,,,,.,.,,,,.,,,,,,,,.,..,,...,...,..,,,,,,.,.,,,.,,.,,
#MRMQAHNISDAG7H35Q2OTS6YI4PS7PS6G4UZSBUK4CBX5Z6WFNXJQDXONBP2FQKTJY7L6SV2GUMHGI
#\\\|JXXGYLILOFS5E4QU5ISCEU5ZY3Z7NHPGMYERTAXKMR5ZPCOHVUD \ / AMOS7 \ YOURUM ::
#\[7]VVYKNVDMIVDQU7WVSORALZNSP53MRS36676AM55FOIQV4D466KCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
