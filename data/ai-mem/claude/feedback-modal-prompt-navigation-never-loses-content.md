---
name: feedback-modal-prompt-navigation-never-loses-content
description: "user's design rule for in-frame/modal prompt input controls: a cancel-on-navigation key (Left-as-Esc) must gate on buffer CONTENT being empty, not cursor position -- ordinary cursor movement must never be able to discard what's been typed"
metadata:
  type: feedback
---

In `editor.control.prompt.handler.key` (the in-frame prompt primitive,
[[project-loader-deferred-compile-disabled-cmd-fix-2026-08-16]]'s sibling
feature), Left arrow originally cancelled the whole prompt unconditionally,
same as Esc/Ctrl-C -- design anchor 5 of `data/tasks/editor-inframe-prompt-
primitive.md` explicitly specified this shape. User caught it live: cancelling
on every Left press meant an ordinary cursor-navigation keystroke mid-typing
could silently throw away whatever had already been entered -- a real
foot-gun, not a style nitpick.

**The fix, and the rule it establishes**: Left now moves the cursor within
existing content (via `editor.control.commands.move_cursor`, same primitive
ordinary fields use), and only falls through to cancel once the buffer is
**genuinely empty** (`length($buffer->{'text'} // '') == 0`) -- the same
threshold Backspace already respects. Gated on buffer CONTENT, deliberately
NOT cursor position: a user who navigates all the way to column 0 without
deleting anything must still be able to press Left once more without losing
the text (cursor-position gating would have let that happen -- caught and
rejected during design, before implementing).

**How to apply**: any future modal/prompt input control in this project
(the deferred `masked`/credential FIELD task, rename/delete's own
confirmation-phrase prompts) must follow this same rule -- a key that ALSO
means "back out"/"cancel" (Left, Backspace-past-empty, etc.) may only trigger
the destructive/exit behaviour once the buffer holds nothing, never based on
where the cursor happens to sit. Content loss must require a deliberate,
visible action (typing it away via Backspace, or an explicit Esc/Ctrl-C),
never an ordinary navigation keystroke.

#,,,,,.,,,.,.,.,.,...,,,,,,.,,..,,,,,,,,.,,.,,..,,...,...,...,,,,,.,.,,,,,,,.,
#VV2PSNURG4DL2B2PT6N3RX7QUYJML6ZCBLRR56EQ4HIJLFW5SVF3RTQ3F4GE53VQEFMEOSK7UNF24
#\\\|K2TF75NWGBL6MTCVKWCHOIZYML4DMVFWQWMSWFFHMYHCRIL2HKT \ / AMOS7 \ YOURUM ::
#\[7]AH2VKFYAGAPM473JX6DEPUEEBXTVC76TKAMDSAIQ2GXOIPYDIUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
