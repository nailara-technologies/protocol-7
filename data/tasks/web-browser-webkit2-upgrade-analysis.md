# task: web-browser zenka — WebKit2GTK upgrade analysis and feature map

## context

the web-browser zenka was force-migrated from `Gtk3::WebKit` (WebKit1) to
`Gtk3::WebKit2` in July 2019 under time pressure. the migration was marked
"incomplete but functional" — many features were stubbed, disabled, or left
as comments. the goal is also future expansion from kiosk-only to a mixed
kiosk/interactive model with optional UI zenka separation.

this is an **analysis task only** — produce a structured document identifying:
1. what was lost or left incomplete in the WebKit1 → WebKit2 migration
2. deprecated/removed APIs in current code that need updating
3. modern WebKit2GTK 4.1 equivalents for everything lost or broken
4. new WebKit2GTK 4.1 capabilities relevant to the system's use cases
5. a structured upgrade plan (for separate implementation tasks)

do NOT implement changes in this task. produce the analysis document only.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to analyze

### 1. api version mismatch

current init_code targets WebKit2GTK 4.0:
```perl
Glib::Object::Introspection->setup(
    qw| basename WebKit2 version 4.0 package Gtk3::WebKit2 |);
```

installed on system: `libwebkit2gtk-4.1-0` (2.50.5) and `libwebkitgtk-6.0-4` (2.50.5).
the `libgtk3-webkit2-perl` package (0.06-6) bridges Perl to the underlying C library.

identify: what changes between webkit2gtk 4.0 and 4.1 API that affect this code?
the introspection setup line — does `version 4.0` still work with 4.1 installed,
or does it need to be `version 4.1`?

### 2. deprecated/removed settings in set_properties

current `web-browser.set_properties` uses these that may be deprecated or removed:
```perl
$settings->set_property( 'enable-plugins', ... );             ## NPAPI removed entirely
$settings->set_property( 'enable-offline-web-application-cache', 0 );  ## likely gone
$settings->set_property( 'enable-html5-local-storage', 0 );  ## likely gone
$settings->set_property( 'enable-html5-database', 0 );       ## likely gone
$settings->set_property( 'enable-frame-flattening', 1 );     ## deprecated
```

also commented out with "deprecated" note:
```perl
###    $settings->set_property( 'enable-private-browsing', 1 );
## LLL: use #WebKitWebView:is-ephemeral or #WebKitWebContext:is-ephemeral instead
```
— this was never migrated to the WebKit2 ephemeral API.

for each: what is the correct modern replacement, or confirm it can be removed?

### 3. what was in WebKit1 that was never completed in WebKit2

the pre-migration (Gtk3::WebKit era) code had:
- `HTTP::Soup` — tight HTTP session management for cookies, authentication, proxy
  in WebKit2 this moved to: WebKitWebContext + WebKitCookieManager + WebKitNetworkProxySettings
  current code: HTTP::Soup is still imported but it's unclear if it's actually used
  identify: what Soup functionality was used in WebKit1 and what is the WebKit2 equivalent?

- `browser.handler.load_status_signal` — renamed to `load_changed` signal in WebKit2,
  which was done, but `load-failed` handling in `web-browser.handler.signal.load_failed`
  may have gaps vs what the WebKit1 version had. check for completeness.

- `browser.handler.request_starting_signal` — in WebKit1 this was a simple request
  interception hook. in WebKit2 this became `decide-policy` with WebKitPolicyDecision.
  the current module may be incomplete. check it.

- the `# AUTOSCROLL WITHOUT JS` comment block:
  ```
  # web extension to access DOM coming later: needs webkit2/webkit-web-extension.h
  ```
  this was never implemented. the current auto-scroll uses JavaScript injection instead
  (`web-browser.js_call`). what would a proper web extension approach look like in
  WebKit2GTK 4.1? is there a simpler path via `WebKitUserContentManager`?

- `Browser::ScrolledWindow` subclass — in WebKit1 this was used with a `self-scrolling`
  property for the translucent overlay tab system. in WebKit2 the subclass changed to
  `Gtk3::WebKit2::WebView` directly. how does the translucent overlay tab system work
  now? what is `cfg.use_transparency` and `cfg.overlay_scrolling` actually doing?

### 4. read the relevant modules for full context

read these modules to understand the current state before analyzing:
```bash
cat modules/web-browser.init_code
cat modules/web-browser.set_properties
cat modules/web-browser.init_view
cat modules/web-browser.open_window
cat modules/web-browser.handler.load_changed
cat modules/web-browser.handler.signal.load_failed
cat modules/web-browser.handler.request_starting_signal
cat modules/web-browser.js_call
cat modules/web-browser.cmd.run_js
cat modules/web-browser.proxy_setup
cat modules/web-browser.disable_proxy
cat modules/web-browser.swap_views
cat modules/web-browser.handler.swap_views
cat modules/web-browser.handler.fade_in_view
configuration/zenki/web-browser/zenka-startup.v7
configuration/zenki/web-browser/start
```

also read the pre-migration WebKit1 versions from git for comparison:
```bash
git show e13607469^:src/browser.init_code
git show e13607469^:src/browser.set_properties
git show e13607469^:src/browser.init_view
git show e13607469^:src/browser.open_window
git show e13607469^:src/browser.handler.load_status_signal
git show e13607469^:src/browser.proxy_setup
```
(note: modules were in `src/` before the rename to `modules/`)

---

## new features to evaluate

for each, assess: relevant to this system? implementation complexity? priority?

### automation capabilities
- `webkit_web_view_get_snapshot()` — native view-to-PNG screenshot, no Xvfb/scrot needed
  this is the key one: could replace the entire visual-feedback capture pipeline
  (see data/tasks/visual-feedback-capture-analyzer.md for context)
- `WebKitAutomationSession` — W3C WebDriver protocol, proper headless automation
- `evaluate_javascript()` / `evaluate_javascript_finish()` — async JS eval
  (current `web-browser.js_call` may use the older synchronous API)
- `WebKitUserContentManager` — inject CSS/JS into pages without web extension process
  could replace the JavaScript auto-scroll injection with a cleaner approach

### network and privacy
- `WebKitCookieManager` — per-context cookie management (was HTTP::Soup in WebKit1)
- `WebKitNetworkProxySettings` — per-context proxy (was HTTP::Soup in WebKit1)
- `WebKitWebView:is-ephemeral` / `WebKitWebContext:is-ephemeral` — proper private mode
  (noted as TODO in current code but never implemented)
- `WebKitNetworkSession` (WebKit2GTK 2.40+) — fully isolated per-view network stacks

### display and transparency
- `webkit_web_view_set_background_color()` — rgba background with alpha channel
  this enables the translucent overlay tab system at a native level
  how does the current `cfg.use_transparency = 1` actually work — is it using this?
- compositing model for overlay views — how are the fg/bg views layered?
  `web-browser.fg_view_insert`, `web-browser.clear_bg_view` suggest two-layer system

### process model
- `WebKitProcessModel` — one-process-per-webview vs shared process
  relevant for isolation when running multiple kiosk sites
- web extension in separate process — still needed for DOM access without JS?

### ui zenka separation architecture
the long-term vision is:
- `web-browser` zenka: browser process only, no toolbar/chrome UI
- separate `web-browser-ui` zenka: toolbar, tabs, url bar, controls — its own process
- communication: via P7 routing (`web-browser-ui.cmd.navigate` → routes to web-browser)
- XEmbed or GtkSocket: UI zenka embeds browser window into its container
- mixed control: kiosk mode = UI zenka disabled, automation zenka controls everything;
  interactive mode = UI zenka visible + user input + automation zenka still available

identify: what WebKit2GTK APIs support this separation?
specifically: can a GtkWindow containing a WebKitWebView be embedded into another
GTK process via XEmbed/GtkSocket? what are the limitations?

---

## output format

produce the analysis as: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`

structure:
```
# web-browser zenka: WebKit2GTK upgrade analysis

## executive summary
[3-5 bullet points: most important gaps and opportunities]

## 1. api version: 4.0 → 4.1 migration
[what changes, what breaks, what the setup line should become]

## 2. deprecated settings in set_properties
[table: setting | status | replacement | notes]

## 3. incomplete/lost WebKit1 features
[for each: what it was, current state, WebKit2GTK 4.1 equivalent]

## 4. new WebKit2GTK 4.1 features
[for each: capability | relevance | priority | implementation notes]

### 4a. get_snapshot() — native screenshot
[detail this one separately: it unblocks visual-feedback pipeline]

## 5. ui zenka separation
[XEmbed feasibility, WebKit2GTK process model, API surface for separation]

## 6. upgrade plan
[ordered list of implementation tasks, each self-contained, roughly 1 kimi session each]
```

---

## success criteria

- [ ] analysis covers all deprecated settings with confirmed replacements
- [ ] HTTP::Soup usage mapped to WebKit2 equivalents
- [ ] `get_snapshot()` section detailed enough to implement from it alone
- [ ] translucent overlay tab mechanism understood and documented
- [ ] UI zenka separation feasibility confirmed or denied with reasoning
- [ ] upgrade plan produces at least 3 concrete follow-up task descriptions
- [ ] document written to `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`

#,,..,..,,,,,,,,,,.,,,,,.,,..,.,.,,.,,..,,.,.,..,,...,...,.,,,,,.,,,.,,..,,..,
#J4AAIY5XQG2VGKFHHNRCXLJX4S4S7X2SEJPOQ56YP7UWOUGIZ3T62KERLAACBIGEM4FQY6TK3CN2S
#\\\|J5FEILBX7A2IAFDAHJKI4ECYMEKU6QSKUXO2MRSXGAXEQKFG3MU \ / AMOS7 \ YOURUM ::
#\[7]UV6N2L4GRCYGMDABBH326O5HMMWOWZ6R2NRBXPFFVAPR6YB2FADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
