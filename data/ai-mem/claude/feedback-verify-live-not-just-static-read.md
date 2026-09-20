---
name: feedback-verify-live-not-just-static-read
description: "user explicitly confirmed the instinct to empirically test a security/behavioral claim live (USER=root p7c whoami) rather than resting on a static code trace, right before that live test overturned my own confident-but-wrong static reading"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6e49f0ab-caa0-40aa-880e-624860973ca3
  modified: 2026-09-20T13:57:56.444Z
---

When a question is "does this check actually enforce X" (especially
anything auth/permission-adjacent), run the real command and observe
the real behavior before asserting an answer from reading the code
alone — even a careful line-by-line trace.

**Why**: confirmed 2026-09-20 during
[[project-2026-09-20-unix-auth-identity-bypass-fixed]]. I traced
`plugin.auth.unix` statically and concluded spoofing `USER=root` would
succeed; the user pushed back with a different, also-plausible read of
the same config: `auth.setup.usr.unix-root = :unix:root,protocol-7`
looks like an intentional, designed cross-identity delegation
mechanism (root explicitly allowed to authorize as protocol-7), and
taeki being the configured `admin-user` might be meant to work the
same way — not a bypass, just the documented mechanism doing what it
says. Only the live empirical test — first from taeki's own account,
then decisively from a genuinely separate unix account (`another`) —
settled it: the real bug was in a different direction than that
benign reading covered. It wasn't "taeki-as-admin legitimately
claiming a related identity" (which the config-delegation
explanation would have covered) — it was *any* connecting account,
admin or not, claiming *any* configured alias, including ones it has
no relationship to at all. Once `another` (no admin relationship to
`taeki` whatsoever) authenticated as `unix-taeki` by setting
`USER=taeki`, the delegation-mechanism explanation stopped applying
and the bug was confirmed. User's own words: "we should actually test
that claim.. it would be a regression.." and afterward, "i very much
welcome the instinct to immediately check and double check the actual
function and not relying on the implicitly assumed one."

**How to apply**: for security/permission/auth claims specifically,
treat a static code trace as a hypothesis to test, not a conclusion —
especially when there's already a plausible benign explanation on the
table that would let the investigation stop early. Run the actual
command/path live before reporting a verdict either way.

#,,..,,.,,.,,,.,.,,,,,.,,,,.,,,,.,..,,,,,,,,.,..,,...,..,,,..,,..,..,,..,,..,,
#PP7BXLIQKEAQ7P76C5ECRJCMJJ7VWDQDVMEXYCWR2VFLVRX4BF23M4ILCIVERJVKYOFQIL2QTXI6A
#\\\|JYKVJ2CLIIAJRCEHB2F4STU3G44ZB47JA7IIUX3Z7HIOQEJ47Z3 \ / AMOS7 \ YOURUM ::
#\[7]LX6CWG627H7PEFIXIPPQ6GRJGVUCV35IV6KBA2ZBKYYN7UIUPKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
