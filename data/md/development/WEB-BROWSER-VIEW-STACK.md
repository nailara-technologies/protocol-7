# web-browser zenka: view stack architecture

## origin

the current two-view fg/bg system implements smooth cross-dissolve transitions
between web pages by keeping two WebKitWebView instances stacked in a
Gtk3::Overlay. the foreground view shows the current page; the background view
pre-loads the next. switching is instant — just reorder the overlay stack and
fade the opacity.

this document describes the generalization to a dynamic N-view stack, inspired
by the Amiga Workbench screen system where independent screens could be pulled
down to reveal the one behind, each running its own content with full
independence. the web-browser view stack is the same spatial metaphor applied
to web content: pages are literally behind each other in depth, not beside each
other in a tab bar.

---

## current architecture (2 views, fixed)

```
Gtk3::Overlay
  └── view[2]  (bg — pre-loading next page, hidden behind)
  └── view[1]  (fg — current page, fully visible)
```

- `<web-browser.overlay.index.fg>` = 1 or 2
- `<web-browser.overlay.index.bg>` = 2 or 1
- swap via `overlay->reorder_overlay()` + opacity fade

each view has its own `WebKitWebProcess` (separate process, isolated JS/DOM).
the `WebKitNetworkProcess` is shared across all views.

---

## view stack model (N views, dynamic)

```
Gtk3::Overlay
  └── view[n]  (depth n — light mode, DOM alive, JS throttled)
  └── ...
  └── view[2]  (depth 2 — light mode)
  └── view[1]  (depth 1 — full rendering, current context)
```

### view states

| state | rendering | JS | memory | use case |
|---|---|---|---|---|
| `full` | active, 60fps | unrestricted | full | foreground view |
| `light` | paused | throttled via visibility API | full | background, ready for instant recall |
| `cold` | none | none | minimal | slot reserved, view not yet created |

### depth semantics

depth is meaningful, not arbitrary:
- **depth 1** — current context, user is here
- **depth 2..n** — related context, queued, or parallel stream
- **depth 0** — not in stack (destroyed or never created)

bringing a view to depth 1 is instant — GTK overlay reorder + opacity fade.
no reload, no flicker, JS state preserved exactly as left.

---

## light mode

when a view moves below depth 1:

```perl
## page visibility API — well-behaved pages pause themselves ##
## document.hidden = true fires automatically when view is hidden ##
$view->set_opacity(0);

## optionally throttle background activity ##
## webkit has no direct 'low-power' mode, but:
## - compositor stops painting (view invisible)
## - JS timers may be throttled by webkit internally
## - audio: $view->set_is_muted(TRUE) if not needed
```

when a view returns to depth 1:
```perl
$view->set_opacity(1);   ## fade in via handler.fade_in_view
## document.hidden = false fires — pages resume
```

---

## data structures

```perl
## view registry
<web-browser.view_stack>        = [ 1, 2 ];     ## ordered fg→bg
<web-browser.view_max>          = 8;            ## maximum concurrent views
<web-browser.view_next_id>      = 3;            ## next view id to allocate

## per-view state
<web-browser.view_state>->{$id} = {
    state    => 'full',     ## full | light | cold
    url      => $url,
    scrolled => $sw,        ## Gtk3::ScrolledWindow
    view     => $view,      ## WebKitWebView
};
```

---

## new commands

### web-browser.cmd.push-view

creates a new view (or promotes a cold slot), loads URL, places at depth 2+:

```bash
p7c web-browser.cmd.push-view 'https://space.v7.ax'
## → allocates view[n+1], loads URL, sets state=light
## returns: view_id
```

### web-browser.cmd.pop-view

removes the deepest view from the stack, destroys its web process:

```bash
p7c web-browser.cmd.pop-view
## → destroys view[n], frees WebKitWebProcess
```

### web-browser.cmd.swap-view

brings a specific view to foreground:

```bash
p7c web-browser.cmd.swap-view 3
## → cross-dissolve: view[3] fades in as depth 1
##   previous depth 1 moves to depth 2 (light mode)
```

### web-browser.cmd.list-views

```bash
p7c web-browser.cmd.list-views
## 1 [full]  https://space.v7.ax
## 2 [light] https://iris.v7.ax
## 3 [light] https://news.example.com
```

### web-browser.cmd.set-view-state

explicitly set a view to light or full mode:

```bash
p7c web-browser.cmd.set-view-state '2 light'
p7c web-browser.cmd.set-view-state '2 full'
```

---

## memory model

each active (non-cold) view costs approximately:
- `WebKitWebProcess`: ~270MB RSS (JS engine + DOM + renderer)
- `Gtk3::ScrolledWindow` + `WebKitWebView` widget: ~5MB

the `WebKitNetworkProcess` (57MB) is shared across all views regardless of N.

| stack depth | web processes | approx total RSS |
|---|---|---|
| 1 | 1 | ~430MB |
| 2 | 2 | ~700MB |
| 4 | 4 | ~1.25GB |
| 8 | 8 | ~2.4GB |

with `WEBKIT_PROCESS_MODEL_SHARED_SECONDARY_PROCESS`:
all views share one web process — saves N-1 × 270MB but loses JS isolation.
suitable for trusted content (kiosk), not general browsing.

---

## use cases

### kiosk rotating display (N=4-8)
all sites pre-loaded in light mode. rotation is instant cross-dissolve.
no "loading" ever visible. each site updates its own data feed in background.

### dashboard (N=3-6)
data streams updating in background. alert condition on any view triggers
`swap-view` bringing it to foreground. operator sees live data, not a refresh.

### complex web application
separate views for different app sections. switching sections is depth
navigation not page reload. back = previous depth, not browser history.

### visual feedback pipeline
`visual-feedback.capture-analyzer` can request a specific view, load HTML,
call `get_snapshot`, then `pop-view`. ephemeral rendering view, no cleanup.

---

## implementation order

1. **generalize init_view** — accept view id parameter, store in registry
2. **generalize overlay management** — use stack order not hardcoded 1/2
3. **implement push-view / pop-view** — dynamic WebKitWebView lifecycle
4. **implement swap-view** — cross-dissolve reusing existing fade handlers
5. **implement light mode** — visibility API + optional mute
6. **implement list-views** — status command

the current 2-view system is a degenerate case of the stack (N=2, fixed ids 1
and 2). migration: rename existing fg/bg to stack-based addressing, keep
behavior identical, then extend.

---

## connection to window registry

once the X-11 window registry STRM system is implemented
(see `X11-RELIABILITY-AND-WINDOW-REGISTRY.md`), each view in the stack
can self-register its XID with X-11 — tile-groups can then manage placement
of individual views independently if needed.

#,,.,,,,,,.,.,..,,,,,,...,,..,,,.,.,.,,.,,.,,,..,,...,...,...,,..,,,.,,..,,,.,
#I6N3UNPNDNNJBBUTVWXQFSCLFU4RJZMFX3RNWOH5UIPDQ2ZTPQZC7CIIKHR5G2U74YA2V4S572YWE
#\\\|ESH6CKJKPJCXNBGDHXIVYELX4NI3CQL5F36XXIKC6NGTCMZXVIA \ / AMOS7 \ YOURUM ::
#\[7]YP6SOE4C5UV52X7HO4XXWAVHKMYOVLBRTPHI4NOLTWOCXRS2LUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
