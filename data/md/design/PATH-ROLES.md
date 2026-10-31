## [:< ##

# path roles
# the official /data/ paths and the roles code asks for, not the paths

---

## why

[ owner 2026-10-31 ] a network grows out of the project stage -- the
personal project stage above all -- by definition. the structure gets
ready for that now, while there are no users yet and nothing has to stay
compatible :

- `/data/` paths are kept and used OFFICIALLY, intuitive to read
- `/data/source/` replaces the personal `/data/projects/` [ the owner moves
  their own habits over ] ; 'project' is already gone from the readme title
  [ A193AE72, 'network' instead ]
- every path stays mappable to something else by the set-up tools

today 54 tracked files under src \ bin \ cfg hardcode
`/data/projects/protocol-7` and 10 `/usr/local/protocol-7` [ 2026-10-31 ].
code should ask for a ROLE ; one place resolves it.

---

## principle : ownership

[ owner 2026-10-31 ] the FHS is ordered by what the SYSTEM needs ; it has
no user aligned branches -- `/var` is unsafe for real user data, `/srv`
implies root controlled deployment only, `/home` mixes config, caches and
data [ the owner's systems use `/users/` instead ]. protocol-7 composes a
meta operating system and may order by OWNERSHIP, as long as it stays
logical :

| path | belongs to | holds |
|---|---|---|
| `/usr/local/protocol-7` | the system | installed software, replaced on update |
| `/var/..` | the system, transient | sockets, caches, logs -- lost without harm |
| `/users/<name>` | one person | personal, private |
| `/data/..` | the user \ the network | content people care about, shared or carried |

the test for every new path : who owns it, and would losing it hurt ? if
it hurts, it is not `/var`.

- `/data/` is NOT ordered by hardware [ raw device mounts like
  `/data/disk-0000/`, `/data/disks/` -- the owner's systems used it like
  `/mnt` ] and NOT by file type [ `/data/html`, `/data/pdf`, `/data/odt` ..
  -- neither to copy ]. mounts as such are fine : `/data/network/` is
  mounted too, but its structure comes from the protocol mapping, not
  from the disk under it. disks belong in the address where they mean
  something [ N7FS : the `<disk>` level under `/N7FS/` ], not as a
  top-level folder
- **today's exception** : `/var/protocol-7/` still holds data that must
  NOT be wiped -- `/var/protocol-7/jobsite/` and everything zenki work
  with. it moves out by the ownership rule as N7FS takes over storage ;
  until then no tool may treat `/var/protocol-7/` as disposable
- clean dynamic mapping makes the ownership view implementable as it
  should be, instead of stale static trees with overlapping, ambiguous
  permissions and access

---

## roles

| role | default | holds |
|---|---|---|
| `install` | `/usr/local/protocol-7` | the running zenki, production [ stays ] |
| `work` | `/data/source/protocol-7.work` | the coding zenka's worktrees [ user content : reviewed source ] |
| `dev` | `/data/source/protocol-7` | a developer checkout on a dev-enabled host |
| `network` | `/data/network` | protocol namespaces, mapped by zenki |
| `users` [ optional ] | `/users` | personal branches [ a host may map it to `/home` ] |
| `state` | `/var/protocol-7` | zenka runtime state -- see today's exception above |

- resolution : host config [ the host's cfg dir, never the repo ] over the
  defaults above ; one helper answers 'path of role X'
- `work` : a `git worktree` of the install or dev repository, its own
  branch [ e.g. `/data/source/protocol-7.work/<task>` on `coding/<task>` ]
  -- coding never edits the running tree, the result is an ordinary
  branch diff. its disposable parts [ inference caches, sockets, temp ]
  go to `state`, not next to the source. the name may still change to
  match other current \ future zenki [ owner has candidates ]
- `dev` is optional : a production host has no dev role

---

## /data/network/

one neutral place per protocol, p7 being one of several :

```
/data/network/
├── p7/
│   └── N7FS/
│       └── root/ ..
└── xmpp/ ..        [ an external protocol, mapped by its gateway zenka ]
```

- names : short protocol names [ `p7`, `xmpp`, `jabber` ], lowercase ; never
  both `p7/` and `protocol-7/`
- mounts : `nosuid,nodev,noexec` by default ; fuse without `allow_other`
  unless a protocol needs it
- untrusted names : content from outside can carry `..`, control
  characters, very long names, symlinks out of the tree -- the mapping
  zenka normalizes them [ N7FS ids are safe by construction, xmpp is not ]
- tree walkers [ `find /data`, backups, indexers ] skip it : own mount
  point \ backup exclusion -- network content can be large, slow, remote

**N7FS today** : `N7FS-SPEC.md` section 1 has its own fixed entry point
`/N7FS/<disk>/..` [ a directory or symlink per host ] and knows nothing of
`/data/network/` yet. that stays as it is ; `/data/network/p7/N7FS/` comes
later as a mapping onto the same tree, decided when N7FS work resumes.

---

## steps

1. the role helper + host config keys ; switch the 54 + 10 hardcoded
   spots [ `bin/ncode` makes it mechanical ]
2. `cfg/install/bin-links` : the curated `/usr/local/bin` entries
   [ p7c, p-7-r compiled there by v7-zenki ; links for amos-chksum, nshell,
   .. ] used by p7-install and v7-zenki, warning when a root-run target
   sits in a tree not owned by root ; root's PATH case still to clarify
3. the coding work copy as a worktree [ after the path name is chosen ]
4. the owner moves the dev checkout to `/data/source/protocol-7`
5. `/data/network/` mappings, protocol by protocol

#,,..,,..,,.,,..,,,.,,,,,,.,.,,.,,,,.,,.,,,..,..,,...,...,...,..,,..,,.,,,,,,,
#67UOEOTB73TKHM5WNZRCQVEXKMJSP5VN6DT66V5S3K5DKZIEFQK22K2SOW6Y5BPZHUOFIJADP5QJK
#\\\|QDRRZ5AJ7RTS7I723B22RBKB5AYMHNV7VRAPP3WODFKBXZF4W65 \ / AMOS7 \ YOURUM ::
#\[7]S3N7C3FNCSL67HAD6CBRPERLJO32TNMS355YAHWIUZLDT5TJZGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
