# dependency chain : a system ensures its essential dependencies

## status

**requirement, agreed direction 2026-10-27.** born from two observations :

- the kimi-legacy incident [ see
  data/ai-mem/kimi/bug-kimi-legacy-shim-python313-orphan.md ] : a routine
  dist-upgrade killed the only dispatch path for the agent that still has
  weekly quota, and nothing noticed — because no check anywhere *executed*
  the artifact.
- the registries meant to prevent this are incomplete : tier-0 bootstrap
  tools untracked, one entry check\install mismatched, native installers
  outside every registry.

direction from the owner : clean, step by step, most useful first --
but ultimately the system must be able to ensure its essential
dependencies end-to-end, including git-source builds [ custom invoke
fork for qwen 2.1 t2i , ik_llama.cpp , prismml-llama.cpp ].

## driving principles

- **checks exec the artifact** [`<tool> --version`] .., never `command -v`
  alone -- path presence is blind to exactly the failure class that bit us.
- **each artifact lives in the system matching its install channel** :
  os-pkg = apt , ext-pkg = pip/npm/uv-tool , build-zenka = scripts /
  tarballs / git [ per build-zenka recipe `kind:` taxonomy : `git-build` ,
  `tarball-extract` , `pip-venv` , `vendor-deb` ].
- **install-if-missing everywhere** ; ongoing version management stays
  with each tool's own updater.
- **one coverage view** : the phase-2 audit already planned in
  cfg/zenki/ext-pkg/README.md [ task 2.1 ] reads all registries into a
  single status view -- this task extends that idea to the whole chain.
- the chain **crosses the WSL boundary** : the windows host has its own
  tier-0 [ winget ] -- see data/tasks/ext-pkg-winget-manager.md , the
  windows-side sibling of phase 1.

## phase 1 : agent runtime chain [ most useful first ]

**1.1 os-pkg tier-0.** register `uv` and `nodejs`/`npm` [ apt ] -- nothing
above tier 0 is resolvable on a fresh machine without them ; they are
untracked anywhere today [ checked .deps/profiles.yaml , 2026-10-27 ].

**1.2 ext-pkg split of the mismatched kimi-cli entry.** today its check
[`command -v kimi`] matches the *native* binary while its install
[`uv tool install kimi-cli`] creates the *legacy* tool the mcp server
actually execs -- green through total failure. split : `kimi-legacy`
entry [ uv-tool manager kept , check : `kimi-legacy --version` ] ; the
native binary leaves ext-pkg [ 1.3 ].

**1.3 build-zenka recipes for native installers.** `kimi-native`
[~/.kimi-code , moonshot curl installer , self-updating] consumed by the
kimi zenka , kimi-web zenka and interactive use ; `claude-native` as the
documented fallback in cfg/zenki/ext-pkg/packages/claude.yaml [ the host
already runs the native layout : ~/.local/share/claude/versions/ ].

**1.4 rot detection.** checks only pay off if they run : a periodic
check-run over every registry [ fold into the coverage audit ] turns
'dead for a day' into 'dead for minutes'.

## phase 2 : inference stack [ same pattern , existing consumers ]

- invokeai [ pip-venv recipe exists ] , invoke-web zenka , and the
  **custom invoke fork** built in parallel for qwen 2.1 text-to-image
  support [ invoke-web supports both ]. recipes must encode which fork /
  branch is live and why -- same discipline as ik_llama-cuda.yaml's
  `fix_cli_log` own-fork note.
- ik_llama.cpp [ ik_llama-cuda.yaml , git-build ] and prismml-llama.cpp :
  same treatment.
- goal : all of them buildable and *ensurable* from registry data, not
  from runbook memory in someone's head.

## phase 3 : generalized git-source auto-build [ horizon ]

- **ensure-on-demand** for `git-build` recipes : pinned ref , freshness
  check [ upstream ahead ? fork branch intact ? ] , build cache , clean
  rebuild triggers , artifact install step.
- the ensure verb unifies across all three systems -- os-pkg ensure ,
  ext-pkg ensure , build-zenka ensure -- one semantics, one coverage
  view, one place to ask 'is this machine ready to do its job ?'.

## non-goals

- fighting distro transitions [ no pinning the system python -- the
  durable form is uv-managed interpreters , lesson recorded in the
  incident memory ].
- ongoing version management [ tools own their updates ].
- replacing any tool's own updater.

#,,,.,.,,,...,,,,,,..,,,,,...,.,,,.,.,,,,,,..,..,,...,...,,..,...,..,,...,,..,
#J3CKG7RJ3HOW6BRBZDSCKYLKHOC23V47PSJKZHTJCD7LUO3DCKACOTAZHJUHMNLALQ2ZV7RTTHAAE
#\\\|WZS4GWL3WTTA66GT5DDMOBP5KVCMYUJHIU47HWUHL3SFSAKWJKH \ / AMOS7 \ YOURUM ::
#\[7]4BIQHDZHLTG5SEG4VYHAOOT5GECZ4BC2GV35FCHX7T6R5N335SAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
