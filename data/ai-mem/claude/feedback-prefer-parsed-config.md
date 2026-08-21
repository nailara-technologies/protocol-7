---
name: feedback-prefer-parsed-config
description: "when v7/zenka already parses configs into <data> tree, don't re-scan filesystem for the same info"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dcbc6065-ca1e-4d35-b876-1a342dfe7eb6
---

When implementing logic that depends on zenka start-up config data, prefer reading
the already-parsed `<v7.start_setup.zenki.config>->{$name}` tree over re-walking
`cfg/zenki/*/start.cfg` files from disk.

**Why:** At any post-init or reload time, v7 has already parsed every start.cfg
into its `%data` tree (see `v7.load_zenka_startup_cfgs` + `v7.init_start_setup`).
Re-scanning the filesystem is redundant work that can drift if parse semantics change
(comment handling, quoting, etc.) — and it shows up in logs as "loading 95 zenki" then
again "scanning 95 files" which looks wasteful.

**How to apply:** For "what zenki have property X set?" questions during v7
post_init/reload paths, walk `<v7.start_setup.zenki.config>` keys and check the parsed
sub-hash (`->{start}->{'on-demand'}` etc.). Only fall back to FS scanning when the
parsed tree genuinely doesn't carry the answer.

Related: [[topic-patterns]] (zenka idioms).

#,,..,..,,.,.,,,.,...,,,,,,,,,..,,.,.,.,,,,,.,..,,...,...,...,..,,.,.,.,.,.,,,
#MKDTH57INZ6JYARO6J7DXLQDTQ4OMTX32J2Z5ZT43S2PZRBWH3OSQVDFBS46NQOA5E5MGJ7PW4YUI
#\\\|PROI6DLRX4F6QIZ4WEHTNREGMCIJ5XEJQJATC6FRROZ2PLRD2KB \ / AMOS7 \ YOURUM ::
#\[7]2YUQY2KO4C6OSJJQXXCSGB3WTRNWPGBKWT2JTZ7KMJCIZMKCPQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
