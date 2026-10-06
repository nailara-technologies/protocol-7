---
name: feedback-release-version-tag-explicit
description: release flow : `release-version 2>cfg/protocol-7.rel-ver` [ bare version on STDERR by design ] ; `-s` without an argument RECALCULATES the version [ time-dependent ] instead of reading cfg/protocol-7.rel-ver -> tag with the explicit version : `bin/dev/release-version -s AMOS7-v<x.y.z>`
metadata:
  type: feedback
---

2026-10-06, release AMOS7-v6.13.5 [ `1282c3cd6` ] : `bin/dev/release-version
-s` tagged **AMOS7-v6.13.8** -- it calculated a fresh version [ the
calculation has a time component ; source version and rel-ver were both
unchanged ] instead of using the committed `cfg/protocol-7.rel-ver`. the
wrong tag was local only, deleted, re-tagged correctly.

**Why:** in `-s` mode the tool tags whatever it calculates unless a version
is passed ; the calculated value drifts between writing rel-ver and tagging.

**the intended release flow [ user ]** : the tool prints ONLY the bare
version string on STDERR [ the decorated lines go to stdout ], so
`bin/dev/release-version 2>cfg/protocol-7.rel-ver` writes the release file
directly [ the terminal line then shows the version part empty -- by
design ] ; then sign + version [ `uvs` ], commit, tag.

**How to apply:** after the release commit, tag with the version FROM the
committed file : `bin/dev/release-version -s $(head -1 cfg/protocol-7.rel-ver)`
-- validate it first [ `^AMOS7-v\d+\.\d+\.\d+$` ], see
[[feedback-never-feed-command-substitution-into-destructive-cmds]] -- then
check `git tag --points-at HEAD` before pushing tags.

#,,.,,,,,,.,.,.,,,,..,.,,,..,,,,,,,,,,.,.,,,,,..,,...,...,,.,,...,.,,,,,.,,.,,
#GK2U4JITEZNNHTFVHX6WB74CZPEOFNBIGKIIYU2AZ2ADWACI5UAUOV6XOQXMFM2ANBPW64COUKCWW
#\\\|E7LJRSWVLUDZAJKOO2AGX4NBBDI7KC76GNU6UG3MJG5I6PAJ7A7 \ / AMOS7 \ YOURUM ::
#\[7]5MURZFAJSQZI5LIUC5Q5OCVMLJADPL55VQTQOCJQIZL56QQXGACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
