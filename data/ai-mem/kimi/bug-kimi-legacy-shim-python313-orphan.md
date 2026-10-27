---
name: kimi-legacy-shim-python313-orphan
description: kimi_dispatch failed with 'sh: 1: kimi-legacy: not found' — stale shebang ; system python3.13 removed by dist-upgrade 2026-10-26 orphaned the uv venv interpreter ; fixed via uv python install 3.13 + repointing the venv python symlink
metadata:
  type: bug
---

2026-10-27 : kimi_dispatch returned `sh: 1: kimi-legacy: not found` after ~10 min
of polling. root cause chain, PROVEN :

- bin/mcp-server-p7 shells out to `kimi-legacy` [ hardcoded at ~139 , ~221 ,
  ~2672 ] because the legacy python CLI accepts `--afk` and `-r`, which the
  current native binary [ ~/.kimi-code/bin/kimi ] does NOT [ it has -y/-p/-S ].
- `kimi-legacy` -> ~/.local/share/uv/tools/kimi-cli/bin/kimi , shebang
  `#!/home/taeki/.local/share/uv/tools/kimi-cli/bin/python3.13` , and that
  venv's `python` symlink pointed at /usr/bin/python3.13 .
- dpkg.log : python3.13 removed 2026-10-26 16:13:54 by dist-upgrade [ the
  distro moved to 3.14 ] -> ENOENT at exec -> dash reports 'not found'.
  this was ONE DAY old, not weeks — kimi_dispatch worked fine before the
  2026-10-26 dist-upgrade run.

FIX APPLIED [ verified `kimi, version 1.50.0` + `--afk` present ] :
`uv python install 3.13` [ cpython-3.13.12 -> ~/.local/share/uv/python/ ]
then repointed ~/.local/share/uv/tools/kimi-cli/bin/python -> that managed
interpreter. venv site-packages [ 267 ] untouched — pin preserved.

LESSONS :
- uv venvs built against SYSTEM python are one apt dist-upgrade away from
  death ; durable form is `uv tool install --python <ver>` so uv owns a
  managed interpreter apt cannot remove.
- ext-pkg's kimi-cli check [ command -v kimi ] covers the NATIVE binary
  only — the kimi-legacy shim has NO coverage ; a cheap
  `kimi-legacy --version` check would catch interpreter orphaning in
  minutes. matters more now that kimi is the only agent with weekly quota.
- native kimi flags : -y/--yolo , -p/--prompt , -S/--session [ NOT -r ] ,
  -m/--model ; no --afk. any future migration of mcp-server-p7 to the
  native binary must map -r -> -S and drop --afk.

#,,,,,,..,,.,,,.,,.,,,,,.,,..,,..,,,,,,,.,..,,..,,...,...,..,,.,,,,,.,,.,,,.,,
#N54ZIOE3NF5KAOBFR3EUL4MOAHBEI6HWGNZC23Q5ZFDLDFSRUW3WG3LC5R4ELIETP4T4W35NPRK4Q
#\\\|USXVQ66NKLBZFGARAYFJ24DJXTTX2KNQKQ62YVVOOROPARJD24B \ / AMOS7 \ YOURUM ::
#\[7]GKBRCPGOMMGDHCNHBF6PR2SYJOFQUMXCHUCEPXJZWQ4OHFPE6UAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
