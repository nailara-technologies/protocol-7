# Protocol-7 / AMOS7 colour palette

Starting base extracted from the project’s own ANSI colour definitions and the
`data/gfx/cubic-space-topology/holographic-cube.png` artwork. Expand here as
more components get themed.

## Sources

* `data/lib-path/pm/AMOS7.pm` – ANSI colour table used by `bin/amos-chksum`
  and other AMOS7 tooling.
* `data/gfx/cubic-space-topology/holographic-cube.png` – sampled dominant
  colours (ImageMagick `-colors 10`).

## Core ANSI colours

| Name | Hex | RGB | Role |
|------|-----|-----|------|
| `T`  | `#0647C3` | `rgb(6,71,195)`   | Primary accent (blue) |
| `0`  | `#4427AC` | `rgb(68,39,172)`  | Secondary purple/blue |
| `G`  | `#032552` | `rgb(3,37,82)`    | Dark background blue |
| `g`  | `#47C306` | `rgb(71,195,6)`   | Positive / active green |
| `o`  | `#C58D07` | `rgb(197,141,7)`  | Attention / warning gold |
| `B00`| `#000011` | `rgb(0,0,17)`     | Deepest background |
| `B01`| `#090518` | `rgb(9,5,24)`     | Dark panel background |
| `B02`| `#09052A` | `rgb(9,5,42)`     | Dark elevated surface |
| `b`  | `#09052A` | `rgb(9,5,42)`     | Alias of `B02` |
| `R`  | reset     | –                 | Reset / default |

## Holographic cube sampled tones

| Hex | RGB | Role |
|-----|-----|------|
| `#12061B` | `rgb(18,6,27)`    | Near-black purple background |
| `#150C4C` | `rgb(21,12,76)`   | Deep indigo |
| `#180324` | `rgb(24,3,36)`    | Dark plum |
| `#190228` | `rgb(25,2,40)`    | Dark violet-black |
| `#1A0228` | `rgb(26,2,40)`    | Dark violet-black |
| `#46486D` | `rgb(70,72,109)`  | Muted slate blue |

## Suggested usage notes

* Use the cube tones (`#12061B`, `#180324`, `#190228`) for large dark
  backgrounds / panels.
* Use `T` `#0647C3` and `g` `#47C306` for primary interactive elements.
* Use `o` `#C58D07` sparingly for hover / attention states.
* Use `#46486D` for disabled / held / secondary surfaces.

## Example mapping: mpv OSC

Applied in `cfg/zenki/mpv/zenka.v7`:

```text
background_color        #12061B
timecode_color          #47C306
title_color             #0647C3
time_pos_color          #C58D07
buttons_color           #47C306
small_buttonsL_color    #0647C3
small_buttonsR_color    #0647C3
top_buttons_color       #C58D07
held_element_color      #46486D
time_pos_outline_color  #000000
```

## Example mapping: SciTE

Applied in `cfg/backup/.SciTEUser.properties` and
`cfg/backup/scite/perl.properties`:

* UI chrome (caret, selection, fold margin, error/bookmark markers) →
  project blues / greens / golds.
* Base `colour.*` variables (keyword, string, comment, operator, error) →
  the core ANSI palette.
* Language-specific `style.*.fore:` / `style.*.back:` outliers were
  remapped automatically: bright reds/pinks/yellows → gold, cyans → blue,
  greens → green, purples/magentas → purple, light backgrounds → `#12061B`
  or `#180324`, near-black backgrounds → `#000011`.
* Syntax/form fixes: corrected `style.*.32` punctuation, removed trailing
  comma in `colour.other.comment`, fixed negative `alpha` values.

## Example mapping: highlight

`cfg/backup/themes/highlight/amos-7.blue.theme` already used the
project identity; it was tightened to the exact palette:

| Token | Colour |
|-------|--------|
| Default / Keywords 1-2 | `#0647C3` |
| Number / String / Keyword 3 | `#47C306` |
| Escape / Interpolation | `#C58D07` |
| BlockComment / Keyword 4 | `#4427AC` |
| Canvas | `#09052A` |

## Existing project theme colour references

See [`existing-theme-colors.md`](existing-theme-colors.md) for a full dump of
colours extracted from the old gkrellm2, rofi and highlight themes, with
suggested mappings to the core palette above.

