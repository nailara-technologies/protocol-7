---
name: cmd-data-must-be-string
description: "any modules/*.cmd.* (or whitelisted) routine must return {mode=>true|false, data=>STRING} - never a raw hashref/undef"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 37befb37-edc6-4438-bc0e-d650bc337ee4
---

`.cmd.` routines (and anything on a zenka's `subroutines.load-early`) go through `base.handler.command`, which enforces a strict reply contract: `{ 'mode' => 'true'|'false'|'size'|..., 'data' => <string> }`. A bare `undef` return gets coerced to a generic `{mode=>false, data=>'error during command invocation [details are logged]'}` plus a level-0 "hashref expected" log; a hashref without `mode`/`data` keys triggers "expected 'mode' and 'data' reply keys" - both on every call, success or failure.

**Why:** discovered while fixing `ticker.cmd.select_monitor`, which returned raw `{x,y,width,height,source}` geometry hashes or `undef` for internal callers (`set-window-profile`, `open_window`). It had been on the white-list the whole time but was silently broken for any network/command-protocol caller - both success and failure paths.

**How to apply:** if a routine needs to return structured data (hashref/arrayref) to internal `<[...]>` callers, give it a plain name (no `.cmd.` segment, not on the white-list) and write a separate thin `.cmd.` wrapper that calls it and formats the result as a string `data` payload (see [[feedback-list-return-format]] for the related size-vs-true mode distinction). Don't try to make one routine serve both contracts.

#,,.,,,..,...,.,.,...,.,.,...,,..,...,..,,,,.,..,,...,...,.,.,,.,,,,,,.,.,...,
#RN6SRTUQZPV7JQUN3X33TRZ5EMHGVNANRIOLKYYSPWFDM62JEKW77ELMJMXQU7UAPH4ASLOO54DEQ
#\\\|TQVMXKVDLHE566NCS5DAUEO44BISO4N7UVDXYWQWQIME4XZADWJ \ / AMOS7 \ YOURUM ::
#\[7]JIFCVHW6SL6BFG2LOBIEDDLZVWKAB7WRU3CSZBIR2CKNVOMYDKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
