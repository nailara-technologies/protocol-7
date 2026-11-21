## [:< ##

# desktop ui surfaces : source inventory [ part 1 of desktop-ui-surfaces.md ]

status : done 2026-11-21, read only. everything below comes from source and config, not from
a running desktop. anything not determined is marked 'not found' or 'not checked'. vhost
directories named after real domains and the per-user cfg/backup directory are written as
placeholders, host and user names are left out.

notation : `path:line`, colours as rrggbb hex unless a cairo float triple is named.
'p7 palette' = the five console truecolor roles [ p7_fg_0000 .. 0004 ] from `bin/Protocol-7:884-888`.

## 0. where theme data lives today [ the only shared mechanisms ]

| mechanism | what it holds | readers |
|---|---|---|
| `bin/Protocol-7:879-912` `%colors` | console ansi table : B00 B01 B02 backgrounds, p7_fg_0000..0004, bold, reset ; off when `system.ansi_color` is false | every console writer, ascii-frame, nshell |
| `cfg/ascii-frame:1-40` | role -> %colors name for frame parts | `src/ascii.frame.render.color:10-34` |
| `src/base.gtk.style:8-17` | 8 gtk roles [ background panel text hover focus border muted selection ], css built at `:24-52` ; callers may override roles, font_family, font_size, css | protocol-7-menu, login-screen |
| `cfg/zenki/login-screen/theme.cfg` | login colours \ sizes \ paddings, no leading `#` | `src/login-screen.open_window:11-75` |
| `data/color-themes/p7-blue.yaml:1-16` | 13 roles [ bg bg_mid bg_dark fg fg_bright fg_dim btn btn_top accent accent2 gold outline held ], yaml not p7 config style | `window.profile.color.load` in mpv and impressive only [ `cfg/zenki/mpv/zenka.v7:116`, `cfg/zenki/impressive/subroutines.load-early:309` ] |
| `:root` css variables `--p7-*` | 16 tokens | `data/web-root/vhosts/jobsite.vhost/index.html:15-31` only |

no single token file exists. every other surface hard-codes its values.

## 1. gtk zenki

all gtk zenki force `GDK_BACKEND=x11` [ `src/base.gtk.ensure_display:11`, `src/screen.setup.ensure-display:9`, `src/select.region.open_window:19`, `src/ticker.open_window:8`, `src/dunst.startup:21` ] and `XCURSOR_SIZE=24` [ `src/base.gtk.ensure_display:16`, `src/screen.setup.ensure-display:15`, `src/select.region.open_window:30` ]. translucency is by `get_rgba_visual` + `set_opacity` in every overlay.

| surface | lives in | colours | fonts | sizes \ spacing | interaction | dark \ light |
|---|---|---|---|---|---|---|
| screen-setup [ display layout map ] | zenka `screen-setup` ; `src/screen.setup.*` ; `cfg/zenki/screen-setup/zenka.v7` ; draw `src/screen.setup.handler.draw` | cairo floats, all hard-coded : map fill 0.055,0.185,0.470,0.62 [ ~0e2f78 ] `:25` ; monitor fill 0,0.015,0.075,0.74 `:36,97` ; monitor edge 0.10,0.45,0.95 [ ~1a73f2 ] `:103` ; label 0.60,0.72,0.90 [ ~99b8e6 ] `:116` ; sub-label 0.46,0.58,0.80 `:129` ; title 0.0235,0.2784,0.7647 [ 0647c3 ] `:200` ; window rects in ORANGE 0.7,0.4,0.05 .. 0.9,0.6,0.2 `:159-185` | white-rabbit face via FreeType when it loads [ `<screen.setup.font.face>` `:85` ], else cairo toy font ; sizes 16 `:117`, 13 `:123`, 9 `:186`, 14 `:201` px literal | window 60% of primary monitor, capped 900x620 `src/screen.setup.open_window:35-38` ; saved size overrides `:46-47` ; undecorated, keep above `:71-72` | Esc \ Return \ q only dismiss `src/screen.setup.handler.key_press:12-16` ; mouse : drag monitors \ windows `handler.motion`, right click dismisses `handler.button_press:15` ; NOT keyboard usable for the actual layout work | dark only, hard-coded |
| window-place [ placement overlay ] | zenka `window-place` ; `src/window.place.*` | fill 0,0,0.24,alpha [ 00003d ] `handler.draw:24` ; brackets and text 0.023529,0.278431,0.764706 [ 0647c3 ] `:32,82,97` | white-rabbit via FreeType `src/window.place.open_window:41-50` ; title 40, coords 24, margin 10 as `window.place.font-size.*` `handler.draw:70-72` | corner brackets line width 2 `:33` | arrows move, ctrl+arrows resize, Return commit, Esc cancel `src/window.place.handler.key_press:16-48` ; mouse drag ; fully keyboard usable | dark only |
| select-region [ region \ window picker ] | zenka `select-region` ; `src/select.region.*` | same as window-place plus fill alpha 0.72 \ 0.40 `handler.draw:23,25` | same face loader `src/select.region.open_window:42-51` ; same keys `select.region.font-size.*` 40 \ 24 \ 10 `handler.draw:67-69` | line width 2 `:35` | same key map as window-place `src/select.region.handler.key_press:16-48` + scroll handler ; keyboard usable | dark only |
| ticker | zenka `ticker` ; `src/ticker.*` ; `cfg/zenki/ticker/zenka.v7` | bg `<ticker.bg-color>` from `ticker.cfg.bg_col` or `ticker.default_background` through `ticker.calc-col.RGB` `src/ticker.calc_colors:7` ; fg `ticker.cfg.fg_col` ; outline derived `src/ticker.cfg.font.calc_outline_col:67,104` ; idle fallback greys 0,0,0,0.13 and 0.87 `src/ticker.callback.draw:173-175` | face `ticker.font.path/name` = `data/ttf/console/white-rabbit.flipped` `cfg/zenki/ticker/zenka.v7:30-31` [ init default DroidSans-Bold `src/ticker.init_code:24-25` ] ; size NOT configured : grown until it fits the window height `src/ticker.callback.draw:105-120` ; `ticker.font.size_percent` 100 `src/ticker.init_code:26` is a stub | window height drives font size ; speed 8.47 `zenka.v7:46` ; `ticker.use_transparency=1` `:43` | none : `set_accept_focus 0`, `set_can_focus 0` `src/ticker.open_window:88-90` ; input shape kept in sync `:514-564` | colours follow config, no dark \ light logic |
| protocol-7-menu [ logo + popup menu ] | zenka `protocol-7-menu` ; `src/protocol-7-menu.graphical-*` ; `cfg/zenki/protocol-7-menu/zenka.v7:12-15` | through `base.gtk.style` defaults `src/protocol-7-menu.graphical-window-init:60-65` + extra css `menu { font-size: x-large; }`, transparent window \ box \ grid ; opacity min \ max \ click 0.37 \ 0.67 \ 0.77 `zenka.v7:12-14` [ code defaults 0.47 \ 0.70 `graphical-window-init:229-230` differ ] | `White Rabbit` from `base.gtk.style:25`, menu `x-large` | logo width = screen width x `scale_factor` 0.043 `graphical-window-init:11,74` ; margin 20 top right `:221` ; opacity follows pointer distance, 50 ms literal timer `:335`, distance 2000 `zenka.v7:15` | mouse : press on logo opens the menu `:87,126,209` ; menu itself is a `Gtk3::Menu` with gtk default arrows \ Enter ; a key that OPENS it : not found | dark only |
| login-screen \ lock | zenka `login-screen` ; `src/login-screen.*` ; `cfg/zenki/login-screen/theme.cfg` | background 000013, panel 000042, text 0055cc, muted 003a8c, accent 0055cc, entry 000042, error 4427ac `theme.cfg` ; panel_alpha 0.92 ; code fallbacks `src/login-screen.open_window:17-29` ; brightness 1.0 | `login-screen.theme.font_family=White Rabbit` ; font 32 [ clamp 16..96 `open_window:35-38` ], title 42, status 22 | content_width 620, padding 42, panel_padding 36 `theme.cfg` ; entry padding 12px, button padding 14px `open_window:72-73` ; window = full screen `:90` | user entry activate moves focus to password `:168` ; key \ motion \ button events watched `:173-175` ; tab order = gtk default ; fade timings in theme.cfg | dark only ; `brightness` key scales |
| amos-term [ gtk terminal view \ xterm launcher ] | zenka `amos-term` ; `src/amos-term.*` | draw : background 0,0,0.024 [ 000006 ] x alpha `src/amos-term.render.draw_buffer:17` ; cell colours computed, alpha 0.3 `:39` ; cursor 0.27,0.15,0.67 [ ~4427ac ] `:74` ; xterm resources : Background 010015, Foreground 0647c3, cursor 4427ac, pointer 7700ff `src/amos-term.init_code:14-16` | xterm `faceName WhiteRabbit`, `faceSize 13` `:11,17` | geometry `80x25` `:11` ; gtk window from `display.geometry`, default 640x480 `src/amos-term.window-open:45-49` | arrows \ PgUp \ PgDn navigate, Esc, F11, ctrl+f `src/amos-term.handler.key_press:24-57` ; keyboard usable | dark only |
| reenc-msg | `src/reenc-msg.window.util.cairo_draw` | text 0.2,0,0.97 [ 3300f7 ] `:23`, shadow black `:16` | cairo toy `sans` bold 23 `:14-15` | none | none | dark text on transparent, hard-coded |
| osd-logo | `src/osd-logo.open_window` | fallback when no alpha : `*{background-color:#ffffff}` `:37` | not found | height from `osd-logo.cfg.height` percent of screen `:53-63` | none | WHITE background fallback |
| power-x11 | `src/power-x11.open_window` | fallback `*{background-color:#424242}` `:44` ; pango markup `size="large"` `:58,70` | pango default | window default size 0x0 `:14` | not checked | GREY fallback |
| start-anim | `src/start-anim.*` | not found | not found | `start-anim.width \ height` `src/start-anim.handler.draw:23,64` | none | fade in \ out by opacity |
| impressive | `src/impressive.*` | `$bg_color` black on fullscreen, else config `src/impressive.open_window:36` | not found | geometry from `x11.geometry` `:96` | not checked | colour profile via `window.profile.color` |
| web-browser | zenka `web-browser` ; `src/web-browser.*` ; `cfg/zenki/web-browser/zenka.v7` | base background `web-browser.bg_color` default 000013 `src/web-browser.init_view:7,75-77`, same in the blank page `:79` | page content decides | `cursor_size` 24 `zenka.v7:64` ; zoom `zoom_level \ zoom_factor \ zoom_text_only` `src/web-browser.init_code:51-53`, applied `src/web-browser.init_view:206-209` | key handling : not checked | dark base only ; page decides the rest |
| dunst [ notifications, external program configured by zenka ] | zenka `dunst` ; `src/dunst.startup` ; `cfg/zenki/dunst/dunstrc` | low `12101a \ 5850a0 \ 3a2f52` `:42-44` ; normal `181428 \ 8070e0 \ 5a4a86` `:48-50` ; critical `241030 \ c85898 \ a84a6a` `:54-56` [ bg fg frame ] | `White Rabbit Regular 17` `:27` made visible by a fontconfig snippet `src/dunst.startup:29-35` | frame 2 `:17`, padding 8, horizontal 14, text-icon 8 `:28-30`, icons 48..128 `:31-32`, width 300..777 `:15`, offset 10,50 `:14` | notifications : not checked | dark only, own purple-grey family |
| notify-osd | `src/notify-osd.startup` | not found | not found | not found | not found | not found |
| remote-cam \ storchencam [ sdl ] | `src/remote-cam.*`, `src/storchencam.*` | not checked | sdl ttf size 33 `src/remote-cam.init_code:23` ; 11 `cfg/zenki/storchencam/zenka.v7:28` | font based offsets `src/remote-cam.sdl_loop:166-167` | not checked | not checked |
| x11 helpers [ X-11, X-11-pointer, compton, select-region cursors ] | `src/X-11.*` ; `src/X-11-pointer.*` | none visual ; compton opacity rule 76 for XTerm `src/compton.startup:72` | none | xrandr custom args `X-11.custom_xrandr.*` `cfg/zenki/X-11/zenka.v7:30-32` [ commented examples ] ; host overlay for `X-11.mode` `:118` | cursor blank \ restore commands | none |

## 2. web pages served by httpd \ web

| surface | lives in | colours | fonts | sizes | interaction | dark \ light |
|---|---|---|---|---|---|---|
| jobsite page | `data/web-root/vhosts/jobsite.vhost/index.html` ; zenki `httpd`, `web`, `jobsite` | the ONLY page with css variables : bg 00040c, bg-mid 031542, bg-dark 12061b, fg 0028c0, fg-bright 5a70ff, fg-dim 2a3a9a, btn 001a88, btn-top 000ea0, accent 4427ac, gold c58d07, outline 000208, held 05082a, text-soft 6a8cff, text-mid 4a68c0, text-dim 344080 `:15-31` ; radial gradients of 4427ac \ 003aff `:35-38` ; status colours inline : 4ac0a0 teal, 7aabcc, d4a830, c05050 | `@font-face White Rabbit` `:9`, body `White Rabbit, Courier New, Courier, monospace` `:34` ; rem sizes e.g. h1 1.25rem `:47`, subtitle 0.72rem `:48`, hint 0.68rem `:77` | rem based, no fixed px layout checked | forms \ buttons, auth box `:76` ; keyboard use : not checked | dark ; `@media print` `:663` |
| jobsite dossier \ report | `data/web-root/shared/templates/jobsite-report/dossier.html`, `report.html` | dossier : 5e35b1 purple, white, 666, 8e3b5e, 7f87b0 ; report : fafafa, f0f0f0, ccc, a51d2d, 888, 555 | dossier `Segoe UI, Arial, Helvetica` and `DejaVu Sans Mono` ; report `Arial, Helvetica` | not checked | static | LIGHT by default ; dossier has `prefers-color-scheme: dark` `dossier.html:95` and print `:115` ; report print `report.html:18` |
| weather widget + templates | `src/weather.widget.util.get_weather_widget_css` ; `data/web-root/shared/templates/weather/*` | widget css 64 colour uses : 22d3ee cyan, a78bfa violet, 8b5cf6, 06b6d4, 001433, 000a1f ; templates bcd \ 334 \ cde \ 445 greys `body.html` | widget `Courier New, monospace`, 12px \ 14px ; templates `sans-serif` | px | none | dark teal \ violet widget, grey templates |
| httpd built-in pages | `src/httpd.path.create_default_index:26` [ black body ] ; `src/httpd.diagnostic.report` [ f2f2f2, ddd, ccc, Arial ] ; `src/httpd.handler.template_reply` [ c58d07 ] ; `src/proxy.handler.site_yaml_reply` [ 333366, 9999cc, 6699ff, 666699, c0c0c0, monospace, em sizes ] | see left | Arial \ monospace | em | none | mixed : report light, index black |
| ascii-frame html | `src/ascii.frame.render.html` | e0e0e0, c5c5ff, 8c7a3a, 4b3b8c, 4427ac, 06c3c3 | monospace | not found | none | dark |
| shared static \ component pages | `data/web-root/shared/static/loading_animation.html`, `failed_to_load.html`, `templates/web-browser/loading.html`, `templates/image2html/*`, `templates/pdf2html/*`, `templates/components/spectrum.css` | loading \ stub pages `#aaa` on default ; failed_to_load 000050 ; spectrum.css 80c0ff \ 4080ff \ e0b060 \ e08080 \ 90b0e0 \ 9060ff | `sans-serif` | not found | none | mostly unset background |
| visualization vhosts | `data/web-root/vhosts/<iris \ viz \ visual \ space vhosts>/*` | 0a0a0f, 0a0a14, 03030a, 06060e, 08041a, 020208, 000007, 0c0518 backgrounds ; accents ffe5a0, 9b7fd6, 6fd6ff, 60d0ff, a0c0ff, 8090a0, 8c7dff, 4dd8ff, ffd700, 9b59b6 | `monospace`, `Courier New`, `JetBrains Mono`, `IBM Plex Mono`, `var(--font)` | not checked | overlay-search page, tweaks panel : not checked | dark |
| skins [ web skin system ] | `src/web.skin_resolver` ; `src/web.render_skinned_content` ; `data/examples/skins/{default,dark,mobile}/` | default : ffffff, ecf0f1, e74c3c, 3498db, 333, 2c3e50 ; dark : 121212, 1a1a1a, 2a2a2a, e0e0e0, ff6b6b, 0288d1 | default `-apple-system, Segoe UI, Roboto, sans-serif` | not checked | skin chosen per vhost \ user pref cascade | default skin LIGHT, dark skin separate ; neither uses violet \ blue |

no web page reads a shared token file at request time ; `data/color-themes/p7-blue.yaml` is not served.

## 3. console \ nshell \ amos-term \ ascii-frame

| surface | lives in | colours | fonts | sizes | interaction | dark \ light |
|---|---|---|---|---|---|---|
| console log \ banner | `bin/Protocol-7:879-912` ; `src/base.log*` | p7 palette : p7_fg_0000 `\e[38;2;68;39;172m` 4427ac purple ; 0001 `38;46;153` 262e99 blue ; 0002 `170;94;2` aa5e02 amber ; 0003 `9;170;94` 09aa5e green ; 0004 `6;71;195` 0647c3 true blue ; backgrounds B00 `48;2;0;0;17` 000011, B01 `9;5;24` 090518, B02 `9;5;42` 09052a | terminal's | n/a | n/a | one palette for dark terminals ; no light ; ansi off switch `system.ansi_color` `:879` |
| nshell [ zenka \ `bin/nshell` ] | `src/nshell.*` ; `bin/nshell` | echo and editor in p7_fg_0004, cursor underline in p7_fg_0003 `src/nshell.editor.process:225-304` ; start colour `src/nshell.init_code:107` ; custom cursor, system cursor hidden `:110` | terminal's | terminal size via `nshell.handler.term_resize` | line editor : arrows, history up \ down, page up, ctrl+o display cycle, F1 redo, search `src/nshell.editor.process:70-79`, `src/nshell.history.*`, `src/nshell.display.cycle` ; fully keyboard | dark terminal assumed |
| ascii-frame | `src/ascii.frame.*` ; `cfg/ascii-frame:1-40` | fill single p7_fg_0000, double \ dot p7_fg_0001, equals p7_fg_0002 ; bracket char 0000, label 0004 ; corner soft 0001, anchor 0000 bold ; content value 0004, label 0001, progress 0003 | terminal's | box drawing by character class | none | dark terminal ; plain fallback `src/ascii.frame.render.color:39` |
| `bin/ncode`, `bin/dev/apply-colors`, `bin/color` | `bin/ncode:44-65` [ own copy of the palette + T 0 1 2 3 g o aliases ], `bin/dev/apply-colors:52`, `bin/color` | same truecolor values, duplicated in each tool | terminal's | n/a | n/a | n/a |
| xterm launch [ amos-term ] | `src/amos-term.init_code:9-17`, override `src/amos-term.term-params-update` | see amos-term row | WhiteRabbit 13 | 80x25 | cursor blink on 1274 \ off 769 ms `:10-11` literal | dark |
| terminal profile backups | `cfg/backup/terminals/colors.asc`, `colors.desc` [ LS_COLORS via dircolors ] ; `cfg/backup/themes/highlight/amos-7.blue.theme` [ editor highlight : default 0647c3, canvas 09052a, number \ string 47c306, escape c58d07, comment 4427ac ] | see left | not found | n/a | n/a | dark |

## 4. desktop shell : tint2, openbox, jgmenu, rofi, gtk themes, gkrellm

tint2 is started by zenka `tint2` [ `cfg/zenki/tint2/start.cfg`, exec external ], jgmenu by zenka `jgmenu` [ `--hide-on-startup` ], openbox by zenka `openbox` [ `src/openbox.start_wm`, `cfg/zenki/openbox/*.xml` ]. their rc files are BACKUPS copied by hand, nothing generates them.

| surface | lives in | colours | fonts | sizes \ spacing | interaction | dark \ light |
|---|---|---|---|---|---|---|
| tint2 panel | three copies : `cfg/backup/tint2/tint2rc`, `cfg/applications/tint2/backup/tint2rc` [ differs : `panel_items = PLSTB`, hex case ], `data/configs/desktop/photonic/.config/tint2/tint2rc` ; alternates `cfg/backup/tint2/horizontal-light-transparent.tint2rc`, `vertical-dark-transparent.tint2rc` | backgrounds [ colour alpha% ] : panel 000000 60 `:14` ; taskbar 00003a 22 `:27`, hover 00007a 33 ; task 0a1271 69 `:40`, hover 0000cf 48 ; active 000d9a 100 `:53`, hover 0044ff 100, pressed 0095ff 55 ; borders 0000ff, 0042ff, 0009ff, 0021ff, 006eff, 00fff4 ; fonts : task 0044aa 92 `:136` ; clock 00ccee `:178` ; battery 00ddff `:197` ; taskbar name 38564b `:118`, active 65e7ff `:119` ; tooltip font 18a888 `:217` ; tooltip bg ffffaa on black border `:66-72` | `White Rabbit 13` task `:132`, taskbar name 13 `:117`, clock 13 \ 12 `:174,177` | panel 100% x 27 bottom `:77,84` ; task max 123x13 `:130`, padding 2 2 4 `:131` ; systray icon 24 `:152` ; launcher icon 24 `:162` ; thumbnail 242 `:135` ; rounded 7 \ 9 \ 1 ; icon asb hover 98 5 10 `:97` ; icons = THIRD PARTY pngs from icon themes | mouse : left toggle iconify, right close, scroll toggle \ iconify `:141-145` ; no keyboard path | dark translucent ; a light variant file exists, use not found |
| openbox window theme | `data/configs/themes/wm/openbox/amos-base/openbox-3/themerc` [ name `openbox.amos-base` ] | title active gradient 000017 -> 000023 ; inactive 00000a -> 000013 ; label text 0092f9 ; menu bg 000000, text 0092f9, disabled 242464 ; menu title 242442 -> 181824, text 01426a ; menu active 000028 -> 000018 with GREEN text 00e840 ; handles \ grips 242442 ; border 000028 | theme : `sans` bold pixelsize 7 windows, 11 menu items, 8 menu title | border 1, padding 0, handle 0 | n/a | dark |
| openbox config | `cfg/backup/<user-dir>/openbox/rc.xml` ; `data/configs/desktop/photonic/.config/openbox/rc.xml` ; zenka templates `cfg/zenki/openbox/openbox.minimal.xml` | n/a | rc `<font>` : `sans` 8 bold active \ inactive window `:60-76`, `FreeSans Semi-Bold` 11 menu header \ item `:78-91`, on screen display 11 `:105-110` [ the rc fonts and the themerc pixelsizes disagree ] | margins top 1 bottom 2 left 2 right 1 `:160-164` ; 63 keybinds [ alt+arrows, super+F1.. ] `:187-250`, drag threshold 1 `:515`, double click 500 ms `:517` | keyboard : many keybinds | n/a |
| jgmenu | `cfg/applications/jgmenu/backup/jgmenurc:46-53` ; identical copy in `data/configs/desktop/photonic/.config/jgmenu/jgmenurc` | menu bg 00000c 69, fg 00aaee 20, border 0000ff 8 ; normal bg 000033 13, fg 0077cc 77 ; selected bg 000042 55, fg 00ccff 94, border 0000ff 42 | not set in the rc : jgmenu default | not set : jgmenu default | menu keyboard : jgmenu default ; not checked | dark |
| rofi | `cfg/backup/rofi/themes/amos.7.rasi` ; `data/configs/desktop/photonic/.config/rofi/photonic.rasi` | rgba in percent : background 0,0,18 13% ; foreground 0,44,255 87% ; selected 0,77,255 100% ; border 0,0,64 77% ; separator 142,0,242 18% ; blue 38,139,255 ; urgent selected 255,129,127 pink ; red 0,50,47 | not found | spacing 2 `:23` | rofi default | dark |
| gtk 3 theme backup | `cfg/backup/gtk/gtk-3.0/gtk.css` [ 3996 lines, a generated dark theme ] | fg \ text eff0f1, bg \ base 050e15, selected bg 75aae0, warning f67400 | `font-weight` only | n/a | n/a | dark ; blue is lighter and greyer than the p7 blues |
| gtk 2 theme backup | `cfg/backup/gtk/.gtkrc-2.0:4-8`, `cfg/backup/gtk/gtk-2.0/*` | dadfe1 \ 050e15 \ 2d79c6 \ 081722 | `White Rabbit 13` `:6` | n/a | n/a | dark |
| gkrellm themes | `cfg/applications/gkrellm2/backup/themes/invisible-{black,blue,white}/gkrellmrc`, `data/configs/themes/wm/gkrellm2/*` | png based, not inspected | not checked | not checked | n/a | one theme per tone |
| protocol-7 icon logo | `data/gfx`, `protocol-7-menu.image_path` | image | n/a | width = 4.3% of screen width | n/a | n/a |

## 5. mpv

zenka `mpv` : `cfg/zenki/mpv/zenka.v7`, `lua/p7-osc.lua` [ 3522 lines, upstream osc modified ], `lua/p7-idle-logo.lua` [ 293 lines ]. the only surface that reads the theme file [ `[window.profile.color.load:'p7-blue']` `zenka.v7:116` ].

| aspect | value | source |
|---|---|---|
| osc colours | all from p7-blue : time \ title 002fdd and dim, timepos 003aff, buttons 001ebb, small buttons L \ R c58d07 gold, top buttons 000ea0, held 05082a, outline 000208 | `zenka.v7:128-135` |
| native osd | `osd_color` 002fdd, `osd_back_color` 000510 | `zenka.v7:138-139` |
| idle logo text | `001e5b` outline `000007` shadow `070005` | `zenka.v7:119-121` ; lua defaults 47c306 green, 000000, 12061b `p7-idle-logo.lua:15-19` |
| osc defaults when no option is passed | white 'ffffff' for every element, held 999999, background 000000 | `p7-osc.lua:69-79` |
| fonts | osd font : mpv default, not set ; icon font `mpv-osd-symbols` ; idle text `sans-serif` 28 | `p7-osc.lua:169`, `p7-idle-logo.lua:14,20` |
| sizes | osc scale windowed \ fullscreen 1 `:15-16`, `vidscale auto` `:17`, hard-coded `\fs` 14 .. 50 in the osc styles `:273-290`, idle logo scale 0.25 | |
| interaction | upstream osc bindings, mouse button commands `:88-130`, keyboard : mpv defaults | |
| dark \ light | dark ; blue translucent role map is complete here | |

## 6. colour values in use [ grouped by closeness ]

group A : the p7 console palette and its near copies

| value | users |
|---|---|
| 4427ac purple [ 68,39,172 ] | p7_fg_0000 `bin/Protocol-7:884` ; amos-term cursor `src/amos-term.init_code:16` and cairo 0.27,0.15,0.67 `draw_buffer:74` ; login error `theme.cfg` ; ascii html ; p7-blue accent ; jobsite `--p7-accent` ; editor theme comments ; `bin/ncode:49` |
| near : 5e35b1 [ dossier ], 8b5cf6 \ a78bfa [ weather widget ], 9b7fd6 \ 8c7dff \ 6f5fff [ vhosts ], 7700ff [ xterm pointer ], 9060ff [ spectrum.css ], 8a2be2 \ 9b59b6 [ vhosts ], 5b4a7a \ bb8fce | |
| 0647c3 true blue [ 6,71,195 ] | p7_fg_0004 ; xterm foreground ; select-region \ window-place brackets and text as 0.023529,0.278431,0.764706 ; screen-setup title ; editor default ; nshell echo |
| near : 0055cc [ base.gtk.style text, login text ], 0044aa [ tint2 task font ], 0044ff [ tint2 active hover ], 003aff [ p7-blue fg_bright ], 002fdd [ p7-blue fg, mpv osd ], 0028c0 [ jobsite fg ], 001ac4 \ 001abb \ 001ebb [ buttons ] | |
| 262e99 blue [ 38,46,153 ] | p7_fg_0001 ; near : 2a3a9a [ jobsite fg-dim ], 5050a0 \ 3030a0 [ vhosts ] |
| aa5e02 amber | p7_fg_0002 ; near : c58d07 gold [ p7-blue gold, mpv small buttons, jobsite gold, editor escape, httpd template_reply ], d4a830, e0b060, f39c12, ff730d \ cairo orange rects in screen-setup |
| 09aa5e green | p7_fg_0003 ; near : 47c306 [ editor, mpv idle default ], 00e840 [ openbox menu active text ], 4ac0a0 [ jobsite status ], 18a888 [ tint2 tooltip font ], 00ff88 [ guide page ] |

group B : near black blue backgrounds

| value | users |
|---|---|
| 000013 | `src/base.gtk.style:9`, login background, `web-browser.bg_color` default, openbox inactive title end |
| 000011 | console B00 background |
| 000017 \ 000023 \ 00000a | openbox title gradients |
| 000006 | amos-term draw background |
| 000007 \ 000208 \ 000510 \ 00040c \ 00000c | ring-trie vhost, p7-blue outline, p7-blue bg \ mpv osd back, jobsite bg, jgmenu menu bg |
| 010015 \ 0a0a0f \ 0a0a14 \ 03030a \ 06060e \ 08041a \ 0c0518 | xterm background and the dark vhost pages |
| 090518 \ 09052a \ 05082a \ 12061b \ 12101a \ 181428 \ 241030 | console B01 \ B02 and editor canvas, p7-blue held, shadow, dunst backgrounds |
| 000042 \ 000028 \ 00003a \ 000033 \ 00003d [ cairo 0,0,0.24 ] | gtk panel, openbox menu active \ border, tint2 taskbar, jgmenu normal bg, select \ place fill |
| 242442 \ 242464 \ 181824 | openbox menu title \ handles \ disabled |

group C : light and neutral values [ outliers of the violet \ blue look ]

| value | users |
|---|---|
| ffffff \ fff | osd-logo fallback `:37`, skins default, dossier, mpv osc defaults |
| 424242 | power-x11 fallback `:44` |
| ffffaa + 000000 | tint2 tooltip |
| eff0f1 \ dadfe1 \ 75aae0 \ 050e15 | gtk 3 \ 2 theme backups |
| fafafa \ f0f0f0 \ ccc \ aaa \ 888 \ 555 \ 333 \ 666 \ e0e0e0 \ f2f2f2 \ ddd | report, loading pages, diagnostic report, skins |
| e74c3c \ 3498db \ 2c3e50 \ ecf0f1 \ ff6b6b \ 0288d1 | example skins |
| a51d2d \ c05050 | report \ jobsite error reds |

group D : cairo float triples that map to hex only approximately

| triple | hex | users |
|---|---|---|
| 0.0235,0.2784,0.7647 | 0647c3 | screen-setup, select-region, window-place |
| 0.055,0.185,0.470 | 0e2f78 | screen-setup map |
| 0.10,0.45,0.95 | 1a73f2 | screen-setup monitor edge |
| 0.60,0.72,0.90 \ 0.46,0.58,0.80 | 99b8e6 \ 7594cc | screen-setup labels |
| 0,0,0.24 | 00003d | select-region, window-place fill |
| 0.2,0,0.97 | 3300f7 | reenc-msg |
| 0.7,0.4,0.05 .. 0.9,0.6,0.2 | orange family | screen-setup window rects |

## 7. font settings in use

| font | users | where set |
|---|---|---|
| white-rabbit [ `data/ttf/console/white-rabbit.flipped.ttf` ] | gtk css default `White Rabbit` `src/base.gtk.style:25` ; login `theme.cfg` ; cairo overlays by FreeType path [ screen-setup, window-place, select-region ] ; ticker `cfg/zenki/ticker/zenka.v7:30-31` ; xterm `WhiteRabbit` `src/amos-term.init_code:17` ; tint2 `White Rabbit 13 \ 12` ; gtk 2 `White Rabbit 13` ; dunst `White Rabbit Regular 17` ; jobsite page `@font-face` | four different spellings : `White Rabbit`, `WhiteRabbit`, `white-rabbit.flipped`, `White Rabbit Regular` ; each surface finds the file its own way [ fontconfig snippet for dunst, FreeType path for cairo, system install for tint2 \ xterm \ gtk ] |
| sans \ sans-serif | openbox windows 8 bold, themerc pixelsize 7 \ 8 \ 11 ; reenc-msg 23 bold ; mpv idle text 28 ; weather templates ; shared static pages | rc \ cairo \ lua literals |
| FreeSans Semi-Bold 11 | openbox menus | `rc.xml:79,88` |
| DroidSans-Bold | ticker init default only | `src/ticker.init_code:25` |
| monospace \ Courier New \ JetBrains Mono \ IBM Plex Mono | web pages, weather widget | css |
| Arial \ Helvetica \ Segoe UI \ Roboto | httpd diagnostic report, dossier, report, default skin | css |
| mpv-osd-symbols | mpv osc icons | `p7-osc.lua:169` |
| sdl ttf | remote-cam 33, storchencam 11 | zenka config |
| jgmenu, rofi | font not set in the config : default | not found |

## 8. outliers [ deviate from dark violet \ blue ]

| surface | deviation | reason |
|---|---|---|
| tint2 application icons [ launcher, task bar, systray ] | third party pngs from icon themes, any colour | not rendered by the project ; colours of the rc cannot fix them ; `launcher_icon_theme_override 0`, `systray_icon_size 24` |
| tint2 tooltip, taskbar name, tooltip font | ffffaa yellow with black border ; 38564b grey green ; 18a888 teal green | tint2 stock look, never retuned `tint2rc:66-72,118,217` |
| openbox menu active text | 00e840 green | themerc stock `menu.items.active.text.color` |
| osd-logo no-alpha fallback | ffffff white | only when transparency is off `src/osd-logo.open_window:37` ; shows a bright flash on a dark desktop |
| power-x11 no-alpha fallback | 424242 grey | same pattern `src/power-x11.open_window:44` |
| screen-setup window rects | orange | deliberate highlight of windows against the blue monitors `handler.draw:159-185` |
| dunst | purple grey 12101a .. 241030, pink critical c85898 | own palette [ `cfg/zenki/dunst/dunstrc:42-56` ] close to the family but not the same hexes |
| mpv osc and idle logo defaults | white elements, 47c306 green idle text | upstream and lua defaults ; the cfg overrides them, an unset option brings them back |
| gtk 3 and 2 theme backups | eff0f1 text, 75aae0 selection, 050e15 base | generated dark theme [ breeze like ], lighter and greyer blue |
| jobsite dossier and report, default skin, httpd diagnostic report, loading pages, weather templates | light backgrounds, Arial \ sans-serif | printable \ legacy pages ; only dossier has a dark media query `dossier.html:95` |
| weather widget | cyan 22d3ee, violet a78bfa | utility palette from a css kit, `src/weather.widget.util.get_weather_widget_css` |
| visualization vhosts | gold ffd700, ffe5a0, magenta guide page ff00ff \ 00ffff \ a0ff00 | art pages, high chroma on purpose |
| reenc-msg | 3300f7 on black shadow, `sans` 23 | own style, not via any shared table |

## 9. dpi consumers [ input for stage 2 ]

every place a font size, dpi or scale is read or set. no consumer of `Xft.dpi`, `xrdb`, `GDK_SCALE`, `GDK_DPI_SCALE`, `QT_FONT_DPI` or `QT_SCALE_FACTOR` exists in `src`, `bin/Protocol-7` or the zenka configs : not found. no code reads xrandr physical size \ edid for a dpi : not found.

| consumer | what is read \ set | where | unit |
|---|---|---|---|
| gtk css helper | `font_size` option -> `font-size: Npx` ; default family White Rabbit | `src/base.gtk.style:30-35` | px, no scale |
| protocol-7-menu | `scale_factor` 0.043 x screen width = logo width ; menu `font-size: x-large` | `src/protocol-7-menu.graphical-window-init:11,62,74` ; `graphical-startup-init:12,60` ; `cfg.scale_factor` | fraction of screen pixels |
| login-screen | `font_size` 32 [ 16..96 ], `title_size` 42, `status_size` 22, `padding` 42, `panel_padding` 36, `content_width` 620, entry \ button padding px | `cfg/zenki/login-screen/theme.cfg` ; `src/login-screen.open_window:35-50,72-73,118` | px |
| screen-setup | window 60% of monitor capped 900x620 ; fonts 16 \ 13 \ 9 \ 14 literal | `src/screen.setup.open_window:35-38` ; `handler.draw:117,123,186,201` | px |
| select-region \ window-place | `font-size.title \ coords \ margin` 40 \ 24 \ 10 | `handler.draw:67-72` \ `:70-72` | px |
| ticker | font grown until it fits the window height ; `font.size_percent` 100 stub | `src/ticker.callback.draw:105-120` ; `src/ticker.init_code:26` | px derived |
| amos-term | xterm `faceSize 13`, `geometry 80x25` ; gtk window default 640x480 | `src/amos-term.init_code:11` ; `src/amos-term.window-open:45-49` | pt \ chars \ px |
| reenc-msg | `set_font_size(23)` | `src/reenc-msg.window.util.cairo_draw:15` | px |
| osd-logo | `osd-logo.cfg.height` percent of screen | `src/osd-logo.open_window:53-63` | percent |
| start-anim | `start-anim.width \ height` | `src/start-anim.handler.draw:23,64` | px |
| cursor | `XCURSOR_SIZE=24` fixed in 4 zenki, configurable only in web-browser `cfg.cursor_size` | `src/base.gtk.ensure_display:16`, `src/screen.setup.ensure-display:15`, `src/select.region.open_window:30`, `src/web-browser.init_code:22` + `cfg/zenki/web-browser/zenka.v7:64` | px |
| web-browser | `zoom_level`, `zoom_factor`, `zoom_text_only` | `src/web-browser.init_code:51-53` ; `src/web-browser.init_view:206-209` | factor |
| dunst | `font White Rabbit Regular 17`, padding 8 \ 14 \ 8, icons 48..128, width 300..777, frame 2 | `cfg/zenki/dunst/dunstrc:14-32` | pt \ px |
| tint2 | fonts 13 \ 12, panel height 27, icons 24 \ 24, task 123x13, thumbnail 242, padding literals | `cfg/backup/tint2/tint2rc:77,117,130-135,152,162,174-177` [ three copies ] | pt \ px |
| openbox | rc fonts 8 \ 11 pt, themerc pixelsize 7 \ 8 \ 11, margins 1 2 2 1 | `rc.xml:60-110,160-164` ; `themerc` | pt and px mixed |
| gtk 2 | `font_name="White Rabbit 13"` | `cfg/backup/gtk/.gtkrc-2.0:6` | pt |
| xterm via amos-term | `*xterm*faceSize:13` | `src/amos-term.init_code:11` | pt |
| mpv | osc `scalewindowed \ scalefullscreen` 1, `vidscale auto`, `\fs` literals, idle text 28, idle logo scale 0.25 ; `osd-font-size` not set | `cfg/zenki/mpv/lua/p7-osc.lua:15-17,273-290` ; `p7-idle-logo.lua:12-14` | px, factor |
| sdl cams | font 33 \ 11 | `src/remote-cam.init_code:23` ; `cfg/zenki/storchencam/zenka.v7:28` | px |
| web pages | jobsite page in rem ; weather widget px 12 \ 14 ; others px \ em | see section 2 | rem, px, em |
| jgmenu, rofi | size \ font : default, not set in the rc | `jgmenurc`, `amos.7.rasi` | not found |
| x11 resolution | `X-11.custom_xrandr.*`, host `X-11.mode` | `cfg/zenki/X-11/zenka.v7:30-32,118` | mode, not dpi |
| screen enumeration \ physical size | `src/screen.setup.enumerate-monitors`, `src/base.gtk.list_monitors` : mm size read : not found | | |

## summary : the five largest inconsistencies

1. there is no token source : the theme file `data/color-themes/p7-blue.yaml` feeds only mpv and impressive, the jobsite page has its own css variables copy, everything else hard-codes the same 6 or 7 blues in three notations [ hex, cairo floats, ansi truecolor ] ; the near-duplicate blue text values alone number more than ten [ 0044aa 0055cc 0647c3 002fdd 0028c0 0092f9 ].
2. one font, four spellings, four loaders : white rabbit is found by fontconfig snippet [ dunst ], FreeType file path [ cairo overlays, ticker ], system install [ tint2, xterm, gtk 2 ] and css `@font-face` [ jobsite page ] ; web pages otherwise use monospace \ arial \ segoe ui.
3. font sizes are scattered literals in four units [ px, pt, pixelsize, rem \ em ] with no dpi or scale input anywhere : no Xft.dpi, GDK or QT scale is read or set, the cursor is forced to 24 px, and menu and logo size follow screen pixels not physical size.
4. the generated look is not generated : tint2rc exists in three diverging copies [ `PLSTB` vs `STB`, hex case ], openbox rc fonts [ pt ] and themerc fonts [ pixelsize ] disagree, jgmenu and rofi set no font, and tint2 icons are third party pngs.
5. keyboard and light handling are uneven : only window-place, select-region, amos-term, nshell and openbox are keyboard driven, screen-setup only dismisses by key, tint2 and the menu have no key path found ; light fallbacks leak through osd-logo white, power-x11 grey, tint2 tooltip yellow and the light web pages, and only the dossier reacts to `prefers-color-scheme`.

#,,..,,.,,,.,,...,,.,,..,,...,...,,..,,,,,,.,,..,,...,...,.,.,.,,,.,,,..,,,,.,
#U4TZJ64X275DUEDKPE3AYSKMJ6I6JKCWNXAIONWEEKMJ2C54ZH2K5C4YDEHCZVZ5CG2YEO2U4FJYC
#\\\|KOWU7L7FASCXE6AFBXRPMF3PAWV3B7IMQRJJD45BQGJMYOHBUD3 \ / AMOS7 \ YOURUM ::
#\[7]YXU2GA3XIKPAZIPU2NPGNXTONDOXKCWQXPSFLMZULUASTJ3I3GBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
