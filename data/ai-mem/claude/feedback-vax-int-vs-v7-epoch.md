---
name: vax-int-vs-v7-epoch
description: "bin/vax-int (32-bit VAX-int/BASE32) is a different encoding than the V7 epoch scheme (epoch_v7/epoch-num); don't cross-decode"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 02ada4be-0e30-4708-9681-b127fcc164d7
---

`bin/vax-int` decodes/encodes 32-bit VAX-int values as up to 7-char BASE32 strings
(`Crypt::Misc::encode_b32r`/`decode_b32r` + `V` pack template). This is used for
short opaque job/record IDs (e.g. `<[base.vax-int.encode]>` in jobsite).

The "V7 epoch" scheme (epoch-bucket directory names like `V7L36RQ`, seen in
`checksum-store/urls/<epoch>/` and trash-batch dirs) is a **different, unrelated**
encoding — decode it with `p7c localtime <str>` or the cube `epoch_v7`/`epoch-num`
commands, never `vax-int`. Feeding a V7-epoch string into `vax-int` decodes without
error but produces a nonsense result (e.g. decoded to a 2007 timestamp instead of
2026) — no warning, just wrong.

Also: an epoch-bucket dir name is only the **start of that epoch's time window**,
not a per-entry timestamp — entries filed under it could have landed anywhere
within the window. Don't treat it as precise dating for individual files.

**Why**: caught mid-investigation ([[topic-plugin-web-jobs]], 2026-07-01 session) —
assumed `vax-int` was "the" BASE32 decoder in this codebase and got a silently
wrong date before the user corrected it.

**How to apply**: before decoding any BASE32-looking string in this codebase,
check which subsystem produced it (vax-int encode call vs. ntime/epoch_v7 call)
rather than assuming one universal decoder.

#,,..,.,,,..,,...,,,,,...,,.,,..,,...,,,.,.,.,..,,...,...,,,.,...,.,,,...,,.,,
#OTACW32OQH3VCQ74LOSMEY6N7WIYVN3YYOZZH2T7VQBXFT5SEJU4HQINURG4PLSUJLYGO6PBDSTES
#\\\|JHSKGSBJPPLQNHBRSIW6X2ERVU4O23BOBLGYQKR5HWWRWL4RGCT \ / AMOS7 \ YOURUM ::
#\[7]IQKROWULJNTB2AP75HXN2BAFBRRXZ6SCIDFY2HX6E66FMR4SWEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
