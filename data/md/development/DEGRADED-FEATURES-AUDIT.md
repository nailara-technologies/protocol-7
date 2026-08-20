# degraded features audit

## methodology

systematic scan of the full git history and current module tree for degradation
signals: incomplete ports, temporary workarounds, disabled features, and deferred
markers that were never resolved.

| scan | command | matches |
|------|---------|---------|
| incomplete / partial | `git log --oneline --all \| grep -iE 'incomplete\|not complete\|partial\|wip\|work.in.progress'` | 51 |
| forced migrations | `git log --oneline --all \| grep -iE 'port\|ported\|migrat\|upgrade\|replac' \| grep -iE 'incomplete\|broken\|workaround\|hack\|temporary\|quick.fix\|todo'` | 9 |
| degradation markers | `git log --oneline --all \| grep -iE '\[incomplete\]\|!incomplete\|broken\|disabled.*deprecated\|deprecated.*disabled'` | 58 |
| repair signals | `git log --oneline --all \| grep -iE 'repair\|workaround\|hack\|kludge\|stopgap\|temporary'` | 278 |
| deferred features | `git log --oneline --all \| grep -iE 'coming later\|for later\|TODO\|LLL\|fixme\|stub'` | 115 |
| forced/emergency | `git log --oneline --all \| grep -iE 'force\|emergency\|urgent\|quick\|<!>\|sudden\|disappear\|removed from.*repo'` | 108 |
| `<!>` commits | `git log --oneline --all \| grep '<!>'` | 8 |
| module LLL | `grep -rn '# LLL\|## LLL' src/ \| sort` | 329 |
| module TODO | `grep -rn '# TODO\|# FIXME' src/` | 117 |
| module broken/disabled | `grep -rn 'seems to not work\|not working\|broken\|disabled\|workaround' src/ \| head -80` | 80 |

note: the project has dual commits (each change committed twice in some eras).
duplicate messages were de-duplicated when counting.

focus areas: `src/` and `cfg/zenki/` — `bin/` and `data/` are lower
priority.

---

## high priority candidates

### candidate: screenshot-write-png
- **commit**: `44ca50f9f` (2020-02-14) "committed still incomplete implementation for 'screenshot.write_png' command"
- **files**: `src/screenshot.cmd.write_png`, `src/screenshot.grab_region`, `src/screenshot.scale_image`, `src/screenshot.pixel_color`
- **what was lost**: the `screenshot.write_png` command was committed as a stub that returns `"not implemented yet"` on the first line. however, the supporting modules (`grab_region`, `scale_image`, `pixel_color`) were fully implemented in the same commit.
- **current state**: the module still begins with `return { 'mode' => 'false', 'data' => "not implemented yet" };` — unreachable code after the return includes the actual implementation logic (parameter parsing, `grab_region` call, error handling).
- **fix**: remove the early stub return, test that `grab_region` returns an `Imager` object, wire the PNG write path (Imager's `write` method), and return the file path.
- **complexity**: small
- **value**: functionality
- **suggested task file**: `data/tasks/screenshot-write-png.md`

### candidate: ticker-reread-config
- **commit**: unknown (the disabling commit is not in the git log; likely edited in place)
- **files**: `src/ticker.cmd.reread_config`
- **what was lost**: config reload for the ticker zenka is completely disabled.
- **current state**: the very first line of the subroutine body is `return { 'mode' => 'false', 'data' => 'currently disabled! (buggy)' };`. the rest of the implementation (json import, font reload, file re-read, `base.init_modules`) exists but is unreachable.
- **fix**: remove the early return, test config reload in a non-production ticker instance, and fix any bugs that surface.
- **complexity**: trivial (enable) to small (if bugs exist)
- **value**: functionality
- **suggested task file**: `data/tasks/ticker-reread-config.md`

### candidate: source-code-header-check
- **commit**: unknown (line edited in place, comment says "temporarely disabled")
- **files**: `src/source.cmd.get-code-signed`
- **what was lost**: source code header validation (`## [:< ##`) is hardcoded off.
- **current state**: line 11 reads `my $expect_valid_code_header = FALSE; ## temporarely disabled ##`. this skips the header-check block that would reject files without the protocol-7 source header, weakening the signature system's integrity check.
- **fix**: change to `TRUE` or make it configurable via command parameter. verify that all current modules have valid headers before enabling globally.
- **complexity**: trivial
- **value**: security / code quality
- **suggested task file**: `data/tasks/source-code-header-check.md`

### candidate: mpv-xephyr-vo-override
- **commit**: `0c22a313c` (2019-12-03) "overriding 'xephyr.vo' in 'mpv' agent config [ as SDL is suddently broken ]"
- **files**: `cfg/zenki/mpv/start`, `src/mpv.init_code`
- **what was lost**: the mpv zenka forces `mpv.xmode.xephyr.vo = sdl` (and `mpv.xmode.nxagent.vo = sdl`) because SDL was "suddenly broken" in 2019. the default `mpv.vo_backend` is `gpu` (with `sdl` commented out), but xephyr mode overrides it back to `sdl`.
- **current state**: `cfg/zenki/mpv/start:57` still contains `mpv.xmode.xephyr.vo = sdl # [sdl|xv] <-- override if SDL is broken [dev.feature]`. `src/mpv.init_code:51` defaults `<mpv.xmode.xephyr.vo> //= qw| sdl |;`. SDL on Debian unstable in 2026 is likely stable again. forcing sdl instead of gpu loses hardware decoding and performance in nested X sessions.
- **fix**: test mpv with `gpu` (or `xv`) under xephyr. if stable, remove the override and let `mpv.vo_backend` propagate.
- **complexity**: trivial
- **value**: performance / functionality
- **suggested task file**: `data/tasks/mpv-xephyr-vo-override.md`

### candidate: weather-forecast-humidity
- **commit**: unknown (commented out in place)
- **files**: `src/weather.parent.extract_forecast`
- **what was lost**: humidity data is not included in weather forecast extraction.
- **current state**: line 97 contains `# 'humidity' is disabled as it always returned '0%'`. the openweathermap API may have changed since this was disabled. humidity is a useful forecast field.
- **fix**: check the current openweathermap API response structure for the `humidity` field, re-enable the line if the data is valid, and test with live API calls.
- **complexity**: small
- **value**: functionality
- **suggested task file**: `data/tasks/weather-forecast-humidity.md`

---

## medium priority candidates

### candidate: web-browser-js-throw-hack
- **commit**: `e13607469` (2019-07-26) WebKit2 migration introduced the throw workaround
- **files**: `src/web-browser.js_call`, `src/web-browser.cmd.run_js`
- **what was lost**: clean javascript return value handling. both modules prefix the JS string with `throw` to access the result through the exception path, because `run_javascript_finish` did not provide direct value access in the original WebKit2 Perl bindings.
- **current state**: `web-browser.js_call:36` — `$js_string = "throw $js_string"; # <-prepares result access through exception`. `web-browser.cmd.run_js` has the same pattern. WebKit2GTK 4.1 provides `evaluate_javascript()` which returns a `JSCValue` with `to_string()` — no throw hack needed.
- **fix**: migrate both modules to `evaluate_javascript()` + `evaluate_javascript_finish()` + `JSCValue->to_string()`. remove the throw prefix and exception-string parsing.
- **complexity**: small
- **value**: code quality / robustness
- **suggested task file**: `data/tasks/web-browser-js-throw-hack.md`

### candidate: base-parser-list-width
- **commit**: `6c2667527` (2016-06-20) "slightly adjusted table header width in 'base.parser.list' (still broken!)"
- **files**: `src/base.parser.list`
- **what was lost**: correct table column width calculation for certain key formats.
- **current state**: the TODO comment on line 25 reads `# todo = fix alignment [width] bug. [ex0:ex1 case]`. a partial fix was applied in commit `a6cb84fb6` (2026-03-09) for the `<key>:` prefix case, but the `ex0:ex1` case (nested key names with colons) may still misalign. the module is used by many list commands across zenki.
- **fix**: audit the width math for all key-name patterns (`plain`, `<key>:prefix`, `prefix:suffix`), write a test that renders known data and assert column widths, then fix any remaining off-by-N errors.
- **complexity**: small
- **value**: code quality
- **suggested task file**: `data/tasks/base-parser-list-width.md`

### candidate: universal-playlist-anti-desync
- **commit**: `6a372a199` (2016-02-18) "committed quick-fix for media agent desyncronization when reencoding videos"
- **files**: `src/universal.handler.get_list_reply`, `src/mpv.handler.rescale_video_reply`
- **what was lost**: clean playlist change handling. the universal zenka self-restarts as a "temporary [anti-desync] workaround" when the playlist changes while rescaling is active.
- **current state**: `universal.handler.get_list_reply:176` — `if (...) { # temporary [anti-desync] workaround; <[universal.self_restart]>; }`. `mpv.handler.rescale_video_reply:27` still references the original quick-fix. this causes unnecessary zenka restarts.
- **fix**: review the playlist change event ordering between `universal` and `mpv`. ensure rescale replies are synchronized with playlist updates without requiring a full restart.
- **complexity**: medium
- **value**: stability
- **suggested task file**: `data/tasks/universal-playlist-anti-desync.md`

---

## low priority / deferred

these are intentional LLL markers or architectural notes, not urgent fixes.

| module | marker | note |
|--------|--------|------|
| `base.event.add_io` | bytewise-mode question | architectural, Event.pm API detail |
| `base.net.connect` | unix socket implementation | feature request, not a degradation |
| `base.net.send_to_socket` | check write completeness | optimization, not broken |
| `base.handler.command` | incomplete SIZE reply stream transfer | large refactor, low urgency |
| `base.handler.deferred_compile` | "broken stub" | intentional pattern to prevent retry loops |
| `web-browser.init_code` | web extension for DOM access | research item, JS scroll works fine |
| `context.tree.index.position` | TODO: store position index | feature request |
| `base.editor.init_buffer` | stub for virtual editor buffer | feature request |

---

## not actionable

| item | reason |
|------|--------|
| web-browser WebKit2 4.0→4.1 migration | **resolved** — `src/web-browser.init_code` already uses `version 4.1` |
| web-browser proxy setup | **resolved** — `src/web-browser.proxy_setup` now uses `NetworkProxySettings`, `disable_proxy` uses `WEBKIT_NETWORK_PROXY_MODE_NO_PROXY` |
| web-browser request interception | **resolved** — `src/web-browser.handler.request_starting_signal` already ported to `decide-policy` with WebKit2 signature |
| web-browser deprecated settings | **resolved** — `src/web-browser.set_properties` no longer contains `enable-plugins`, `enable-private-browsing`, etc. |
| STRM-SIZE fragmentation | **resolved** — disabled in `c9c76584b` but fully reimplemented in commits `445c57de9`, `a8b9d9d37`, `1a472766c` |
| deprecated warnings in `bin/nailara` | **resolved** — `bin/nailara` was renamed to `bin/Protocol-7`; the `no warnings 'deprecated'` line was removed during refactor |
| X-11 DPMS blanking quickfix | **resolved** — the 2016 "temporary" fix (`DPMSDisable` + `SetScreenSaver`) is now the canonical implementation in `src/X-11.cmd.dpms-blanking-disable` |
| `mod-test` zenka incomplete | **resolved** — substantial functionality was added after the initial stub commit (`2bf6fc254`); the zenka is now operational |
| `base.handler.command` incomplete SIZE reply | **architectural** — the LLL refers to a future stream-type refactor, not a current bug |
| `base.handler.deferred_compile` broken stub | **intentional design** — prevents infinite retry loops for modules that fail compilation |

---

## summary

| priority | count | examples |
|----------|-------|----------|
| high | 5 | screenshot-write-png, ticker-reread-config, source-code-header-check, mpv-xephyr-vo-override, weather-forecast-humidity |
| medium | 3 | web-browser-js-throw-hack, base-parser-list-width, universal-playlist-anti-desync |
| low / deferred | 8+ | various LLL markers |
| not actionable | 10 | already resolved or architectural |

most of the web-browser WebKit2 degradation pattern (proxy, request interception,
deprecated settings) has been silently fixed in recent commits without dedicated
task tracking. the remaining degradation is scattered across smaller modules:
stubs that were never completed, overrides that outlived their reason, and
features that were disabled and forgotten.

---

*audit generated: 2026-05-20*
*commits scanned: ~5,000+ (full git history)*
*modules scanned: 3,900+ files in `src/`*

#,,..,,..,.,,,..,,.,,,.,,,,,.,,,,,.,,,..,,...,.,.,...,...,...,...,.,.,.,,,,..,
#WMN64JLU4MXKAV62QKD7NB5IREO5TNBJYOU2L7RF4D5NTPD3432Q2FKLHV2XLN4NFIIDTH6BVAOMM
#\\\|K22SGZNADPUCIRF2IGMM7IN2QWCKPDOEF2JI2LYGFDOX2BLFWW5 \ / AMOS7 \ YOURUM ::
#\[7]6DVZ2JNHB7VWWO42LB3SVTLO4SYKUJ7Z6WK5MEGPLXDLHF63WQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
