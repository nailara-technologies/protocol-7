---
name: cmd-data-must-be-string
description: "any src/*.cmd.* (or whitelisted) routine must return {mode=>true|false, data=>STRING} - never a raw hashref/undef"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 37befb37-edc6-4438-bc0e-d650bc337ee4
---

`.cmd.` routines (and anything on a zenka's `subroutines.load-early`) go through `base.handler.command`, which enforces a strict reply contract: `{ 'mode' => 'true'|'false'|'size'|..., 'data' => <string> }`. A bare `undef` return gets coerced to a generic `{mode=>false, data=>'error during command invocation [details are logged]'}` plus a level-0 "hashref expected" log; a hashref without `mode`/`data` keys triggers "expected 'mode' and 'data' reply keys" - both on every call, success or failure.

**Why:** discovered while fixing `ticker.cmd.select_monitor`, which returned raw `{x,y,width,height,source}` geometry hashes or `undef` for internal callers (`set-window-profile`, `open_window`). It had been on the white-list the whole time but was silently broken for any network/command-protocol caller - both success and failure paths.

**How to apply:** if a routine needs to return structured data (hashref/arrayref) to internal `<[...]>` callers, give it a plain name (no `.cmd.` segment, not on the white-list) and write a separate thin `.cmd.` wrapper that calls it and formats the result as a string `data` payload (see [[feedback-list-return-format]] for the related size-vs-true mode distinction). Don't try to make one routine serve both contracts.

#,,.,,...,..,,...,,,.,...,...,,,,,,,.,,..,,,,,..,,...,...,...,..,,,.,,,..,,,,,
#3ALEQUSO2HACFR2RCDQFOWKLVQGQMXOHRYATGRUFM2UWJGRK5R2WI6AXWHGMFX4EK3AD4OV7ODIMS
#\\\|BIWM7IUSOEOHUJJNM7JV2YY7IEUXZWTWAFG6DGLQ2XOKCOITWIZ \ / AMOS7 \ YOURUM ::
#\[7]ZCVR5YDFRH5MQPWA5C2LGPOBTIPMI542G5SKCKE46SJFHQCWRGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
