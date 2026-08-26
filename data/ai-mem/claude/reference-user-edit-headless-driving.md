---
name: reference-user-edit-headless-driving
description: "how to actually drive the user-edit form with no terminal: start it detached with -no-tty, route char-add by SESSION ID (not by name — 'client not present'), navigate by the returned rendering rather than a guessed tab count; also why this harness can never show real ANSI cursor styling and how to verify cursor-position wiring anyway (sentinel swap, not visual diff)"
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

**"take the newest" is not enough on its own**: the user's own live TTY
session shows up in the same `list subnames` output alongside a `-no-tty`
throwaway, and both can look recently-touched at a glance if the user has
been actively using their own session too. Cross-check the candidate SID's
actual connection age via `list sessions` [ same SID, different column ]
before routing `char-add` at it — don't just eyeball `list subnames`'
ordering. Got this wrong once (2026-08-13): routed `char-add` at the
user's own pts/4 session by mistake. `user-edit.cmd.char-add`'s own
`<user-edit.mode.no_tty_debug>` guard refused it outright rather than
injecting into a real interactive session, so nothing was actually at
risk — but it wasted a step and is worth just getting right first time.

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

## char-add cannot test the bare-Esc debounce, at all

`char-add`'s own driving loop (`while (length($input_buffer)) { stdin_key;
event.once(0.02); }`) re-invokes `stdin_key` every ~20ms for as long as an
unresolved lone `\e` sits in the buffer, and `stdin_key` unconditionally
cancels any pending esc-timer at its own top on every invocation — regardless
of whether new bytes actually arrived. Since the timeout is 50ms and the
loop's own gap is 20ms, the timer is cancelled-and-rearmed every iteration
and never gets an uninterrupted window to fire. A `[Escape]` key-spec sent
through `char-add`, alone or repeated, will never trigger
`user-edit.handler.esc_timeout` — not "sometimes doesn't," never does. Bugs
reachable only through that path (see
[[reference-editor-add-field-cycler]]'s Esc-on-expanded-list section) have to
be fixed by reading the code, then confirmed against a real interactive
session — this harness cannot verify them.

## `-no-tty` can NEVER verify real ANSI styling, pty tricks included

`user-edit.form.render` — the module that actually applies inverse-video /
coloured cursor styling — only runs at all when
`<user-edit.form.interactive> and not <user-edit.mode.no_tty_debug>`
(`user-edit.handler.value_get_reply`'s own gate on the dirty-watcher print
path). A `-no-tty` session sets `no_tty_debug` TRUE by definition, so that
gate is FALSE unconditionally — the print path never fires, no matter what
STDOUT is connected to. Wrapping the launch in `script`/a real pty does
NOT help: the gate checks the MODE flag, never `-t STDOUT`. `char-add`'s
own reply is built by a completely separate, always-unstyled render call
(see its own note above) that self-overlays the cursor with the raw
character and never applies colour. Bottom line, found 2026-08-13 after
two dead-end pty attempts: there is no way to see real cursor styling
without a real interactive terminal — read the styling code and reason
about it, then ask the user to confirm live, rather than spending more
time trying to capture it headless.

## `char-add`'s self-overlay makes visual diffing useless for cursor bugs

Every `char-add` reply overlays the cursor with the character ALREADY
there (see the note above on why — captures must not corrupt the value).
That means moving the cursor across ordinary text and diffing successive
captures shows **no visible difference at all** when the underlying logic
is correct — a real character overlaid with itself is invisible. Do not
conclude "nothing changed" means "cursor tracking is broken"; it means
the test can't see this class of bug through content alone. To actually
verify a cursor-position computation is wired correctly, temporarily make
the sub return an impossible sentinel value (e.g. a fixed `'Z'`), drive
the field, confirm the sentinel appears exactly where expected in the
capture, then revert it. Confirmed working this way for
`plugin.user-edit.address-cluster.cursor_char` — content-diffing had
falsely looked fine both before AND after a real wiring bug would have
existed, the sentinel swap was the only test that actually discriminated.

## `list subnames` lags a freshly started session by a few seconds

A `-no-tty` session started via `nohup ... & disown` does not always show
up in the very next `list subnames` call — it can take a couple of
seconds to register, and in the meantime the command will show only the
PREVIOUSLY existing sessions, which reads as "my new session failed to
start" even though the process is running fine. Confirm via `ps aux |
grep '[u]ser-edit'` sorted by start time (or `ps -eo pid,lstart,cmd
--sort=-start_time`) instead of trusting `list subnames`' completeness
immediately after launch, or use `list sessions`' own `since` column
(sub-second for a session that just registered) to positively identify
the new one rather than guessing from position in the list. Got a
`char-add` call routed at a stale, wrong-mode session this way once
(2026-08-13) purely from trusting `list subnames` too early.

## test against a throwaway record, not your own

`p7c 'users.create-default p7-fieldtest'` makes one; the record lives at
`/etc/protocol-7/users/host-system/<name>/` (`[USERS_HOST]`, registered in
`users.init_code`) and is removed with `rm -rf` on that directory — there is
no delete command. Editing a form does not touch the record until submit,
so an abandoned form leaves the record alone, but anything you submit is
real.

## driving a REAL pty with `expect`, not `char-add` — gotchas found 2026-08-16

`script -qec` is what actually opens a real pty for `start <user>` [ needed
for real cursor styling, the bare-Esc debounce, and anything else `char-add`
structurally cannot reach — see this file's own notes above ], but something
still has to feed it keystrokes programmatically for a scripted/agent
session. `expect` works well for this. Found live while verifying the
in-frame prompt primitive ([[project-loader-deferred-compile-disabled-cmd-fix-2026-08-16]]'s
sibling feature):

- **plugin-mode entry needs a real Right arrow first** — `key_actions` (and
  any other plugin-pinned field) is not "entered" by Down/Enter alone.
  `user-edit.handler.stdin_key`'s own two-stage Right-arrow entry trigger
  (`\e[C`, gated on the field being empty or the cursor already past 0) must
  fire before Enter reaches the plugin's own `handler.key` at all — skip it
  and Enter still SEEMS to do something (it falls through to ordinary
  process_key handling instead), which produced a convincing but entirely
  false "Ctrl-C kills the zenka" bug report during this session: the
  zenka really was dying, but only because plugin mode was never entered,
  so Ctrl-C hit the ordinary top-level quit path, not the prompt's own
  cancel handling. Re-tested with the Right arrow included and it was fine.
  **Always send `\033\[C` after focusing a plugin-pinned field, before
  Enter**, or a "bug" found this way may not be real.
- **`send`'s Tcl argument parsing treats a leading `-` as a flag** — sending
  a literal hyphen character (e.g. typing `-` as part of a key name like
  `zz-test-key`) via `send "$c"` in a char-by-char typing loop throws
  `ambiguous flag "-"` and kills the `expect` SCRIPT itself, which then
  takes its spawned child down too via the closed pty (SIGHUP) — this reads
  exactly like the zenka crashed, when it was only the test harness. Use
  `send -- "$c"` for any programmatically-built literal argument, not just
  ones you know might start with `-`.
- **background a spawned zenka test session with `setsid nohup ... &
  disown`**, not a bare `&`, even when only wrapping a short-lived `expect`
  script — a bare `&`-backgrounded process can get reaped when the shell
  invocation that started it ends (tool-call-scoped shells), silently
  orphaning it before it ever produces output. If a background test run
  produces zero output and the spawned zenka process is simply gone
  afterward with no error, suspect this before suspecting a real bug.
- to reliably tell "did the deferred-compile recursion bug's `no routines
  were loaded` flood happen" from "is this just normal per-keystroke output
  I haven't drained yet" in a captured log, synchronize on the real repaint
  marker (`\x1b\[H\x1b\[2J`, the clear+home sequence every full frame paint
  starts with) rather than a fixed sleep — per-keystroke incremental updates
  inside an open prompt do NOT always trigger a full clear+repaint, so a
  drain that only waits for that exact sequence will legitimately time out
  on some keystrokes; treat that as normal, not a hang.

#,,,,,...,,..,...,.,.,,,.,.,,,...,..,,.,.,...,..,,...,...,...,,,.,,,.,,.,,.,,,
#ATVQ5KUYC6NE6RELK4FW5XNTV4DDSA45OWG7VGB2YRQVKCUJUKNLW2DTEL563AQGG6E2NBPDA7TFO
#\\\|K47OVF4LMVH63TWRJCH7RUANRLRHLDG2VR4XC7QSTHKU4MQBRDD \ / AMOS7 \ YOURUM ::
#\[7]66BMRPIS3K4BXJUKJDSCLRNKW5MYLH5QREYXT3HWTDY2K62226DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
