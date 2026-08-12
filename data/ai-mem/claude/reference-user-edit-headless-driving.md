---
name: reference-user-edit-headless-driving
description: "how to actually drive the user-edit form with no terminal: start it detached with -no-tty, route char-add by SESSION ID (not by name — 'client not present'), navigate by the returned rendering rather than a guessed tab count"
metadata:
  type: reference
---

Recorded 2026-08-12, after losing time to each of these in turn.

## the three render paths, and which one you are looking at

- `./bin/Protocol-7 user-edit show-form <user>` — one shot, no input side,
  no add-a-field row (it needs the vocabulary round trip and interactive
  mode). Good for "does it render at all", useless for interaction.
- `./bin/Protocol-7 user-edit start <user>` — the real interactive form.
- `... start <user> -no-tty` — same thing with the input side driven over
  the network by `char-add`. **This is the test surface.**

`start` and `show-form` both paint through `user-edit.form.render`;
`cmd.char-add` renders its own frame and is always a CAPTURE.

## starting it

```
setsid nohup ./bin/Protocol-7 user-edit start <user> -no-tty \
    > /tmp/.../ue.log 2>&1 < /dev/null & disown
```

`setsid` + `< /dev/null` + `disown` all matter — started plainly it dies
with the shell. The log holds the first paint and any load errors; grep it
for `broken` after every code change, since a module that fails to compile
just gets skipped (`success on N subs, 1 broken`) and the form runs on with
the old behaviour.

## routing to it — the part that wastes the most time

`p7c 'user-edit.char-add ...'` answers **`client not present`**. The zenka
does not register under the name `user-edit`: per its start file it
authenticates as the invoking UNIX USER with `user-edit` as a SUBNAME
(`<unix-user>[user-edit]`, see `user-edit.auth_name`).

Route by SESSION ID instead:

```
SID=$( p7c 'list subnames' | grep user-edit | awk '{print $1}' )
p7c "$SID.char-add [Down][Down]"
```

`list subnames` is the command that shows the subname column; `list
sessions` does not. Stale sessions from earlier runs linger in that list —
take the newest, or kill the old ones first.

## key specs

`editor.input.parse_key_spec`: `[Up]` `[Down]` `[Left]` `[Right]` `[Home]`
`[End]` `[PageUp]` `[PageDown]` `[Tab]` `[ShiftTab]` `[Delete]`
`[Backspace]` `[Insert]` `[Enter]` `[Escape]` `[Space]` `[F1]`–`[F4]`, and
control keys as **`[Ctrl+k]` — a PLUS, not a hyphen**. `[Ctrl-k]` is not a
token and the whole call fails.

## navigate by FEEDBACK, never by a counted sequence

Every `char-add` returns the rendered form plus an `: active field : <name>
[ n of m ]` line. Use it. The number of rows CHANGES underneath you — an
expanded list is entries + 1 rows, collapsing mid-sequence alters the count,
and adding or removing a field changes it again. A hardcoded run of `[Down]`
silently stops testing what it thinks it does; this produced two false
"it is broken" conclusions in one session and an overshoot in the next.

## restart after every code change

The form process holds the code it loaded at start. `v7.restart users` for
the `users` side ([[reference-editor-add-field-cycler]]) does nothing for
the form — kill and restart it.

**Do not `pkill -f user-edit`.** The pattern matches the shell's own command
line and kills the calling shell (exit 144), repeatedly. Use:

```
for pid in $( ps aux | grep '[u]ser-edit' | awk '{print $2}' ); do kill $pid; done
```

## test against a throwaway record, not your own

`p7c 'users.create-default p7-fieldtest'` makes one; the record lives at
`/etc/protocol-7/users/host-system/<name>/` (`[USERS_HOST]`, registered in
`users.init_code`) and is removed with `rm -rf` on that directory — there is
no delete command. Editing a form does not touch the record until submit,
so an abandoned form leaves the record alone, but anything you submit is
real.

#,,.,,,,.,.,.,.,.,,,,,,,,,...,...,..,,,..,,,.,..,,...,...,,..,,.,,,,.,,..,,..,
#OOEQ7EJETSU5DQ3ANHAVVATW662ECZC4UE33GKIRFCNBKWW5RTET23USSW43HVCG5N6OVI66PJYCC
#\\\|5GUKMJDIHUBGF26RMBIXXI7VP53L4Y3QYJNOJ2YO7QEWAKXVT72 \ / AMOS7 \ YOURUM ::
#\[7]3N5I4Z2WFAOJ2M64WL7BNNNIGZCPLLN4NMUFDDI3JIONV3NF2WDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
