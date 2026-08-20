---
name: topic-bin-todo-style-refresh
description: scoped plan to restyle bin/todo's frame/color/help output using AMOS7::TERM, borrowing from src/ascii.frame.* and base.parser.txt_box
metadata:
  type: project
---

`bin/todo` (standalone script, not a zenka module) has crude ascii header/footer
drawing and no help/error styling, unlike `bin/amos-chksum` which uses a consistent
structural-color vs. content-color split and a boxed-line motif.

Plan agreed with user:
1. Add frame-drawing functions to `data/lib-path/pm/AMOS7/TERM.pm` (e.g.
   `frame_border_line`, `frame_colorize_border`, `frame_colorize_content`,
   `frame_bar`), ported/generalized from `src/ascii.frame.render.border_line`,
   `.render.data.border_string`, `.render.color.border_line`, `.render.color.content_line`,
   `.bar` — those are zenka modules (use the `%code` dispatch) so can't be `use`d
   directly from a standalone script; porting their logic into the real `AMOS7::TERM`
   package is the bridge, following the pattern `src/base.parser.txt_box` already
   uses (`AMOS7::TERM::terminal_size()` called as a plain sub once the package is
   loaded).
2. Rewrite `bin/todo`'s `draw_header`/`draw_footer`/row-padding to call the new
   `AMOS7::TERM` functions instead of hand-rolled `$width - length($text)` math.
3. Add a `-options`/help command styled like `amos-chksum`'s `list_options()`.
4. Optional/later: point `src/ascii.frame.*` and `base.parser.txt_box` at the same
   `AMOS7::TERM` functions so there's one implementation — not required now; see
   [[topic-amos7-p7-loader]] for why duplication is currently fine (same underlying
   vision: a future dep-graph loader/parser removes the need to port zenka-module
   logic into standalone-usable packages at all).

**How to apply:** if this surfaces again, the task was sized for a single Opus/Kimi
(k3-256k) dispatch — spec the `AMOS7::TERM` function signatures + `bin/todo` call
sites explicitly in the dispatch prompt rather than leaving them to be inferred.

#,,..,..,,..,,,,.,,,.,.,.,,,,,,..,.,.,,,,,..,,..,,...,...,...,,,,,.,.,.,,,,.,,
#5RE36E5V2L2GP7AWE2CAUFU4D2N2HZ5FKDXA2MDECAG5T76FMST7PXUVDSJEGC7AB5LRLYLFFLMHY
#\\\|3525FLEDT4EP3ID2KVGHHDP6Z7RHSSWWGOKHZ5677LVZMM6MQL5 \ / AMOS7 \ YOURUM ::
#\[7]3MJ6PXW56RG32PF2MLIEKSYQUECDVIDJV3N4FGXR2LTRLSAEVOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
