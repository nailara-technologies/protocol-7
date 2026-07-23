---
name: webkit-double-click-dispatch
description: the web-browser zenka's WebKit fires two native click events for one physical click on some buttons — Firefox doesn't; wrap handlers in a shared debounce, don't patch one button at a time
metadata:
  type: feedback
---

## the trap

A single physical click/tap on a button in the web-browser zenka
(WebKit) can dispatch the `click` event twice in quick succession.
Firefox, on the same page, same button, fires once as expected.

Symptom is whatever the handler does, applied twice: a toggle button
that should open a panel opens then immediately closes itself again; a
counter-increment button ("reveal one more item") jumps by two instead
of one. Easy to misdiagnose as application logic — the handler itself
is correct, it's just genuinely being invoked twice.

Found and fixed live in [[topic-job-pipeline]]'s trash-history panel
(2026-07-23 session) — first patched only the toggle button with an
ad-hoc per-button timestamp guard when that was the first symptom
reported, then had to generalize once a second, unrelated button in the
same panel showed the identical symptom.

**How to apply**: don't patch WebKit double-click symptoms one button
at a time as each gets reported — wrap every click handler in a shared
debounce from the start on any UI that will be tested through the
web-browser zenka:

```js
function debounceClick(fn, ms = 250) {
    let last = 0;
    return (...args) => {
        const now = Date.now();
        if (now - last < ms) return;
        last = now;
        return fn(...args);
    };
}
el.addEventListener('click', debounceClick(() => { ... }));
```

Per-handler last-fire timestamp (not one shared global timestamp) so
unrelated buttons don't block each other. See
[[feedback-webkit-vs-firefox-css-blindspots]] for the sibling CSS-side
category of WebKit-vs-Firefox divergence in this project — this is the
same "WebKit-blind, Firefox looks fine" testing gap, but on the event
side rather than styling.

#,,,.,.,.,,,,,,,.,.,.,,,.,,,,,.,.,..,,.,.,,..,...,...,...,,,,,,,.,...,,.,,,,.,
#3BJWFH6TUP6UKJBVFQZ6YPOBAWITS3VBQ3R4VRIE7JHCD2GBNS62ON3JY7XZUHIKK4WVIVPCMZQRK
#\\\|PWBCV44NNJSQ54DW7XLEDYSQWZ5UZSAV3OIBEINYU5PN2XDRD7O \ / AMOS7 \ YOURUM ::
#\[7]O2BBH77JG74CQA6KADNIEHCBEDIIYXBOE2ZANEY27P7VYR2YX2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
