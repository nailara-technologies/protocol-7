# desktop ui surfaces : inventory, one look, an icon set, comfortable dpi

status : brief, not dispatched [ owner 2026-11-21 ]. driven by native linux desktops
[ the home server and the laptops ] : real everyday use shows where the surfaces
differ. the surfaces are also a unifying factor -- one look across gtk, web, console.

## problem

- the ui surfaces [ gtk zenki, web pages, console \ nshell, ascii-frame, tint2 \ openbox ]
  grew separately : colours, spacing, fonts and interaction differ
- the tint2 application icons [ menu, task bar, systray ] are outliers : finetuning
  colours cannot fix them, they need re-rendering into the blue translucent range
- a new desktop is first stalled by too small fonts : there is no comfortable, in-style
  way to set the dpi, and every toolkit reads it from somewhere else

## part 1 : inventory [ low intensity, a sonnet or kimi k2.8 task ]

per surface : where it lives [ zenka, files ], which colours \ fonts \ sizes it uses and
where they come from [ hard-coded, config, theme file ], interaction patterns [ keys,
mouse, focus ], dark \ light handling. output : one table in this brief's folder, no
code changes.

## part 2 : one look

- theme tokens in one p7 config file [ colours, translucency, font families, sizes,
  spacing ] that every surface reads -- dark violet \ blue by default, print light
- each surface maps the tokens through a small adapter [ gtk css, web css variables,
  console palette, tint2rc \ openbox theme generated from the tokens ]
- console colour rules stay as they are [ background on the element only ]
- no fast \ high-contrast cycling animations by default ; anything animated has a slow
  default rate

## part 3 : icon set through the povray zenka

- the povray zenka already renders audio icons [ src/povray.*, data/povray-templates ]
- one icon template : shared material [ blue, translucent ], light and camera ; one small
  input per icon [ shape \ symbol ] ; rendered for every size tint2 needs [ systray 24,
  task bar and menu sizes from the tint2rc ] plus 2x for high dpi
- the icon theme is generated into one directory and referenced by tint2 \ the menu ;
  re-rendering after a token change is one command
- inputs and templates in the repo ; rendered pngs are build output, not tracked

## part 4 : comfortable dpi

- ONE dpi value per host [ host config ], applied to every consumer at once :
  Xft.dpi [ xrdb ], gtk [ font scale \ GDK_DPI_SCALE ], qt [ QT_FONT_DPI ], openbox
  theme fonts [ + reconfigure ], tint2 font and icon sizes [ + its icon size from part 3 ],
  terminal fonts, the gtk zenki
- a suggestion from the screen's physical size [ xrandr mm \ edid ], shown, not forced
- adjusting : step up \ down with a live preview, in style [ a small themed popup and a
  key binding, plus a console command such as `desktop.dpi +1` \ `desktop.dpi 120` ]
- safe like display settings : a changed value reverts after a short timeout unless
  confirmed [ timer through <[base.interval.next]>, human scale ] -- a too-large or
  too-small setting can never lock the user out
- per-host profiles reuse the x11 resolution profiles where they exist
- fully keyboard controllable and intuitive [ owner 2026-11-21 ] : arrows \ + - change
  the value with live preview, enter confirms, escape reverts at once, a visible hint
  line names the keys ; no step needs the mouse. where a keyboard has large volume \
  media keys [ XF86AudioRaiseVolume \ LowerVolume \ Mute, the scroll wheel style
  ones ], they can drive the value WHILE the dpi control is open [ volume again once
  it closes ] -- detected, never assumed
- the thinkpad blue key [ ThinkVantage \ XF86Launch1 on most models, a vendor keycode on
  some -- detect, offer to bind ] toggles the visual set-up components : one press opens
  the set-up view [ dpi, screen layout, theme ], the next closes it. bound through the
  existing key \ menu path, a configurable key on hosts without one
- built into the existing zenki, no new one [ owner 2026-11-21 ] :
  - screen-setup owns it : it already enumerates monitors [ screen.setup.enumerate-
    monitors, layout-model, screen-change events ] -- physical size per monitor for the
    suggestion, the dpi control and live preview in its window, the revert timer
  - window-place follows a change : its window profiles re-place \ re-size the open
    windows for the new dpi [ window.place.* ]
  - protocol-7-menu makes it reachable : a menu entry [ e.g. 'display : font size \
    dpi' ] wired to the screen-setup command, plus the key binding

## part 5 : shortcut profiles suggested by a local model [ owner 2026-11-21 ]

- inputs, all detected : dmi vendor \ model, the keys the keyboard really sends
  [ special keys, media keys, the blue key ], screens and dpi, which zenki and
  surfaces are in use on this host
- a local model [ the inference servers of the coding zenka ] turns them into a
  shortcut profile : which key does what, in this hardware and usage context
- suggestion only : shown as a list with the reason per binding, the user accepts,
  edits or drops each one ; nothing is bound without confirmation
- a profile is a LOCALIZED BRANCH of the settings tree, not a format of its own
  [ owner 2026-11-21 ] : read through AMOS7::Config::Reader with its layers
  [ inline < disk < host ], plus a hardware-model layer between disk and host -- a
  profile accepted for one model applies to every host of that model, a host still
  overrides it. the same holds for dpi, theme tokens and icon sizes [ parts 2 - 4 ]

## stages

1. inventory [ part 1 ]
2. dpi : one value, applied to xrdb \ gtk \ tint2 \ openbox, console command, revert timer
3. theme tokens + adapters for gtk and web
4. povray icon template + tint2 icon set
5. themed dpi popup with live preview ; remaining adapters

## rules

- p7 config style, no json ; perl floor 5.32 ; timers through <[base.interval.next]>
- dark violet \ blue by default ; slow, easily slowed animation only
- no host names or personal data in repo files

#,,,,,,..,...,,,.,,,.,,,,,.,,,,,.,,..,.,.,.,.,..,,...,..,,..,,..,,..,,,.,,,,.,
#JV64J2Y67TLFYPVZJDJP3464G56EWCTQSVKMB7TL27M7RQV7XUCRGHT6WTGA2YUYHKQ3E6SZWIDXU
#\\\|WJZO4SAJU5LASICZUYKECQWFT5TU4HTD7M7ZAEGGPD2NDAPANTM \ / AMOS7 \ YOURUM ::
#\[7]ZARVEBAZNLKHLEHXBRHLK7DSBTL2DKHOXOQOR4TVG7SUF7V7U2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
