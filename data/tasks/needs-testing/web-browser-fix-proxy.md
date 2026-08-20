## [:< ##

# name  = task: web-browser fix — proxy setup rewrite for WebKit2GTK 4.1
# descr = replace broken HTTP::Soup proxy code with WebKitNetworkProxySettings

## context

proxy support in the web-browser zenka is completely broken:
- `web-browser.disable_proxy` calls `Gtk3::WebKit2::get_default_session()` which
  does not exist in WebKit2 — this throws a fatal error if proxy disable is called
- `web-browser.proxy_setup` constructs an `HTTP::Soup::URI` but never applies it
  (the `NetworkProxySettings` lines are commented out)
- `HTTP::Soup` is imported in `init_code` but is no longer needed

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 3.1 (proxy) and section 4e.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## fix 1: rewrite web-browser.proxy_setup

file: `src/web-browser.proxy_setup`

read the current file first. it creates an `HTTP::Soup::URI` but never applies it.

replace the body with WebKit2 proxy settings:
```perl
my $web_context = <web-browser.gtk_obj.web_context>;

my $proxy_addr = <web-browser.cfg.proxy_addr>;
my $proxy_port = <web-browser.cfg.proxy_port>;

my $proxy_settings = Gtk3::WebKit2::NetworkProxySettings->new(
    "http://$proxy_addr:$proxy_port",
    []    ## ignore-hosts: empty array = no exceptions
);
$web_context->set_network_proxy_settings(
    'WEBKIT_NETWORK_PROXY_MODE_CUSTOM',
    $proxy_settings
);
```

check the existing module for any `ignore_hosts` or per-host exception logic
that should be preserved — if so, add those hosts to the array.

## fix 2: rewrite web-browser.disable_proxy

file: `src/web-browser.disable_proxy`

read the current file first. it calls `get_default_session()` which is broken.

replace with:
```perl
my $web_context = <web-browser.gtk_obj.web_context>;

$web_context->set_network_proxy_settings(
    'WEBKIT_NETWORK_PROXY_MODE_NO_PROXY',
    undef
);
```

## fix 3: remove HTTP::Soup import from init_code

file: `src/web-browser.init_code`

remove:
```perl
<[base.perlmod.autoload]>->('HTTP::Soup');
```

verify no other module in the web-browser namespace uses `HTTP::Soup` before
removing. search: `grep -r 'HTTP::Soup\|Soup::' src/web-browser.*`

if any other module still uses it, leave the import and note it in a comment.

## fix 4: clean up init_code proxy flag default

file: `src/web-browser.init_code`

check if `<web-browser.cfg.use_proxy>` default is set. keep it — proxy enable/
disable logic still needs the flag. just ensure the default makes sense
(typically `use_proxy //= 0` for kiosk mode).

## verification

```bash
## verify proxy setup doesn't crash at module load:
perl -e "
  use Gtk3 -init;
  use Glib::Object::Introspection;
  Glib::Object::Introspection->setup(
    basename => 'WebKit2', version => '4.1', package => 'Gtk3::WebKit2'
  );
  ## check NetworkProxySettings constructor exists:
  my \$s = Gtk3::WebKit2::NetworkProxySettings->new('http://127.0.0.1:8080', []);
  print 'ok: proxy settings constructed\n';
"
```

## success criteria

- [ ] `proxy_setup` applies proxy via `WebKitNetworkProxySettings` (not HTTP::Soup)
- [ ] `disable_proxy` uses `WEBKIT_NETWORK_PROXY_MODE_NO_PROXY` (not `get_default_session`)
- [ ] `HTTP::Soup` autoload removed from `init_code` (or noted if still needed elsewhere)
- [ ] no `HTTP::Soup::URI` or `get_default_session` references remain in web-browser modules
- [ ] perl one-liner above confirms `NetworkProxySettings->new()` works
- [ ] signatures updated

#,,..,..,,.,,,.,,,.,.,.,.,.,,,...,.,,,,.,,...,..,,...,..,,.,,,,.,,,,.,,..,..,,
#HTTOQLPEJ2XY23EYL3CRBPRED54MF7CLHLX5HJ6TUMX4RPYBILUWHJEHSKS4XH7UUB6OO6XCBNVDM
#\\\|ZZL2CXP5ZTWB5MF5BCE33I6CROTYBUX4CLF2BDIBU5H5ZIGRVJG \ / AMOS7 \ YOURUM ::
#\[7]4YBCLGH2HHD3KJ6GVUCHG6FFRCFWJNXWH6IHXM4V7NVDRUSP4YDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
