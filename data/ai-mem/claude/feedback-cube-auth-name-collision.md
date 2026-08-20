---
name: cube-auth-name-collision
description: zenka names matching the cube auth wire grammar (declare-/select-<word>) silently break zenka authentication
metadata:
  type: feedback
---

`base.handler.auth`'s capability-negotiation branch used to match a *bare*
`(declare|select)-(\S+)\s*(.*?)\n` line (the `auth.` prefix was optional).
The zenka-auth wire format is literally `"$zenka_name $key\n"`
(`src/auth.zenka.authenticate:97`), so any zenka named like
`select-region` or `declare-foo` produces a line this branch greedily
matched and silently swallowed (`return 1`, no output) *before* the real
`plugin.auth.zenka` handler ever saw it — the client then just sits until
cube's own auth-timeout watchdog disconnects it. No useful error surfaces
except a cube-side log line ("unknown capability: select-region") that
doesn't obviously point at the real cause.

Fixed 2026-06-19 (commit be2ea562d): made the `auth.` prefix mandatory for
that branch — nothing in the codebase actually sends the unprefixed form
on the wire (capability changes go through the authenticated
`cube.cmd.set-capability` command instead), so this was a zero-cost fix.

**Why this matters going forward:** any *future* zenka name starting with
`select-` or `declare-` will trip this exact bug again if this fix is ever
reverted or the regex is touched again. If a zenka silently fails to
authenticate with no obvious client-side error, check the zenka's name
against this grammar first — it's a fast, deterministic check before
chasing anything more exotic.

**How to apply:** when naming a new zenka, a quick grep for the chosen name
against `(declare|select)-` is cheap insurance, though the real fix already
landed so new names should be safe now.

#,,.,,.,,,,,.,...,...,,.,,,,.,...,,..,,..,,..,..,,...,...,,..,.,,,,..,,,.,,,.,
#4MJRQ6UZHYCWLNEJ3QQBZCKHXENMAC5UV3GUJNHKXPYBYCCGUKHJC4ZALREXEAKWI434NAWGUBAQS
#\\\|JFTQXG7CJO3U47JHAQR475XKW36Y6JEAU7RS7POTIRQJJUJMNPX \ / AMOS7 \ YOURUM ::
#\[7]GT577QDSVZ4C7ASP77RPHJAZM556O4E6PWUHJ7FI7CO4RVQ7ICBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
