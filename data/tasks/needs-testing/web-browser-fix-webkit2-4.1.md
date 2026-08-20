## [:< ##

# name  = task: web-browser fix — WebKit2GTK 4.0 → 4.1 and deprecated settings
# descr = critical fixes: introspection version bump + remove dead properties

## context

the web-browser zenka currently fails to load because the installed WebKit2GTK
is version 4.1 but the introspection setup line targets version 4.0 (typelib not found).
additionally, `set_properties` contains several deprecated/removed settings that
generate warnings or silently do nothing in WebKit2GTK 4.1.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 1 (api version) and section 2 (deprecated settings).

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## fix 1: introspection version in init_code

file: `src/web-browser.init_code`

change:
```perl
Glib::Object::Introspection->setup(
    qw| basename WebKit2 version 4.0 package Gtk3::WebKit2 |);
```

to:
```perl
Glib::Object::Introspection->setup(
    qw| basename WebKit2 version 4.1 package Gtk3::WebKit2 |);
```

this is a single character change (4.0 → 4.1). no other WebKit2 API changes
are required — the 4.0 and 4.1 GObject API surface is identical.

## fix 2: remove deprecated settings from set_properties

file: `src/web-browser.set_properties`

remove these lines entirely (deprecated/removed in WebKit2GTK 4.1, no effect):
```perl
$settings->set_property( 'enable-plugins', <web-browser.cfg.plugins_enabled> );
$settings->set_property( 'enable-offline-web-application-cache', 0 );
$settings->set_property( 'enable-html5-local-storage', 0 );
$settings->set_property( 'enable-html5-database',      0 );
$settings->set_property( 'enable-frame-flattening',     1 );
```

also remove this commented-out deprecated line (plus its comment):
```perl
###    $settings->set_property( 'enable-private-browsing',     1 );
##
# LLL: use #WebKitWebView:is-ephemeral or #WebKitWebContext:is-ephemeral instead
```

the `enable-private-browsing` replacement (ephemeral WebView) is a separate
task — just remove the dead comment here.

keep these (still valid in 4.1):
- `set_enable_javascript(...)`
- `javascript-can-access-clipboard`
- `enable-fullscreen`
- `enable-site-specific-quirks`
- `enable-smooth-scrolling`

## fix 3: remove cfg.plugins_enabled default if orphaned

file: `src/web-browser.init_code`

check if `<web-browser.cfg.plugins_enabled> //= 0;` is still set in init_code.
if so, remove it — the setting is no longer referenced anywhere after fix 2.

also check `cfg/zenki/web-browser/zenka-startup.v7` for any
`cfg.plugins_enabled` line and remove it if present.

## verification

after applying fixes, verify:
```bash
## check that the typelib now resolves at runtime:
perl -e "
  use Gtk3 -init;
  use Glib::Object::Introspection;
  Glib::Object::Introspection->setup(
    basename => 'WebKit2', version => '4.1', package => 'Gtk3::WebKit2'
  );
  print 'ok: WebKit2 4.1 loaded\n';
"
```

## success criteria

- [ ] introspection line changed to version 4.1
- [ ] perl one-liner above prints "ok: WebKit2 4.1 loaded" with no errors
- [ ] five deprecated `set_property` calls removed from set_properties
- [ ] deprecated `enable-private-browsing` comment block removed
- [ ] `cfg.plugins_enabled` default and any config reference removed
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,.,,.,.,,,,,,.,,.,.,...,,.,,.,,,...,,,.,,.,,..,,...,..,,.,.,.,.,,,,,,,.,,.,,
#5AQQQMZQ5E6DEEUHW5QHPBD32E3IIBXQKYV2XSPIKSYN5JDEVPSVO4BCTG3ZPGAMIRRFY6LK2QKYK
#\\\|4WBGMDAK42OKB3ZDZZVWWXZUZBL7HB2FC4ZU4IWF5QQ33XUWYJU \ / AMOS7 \ YOURUM ::
#\[7]U6YIVWO2EJGMSKJIDOSE775PCBHZMXPFZT3RI44ILW5IEU3LBYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
