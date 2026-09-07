---
name: feedback-user-edit-char-add-mutates-live-data
description: user-edit.cmd.char-add writes every injected keystroke straight into the LIVE form buffer -- happened twice against the real taeki record already, both times from keys that read as safe "navigation" in a different zenka's vocabulary
metadata:
  type: feedback
---

`user-edit.cmd.char-add` is not a passive observation tool the way
`vault-edit.cmd.char-add` is. It injects bytes into the exact same input
buffer a real keystroke would use, and a plain letter typed into a
focused TEXT field edits that field immediately, in memory, before any
submit — there is no separate "navigation mode" that treats `j`/`g`/`a`/
`x`/`r` etc. as safe the way [[project-cred-mesh-console-ui-architecture]]'s
`vault-edit` does.

**Happened twice already, both against the real `taeki` record**: once
sending `j` intending a vault-edit-style nav key (2026-09-07, `full_user_name`
briefly became `jTaeki Ten`), once more the same session doing a
side-by-side comparison test for the same reason. Both times caught
immediately with `[Backspace]`, confirmed untouched via `users.value-get
taeki <field>` (submit is explicit and separate, so an unsubmitted stray
edit never persists) — but two independent incidents in one project is a
pattern, not a fluke.

**Why it keeps happening**: the instinct to test with a short, memorable
key sequence (`j`, single letters) is exactly the instinct that's safe on
`vault-edit`, `nshell`, or any navigation-first interface, and exactly
wrong here — user-edit's fields are text-editing-first, and whichever
field happens to be focused (often field 1, e.g. `full_user_name`) eats
the very first ordinary character sent.

**How to apply**: before sending ANY `user-edit.char-add` key spec
containing plain characters (not just `[Named]` keys like `[Tab]`/
`[Ctrl+?]`/`[Backspace]`), either (a) confirm the currently focused field
is not a real data field worth protecting, or (b) start the session
against a disposable/throwaway username instead of `taeki` — a
`p7-fieldtest*`-style record, matching every OTHER char-add session
logged in [[topic-user-edit-console-zenka-status]]. `[Tab]`, `[Ctrl+?]`,
arrow keys, and other bracketed named-key specs are always safe (they
decode to control bytes, never inserted as text) — only bare characters
in the spec string are the hazard.

#,,.,,...,.,.,,,.,,,,,.,.,,..,,,,,...,.,,,.,,,..,,...,...,...,,,,,..,,,,.,.,,,
#S5BWNY3B4FEUKM4UK4G3HK25OQMNQBUZCM6F6RXHQNDXAN7BMO6Z7MOJOPHRBQKLHB6A7LEWKR43Q
#\\\|SLIQAJIJWJCUL4G6L2IJZ6WMKYQKIMNFALKFO2YQWSDMTPR3P4M \ / AMOS7 \ YOURUM ::
#\[7]FLMWZQGXYQVWHTACSTDC5J7HXNBTQ3XTRCPTSZGRBZ35BXVZG6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
