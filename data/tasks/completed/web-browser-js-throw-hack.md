## [:< ##

# name  = task: web-browser — replace JS throw hack with evaluate_javascript
# descr = migrate js_call and run_js from throw-prefix to JSCValue

## context

`src/web-browser.js_call` and `src/web-browser.cmd.run_js` use a
workaround to capture javascript return values:

```perl
$js_string = "throw $js_string";  # <-prepares result access through exception
```

they then call `run_javascript()` and parse the exception string to extract the
result. this is fragile and breaks if the JS expression itself throws.

WebKit2GTK 4.1 provides `evaluate_javascript()` which returns a `JSCValue`
object with `to_string()` — no throw hack needed.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 4b, and `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: migrate web-browser.js_call

file: `src/web-browser.js_call`

remove the throw prefix:
```perl
# $js_string = "throw $js_string";  # <-prepares result access through exception
```

replace `run_javascript` with `evaluate_javascript`:

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
        my $result_str = '';
        if ($jsc_value) {
            $result_str = $jsc_value->to_string;
        } else {
            $result_str = "error: $EVAL_ERROR";
        }
        ## ... pass $result_str to callback ...
    },
    { 're_cb' => $result_callback, 'cb_params' => $re_cb_params }
);
```

## fix 2: migrate web-browser.cmd.run_js

file: `src/web-browser.cmd.run_js`

apply the same pattern. the callback must send a P7 reply instead of calling a
Perl sub directly.

## fix 3: verify no regressions

test commands that exercise `js_call`:
- `web-browser.cmd.scroll_start` (auto-scroll)
- `web-browser.cmd.run_js` (manual JS execution)
- any slideshow or ticker that injects JS into the browser

## success criteria

- [ ] `throw` prefix removed from both modules
- [ ] `evaluate_javascript` + `evaluate_javascript_finish` used
- [ ] return values extracted via `JSCValue->to_string()`
- [ ] existing JS callers (scroll, run_js) work without regressions
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,.,,.,.,,..,..,,,,.,,..,,..,,..,..,,,,.,,,.,..,,...,...,.,,,,,.,...,.,.,...,
#IHPOYFTRFB47RUEVQLZHMU5X5DM4ZDYD6X6MQMQ63PRJTJNJSCNBLPLLOBYPMUKOXHSJPYH3IFBZY
#\\\|CWOL7GQEVTLOF74BU626KUNPDLLXGOSEBEGRFPNPEBM7Z2QCZGO \ / AMOS7 \ YOURUM ::
#\[7]XMJGP27Q7HSO2VVOVDE7DUOTUUXWR453CYPEFIQZFQW4SRT2OADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
