---
name: feedback-web-browser-js-form-fill-reset-on-submit
description: "web-browser.run_js filling a React-style controlled input (native setter + input/change/keyup events dispatched) displayed correctly and survived blur, but the field silently reset to empty every time the form's Continue button was clicked via JS -- likely the SPA's own submit validation rejecting the value server-side and clearing it, not a synthetic-event dispatch failure; switched to interactive mode instead of chasing it further"
metadata:
  type: feedback
---

Hit live 2026-07-29 trying to drive the Nessus setup wizard
(`https://localhost:8834/`) through `web-browser.cmd.run_js` instead of
interactive mode.

**What worked**: filling a controlled `<input>` via the native-setter +
dispatched-events pattern (needed because React/Vue's controlled inputs
ignore a plain `el.value = '...'` assignment — the framework's own
`onChange` never fires, so its internal state never updates even though
the DOM shows the new value):

```js
var nativeSetter = Object.getOwnPropertyDescriptor(
    window.HTMLInputElement.prototype, 'value'
).set;
nativeSetter.call(inp, 'the value');
inp.dispatchEvent(new Event('input', {bubbles: true}));
inp.dispatchEvent(new Event('change', {bubbles: true}));
```

This displayed correctly and survived a `blur()` — confirmed via
`web-browser.cmd.get_snapshot` before ever clicking submit.

**What failed, repeatedly, same way each time**: clicking the page's
"Continue" button via
`document.evaluate("//*[normalize-space(text())='Continue']", ...)` +
`.click()` — the email field silently reset to its empty placeholder
every single time, even after adding a `keyup` KeyboardEvent to the
dispatch chain on a retry. Two attempts, identical failure mode.

**Why (user's read, more likely than my first guess)**: the XPath
text-match `//*[normalize-space(text())='Continue']` almost certainly
landed on the wrong element — there was a "Reset" button positioned
right beside "Continue," and a same-name/near-duplicate-structure match
picked that one instead. A reset button clearing the field on click
would produce exactly this symptom (identical failure both times,
regardless of how carefully the input events were dispatched) without
needing any server-side validation theory at all. My first hypothesis
(app-level validation rejecting the value) was a guess made without
checking what element the XPath actually resolved to — should have
logged/highlighted the matched element before clicking, not after two
failed attempts.

**How to apply**: when a `run_js` text-match click produces a
suspicious/wrong-looking result, first verify *which* element the
XPath/selector actually resolved to (log its tag, class, or outline it
visually) before assuming the app's own logic is misbehaving — a
same-text or nearby-element mismatch is a simpler and more common
explanation than framework/backend validation weirdness. Only fall back
to interactive mode if the matched element is confirmed correct and the
behavior is still wrong.

#,,,,,,,,,...,,..,,,.,...,,.,,,,,,.,.,.,,,.,.,..,,...,...,,,,,.,,,.,.,...,,..,
#SNPQKER6Z3OYC4IWI7J67TLPY77TOZEAPTBKYH3EC4XGBFYZDRIY3WYEZEHET4H6M4EQTHAWR5H2E
#\\\|CRHB4KQNGIDNGX5KX7EOIBTOAEVGOK43EZGJVGGL75CCFX4TO5A \ / AMOS7 \ YOURUM ::
#\[7]DFS7B7YWQD6BBBRDNC2KJS3PJOEWKMPD2PSIYN6M3KMWKW4IDIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
