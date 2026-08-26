---
name: chmod child restore readline
description: every restore command sent to chmod child needs a readline — missing one desynchronizes the pipe
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
After every `print {$chmod_fh} "restore ..."` call, always follow with `<[coding.chmod_child.readline]>` to consume the reply.

**Why:** the chmod child prints exactly one reply per command. If restore's reply is not consumed, the next tool call's readline reads it instead of its own command's reply — pipe is permanently one step out of sync, causing all subsequent writes to fall through to staging silently.

**How to apply:** affects all 6 write handlers: write_new_file, insert_line, delete_lines, replace_line, remove_file, file_rename. Pattern: send command → readline. No exceptions.

**2026-07-24:** `ncode`'s own chmod-child (ported from `coding`'s, see
[[project-ncode-write-path-2026-07-24]]) follows this correctly throughout
`ncode.cmd.apply` — every `printf {$chmod_fh} "restore ..."`/`"create ..."`
is paired with a `<[ncode.chmod_child.readline]>` immediately after.

#,,.,,,,.,,.,,,,,,.,.,,,,,,,.,,,,,...,.,,,,..,..,,...,...,...,...,..,,,,.,...,
#VCVOIVG5A52DA6OCHZHM4XRBFCSBWKKNFLZ4VERTEZOZPXC6BNLTDPLLQDEGYBR2BHFA4WJZWKUD2
#\\\|7S7CMUTI52XOMAWG4R7WFJ6OSWVO7J3O233JWRTL3VTUUZBQ25L \ / AMOS7 \ YOURUM ::
#\[7]TLQQD7P6YCWFMHTC2VTBYM2RZZNAJ5IDIWGY3NT7AYZ7AMJI7EDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
