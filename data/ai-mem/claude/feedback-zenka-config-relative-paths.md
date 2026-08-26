---
name: zenka-config-relative-paths
description: "zenka start config paths must use <system.root_path>/... not bare relative paths — cwd is /home/protocol-7 at runtime"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: be9c58bb-2e39-476f-8bcb-6ea253d0c195
---

Zenka config values that reference filesystem paths (data/, cfg/, var/) must be written as `<system.root_path>/data/yaml/...` not `data/yaml/...`. The transport zenka (and likely all zenki) run from cwd `/home/protocol-7`, so bare relative paths silently miss the actual project root at `/data/projects/protocol-7`. The `<system.root_path>` template is expanded by the config loader (confirmed live: `$data{proxy}{cfg}{selector_config}` shows `/data/projects/protocol-7/data/yaml/web-proxy/...`).

**Why:** `transport.cfg.profile_dir = data/yaml/transport/profiles` caused `transport.profile.match` to find zero profile files — `opendir` on `/home/protocol-7/data/yaml/transport/profiles` returns empty since that directory doesn't exist. Fixed to `<system.root_path>/data/yaml/transport/profiles`.

**How to apply:** any time you write a `<zenka>.cfg.*` config value pointing to a path in the project tree, prefix with `<system.root_path>/`. Verify with `p7c <zenka>.eval-code 'return $data{<zenka>}{cfg}{<key>}'` after reload.

#,,,.,.,,,,,,,.,,,,..,.,.,..,,..,,...,,.,,,.,,..,,...,...,,,,,.,,,,..,..,,,,,,
#WF5UIXYF5OKHLNXNWXUTVR6IVCMY2BD6BXO2AWTWYESHDQ4FLCB7LOUOE46RLXAQO4L4XAYWQ7CGM
#\\\|M625I4FCCTYXGXXP7N4RS7OBK3LA2X6CQYDME5OBXYGB4ZBXB3D \ / AMOS7 \ YOURUM ::
#\[7]U35JXR4GMARWTT5B634TXERH7E7J5OL7CNQ5RHM7VM5QFH5MWKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
