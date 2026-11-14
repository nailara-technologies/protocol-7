---
name: no-sha-no-json-internal
description: internal protocol-7 code uses BMW \ AMOS checksums and no json ; sha only where an external source defines the value ; say it in every kimi prompt
metadata:
  type: feedback
---

sha [ Digest::SHA, Crypt::Digest::SHA*, sha256sum ] is avoided in protocol-7 : it stays
only where an external source defines the value [ git blob ids, acme, openssh known_hosts,
debian Packages, huggingface ]. internal checksums use BMW384 [ Digest::BMW, b32 names ] \
the AMOS7::CHKSUM family. json is avoided too : hand-editable files use p7 config style
[[p7-config-style-not-json]], and n7fs was meant to be json-free [ only partly done ].

**Why:** owner 2026-11-14, on finding kimi had added sha256sum readback to n7fs and that sha
had spread [ link-upgrade kdf, p7-sort, models.storage .. ] "all against agreement".

**How to apply:** never add sha or json to internal code ; every kimi \ subagent prompt says
so explicitly ; review diffs for it. transition plan : data/tasks/sha-to-amos-checksum-transition.md.
json in n7fs : JSON::XS codec now, json-free format later [[n7fs-go-live-and-terminal-follow-ups]].

#,,,.,.,,,,,,,.,,,..,,,.,,.,,,,,,,..,,.,,,,.,,..,,...,...,..,,,,.,,..,,.,,..,,
#ODMHE2BBNZUXIDY7BDX474MRWLWDSNXBFAPZT7MECS5B3AOZMHIGY3YCG764NNRSDUW4FGGW3KYW2
#\\\|WL5DVDJQQXH64BGS5YV22KGGGPDFPHVOS7TWQMTNTBAPHHIAI5A \ / AMOS7 \ YOURUM ::
#\[7]MLRGNQJNXBICQE26DCOCBWK7G52AAOF4KJQO3DVTDU7KSCAK2KAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
