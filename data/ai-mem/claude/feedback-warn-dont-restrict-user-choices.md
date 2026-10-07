---
name: feedback-warn-dont-restrict-user-choices
description: for user-facing tools [ esp. key \ security tooling ], support every reasonable usage form and WARN about weak choices instead of refusing them -- restrictions get circumvented or block adoption ; special set-ups belong in wrappers, not as limits inside the tool
metadata:
  type: feedback
---

user, 2026-10-07 [ trust chain step 2 design ] : the owner root key must stay FLEXIBLE -- any form the keys zenka supports [ passphrase-derived, encrypted, seed phrase, root-held, plain ] -- "better we write a wrapper if required than to limit usage scenarios unnecessarily" ; and on a passphrase-strength rule : warning only, because "often if a user cannot use what they want they will circumvent things or they will not get adopted".

**Why:** a refusal does not make a user choose the secure path -- it makes them work around the tool [ worse than a warned weak choice ] or drop it.

**How to apply:** a low existing baseline floor is fine and stays [ the 13-char password minimum, `$AMOS7::TERM::pwd_min_len` -- user, same day ] ; beyond such a floor, never add refusals. when designing a command \ option set, accept every reasonable input form and route it through the existing machinery [ e.g. `load_keypair` handles every key form ] ; flag weak choices clearly [ log \ warning \ `list` marker ] ; put opinionated set-ups [ air-gapped, hardware token, split secret ] in wrappers. this is NOT about protocol-level checks [ signature \ pin \ delegation verification stays fail-closed ] -- it is about what a user may choose to use.
related : [[topic-key-recovery-flexible-recreatability]]

#,,,.,...,.,.,,,.,..,,,,.,.,.,...,,,.,,,.,,,.,..,,...,...,...,,..,,.,,..,,...,
#O3LLX7DZSTK3GBXYADZ55D5ZPWB7X47P5TJRAENBLXRGGS6MVCFTZNWOETSHZZ7DA5HSTUJJFGVPW
#\\\|V2E3KSESBLN6KIQXPZHZ6IFGME7SYJ7CAGXMPSY3KUSKKOWIYXH \ / AMOS7 \ YOURUM ::
#\[7]L5BLHVCNR5O2MSEXBQJAU3KSLYPSW2MZKF2X455ACXUF7GUP2GDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
