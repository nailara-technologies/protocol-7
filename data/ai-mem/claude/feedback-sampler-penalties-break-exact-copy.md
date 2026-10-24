---
name: sampler-penalties-break-exact-copy
description: anti-repetition sampling [ DRY with a short allowed length, flat repeat_penalty ] makes an agent model MANGLE every copied path \ old_string \ code line -- and an outlier fix in the global inference.model.* hits every model
metadata:
  type: feedback
---

2026-10-24 : `dry_allowed_length = 2` over the whole context
[ `dry_penalty_last_n = -1` ] + `repeat_penalty = 1.1` [ b7fbdb7c9,
2026-09-18, against ONE looping model 677NSHI ] penalized any sequence of
more than 2 tokens seen earlier. an agent must copy text exactly, so the
models broke their copies : 'protocol -7', 'workspace-tr an sfer',
old_string never matching, garbled mode strings. 9b, 14b and 35b all
failed a 4-line edit ; with `repeat_penalty 1.0` + `dry_allowed_length 64`
[ 35b3dbe6a ] the 14b and the 35b pass it exactly. the tool output was
clean the whole time -- the models wrote the broken strings.

**Why:** the owner : 'the risk with adjusting parameters for outliers --
those suddenly apply to all models'. sampler values are read globally
[ `coding.async.send_request`, `coding.self_test.async_probe`,
`coding.tools.http_inference_client` ] and those callers still carry the
OLD values as `//` fallbacks.

**How to apply:**
- a model that loops gets a PER-MODEL override, never a global change.
  planned : `coding.helper.sampler_value( <key>, <model id> )` --
  `inference.model.<model id>.<key>` first, then the global ; the three
  callers use it and their fallbacks move to the new values [ not built ]
- mangled paths \ 'file not found' \ old_string mismatches from a coding
  model : check the sampler BEFORE blaming the model or the tool [ call the
  tool directly with `p7c coding.call-tool` -- it took four tests here ]
- DRY stays useful for paragraph loops : keep the allowed length well above
  the longest text an agent copies [ 64 covers paths + typical old_string ]
- results per model and the other fixes : [[project-2026-10-24-local-model-edit-comparison]]
- older edit-failure notes predate this : [[coding-zenka-edit-failures]]

#,,,,,,,.,,,.,..,,,,,,.,,,,,,,,,.,,,.,.,,,.,.,..,,...,...,.,,,..,,,,,,,..,,,.,
#VZYBFFYPUVMKBQK7M5VAWNTYJHWJ7ZFOTEDRTUSUXPAPBUWK345U6O7HU5BBQOZ3KVIZFJRO3KPYS
#\\\|FZEKE5VGAXCL5IZ3IG6TRLUZJDLROKHU4O2FQVEXAXOOXK6JZJC \ / AMOS7 \ YOURUM ::
#\[7]QLNNIFFI7P477KVSTQHJGMWV5UGXZPG2OYE5JOXUF4AHPVULKIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
