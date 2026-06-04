---
name: topic-ascii-desktop-domains
description: border glyphs are domain-scoped; nested domains = nested display planes = ascii desktop / multi-node window system via reverse parser + multiple typers
metadata: 
  node_type: memory
  type: project
  originSessionId: c3c1be56-d87b-4049-b5f6-0b91e40f1696
---

vision crystallized 2026-06-04, immediately after the `#`-purge from frame mockups
(see [[topic-frame-plugin-slots]], [[topic-ascii-frame-system]]).

**core insight — border glyphs are DOMAIN-SCOPED.** the `#` removal proved it:
`#:::` is correct in the *signature* domain (every line is a `#` comment, the rule
closes it) but a domain leak in the *display* domain (a frame bottom is structural
border, not a comment). it read harmonious only because the eye recognized the
footer cadence.

**generalization — a desktop is a stack of nested domains, each rendered in its own
material:**
- innermost: `:…:` colon frame = the **application plane** (one zenka's view)
- parent: thin `───│┌┐└┘` box-drawing = the **window chrome / node frame**
- grandparent: the **desktop / multi-node display** — another material again

nesting domains IS nesting display planes. a colon-frame inside a thin-line box =
a window on a desktop / a node in a parent multi-node display. connects to
[[topic-perspective-layers]] (desktop = data + UI intent) and [[observer-centric-space]].

**why the reverse template parser makes this typer-agnostic:** the mockup is the
abstract design; a *typer* is one realization of it. two typers already exist and
prove the axis — `ascii.frame.render` (colon/ascii) and `ascii.frame.render.html`.
box-drawing would be a third; a gtk3 GUI typer a fourth, rendering the SAME logical
desktop.

**THE architectural seam (frames → windowing):** the renderer currently *echoes the
literal fill/corner chars* from the mockup (`render.border_line` rebuilds from parsed
anchor/fill/slot elements that carry the source `char`). to render a thin-line parent
domain wrapping colon children in one pass, the **descriptor must carry ROLES
(corner / h-edge / v-edge / fill) decoupled from GLYPHS**, so each typer substitutes
material per domain. `border_style: double` already hints at this (named material, not
a literal). push it all the way:
- `border_style: colon` → `:…:`
- `border_style: thin`  → `─│┌┐└┘`
- `border_style: double`→ `::` (current)
then one source descriptor renders as terminal-ascii, box-drawing, or HTML windows.

**status:** vision only. `#`-purge done + verified (7 frames close on colon rules,
width rigid). still-open prior pass: converge frames to the `/tmp/frame.asc` idiom
(` .:[ ..x.. ]::[ title ]:. ` / `:….:`) + parser tweak for leading-space/low-density
top line — must precede or accompany any role-vs-glyph work.

#,,,,,,..,.,.,,,.,.,.,,..,.,,,.,.,..,,.,.,,,.,..,,...,...,..,,.,.,,,.,.,.,,,,,
#XOLLQRZS6QAMNIGTMBYNH3EIMSYBWLSMDFOYGAYJJTI3SEJDKU7VHU6LDJ452L7WCHYY6OCD32TAA
#\\\|TBRCDXZWVPHEQUHPZAZ5BAYWVYIJR7PGXO255OA6TXEYCOEIDOC \ / AMOS7 \ YOURUM ::
#\[7]6SGBIBSRCUDLVAQGSU5BUEHPLJFCJJIF5QHHKGLQQ6H3WH34HWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
