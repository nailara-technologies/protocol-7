# web-browser zenka: WebKit2GTK upgrade analysis

## executive summary

- **The introspection setup line `version 4.0` is broken on the current system.** Only `libwebkit2gtk-4.1-0` is installed (no 4.0 typelib). The web-browser zenka will fail to load unless changed to `version 4.1`.
- **Proxy support is completely broken.** `web-browser.disable_proxy` calls `Gtk3::WebKit2::get_default_session()`, which does not exist in WebKit2. The `proxy_setup` module creates a `HTTP::Soup::URI` but never applies it. Both modules need rewriting with `WebKitNetworkProxySettings`.
- **Request interception (`request_starting_signal`) was never ported.** The module still carries the WebKit1 5-parameter signature and is not connected anywhere. It must be reimplemented via `decide-policy` with `WebKitNavigationPolicyDecision`.
- **`get_snapshot()` is available in 4.1** and could eliminate the entire Xvfb/scrot/chromium-headless pipeline used by the visual-feedback capture system.
- **UI zenka separation via XEmbed is not recommended.** `GtkSocket`/`GtkPlug` exist in GTK3 but do not reliably host GL-composited WebKit2 WebViews. The correct separation model is P7 command routing, not visual embedding.

---

## 1. api version: 4.0 → 4.1 migration

### what changes between 4.0 and 4.1

The **only** API difference between WebKit2GTK 4.0 and 4.1 is the underlying HTTP library:

| API version | libsoup version | HTTP protocol support |
|-------------|-----------------|----------------------|
| webkit2gtk-4.0 | libsoup 2.4 | HTTP/1.1 only |
| webkit2gtk-4.1 | libsoup 3.0 | HTTP/2, better performance |

The WebKit2 GObject API surface itself is **identical** between 4.0 and 4.1. No WebKit methods, signals, or properties were added or removed in the transition.

### what breaks on this system

The system has **only** `gir1.2-webkit2-4.1` installed (2.50.5). There is **no** `WebKit2-4.0.typelib`:

```bash
$ ls /usr/lib/x86_64-linux-gnu/girepository-1.0/ | grep WebKit
WebKit2-4.1.typelib
WebKit2WebExtension-4.1.typelib
```

The current introspection setup line:

```perl
Glib::Object::Introspection->setup(
    qw| basename WebKit2 version 4.0 package Gtk3::WebKit2 |);
```

**Fails at runtime:**
```
Typelib file for namespace 'WebKit2', version '4.0' not found
```

### required change

Change the setup line in `src/web-browser.init_code`:

```perl
Glib::Object::Introspection->setup(
    qw| basename WebKit2 version 4.1 package Gtk3::WebKit2 |);
```

This is a **single-character change** (4.0 → 4.1) and is sufficient for the WebKit2 API itself. No other WebKit2 API changes are required for the 4.0→4.1 migration.

### Soup compatibility note

The code still imports `HTTP::Soup` (libsoup 2.4 bindings). The system also has `gir1.2-soup-2.4` installed, so `HTTP::Soup` will still load. However, the WebKit2 4.1 library is linked against libsoup 3.0 internally. The `HTTP::Soup` Perl module uses GObject introspection and will talk to libsoup 2.4, which is fine as long as the code does not try to share Soup objects between the two libraries. **The only place `HTTP::Soup` is used is in `proxy_setup` to construct a URI that is then discarded.** Removing `HTTP::Soup` entirely is the cleanest path forward.

---

## 2. deprecated settings in set_properties

Current `src/web-browser.set_properties` sets the following properties. Their status in WebKit2GTK 4.1 (2.50.5) is:

| setting | status in 4.1 | replacement / action | notes |
|---------|---------------|----------------------|-------|
| `enable-plugins` | **deprecated since 2.32** | Remove line | NPAPI plugins were removed from WebKit entirely. The property still exists for backward compatibility but has no effect. Current code sets it to `cfg.plugins_enabled` (default 0). |
| `enable-offline-web-application-cache` | **obsolete** | Remove line | HTML5 Application Cache was removed from the web platform. Property still exists but does nothing. |
| `enable-html5-local-storage` | **deprecated name** | Keep for now or remove | Local Storage is now controlled via `WebsiteDataManager` privacy settings. The property still works in 4.1 but will be removed in 6.0. |
| `enable-html5-database` | **deprecated name** | Keep for now or remove | IndexedDB. Same situation as above. |
| `enable-frame-flattening` | **deprecated, no-op** | Remove line | Documentation says "Frame flattening is no longer supported." Property exists but has no effect. |
| `enable-private-browsing` | **deprecated since 2.16** | Use `is-ephemeral` on WebView | Current code has a comment pointing to this but never implemented it. The replacement is to create the WebView with `is-ephemeral => 1` or use an ephemeral `WebKitWebContext`. |
| `javascript-can-access-clipboard` | active | Keep | Still valid in 4.1. |
| `enable-fullscreen` | active | Keep | Still valid in 4.1. |
| `enable-site-specific-quirks` | active | Keep | Still valid in 4.1. |
| `enable-smooth-scrolling` | active | Keep | Still valid in 4.1. |

### recommended action for `set_properties`

Remove the following lines entirely:

```perl
$settings->set_property( 'enable-plugins', <web-browser.cfg.plugins_enabled> );
$settings->set_property( 'enable-offline-web-application-cache', 0 );
$settings->set_property( 'enable-html5-local-storage', 0 );
$settings->set_property( 'enable-html5-database', 0 );
$settings->set_property( 'enable-frame-flattening', 1 );
```

Replace `enable-private-browsing` with ephemeral WebView construction in `init_view`:

```perl
my $view = Browser::WebView->new_with_context(
    <web-browser.gtk_obj.web_context>
);
# If private mode desired:
# $view->set_property('is-ephemeral', 1);
```

Note: `is-ephemeral` is a **construct-only** property on `WebKitWebView`. It can only be set at construction time, not after. To make the view ephemeral, pass it to `g_object_new` (via Perl subclass constructor) or use an ephemeral `WebKitWebContext`.

---

## 3. incomplete/lost WebKit1 features

### 3.1 HTTP::Soup session management → WebKit2 context API

#### what it was in WebKit1

In the pre-migration code (`git show e13607469^:src/browser.proxy_setup`):

```perl
my $session = Gtk3::WebKit::get_default_session();
my $proxy_uri = HTTP::Soup::URI->new("http://$proxy_addr:$proxy_port");
$session->set( 'proxy-uri' => $proxy_uri );
```

And in `browser.disable_proxy`:

```perl
my $session = Gtk3::WebKit::get_default_session();
$session->set( 'proxy-uri' => undef );
```

WebKit1 exposed a global `SoupSession` that applications could directly manipulate for cookies, authentication, proxy, and SSL.

#### current (broken) state

`web-browser.proxy_setup`:
```perl
my $proxy_uri = HTTP::Soup::URI->new("http://$proxy_addr:$proxy_port");
# my $proxy_settings = Gtk3::WebKit2::NetworkProxySettings->new($proxy_uri);
# $context->set_network_proxy_settings($proxy_settings);
```

The proxy is **never actually applied**. The `NetworkProxySettings` code is commented out.

`web-browser.disable_proxy`:
```perl
my $session = Gtk3::WebKit2::get_default_session();
$session->set( 'proxy-uri' => undef );
```

This is **completely broken**. `Gtk3::WebKit2::get_default_session()` does not exist in WebKit2. Calling this will throw an error.

#### WebKit2GTK 4.1 equivalent

```perl
# Setup
my $proxy_settings = Gtk3::WebKit2::NetworkProxySettings->new(
    "http://$proxy_addr:$proxy_port",  # default proxy
    []                                 # ignore-hosts array
);
$web_context->set_network_proxy_settings('WEBKIT_NETWORK_PROXY_MODE_CUSTOM',
                                         $proxy_settings);

# Disable
$web_context->set_network_proxy_settings('WEBKIT_NETWORK_PROXY_MODE_NO_PROXY',
                                         undef);
```

Also available: `WebKitCookieManager` via `$web_context->get_cookie_manager()` for per-context cookie policies.

#### HTTP::Soup import cleanup

`HTTP::Soup` is imported in `web-browser.init_code` but is no longer needed once proxy is moved to `NetworkProxySettings`. The `HTTP::Soup::URI` object in `proxy_setup` is unused (commented out). **Recommendation: remove the `HTTP::Soup` autoload and dependency.**

---

### 3.2 `load_status` signal → `load_changed` signal

#### what changed

| Aspect | WebKit1 (`Gtk3::WebKit`) | WebKit2 (`Gtk3::WebKit2`) |
|--------|--------------------------|---------------------------|
| Signal name | `load-status` | `load-changed` |
| Parameter | `Gtk3::WebKit::LoadStatus` enum (strings like `finished`, `failed`, `provisional`) | `WebKitLoadEvent` enum (`started`, `redirected`, `committed`, `finished`) |
| Failure handling | `load-error` signal | `load-failed` signal |

#### current state

The migration renamed the signal and handler (`browser.handler.load_status_signal` → `web-browser.handler.load_changed`). The handler compares `$load_status` with string `eq 'started'` and `eq 'finished'`. In GObject introspection, enum values often stringify to their nick names, so this comparison works in practice.

The handler also uses `$view->get_estimated_load_progress()` and `$view->get_property('is-loading')`, both of which are valid WebKit2 APIs.

**Assessment: FUNCTIONAL.** No changes needed for basic operation, but the string comparison is fragile. Better to compare against the `WebKitLoadEvent` enum values if possible (or keep string comparison since it works).

---

### 3.3 `load-failed` signal handling

#### what changed

WebKit1 `load-failed` signature: `($view, $frame, $load_uri, $error)`
WebKit2 `load-failed` signature: `($view, $load_event, $failing_uri, $error)`

#### current state

`web-browser.handler.signal.load_failed`:
```perl
my ( $view, $sig_status, $error_uri, $glib_error ) = @_;
```

This matches the WebKit2 signature ( `$sig_status` is the `WebKitLoadEvent`, `$error_uri` is the failing URI). The handler ignores `$sig_status`, which is fine.

However, the handler contains a large block of commented-out code that was ported from WebKit1 but deactivated:
- Proxy reachability check (`IO::Socket::IP` to `cfg.proxy_addr:cfg.proxy_port`)
- Status code extraction from response
- Title-based error detection (`404 Not Found`, proxy errors)

All of this logic is duplicated (and active) in `web-browser.handler.load_changed`. In WebKit1, both `load-status` and `load-failed` could signal errors. In WebKit2, `load-failed` fires for network-level failures, while `load_changed` with non-2xx status still fires `finished`. The current split is:
- `load_changed` handles HTTP error status codes (404, proxy errors, etc.)
- `load_failed` handles GLib/network errors (DNS failure, TLS error, etc.)

**Assessment: MOSTLY FUNCTIONAL.** The commented-out code should be removed or reactivated. The proxy check in `load_failed` might be useful to reactivate for network-level failures.

---

### 3.4 `resource-request-starting` → `decide-policy`

#### what it was in WebKit1

`browser.handler.request_starting_signal` in WebKit1:
```perl
my ( $view, $frame, $resource, $request, $response ) = @_;
# Block requests not matching allowed domain
$request->set_uri('about:blank');
```

This was connected to the `resource-request-starting` signal on the WebView.

#### current state

The file `src/web-browser.handler.request_starting_signal` still exists with the **WebKit1 signature** in its parameter list:

```perl
my ( $view, $frame, $resource, $request, $response ) = @_;
```

But it is **never connected** anywhere in the codebase. Searching `src/web-browser.load_uri` and `src/web-browser.init_view` shows no `signal_connect` for `decide-policy` or any request interception.

The module header even says:
```perl
# todo = implement request whitelist support ... // PORT TO WEBKIT2!!
```

#### WebKit2GTK 4.1 equivalent

In WebKit2, request interception is done via the `decide-policy` signal:

```perl
$view->signal_connect('decide-policy' => sub {
    my ($view, $decision, $decision_type) = @_;
    
    return FALSE unless $decision_type eq 'navigation-action';
    
    my $nav_decision = $decision;  # WebKitNavigationPolicyDecision
    my $request = $nav_decision->get_request;
    my $uri = $request->get_uri;
    
    # Allow/deny logic here
    if ($uri =~ m{^https?://([^/]+\.)?\Q$allowed\E}i) {
        return FALSE;  # allow
    } else {
        $nav_decision->ignore;  # block
        return TRUE;  # handled
    }
});
```

**Assessment: NOT IMPLEMENTED.** The whitelist/request-blocking feature from WebKit1 is completely missing in WebKit2. This is a security gap for kiosk mode if the loaded page contains external resources or redirects.

---

### 3.5 auto-scroll without JavaScript

#### what it was

The pre-migration code had a `self-scrolling` property on `Browser::WebView`. In WebKit1, DOM access was possible directly from the UI process, so scrolling could theoretically be done without JS (though the WebKit1 code also used JS).

#### current state

Auto-scroll is implemented entirely via JavaScript injection:

```perl
# web-browser.handler.auto_scroll
<[web-browser.js_call]>->(
    'window.scroll(0,' . <window.scroll.pos> . ')',
    sub { }, $reply_id
);
```

The `init_code` contains a comment:
```perl
#[ AUTOSCROLL WITHOUT JS ]######################################################
# web extension to access DOM coming later: needs webkit2/webkit-web-extension.h
#        ( ... see https://github.com/tlby/webkit2gtk-webextension-example.git )
################################################################################
```

This was never implemented.

#### alternatives in WebKit2GTK 4.1

**Option A: WebKitUserContentManager (recommended)**

`WebKitUserContentManager` allows injecting JavaScript that runs at page load time, without needing a separate extension process. This is cleaner than calling `run_javascript` repeatedly at runtime:

```perl
my $ucm = $view->get_user_content_manager;
$ucm->add_script(WebKit2::UserScript->new(
    "window.nailara_scroll_pos = 0; window.nailara_scroll_step = 5; ...",
    'WEBKIT_USER_CONTENT_INJECT_TOP_FRAMES',
    'WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START',
    undef,  # whitelist
    undef   # blacklist
));
```

However, `UserContentManager` injection is still JavaScript — it just moves the injection from runtime to load-time. It does not provide native DOM access from Perl.

**Option B: Web Extension (not recommended for Perl)**

WebKit2 web extensions are C shared libraries loaded into the web process. They can access the DOM via C APIs. There is no Perl binding for writing web extensions. The linked example (`webkit2gtk-webextension-example`) is a C project. Writing a C extension and communicating with the UI process via D-Bus or custom messages is possible but significantly more complex than the current JS approach.

**Option C: Keep JS injection, use `evaluate_javascript()`**

WebKit2GTK 4.1 provides `evaluate_javascript()` / `evaluate_javascript_finish()`, which is the modern async API for JS evaluation. The current code uses `run_javascript()` with a hack (prefixing `throw`) to capture return values. `evaluate_javascript` can return values properly without the throw trick.

**Recommendation:** Keep JavaScript-based auto-scroll. It is the only practical approach from Perl. Migrate from `run_javascript` + `throw` hack to `evaluate_javascript` for cleaner code. Consider `UserContentManager` for injecting the scroll controller at page load.

---

### 3.6 translucent overlay tab system (`cfg.use_transparency`)

#### how it works now

The browser maintains **two views** (fg=1, bg=2) inside a `Gtk3::Overlay`. The slideshow system loads the next URL into the background view, then swaps them:

```perl
# web-browser.swap_views
$overlay->reorder_overlay( $scrolled_window->{$fg_index}, 0 );
<web-browser.overlay.index> = { 'fg' => $bg_index, 'bg' => $fg_index };
```

When `cfg.use_transparency = 1`:
1. The old fg view is moved to bg (reordered to z-index 0)
2. The new fg view starts at `opacity = 0`
3. A `draw` signal handler (`web-browser.handler.swap_views`) runs at ~60 FPS
4. Each frame calls `web-browser.handler.fade_in_view`, which increments `fg_opacity` using a gaussian curve
5. The `ScrolledWindow` containing the WebView has its opacity set: `$scrolled_window->{$fg_index}->set_opacity(<web-browser.fg_opacity>)`

When `cfg.use_transparency = 0`:
- Instant swap, no fade. Both views remain at opacity 1.

#### transparency at the WebView level

In `web-browser.init_view`, there is a commented-out block:

```perl
##[LLL] seems to not work., check why..,
# my $bg_rgba = Gtk3::Gdk::RGBA->new();
# $bg_rgba->parse('#0000FF');
# $view->set_background_color($bg_rgba);
##
```

The `set_background_color` method exists in WebKit2GTK 4.1 and accepts a `GdkRGBA`. The comment says it "seems to not work" — likely because the method requires an RGBA color with alpha < 1.0 to show transparency, and the HTML page itself may have an opaque background. For true composited transparency (showing the overlay/widget background through the webview), the page CSS must also allow transparency (`background: transparent` or unset).

With `set_background_color` working correctly and the page background made transparent, the fade effect could operate at the WebView level instead of the ScrolledWindow level, which would be more efficient (no need to composite the entire scrolled window container).

**Assessment: FUNCTIONAL but suboptimal.** The ScrolledWindow-level opacity fade works but is less efficient than WebView-level transparency. The `set_background_color` API should be revisited.

---

## 4. new WebKit2GTK 4.1 features

### 4a. `get_snapshot()` — native screenshot

#### API

```c
void webkit_web_view_get_snapshot (WebKitWebView *web_view,
                                   WebKitSnapshotRegion region,
                                   WebKitSnapshotOptions options,
                                   GCancellable *cancellable,
                                   GAsyncReadyCallback callback,
                                   gpointer user_data);
GdkPixbuf * webkit_web_view_get_snapshot_finish (WebKitWebView *web_view,
                                                  GAsyncResult *result,
                                                  GError **error);
```

**Regions:**
- `WEBKIT_SNAPSHOT_REGION_VISIBLE` — captures only the visible viewport
- `WEBKIT_SNAPSHOT_REGION_FULL_DOCUMENT` — captures the entire page (including scrolled-off content)

**Options:**
- `WEBKIT_SNAPSHOT_OPTIONS_NONE`
- `WEBKIT_SNAPSHOT_OPTIONS_INCLUDE_SELECTION_HIGHLIGHTING`

#### relevance to visual-feedback pipeline

The `data/tasks/visual-feedback-capture-analyzer.md` task implements frame capture using:

```bash
chromium --headless=new --window-size=1280,900 --screenshot ...
# or
DISPLAY=:99 scrot frame_NNNN.png
```

Both approaches require:
- An external browser process (Chromium) OR
- An X11 display (Xvfb) + external screenshot tool

Using `get_snapshot()` from the web-browser zenka:
- Requires **no external browser**
- Requires **no Xvfb**
- Captures directly from the WebKit render tree to a `GdkPixbuf`
- The pixbuf can be saved to PNG via `gdk_pixbuf_save()`

#### implementation sketch

```perl
$view->get_snapshot(
    'WEBKIT_SNAPSHOT_REGION_VISIBLE',
    'WEBKIT_SNAPSHOT_OPTIONS_NONE',
    undef,  # cancellable
    sub {
        my ($view, $result) = @_;
        my $pixbuf = eval { $view->get_snapshot_finish($result) };
        if ($pixbuf) {
            $pixbuf->save('/path/to/frame.png', 'png');
        }
    },
    undef   # user_data
);
```

**Caveats:**
- `get_snapshot()` is **asynchronous**. For a sequence of frames, each snapshot must wait for the previous to complete.
- The WebView must be **realized and rendered** before snapshotting. In a headless environment without a display, `Gtk3::Gdk::Window` creation may fail unless a display is available. However, if the web-browser zenka is already running on a real X11 display (which it is, via `cfg/zenki/web-browser/zenka.v7`), snapshots can be taken directly.
- For true headless capture, `Xvfb` is still needed to provide the display, but `scrot`/`chromium` are eliminated.

#### priority: **HIGH**

This unblocks a major simplification of the visual-feedback system and removes the Chromium dependency for capture.

---

### 4b. `evaluate_javascript()` — async JS eval with proper return values

#### API

```c
void webkit_web_view_evaluate_javascript (WebKitWebView *web_view,
                                          const gchar *script,
                                          gssize length,
                                          const gchar *world_name,
                                          const gchar *source_uri,
                                          GCancellable *cancellable,
                                          GAsyncReadyCallback callback,
                                          gpointer user_data);
JSCValue * webkit_web_view_evaluate_javascript_finish (WebKitWebView *web_view,
                                                        GAsyncResult *result,
                                                        GError **error);
```

#### current hack

Both `web-browser.js_call` and `web-browser.cmd.run_js` use a workaround to capture return values:

```perl
$js_string = "throw $js_string";  # prepares result access through exception
$view->run_javascript($js_string, undef, sub {
    eval { $s_res = $self->run_javascript_finish($result) };
    ( my $ex_str = $EVAL_ERROR ) =~ s| at /usr/.+
$||;
    # ...
});
```

This works by intentionally throwing the result as an exception and then parsing the exception string. It is fragile and breaks if the JS expression itself throws.

#### replacement

`evaluate_javascript` returns a `JSCValue` object that can be converted to a string natively:

```perl
$view->evaluate_javascript(
    $js_string,
    -1,           # length (-1 = null-terminated)
    undef,        # world_name
    undef,        # source_uri
    undef,        # cancellable
    sub {
        my ($view, $result) = @_;
        my $jsc_value = eval { $view->evaluate_javascript_finish($result) };
        if ($jsc_value) {
            my $result_str = $jsc_value->to_string;
            # ... use result_str directly, no exception parsing
        }
    },
    undef
);
```

**Priority: MEDIUM** — The current hack works but is brittle. `evaluate_javascript` is cleaner.

---

### 4c. `WebKitUserContentManager` — inject CSS/JS without extension process

#### API

```c
WebKitUserContentManager *webkit_web_view_get_user_content_manager (WebKitWebView *web_view);
void webkit_user_content_manager_add_script (WebKitUserContentManager *manager,
                                              WebKitUserScript *script);
void webkit_user_content_manager_add_style_sheet (WebKitUserContentManager *manager,
                                                   WebKitUserStyleSheet *stylesheet);
```

#### use cases

1. **Auto-scroll controller injection:** Inject a small JS controller at `document-start` that exposes `window.nailara_scrollTo(y)` and `window.nailara_scrollPos`. The Perl code then calls simple JS functions instead of constructing full `window.scroll(...)` strings.
2. **Kiosk mode CSS:** Inject CSS to disable text selection, hide scrollbars, or force pointer events without relying on the page's own styles.
3. **Remove `run_javascript` for static injections:** Replace runtime JS calls that configure the page with load-time injections.

**Priority: LOW-MEDIUM** — Useful for cleanliness but not blocking any current functionality.

---

### 4d. `WebKitCookieManager` — per-context cookie control

#### API

```perl
my $cookie_manager = $web_context->get_cookie_manager;
$cookie_manager->set_accept_policy('WEBKIT_COOKIE_POLICY_ACCEPT_NEVER');
$cookie_manager->delete_all_cookies;
$cookie_manager->set_persistent_storage('/path/to/cookies.db', 'WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE');
```

#### relevance

The current code disables HTML5 local storage via settings but does not explicitly manage cookies. For kiosk mode, cookies should be disabled or ephemeral. With `WebKitCookieManager`, cookies can be:
- Rejected entirely (`ACCEPT_NEVER`)
- Accepted only for the session (`ACCEPT_NO_THIRD_PARTY`)
- Stored in a custom location

**Priority: LOW** — Kiosk mode works without this, but it's a privacy improvement.

---

### 4e. `WebKitNetworkProxySettings` — proper proxy API

Already covered in section 3.1. This is the replacement for `HTTP::Soup` proxy configuration.

**Priority: HIGH** — Proxy support is currently broken.

---

### 4f. `WebKitWebView:is-ephemeral` — proper private browsing

#### API

`is-ephemeral` is a **construct-only, read-only** boolean property on `WebKitWebView`.

```perl
my $view = Browser::WebView->new_with_context($web_context);
# Cannot set is-ephemeral after construction
```

To create an ephemeral view, use an ephemeral `WebKitWebContext`:

```perl
my $data_manager = Gtk3::WebKit2::WebsiteDataManager->new_ephemeral;
my $web_context = Gtk3::WebKit2::WebContext->new_with_website_data_manager($data_manager);
my $view = Browser::WebView->new_with_context($web_context);
```

Or, simpler, create the WebView with the `is-ephemeral` property at construction:

```perl
my $view = Browser::WebView->new(
    'web-context' => $web_context,
    'is-ephemeral' => 1
);
```

#### relevance

Replaces the deprecated `enable-private-browsing` setting. For kiosk mode, ephemeral mode ensures no persistent storage (cookies, localStorage, cache) survives between sessions.

**Priority: MEDIUM** — Improves privacy and removes deprecation warning.

---

### 4g. `webkit_web_view_set_background_color()` — rgba background with alpha

#### API

```c
void webkit_web_view_set_background_color (WebKitWebView *web_view, const GdkRGBA *rgba);
```

#### relevance to transparency

If the web-browser zenka renders pages that have transparent backgrounds (or if the page background is overridden to transparent), `set_background_color` with `alpha < 1.0` allows the underlying GtkOverlay/widget background to show through the WebView.

Current code has this commented out:
```perl
# my $bg_rgba = Gtk3::Gdk::RGBA->new();
# $bg_rgba->parse('#0000FF');
# $view->set_background_color($bg_rgba);
```

The likely reason it "did not work" is that `parse('#0000FF')` sets alpha = 1.0 (opaque), so no transparency is visible. For true transparency:

```perl
my $bg_rgba = Gtk3::Gdk::RGBA->new();
$bg_rgba->parse('rgba(0, 0, 19, 0.0)');  # fully transparent
$view->set_background_color($bg_rgba);
```

Additionally, the page's `<body>` must not have an opaque background color. For the loading page / blank page, use:
```html
<body style="background: transparent;">
```

**Priority: LOW-MEDIUM** — Could simplify the fade effect by removing ScrolledWindow opacity manipulation, but current approach works.

---

### 4h. `WebKitProcessModel` — process isolation

#### API

```c
typedef enum {
    WEBKIT_PROCESS_MODEL_SHARED_SECONDARY_PROCESS,
    WEBKIT_PROCESS_MODEL_MULTIPLE_SECONDARY_PROCESSES
} WebKitProcessModel;
```

#### current state

`web-browser.open_window` already sets:
```perl
$web_context->set_process_model('WEBKIT_PROCESS_MODEL_MULTIPLE_SECONDARY_PROCESSES');
```

This is correct and provides process isolation between different sites. No change needed.

---

### 4i. `WebKitAutomationSession` — W3C WebDriver

#### API

WebKit2GTK supports W3C WebDriver automation via `WebKitAutomationSession`. This is typically enabled by setting the `WEBKIT_INSPECTOR_HTTP_SERVER` environment variable or by using `webkit_web_context_set_automation_allowed()`.

#### relevance

Could provide an alternative automation path for the visual-feedback system or external testing. However, `get_snapshot()` is simpler and more direct for the capture use case. WebDriver is more useful for external tools that need to drive the browser.

**Priority: LOW** — Interesting for future expansion but not needed for current goals.

---

## 5. ui zenka separation

### desired architecture

The long-term vision is:
- `web-browser` zenka: owns the WebKit process, renders content, no UI chrome
- `web-browser-ui` zenka: toolbar, tabs, URL bar, controls — separate process
- Communication via P7 routing (`web-browser-ui.cmd.navigate` → routes to `web-browser`)
- Mixed modes: kiosk (UI disabled, automation controls all) vs interactive (UI visible + user input)

### XEmbed/GtkSocket feasibility

GTK3 still provides `GtkSocket` and `GtkPlug` for X11 embedding:

```perl
# Socket side (web-browser-ui zenka)
my $socket = Gtk3::Socket->new();
$container->add($socket);
my $window_id = $socket->get_id;  # X11 Window ID

# Plug side (web-browser zenka)
my $plug = Gtk3::Plug->new($window_id);
$plug->add($web_view);
```

**Verdict: NOT RECOMMENDED for WebKit2 WebView.**

Reasons:
1. **GL compositing incompatibility.** WebKit2GTK uses hardware-accelerated compositing (EGL/GLX). Reparenting a GL window into a foreign `GtkSocket` often results in rendering artifacts, black regions, or complete failure.
2. **Input event routing.** Touch, scroll, and key events may not propagate correctly across the socket/plug boundary to the WebView.
3. **WebKit2 already has process separation.** The web content runs in a separate process (`WebKitWebProcess`). The UI process is already lightweight. Adding another layer of XEmbed separation provides no benefit and adds significant complexity.
4. **Wayland future.** `GtkSocket`/`GtkPlug` are X11-only. If the system ever migrates to Wayland, this architecture breaks completely.

### recommended separation model

**Control separation, not visual embedding.**

```
┌─────────────────────────────────────┐
│  web-browser-ui zenka               │
│  (Gtk3 window with toolbar/tabs)    │
│                                     │
│  [URL bar] [Back] [Fwd] [Refresh]   │
└──────────┬──────────────────────────┘
           │ P7 command route
           │  (e.g., `web-browser.cmd.load_uri`)
           ▼
┌─────────────────────────────────────┐
│  web-browser zenka                  │
│  (Gtk3 window with WebKitWebView)   │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  WebKitWebView              │    │
│  │  (rendering + input)        │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

The `web-browser` zenka owns its own top-level `GtkWindow` containing the WebView. The `web-browser-ui` zenka sends navigation and control commands via P7. In interactive mode, both windows are visible and positioned/coordinated via P7. In kiosk mode, the UI zenka is not started.

If a single visual frame is absolutely required, the `web-browser-ui` zenka can position its window to surround the browser window (using X11 window management or GTK layer-shell), rather than embedding the WebView widget.

**Conclusion:** UI zenka separation is feasible and desirable, but **must use P7 command routing, not XEmbed/GtkSocket.**

---

## 6. upgrade plan

The following tasks are ordered by priority and dependency. Each is designed to be approximately one Kimi session of work.

### Task 1: Fix 4.0 → 4.1 introspection and remove deprecated settings
**Files:** `src/web-browser.init_code`, `src/web-browser.set_properties`
**Work:**
- Change `version 4.0` → `version 4.1` in `init_code`
- Remove `enable-plugins`, `enable-offline-web-application-cache`, `enable-html5-local-storage`, `enable-html5-database`, `enable-frame-flattening` from `set_properties`
- Test that the web-browser zenka still loads and renders pages
**Priority:** CRITICAL — currently broken on the system

### Task 2: Rewrite proxy setup with WebKitNetworkProxySettings
**Files:** `src/web-browser.proxy_setup`, `src/web-browser.disable_proxy`, `src/web-browser.init_code`
**Work:**
- Remove `HTTP::Soup` import from `init_code`
- Implement proxy activation using `Gtk3::WebKit2::NetworkProxySettings->new()` and `$web_context->set_network_proxy_settings()`
- Fix `disable_proxy` to use `set_network_proxy_settings('WEBKIT_NETWORK_PROXY_MODE_NO_PROXY', undef)` instead of the nonexistent `get_default_session()`
- Test with `cfg.use_proxy = yes` and `cfg.use_proxy = auto`
**Priority:** HIGH — proxy is completely broken

### Task 3: Implement request interception via `decide-policy`
**Files:** `src/web-browser.handler.request_starting_signal`, `src/web-browser.init_view`, `src/web-browser.load_uri`
**Work:**
- Rewrite `request_starting_signal` with the WebKit2 `decide-policy` signature: `($view, $decision, $decision_type)`
- Connect the signal in `init_view` for all new views
- Implement domain whitelist logic using `WebKitNavigationPolicyDecision->get_request->get_uri`
- Reject blocked requests with `$decision->ignore()` and `return TRUE`
**Priority:** HIGH — security feature missing since 2019 migration

### Task 4: Replace JS `throw` hack with `evaluate_javascript()`
**Files:** `src/web-browser.js_call`, `src/web-browser.cmd.run_js`
**Work:**
- Replace `run_javascript` + `throw` prefix with `evaluate_javascript` + `evaluate_javascript_finish`
- Extract return values properly from `JSCValue->to_string()` instead of parsing exception strings
- Maintain backward compatibility with existing callers
**Priority:** MEDIUM — code quality and robustness

### Task 5: Implement `get_snapshot()` for native screenshot capture
**Files:** new module `src/web-browser.cmd.get_snapshot`, possibly `src/web-browser.handler.snapshot_result`
**Work:**
- Implement async `get_snapshot('WEBKIT_SNAPSHOT_REGION_VISIBLE', ...)` call
- Convert resulting `GdkPixbuf` to PNG and save to configurable path
- Add P7 command `web-browser.cmd.get_snapshot` returning `{ mode => 'deferred', data => $path }`
- Update `data/tasks/visual-feedback-capture-analyzer.md` to use the new command instead of chromium-headless/Xvfb
**Priority:** HIGH — unblocks visual-feedback pipeline simplification

### Task 6: Add ephemeral/private-browsing mode support
**Files:** `src/web-browser.init_view`, `src/web-browser.open_window`
**Work:**
- Create ephemeral `WebsiteDataManager` and `WebContext` when `cfg.private_mode = 1`
- Ensure `is-ephemeral` is set at WebView construction time
- Remove/deprecate the commented `enable-private-browsing` setting reference
**Priority:** MEDIUM — privacy hardening for kiosk mode

### Task 7: Evaluate `WebKitUserContentManager` for auto-scroll injection
**Files:** `src/web-browser.init_view`, `src/web-browser.handler.auto_scroll`, `src/web-browser.js_call`
**Work:**
- Prototype injecting a scroll controller script via `UserContentManager->add_script()` at `document-start`
- Compare performance and reliability against runtime `run_javascript` scrolling
- Decide whether to adopt or keep current approach
**Priority:** LOW — research task, not blocking

### Task 8: UI zenka separation — control routing architecture
**Files:** `cfg/zenki/web-browser-ui/`, new modules `web-browser-ui.cmd.*`
**Work:**
- Design P7 command API surface: `web-browser-ui.cmd.navigate`, `.cmd.back`, `.cmd.reload`, `.cmd.set_zoom`, etc.
- Implement `web-browser-ui` zenka as a GTK3 toolbar window (no WebView)
- Route all commands to the existing `web-browser` zenka via P7
- Support both kiosk mode (UI hidden) and interactive mode (UI visible)
- Document window positioning coordination between the two zenkas
**Priority:** LOW — architectural foundation for future expansion

---

*Document generated: 2026-05-20*
*WebKit2GTK version analyzed: 2.50.5 (libwebkit2gtk-4.1-0)*
*System: Debian unstable / libgtk3-webkit2-perl 0.06-6*

#,,..,.,.,...,...,...,,..,,,,,,,.,...,.,.,.,,,..,,...,...,.,,,,,.,...,.,,,..,,
#TKIWQFYW5ELPKNPRXOFUTQIF6VSK6TYIT2KBCGFPMWTIMUDNSKBKVMOSUO5TH73FXE7QAHLDZNGB4
#\\\|ZOR6JGMTBLKATCNOZISFRIU6V4QZ5FUNU5AUR4X3DNZVT4DF4GL \ / AMOS7 \ YOURUM ::
#\[7]IQXFCYB2WLRD5KWG5OVJ4HKFRP3AVZMJGUVRSZD4Q36WCPLESMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
