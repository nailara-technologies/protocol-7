---
name: feedback-2026-11-28-session-lessons
description: 2026-11-28 lessons -- never print config files whole [ a token leaked ], format-code -r is regex-style, pgrep -f matches its own shell, deleting a v7 model deletes its file
metadata:
  type: feedback
---

- **never print a config file whole** : `grep -v '^#' invokeai.yaml` put the owner's hugging
  face token into the transcript. read only the keys needed [ grep -E '^(key1|key2):' ].
  **Why:** a transcript is not a secret store ; the owner had to renew the token.
- `bin/format-code -r` is `-regex-style`, NOT reformat. plain `bin/format-code <file>`
  formats ; `-c` checks. read the whole -c output [ "would reflow" is a failure ].
- `pgrep -f "<path>"` inside `bash -c '...'` matches its OWN command line : a wait loop on it
  never ends. use `ps -eo pid,args | grep "[i]nvokeai-web"` or a pid.
- editing a file while its sign run awaits approval = refused [ happened AGAIN 2026-11-28,
  see [[feedback-sign-gate-and-pending-edits]] ] : check pending runs before any edit.
- invoke.ai v7 : DELETE of a model entry deletes its files -- with linked model dirs that
  hits the other install. change base \ fields with PATCH /api/v2/models/i/<key>.
- a whole-db backup inside a zenka's event loop scales with the db [ 629 MB -> 47 s
  heartbeat exceeded, zenka restarted mid-edit ] : back up only the rows the edit touches.
- before building a speed feature, measure the model's real cost path [ qwen 2.1
  references are normalized to ~1 MP : ref-scale bought no speed ].

**How to apply:** treat these as checks before the matching action.

#,,,.,,..,,,.,.,,,.,.,,..,,,,,,..,,.,,..,,..,,..,,...,...,..,,,,.,,..,,,,,.,.,
#PDMGV5E4SNA6VLELH2VWJQOAH2OTUDGCSGDIJSA7LPIF6RN6CGJQQSMYN6HMZXYQLVQJCJNDV7PQA
#\\\|TFO67BLIXC7OKEOTP4Z62D7K4NNEZX52JWZR33TLRZ4LPDKZMQJ \ / AMOS7 \ YOURUM ::
#\[7]HLMUTFTV4UQFYINXQN63PS6YKFVXVLGFP5NTGNCSYVFSE5JTWCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
