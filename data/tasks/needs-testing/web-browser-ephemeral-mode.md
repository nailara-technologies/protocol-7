## [:< ##

# name  = task: web-browser — ephemeral WebView and WebsiteDataManager control
# descr = replace deprecated enable-private-browsing with proper ephemeral context;
#         expose data policy as P7-controllable state

## context

the browser zenka is primarily a rendering engine fed by P7 zenki over localhost.
persistent browser state (localStorage, IndexedDB, cookies, cache) is redundant
in this model and creates hidden state that drifts between sessions.

the old `enable-private-browsing` setting (removed in fix task 1) has a proper
replacement: ephemeral `WebKitWebContext` or `WebKitWebsiteDataManager`.
this task implements that and exposes data policy as P7 commands.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
sections 3.6 (private browsing) and 4f (is-ephemeral), 4d (CookieManager).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures` —
the human will run it manually after all fixes are applied (requires signing key passphrase).
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat modules/web-browser.open_window
cat modules/web-browser.init_view
cat modules/web-browser.init_code
cfg/zenki/web-browser/zenka-startup.v7
```

understand how the `WebKitWebContext` is currently created in `open_window`,
and how views are constructed in `init_view`, before making changes.

---

## implementation

### 1. add cfg default in init_code

file: `modules/web-browser.init_code`

add alongside other `cfg.*` defaults:
```perl
<web-browser.cfg.ephemeral>  //= 1;   ## default: no persistent storage
```

default is 1 (ephemeral) — the rendering engine model. interactive user mode
sets this to 0 in `zenka-startup.v7` to allow persistent storage.

### 2. create ephemeral context when cfg.ephemeral = 1

file: `modules/web-browser.open_window`

read the current file. find where `WebKitWebContext` is created. the current
code likely calls `Gtk3::WebKit2::WebContext->get_default` or `->new`.

add conditional ephemeral context creation:
```perl
my $web_context;
if ( <web-browser.cfg.ephemeral> ) {
    my $data_manager = Gtk3::WebKit2::WebsiteDataManager->new_ephemeral;
    $web_context = Gtk3::WebKit2::WebContext->new_with_website_data_manager(
        $data_manager
    );
} else {
    $web_context = Gtk3::WebKit2::WebContext->get_default;
}
<web-browser.gtk_obj.web_context> = $web_context;
```

if the context is already stored in `<web-browser.gtk_obj.web_context>`,
update that assignment. preserve any existing context setup that follows
(process model, cache model, etc.).

### 3. add P7 command: web-browser.cmd.clear_data

new file: `modules/web-browser.cmd.clear_data`

clears all website data from the current context on demand:
```perl
## [:< ##

# name = web-browser.cmd.clear_data

my $context = <web-browser.gtk_obj.web_context>;
return 'no web context' unless defined $context;

## clear all data types
my $data_manager = $context->get_website_data_manager;
$data_manager->clear(
    'WEBKIT_WEBSITE_DATA_ALL',
    0,    ## timespan 0 = all time
    undef,
    sub { <[base.log]>->( 1, 'website data cleared' ) },
    undef
);

return 'ok';
```

### 4. add P7 command: web-browser.cmd.set_cookie_policy

new file: `modules/web-browser.cmd.set_cookie_policy`

controls cookie acceptance policy at runtime:
```perl
## [:< ##

# name = web-browser.cmd.set_cookie_policy

my $call  = shift;
my $policy = $call->{'data'} // 'never';

## valid policies: never  no-third-party  always
my %policy_map = (
    qw| never         WEBKIT_COOKIE_POLICY_ACCEPT_NEVER        |,
    qw| no-third-party WEBKIT_COOKIE_POLICY_ACCEPT_NO_THIRD_PARTY |,
    qw| always        WEBKIT_COOKIE_POLICY_ACCEPT_ALWAYS       |,
);

my $wk_policy = $policy_map{$policy}
    // return "unknown policy '$policy'";

my $cookie_manager
    = <web-browser.gtk_obj.web_context>->get_cookie_manager;
$cookie_manager->set_accept_policy($wk_policy);

return "cookie policy: $policy";
```

### 5. add commands to start config

file: `cfg/zenki/web-browser/zenka-startup.v7`

add `cfg.ephemeral = 1` under the existing cfg settings (or confirm it's not
already there). this makes ephemeral the default without needing init_code change.

---

## notes

- `WebsiteDataManager->new_ephemeral` is available in WebKit2GTK 2.16+ (2.50 here)
- in ephemeral mode: no cookies, no localStorage, no IndexedDB, no disk cache
  — all in-memory only, gone when the WebView is destroyed
- `clear_data` command is useful even in ephemeral mode between slideshow cycles
  to ensure no cross-site state leaks through in-memory storage
- `set_cookie_policy` is mainly useful for non-ephemeral (interactive) mode

## success criteria

- [ ] `cfg.ephemeral` default added (value: 1)
- [ ] ephemeral context created when `cfg.ephemeral = 1`
- [ ] default context used when `cfg.ephemeral = 0`
- [ ] `web-browser.cmd.clear_data` module exists and calls `website_data_manager->clear`
- [ ] `web-browser.cmd.set_cookie_policy` module exists with `never`/`no-third-party`/`always`
- [ ] no persistent storage created during normal rendering-engine operation
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,.,.,.,..,,,.,,,..,.,,,..,,.,,,...,...,.,,,..,,...,...,..,,,,,,..,,.,.,.,,,
#NJIPBXHAEPWQUNHPT54TRJ7UMTHW2TTKFZYDK4S7AMLQWOKLKT44NOA3K2BCF2PHSLZXH5OUDSHOG
#\\\|BS2XOM7NTO4BWYZCRBGBQFP2Y7WFA4DFJAPKE3AOAGR3A4BPMZ2 \ / AMOS7 \ YOURUM ::
#\[7]OW23NKXJLQWTJ53J4GMLLNUJRXFNGGHY7FLRRAAGOWMKOHHRZYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
