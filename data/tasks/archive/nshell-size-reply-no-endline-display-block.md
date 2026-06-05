## task: nshell-size-reply-no-endline-display-block

## dispatch
fix the nshell display stall that occurs when a SIZE reply payload has no
trailing newline. read first: `modules/nshell.handler.command_reply` (full);
`modules/nshell.render.empty_prompt`; `modules/nshell.render.cursor`.
do NOT touch signatures or unrelated logic.

## background
`modules/route.bmw384.cmd.visual-wheel` was sending a SIZE reply whose payload
had no trailing `\n`. after that reply, nshell stopped displaying ALL subsequent
replies — received correctly but never rendered. the root cause is that
`nshell.handler.command_reply` currently injects `\n` immediately after the
payload (line 77) and then draws the cursor indicator — both of which corrupt
the terminal state when the payload uses raw ANSI and intentionally has no
trailing newline.

## correct behaviour [ user spec ]

SIZE reply payloads must be printed EXACTLY as received — no injected newline,
no cursor drawn. modules sending SIZE replies may use raw ANSI for UI purposes
(frames, visualizations) and the terminal must be left in the state they intend
until a prompt is drawn.

the prompt is the right place to recover: when the previous SIZE payload had no
trailing `\n`, the NEXT prompt render prefixes two `\n` before drawing, giving
clean visual separation without interfering with the raw output.

## implementation

**1. in `nshell.handler.command_reply`:**

- remove the no-endline guard (line 77):
  ```perl
  ## REMOVE: print "\n" if defined $payload_str && $payload_str !~ m{\n\z};
  ```
- remove the cursor indicator block (lines 79-82) from the SIZE payload path —
  do NOT draw the cursor after a SIZE reply. just flush:
  ```perl
  STDOUT->flush();
  ```
- set a flag on nshell state when the payload had no trailing newline:
  ```perl
  <nshell.state>->{'needs_newline_prefix'} = TRUE
      if defined $payload_str && $payload_str !~ m{\n\z};
  ```
  clear it (set FALSE or delete) when payload DOES end with `\n`, so the flag
  only persists until the next prompt.

**2. in `nshell.render.empty_prompt` (and/or `nshell.render.cursor`):**

- at the very top, before drawing the prompt, check the flag:
  ```perl
  if ( <nshell.state>->{'needs_newline_prefix'} ) {
      print "\n\n";
      delete <nshell.state>->{'needs_newline_prefix'};
  }
  ```
  two newlines: one to end the raw-ANSI line, one blank separator before the
  prompt — matching the visual spacing of a normal reply.

**note on cursor indicator:** the cursor indicator sequence (lines 79-82:
`\r..._\e[K\r\e[0m`) is what blocked subsequent replies in the original bug —
`\e[K` erased the line the cursor was on after `\n` moved it there, leaving
the terminal with no clean line for the next reply to draw on. by deferring
the newline + cursor to the prompt render, this is avoided entirely for
raw-ANSI SIZE replies.

## verify
- SIZE payload WITH trailing `\n`: output as before, flag NOT set, prompt draws
  normally (no extra blank lines).
- SIZE payload WITHOUT trailing `\n`: output raw, flag set, next prompt prefixes
  `\n\n` then draws normally; subsequent replies display correctly.
- TRUE/FALSE single-line replies (line 61-70 path): unchanged — they already
  use `printf "\n%s\e[0m\n\n"` which ends with two newlines.

## acceptance
- SIZE reply with no trailing `\n` renders raw, subsequent replies display
  normally without requiring a manual restart.
- a raw ANSI frame sent via SIZE (no trailing `\n`) leaves the terminal display
  intact — no cursor drawn over it, clean prompt appears below after input.
- TRUE/FALSE and SIZE-with-`\n` replies show no regression in visual spacing.
- no manual AMOS7 signature stubs in edited files.

#,,,,,,..,,,,,..,,..,,,,,,,.,,,,,,.,,,...,,,,,..,,...,...,,.,,,,.,..,,,.,,,..,
#FXNC63KMMYNTRHQHCFTR3DXFXJSDI3KSG76RXJRZGEQXMGHPP7BBKEHC6GDE3RPRT5LK3ELSLKUD4
#\\\|E2M36CKBJNJQ3D56FXDLRKUAOY4W5UD3CQYBBNUHHE6XTXYQXAF \ / AMOS7 \ YOURUM ::
#\[7]KRWVWST57CDOCQPDEWU4W2GXJO2YBVMAZ6LTNBH3BX2EBAYAPGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
