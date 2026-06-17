# Existing project theme colours

Reference dump of colours found in old/backup project themes. These are the
ones worth keeping and normalising against `protocol-7-palette.md`.

## highlight — `configuration/backup/themes/highlight/amos-7.blue.theme`

| Token | Hex | Note |
|-------|-----|------|
| Default | `#0647C3` | exact project blue (T) |
| Canvas | `#09052A` | ANSI B02 dark bg |
| Number | `#379704` → `#47C306` | aligned to project green |
| Escape | `#765403` → `#C58D07` | aligned to project gold |
| String | `#025374` → `#47C306` | aligned to project green |
| BlockComment | `#262673` → `#4427AC` | aligned to project purple |
| Keywords 1-2 | `#2447AC` / `#0647A2` → `#0647C3` | aligned to project blue |
| Keyword 3 | `#043797` → `#47C306` | aligned to project green |
| Keyword 4 | `#0647A2` → `#4427AC` | aligned to project purple |

## gkrellm2 — `invisible-blue` themes

### Configuration colours (`gkrellmrc`)

| Setting | Original | Suggested project mapping |
|---------|----------|---------------------------|
| chart_in_color | `#0000FF` | `#0647C3` |
| chart_in_color_grid | `#0088FF` | `#0647C3` or `#032552` |
| chart_out_color | `#0000DD` | `#0647C3` |
| chart_out_color_grid | `#0088FF` | `#0647C3` or `#032552` |
| textcolor shadow | `#000000` | `#000011` |

### Image-sampled colours (alpha ignored)

Dark backgrounds / canvas:

| Hex | RGB | Closest project colour |
|-----|-----|------------------------|
| `#15052C` | `rgb(21,5,44)`   | `#12061B` / `#180324` |
| `#0A012F` | `rgb(10,1,47)`   | `#09052A` / `#12061B` |
| `#120949` | `rgb(18,9,73)`   | `#150C4C` / `#09052A` |
| `#060533` | `rgb(6,5,51)`    | `#09052A` / `#000011` |
| `#000000` | `rgb(0,0,0)`     | `#000011` |

Blue / purple accents:

| Hex | RGB | Closest project colour |
|-----|-----|------------------------|
| `#222CB3` | `rgb(34,44,179)`  | `#0647C3` / `#4427AC` |
| `#27198B` | `rgb(39,25,139)`  | `#4427AC` |
| `#28256E` | `rgb(40,37,110)`  | `#4427AC` / `#150C4C` |
| `#063987` | `rgb(6,57,135)`   | `#0647C3` |
| `#093063` | `rgb(9,48,99)`    | `#032552` |
| `#0F14D4` | `rgb(15,20,212)`  | `#0647C3` |
| `#100768` | `rgb(16,7,104)`   | `#4427AC` |
| `#120C9F` | `rgb(18,12,159)`  | `#4427AC` |
| `#4300B8` | `rgb(67,0,184)`   | `#4427AC` |
| `#5105C8` | `rgb(81,5,200)`   | `#4427AC` |
| `#8C1FD8` | `rgb(140,31,216)` | `#4427AC` / brightened purple |

Green / teal / amber meter tones:

| Hex | RGB | Closest project colour |
|-----|-----|------------------------|
| `#28594D` | `rgb(40,89,77)`  | `#032552` / dark teal |
| `#3F6D3E` | `rgb(63,109,62)` | `#47C306` (darker) |
| `#288F4F` | `rgb(40,143,79)` | `#47C306` |
| `#498C3E` | `rgb(73,140,62)` | `#47C306` |
| `#4D6E32` | `rgb(77,110,50)` | `#47C306` (darker) |
| `#5E6336` | `rgb(94,99,54)`  | `#C58D07` (darker) |
| `#786334` | `rgb(120,99,52)` | `#C58D07` (darker) |
| `#93571C` | `rgb(147,87,28)` | `#C58D07` |

Alert / foreground greys:

| Hex | RGB | Use |
|-----|-----|-----|
| `#E20000` | `rgb(226,0,0)`   | alert red (keep as-is or map to `#C58D07`) |
| `#97000B` | `rgb(151,0,11)`  | dark alert red |
| `#67608A` | `rgb(103,96,138)`| muted slate / panel |
| `#A5A3B5` | `rgb(165,163,181)`| light grey text |
| `#FCFCFC` | `rgb(252,252,252)`| near-white text |

## rofi — `configuration/backup/rofi/themes/amos.7.rasi`

| Variable | RGBA | Hex (ignoring alpha) | Note |
|----------|------|----------------------|------|
| foreground | `rgba(0,44,255,87%)` | `#002CFF` | bright blue |
| red | `rgba(0,50,47,77%)` | `#00322F` | labelled red, actually dark teal |
| selected-urgent-foreground | `rgba(2,20,63,77%)` | `#02143F` | dark blue |
| blue | `rgba(38,139,255,77%)` | `#268BFF` | sky blue |
| urgent-foreground | `rgba(0,129,255,77%)` | `#0081FF` | bright blue |
| lightbg | `rgba(0,139,255,77%)` | `#008BFF` | bright blue |
| background | `rgba(0,0,18,13%)` | `#000012` | near-black transparent bg |
| bordercolor | `rgba(0,0,64,47%)` | `#000040` | dark navy border |
| normal-background | `rgba(0,0,208,0%)` | `#0000D0` | transparent blue |
| lightfg | `rgba(88,104,117,77%)` | `#586875` | muted blue-grey |
| selected-normal-foreground | `rgba(0,77,255,100%)` | `#004DFF` | bright blue |
| selected-normal-background | `rgba(0,0,18,57%)` | `#000012` | dark transparent bg |
| border-color | `rgba(0,0,64,77%)` | `#000040` | dark navy border |
| separatorcolor | `rgba(142,0,242,18%)` | `#8E00F2` | purple accent |
| urgent-background | `rgba(0,0,255,0%)` | `#0000FF` | transparent blue |
| selected-urgent-background | `rgba(255,129,127,47%)` | `#FF817F` | salmon/red alert |
| background-color | `rgba(0,0,18,47%)` | `#000012` | near-black transparent bg |
| active-foreground | `rgba(0,18,247,97%)` | `#0012F7` | bright blue |
| active-background | `rgba(0,0,64,40%)` | `#000040` | dark navy transparent bg |
| selected-active-foreground | `rgba(77,0,255,64%)` | `#4D00FF` | violet |
| selected-active-background | `rgba(0,24,64,27%)` | `#001840` | dark blue transparent bg |

## Notes

* The gkrellm and rofi themes lean heavily into bright blues (`#002CFF`,
  `#0088FF`, `#0000FF`) which are close to but not exactly `#0647C3`.
  Normalising them to the documented palette would make the desktop coherent
  but is optional for backup themes.
* The only non-project alert colours are the reds (`#E20000`, `#FF817F`).
  These can be kept as alert indicators or mapped to `#C58D07` if a strict
  single palette is required.
* Grey foregrounds (`#A5A3B5`, `#67608A`, `#586875`) are useful for dimmed
  text and map well to `#46486D`.
