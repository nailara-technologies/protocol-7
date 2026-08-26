## [:< ##

# name  = task: web-browser — replace run_javascript throw hack with evaluate_javascript
# descr = migrate js_call and cmd.run_js from the throw-exception return value
#         hack to the proper evaluate_javascript / JSCValue API

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

`src/web-browser.js_call` and `src/web-browser.cmd.run_js` use a
fragile hack to capture JavaScript return values:

```perl
$js_string = "throw $js_string";   ## wrap in throw to capture return value
$view->run_javascript($js_string, undef, sub {
    eval { $s_res = $self->run_javascript_finish($result) };
    ( my $ex_str = $EVAL_ERROR ) =~ s| at /usr/.+\n$||;
    ## parse result from exception string
});
```

this breaks if the JS expression itself throws, and is fragile in general.

WebKit2GTK 4.1 provides `evaluate_javascript` + `evaluate_javascript_finish`
which returns a `JSCValue` object — proper async return values without hacks.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 4b (evaluate_javascript).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat src/web-browser.js_call       ## current throw hack implementation
cat src/web-browser.cmd.run_js    ## uses js_call — check callers
cat src/web-browser.handler.auto_scroll  ## primary caller of js_call
```

---

## fix: web-browser.js_call

replace `run_javascript` + throw hack with `evaluate_javascript`:

```perl
## new signature: same as before — $js_string, $callback, $reply_id
my ( $js_string, $callback, $reply_id ) = @_;

my $view_index = <web-browser.overlay.index.fg> // 1;
my $view       = <web-browser.gtk_obj.view>->{$view_index};

return unless defined $view;

$view->evaluate_javascript(
    $js_string,
    -1,      ## length: -1 = null-terminated string
    undef,   ## world_name: default world
    undef,   ## source_uri
    undef,   ## cancellable
    sub {
        my ( $view, $result ) = @_;
        my $jsc_value = eval { $view->evaluate_javascript_finish($result) };
        my $result_str = '';
        $result_str = $jsc_value->to_string if defined $jsc_value;
        $callback->($result_str) if defined $callback;
        ## reply if reply_id given — match existing deferred reply pattern
    },
    undef    ## user_data
);
```

## fix: web-browser.cmd.run_js

read the current module. it likely calls `js_call` or uses `run_javascript`
directly. if it uses `js_call`, the fix above propagates. if it has its own
`run_javascript` call, apply the same `evaluate_javascript` replacement.

## verify callers unchanged

check that `web-browser.handler.auto_scroll` and any other callers of
`js_call` still work with the new implementation — the callback interface
should be unchanged.

```bash
grep -rn 'js_call\|run_javascript\|run_js' src/web-browser.* | grep -v Binary
```

## success criteria

- [ ] `web-browser.js_call` uses `evaluate_javascript` (not `run_javascript`)
- [ ] no `throw` prefix wrapping in js_call
- [ ] return value extracted via `JSCValue->to_string` (not exception parsing)
- [ ] `web-browser.cmd.run_js` uses the updated path
- [ ] `web-browser.handler.auto_scroll` still calls js_call correctly
- [ ] no `run_javascript` calls remain in web-browser modules
- [ ] no signature stubs added, no whitelist changes

#,,.,,..,,.,,,...,,,.,,.,,,..,,,,,,,.,,,.,...,..,,...,...,...,,..,.,,,,,.,..,,
#BDPALSGLB5ZSAIB3JG6IYJPMKB6PICFYPXAQ2KPOPP4TQNDWWSZ3W4HC3SKC5OUKAO5ZUG4XZTK7M
#\\\|CKB4JXHLX3TWXETBQV55WDFXES34LGTLL2R3YP5H25S5TTYJH6J \ / AMOS7 \ YOURUM ::
#\[7]CVW4DXA6ELSW2PGX4SLTBG36L2AM4NRY2T2LT7NQMRJUVDETYMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
