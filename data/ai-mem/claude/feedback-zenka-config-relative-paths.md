---
name: zenka-config-relative-paths
description: "zenka start config paths must use <system.root_path>/... not bare relative paths — cwd is /home/protocol-7 at runtime"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: be9c58bb-2e39-476f-8bcb-6ea253d0c195
---

Zenka config values that reference filesystem paths (data/, configuration/, var/) must be written as `<system.root_path>/data/yaml/...` not `data/yaml/...`. The transport zenka (and likely all zenki) run from cwd `/home/protocol-7`, so bare relative paths silently miss the actual project root at `/data/projects/protocol-7`. The `<system.root_path>` template is expanded by the config loader (confirmed live: `$data{proxy}{cfg}{selector_config}` shows `/data/projects/protocol-7/data/yaml/web-proxy/...`).

**Why:** `transport.cfg.profile_dir = data/yaml/transport/profiles` caused `transport.profile.match` to find zero profile files — `opendir` on `/home/protocol-7/data/yaml/transport/profiles` returns empty since that directory doesn't exist. Fixed to `<system.root_path>/data/yaml/transport/profiles`.

**How to apply:** any time you write a `<zenka>.cfg.*` config value pointing to a path in the project tree, prefix with `<system.root_path>/`. Verify with `p7c <zenka>.eval-code 'return $data{<zenka>}{cfg}{<key>}'` after reload.

#,,,,,..,,,.,,,..,...,,,.,...,..,,.,.,.,,,...,..,,...,...,,,,,..,,.,,,,.,,,..,
#IXD3SSJEELCTRH7A35I5EKMFME5L64EJH6HTTNHQZ2NLHT4VL2HQLSJG4VEI6XOUKXCN247UXWULY
#\\\|LNTJG4YZKC5O7VJKLTEVJQX76CSOYZ3UDBAUWIE7Z2B4NXXQKYR \ / AMOS7 \ YOURUM ::
#\[7]AIKOYN2SE55V43BHG7ZMZELM3LFJKZG5H3I66R7WPYVSYA4HSMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
