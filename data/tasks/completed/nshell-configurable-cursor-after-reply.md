## task: nshell-configurable-cursor-after-reply

## dispatch
add a `nshell.cfg.cursor_after_reply` config key that controls whether the
cursor indicator is redrawn after replies. read first:
`src/nshell.handler.command_reply`,
`src/nshell.render.empty_prompt`,
`src/nshell.read_from_buffer`,
`cfg/zenki/nshell/zenka.v7`.
do NOT touch signatures or unrelated logic.

## problem
cursor redraw is inconsistent after the SIZE reply no-endline fix:
- TRUE/FALSE single-line replies: cursor indicator redrawn (lines 71-75)
- SIZE/payload multi-line replies: cursor NOT redrawn; `needs_newline_prefix`
  defers `\n\n` to next prompt

user wants: keep the current behavior as default, make it configurable,
ensure the chosen mode is applied consistently regardless of reply type.

## config key

add to `cfg/zenki/nshell/zenka.v7` (as a commented example, following
the `nshell.cfg.overflow_marker_left` pattern):

```
## Whether to redraw cursor indicator after replies [ line | all | none ]
## line : only after single-line TRUE/FALSE replies [default]
## all  : after all reply types including SIZE/payload
## none : never redraw cursor after any reply
# nshell.cfg.cursor_after_reply = line
```

## implementation

### `src/nshell.handler.command_reply`

at top of the print-and-cursor block (around line 53), read the config once:

```perl
my $cursor_mode = $data{'nshell'}{'cfg'}{'cursor_after_reply'} // 'line';
```

in the single-line (TRUE/FALSE) branch (currently lines 71-75), wrap the
cursor redraw block:

```perl
## re-display cursor after single-line reply output
if ( $cursor_mode eq 'line' or $cursor_mode eq 'all' ) {
    print "\r"
        . $colors{'p7_fg_0003'}
        . "_\e[K\r" . "\e[0m"
        . $colors{'p7_fg_0004'};
}
```

in the payload/SIZE branch (after setting `needs_newline_prefix`), add:

```perl
## redraw cursor after SIZE/payload reply if configured
if ( $cursor_mode eq 'all' ) {
    print "\n"
        . "\r"
        . $colors{'p7_fg_0003'}
        . "_\e[K\r" . "\e[0m"
        . $colors{'p7_fg_0004'};
    delete <nshell.state>->{'needs_newline_prefix'};
}
```

note: when `cursor_mode eq 'all'` and payload has no trailing `\n`, print
the `\n` before the cursor and clear `needs_newline_prefix` so the next
prompt does not double-prefix.

### `src/nshell.render.empty_prompt` and `src/nshell.read_from_buffer`

no change needed to these — the `needs_newline_prefix` path already handles
the `line` (default) and `none` modes correctly. only `all` mode bypasses it.

## acceptance
- with default config (no key set / `line`): cursor shown after TRUE/FALSE,
  not after SIZE — same as current behavior
- with `nshell.cfg.cursor_after_reply = all`: cursor shown after both TRUE/FALSE
  and SIZE replies; no double `\n\n` prefix artifacts
- with `nshell.cfg.cursor_after_reply = none`: cursor NOT shown after any reply
- no regressions to `needs_newline_prefix` / next-prompt-newline behavior
- no manual AMOS7 signature stubs in edited files

#,,..,,,,,...,.,.,..,,,.,,,.,,,,.,,,.,..,,,,,,..,,...,..,,,..,.,,,..,,,..,,..,
#VVVSQ7VVXAKKQXK2ZALJKQTP2YNU4T3IE6GMLVV6PZOGIPZ2X2YLV2PEUOTCOLUGGPMSNO7TLM4QW
#\\\|PC4P32TVDJQUIOCSFT7RVP4KLAZCZVM55FQTBW4CQPFGIK3WOOT \ / AMOS7 \ YOURUM ::
#\[7]3TIWZ73QVN5X3QHTSEXU3XYMKJD6QQVH2RIY42X7CQURMOJZ5WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
