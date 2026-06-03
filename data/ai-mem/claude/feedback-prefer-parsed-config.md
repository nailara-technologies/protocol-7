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
`configuration/zenki/*/zenka-startup.v7` files from disk.

**Why:** At any post-init or reload time, v7 has already parsed every zenka-startup.v7
into its `%data` tree (see `v7.load_zenka_startup_cfgs` + `v7.init_start_setup`).
Re-scanning the filesystem is redundant work that can drift if parse semantics change
(comment handling, quoting, etc.) — and it shows up in logs as "loading 95 zenki" then
again "scanning 95 files" which looks wasteful.

**How to apply:** For "what zenki have property X set?" questions during v7
post_init/reload paths, walk `<v7.start_setup.zenki.config>` keys and check the parsed
sub-hash (`->{start}->{'on-demand'}` etc.). Only fall back to FS scanning when the
parsed tree genuinely doesn't carry the answer.

Related: [[topic-patterns]] (zenka idioms).

#,,..,..,,,,.,,,.,...,..,,,,,,,..,,..,,..,,,,,..,,...,...,...,,,.,,..,.,,,,,.,
#HRWVUXFDZW7YPADBLGROCYDMF5P372N2SFRN6F3P6E4UJ24E5Y6TUT5Z7TPNBHUZL5TVOYRDH66FC
#\\\|F22OKOW475NWPP5XILNCCVXZTUC4VB3X3NKRRXDTAJGCLIZ4QEQ \ / AMOS7 \ YOURUM ::
#\[7]VVPTXXODUHMWRRQKKYPQ3GT7NEFCYDZ4NQUUCB5HXQ27IRPL64AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
