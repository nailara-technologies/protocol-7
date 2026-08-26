---
name: topic-jobsite-firefox-webfont-resolved
description: "jobsite UI White Rabbit heading font now renders correctly in real Firefox (172.24.33.224), confirmed 2026-08-07 — was a long-standing WebKit-only-render gap"
metadata:
  node_type: memory
  type: project
---

The jobsite UI's White Rabbit terminal heading font previously rendered fine in the
`web-browser` zenka's WebKit-based check but was reported broken in real Firefox — see
[[feedback-webkit-vs-firefox-css-blindspots]] for the general pattern of Firefox-only bugs
invisible to WebKit-based verification. This one, however, turned out NOT to be a rendering-
engine CSS quirk like those two: session `5db59013` traced the actual root cause to a
Firefox **profile preference**, `browser.display.use_document_fonts` set to `0` — disabled
by that profile's arkenfox `user.js` hardening for anti-fingerprinting. With that pref off,
Firefox ignores *all* `@font-face` declarations globally, on every site, regardless of how
the font is served (TTF, WOFF, WOFF2, http, https — none of it matters). Commit `bc87f8285`
("jobsite: header layout fix + embed White Rabbit web font") reduced the font to a single
self-hosted WOFF2 (`data/web-root/vhosts/jobs.vhost/white-rabbit.flipped.woff2`, 4.6K vs 17K
source TTF) — a real cleanup, but not what actually fixes rendering in a hardened profile.

**Confirmed root cause, 2026-08-07 (isolated by direct test, not guessed)**: user's
`browser.display.use_document_fonts` pref is still `0` — it never flipped back. What
actually made jobsite's font render is that during the testing session the user separately
added `White Rabbit` / `White Rabbit Flipped` to a Firefox **font_allowlist**
(per-font-name exception that permits specific listed font-family names through even while
`use_document_fonts` blocks everything else). Removing the two allowlist entries and
reloading immediately reverted jobsite to the broken (fallback-font) state, confirming the
allowlist entry — not commit `bc87f8285`'s WOFF2 embed — is the operative fix. The WOFF2
work is still a legitimate size cleanup, just not what makes Firefox actually load the font.

With the allowlist entries removed, the page additionally surfaced jobsite's own
`notify()` sync-error toast — `'sync fehler: ' + e.message` from the `JOBS_SYNC` poll
fetch's catch block (`index.html:966`/`:1043`) — displaying Firefox's raw
`e.message` text, which happened to read "NetworkError when attempting to fetch resource".
That's a *different* network call than the font request (`JOBS_SYNC` backend polling, not
the WOFF2 GET), and the httpd access log showed a normal `304 Not Modified` for the font
request in the same window. **Not confirmed** whether the sync-fetch failure was actually
caused by the same font-visibility/allowlist mechanism (e.g. some broader anti-fingerprint
network-layer effect) or was coincidental to the test (server restart, timing, etc.) —
don't assert a causal link here without further testing; it's flagged as an open question,
not an established part of the root-cause chain.

**Still reproducing the original failure, useful as a live reference**:
`https://pri.v7.ax/font.html` still shows the broken state — same mechanism: whatever font
name(s) that page declares aren't on this profile's font_allowlist. Not a separate bug, no
need to debug the page or its HTTPS deployment — just add its font-family name(s) to the
allowlist if/when that page needs to work too.

**How to apply**: if a custom `@font-face` fails in Firefox specifically (works in
WebKit/every other engine, CSS/asset itself is fine), check, in this order: (1)
`about:config` → `browser.display.use_document_fonts` — if `0`, custom fonts are globally
blocked; (2) whether the specific `font-family` name is present in this profile's
font_allowlist exception list. A privacy-hardened profile (arkenfox and similar) disabling
document fonts makes any amount of font-serving/CSS cleanup irrelevant until the font name
is allowlisted — this is a profile-level permission problem, not a code problem, and no
amount of WOFF2 optimization, path fixing, or CORS/caching header tweaking will resolve it.

#,,,,,,..,...,,,,,...,,,,,.,.,,,,,,,,,,,.,,,,,..,,...,...,,.,,,..,,,.,,,,,,,,,
#ZIXE2EJ4PPU4HYFJ3XI5AG7PR575T2ANQW56GMZZ3UUDRCULIPFTOLCE4CESZ4BFCQGWBXWKTCC3I
#\\\|LQDHFABKUXAJFBO46WR6LP3MTAQVWXDVWFGGJVYBIJLHE4NOSXI \ / AMOS7 \ YOURUM ::
#\[7]ARKMSVUTTVUOVVUADEFOIBTIGX5HAIVDP7OZ4HJ4PMAOODVQHGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
