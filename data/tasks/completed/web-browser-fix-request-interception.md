## [:< ##

# name  = task: web-browser fix — port request interception to WebKit2 decide-policy
# descr = rewrite request_starting_signal with WebKit2 decide-policy API and wire it up

## context

request interception (URL whitelist/blocking) was never ported from WebKit1.
the module `web-browser.handler.request_starting_signal` still has the WebKit1
5-parameter signature and is connected nowhere in the codebase. this is a
security gap for kiosk mode: the browser can navigate to arbitrary external URLs
if a loaded page contains redirects or links.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 3.4 (request-starting → decide-policy).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures` —
the human will run it manually after all fixes are applied (requires signing key passphrase).
do not add or modify subroutine whitelists — these are managed separately.

---

## fix 1: rewrite handler signature and logic

file: `modules/web-browser.handler.request_starting_signal`

read the current file first. the current (broken) WebKit1 signature is:
```perl
my ( $view, $frame, $resource, $request, $response ) = @_;
```

rewrite with the WebKit2 decide-policy signature:
```perl
my ( $view, $decision, $decision_type ) = @_;

## only intercept navigation decisions (not resource loads)
return FALSE unless $decision_type eq 'navigation-action';

my $request = $decision->get_request;
my $uri     = $request->get_uri;

## allow non-http/https schemes through (about:blank, data:, file:, etc.)
if ( $uri !~ m{^https?://}i ) {
    return FALSE;
}
```

then implement the existing whitelist logic, adapted from whatever the current
module body has. the WebKit2 way to block:
```perl
$decision->ignore;
return TRUE;    ## TRUE = handled (blocks default action)
```

to allow:
```perl
return FALSE;   ## FALSE = not handled (WebKit proceeds normally)
```

the config key for the whitelist is likely `<web-browser.cfg.allowed_domain>`
or similar — read the current module to find the exact key name and preserve
the logic. if no whitelist is configured, allow all navigation.

## fix 2: connect the signal in init_view

file: `modules/web-browser.init_view`

read the current file. find where other signals are connected to `$view`
(e.g., `load-changed`, `load-failed`, `notify::estimated-load-progress`).

add the decide-policy signal connection in the same block:
```perl
$view->signal_connect(
    'decide-policy' => $code{'web-browser.handler.request_starting_signal'}
);
```

## fix 3: remove WebKit1 signal connection if present

search for any remaining connection to `resource-request-starting` signal:
```bash
grep -r 'resource.request.starting\|request_starting' modules/web-browser.*
```

if found connected anywhere, remove that connection.

## verification

after fixes:
```bash
## check no WebKit1 signature remains:
grep -n 'my.*frame.*resource.*request.*response' modules/web-browser.handler.request_starting_signal
## should return nothing

## check signal is connected:
grep -n 'decide-policy\|request_starting_signal' modules/web-browser.init_view
## should show the signal_connect line
```

## notes

- `decision_type` values in WebKit2GTK: `'navigation-action'`, `'new-window-action'`,
  `'response'` — only `navigation-action` is needed for URL filtering
- `decide-policy` fires for main frame navigations AND iframe navigations —
  if the current whitelist was frame-aware in WebKit1, preserve that distinction
- if `cfg.links_clickable = 0` is set, all link navigations are already blocked
  at the `load_changed` level — the decide-policy handler adds a second layer
  for programmatic navigations (window.location, redirects)

## success criteria

- [ ] handler uses WebKit2 `($view, $decision, $decision_type)` signature
- [ ] `decide-policy` signal connected in `init_view`
- [ ] no WebKit1 5-parameter signature anywhere in web-browser modules
- [ ] no `resource-request-starting` connection anywhere
- [ ] whitelist logic preserved with correct WebKit2 `$decision->ignore` call
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,.,,.,,,.,,...,,,.,,..,.,.,...,...,..,,.,.,..,,...,...,,,.,.,,,,..,,,.,..,,
#SRQEYVKV2XNNMDV7T3LUYUFKI4XDTDPBA7V7SVL27ZV4O7Y3575BNVK6K2Q64PA2HAQQZ7MB2Q2EM
#\\\|2NTYZOQ4YBDCK3AATW6IXNBQA3NG37KBCBWCXSLOFC3WXV62EL2 \ / AMOS7 \ YOURUM ::
#\[7]6WDGNISN42W4HUZO7TICQHZSQQJYQDDA52YRUTFOJNTW2577O4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
