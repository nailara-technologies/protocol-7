# files zenka : attachments, scoped fetch, delegated read rights

draft 2026-10-22. design only -- no code, config or todo changes come with
this file. source : todo J5F [ data/yaml/todo/base.yaml, the 'prefer a
dedicated file-access zenka' entry ] and the owner's direction for this
session. owner decisions taken as given : the name is `files` [ `file.*`
is already the call space of the base.file.* modules through base.
aliasing, and 'files' fits free lists ], a separate user-facing zenka
named `file-view`, attachment groups with nesting, and [ follow-up the
same day ] native N7FS integration : the store IS an N7FS disk.

builds on [ do not rebuild ] : CREDENTIAL-LAYERS.md [ the grant model,
the cred-mesh access lesson ], SESSIONS-ZENKA.md [ session classes ],
LINK-ZENKI-AND-TRANSPORTS.md [ link identities ], AUTH-LINK-BINDING.md
[ the bound link, the exact-bytes signature style ], HOST-ROOT-DELEGATION.md
[ host-root as issuer ], STRM_DESIGN.md, N7FS-SPEC.md + N7FS-FORMAT-1.md
[ the store ], TIMESTAMP-DELTA-SYNC.md [ tombstones ].

## what exists [ read 2026-10-22, base 8bea3a1e ]

- **coding's confinement** [ local, uncommitted, described by the owner ] :
  one input decoder `coding.input.decode` with explicit prefixes plain \
  `B32:` \ `:file:`. `:file:` stays inside the repo tree [ realpath,
  symlink escapes refused, size limit, one log line per read ]. outside
  the tree the CALLER reads with its own rights and sends the content
  [ `bin/coding-task -file` already does this, base32r ]. J5F names the
  gap this leaves : going beyond the repo tree would mean broad rights in
  the coding process, which talks to models.
- **caller identity** : cube rewrites `SOURCE_ZENKA` \ `SOURCE_SID` in an
  alias target with the session's authenticated user name and session id,
  and prepends them to `args` [ `src/base.handler.command`, ALIASES
  section ]. the commands that use it are listed in
  `cfg/zenki/cube/command_aliases` [ `credentials.request_session`,
  `cred-mesh.subscribe_rotation`, ... ]. a caller cannot forge that first
  token.
- **access lists** : `cfg/zenki/cube/access.zenki`. `access.cmd.usr.*`
  grants to every zenka. it holds `cred-mesh.resolve` \ `rotate` \
  `approve`, which CREDENTIAL-LAYERS.md names as the hole : a store
  reachable by everyone, whose command never checks the caller. per-zenka
  lines [ `access.cmd.usr.v7-zenki = ...` ] are the narrow form.
  `*.ui-show` is granted under `usr.*` as a wildcard.
- **multi-line commands** : `<cmd>+\n`, header lines `key : value` or
  `key = value` into `$call->{'param'}`, an empty line, body lines into
  `$call->{'data'}`, and a line holding only `.` ends the packet. there is
  no dot-stuffing, so a body line that is just `.` cuts the packet short.
  raw file content is therefore unsafe there : NUL bytes, lone dots, and
  a missing final newline all break it. see `src/devmod.cmd.receive-multiline`
  for the receiving side.
- **replies** : `{ mode => 'size', data => ... }` sends a `SIZE <n>` reply,
  which the receiver reads bytewise. STRM \ STRM-SIZE need a declared
  total at open [ `topic-strm-unbounded-gap.md` ]. a file of known size
  has one, so that gap does not affect this design.
- **checksums** [ `AMOS7::CHKSUM`, `AMOS7::13`, `src/base.chk-sum.*` ] :
  - `amos_chksum` \ `chk-sum.amos` : an ELF-7 value, VAX-packed to 32 bits
    [ `pack V` in `chk-sum.elf.vax-BASE32` ], 7 base32 characters, and
    truth-filtered on top. that is about 32 bits.
  - `chk-sum.bmw.L13-str` : 13 characters, about 65 bits.
  - `AMOS7::13::key_56` \ `chk-sum.bmw.B-32-56.TRUE` : BMW-384 of an
    optional `<name>:` prefix plus the data, base32, cut to 56 characters
    [ 280 bits ] and harmonized by XOR rounds from the cut-off remainder
    until `is_true`. deterministic.
  - `chk-sum.bmw.filesum.56.TRUE` : `key_56` over a whole file, which it
    slurps, with a 63M cap. it blocks the event loop.
    `chk-sum.bmw.filesum` streams [ `addfile` ] but returns plain BMW, not
    harmonized.
- **own unix user** : `base.root.drop_privs` takes a user and secondary
  groups [ explicit, or auto-detected from membership ]. httpd drops to
  its own `<httpd.system.user>`, which is the precedent. most zenki run
  as `<system.amos-zenka-user>` [ 77 start files ; coding sets it as
  `coding.cfg.drop_privs_user` in `coding.init_code` ]. desktop zenki
  drop to `<system.AMOS-user>`, a few to `<system.admin-user>` \
  `<dbus.privs_user>`. the shared zenka uid means those zenki can read
  each other's var files.
- **index zenka** [ `cfg/zenki/index` ] : `feed-dir`, `add-path`, `search`
  and more, reading paths itself as `<system.amos-zenka-user>`.
- **N7FS format 1** [ `bin/n7fs`, `AMOS7::N7FS*`, N7FS-SPEC.md,
  N7FS-FORMAT-1.md, todo 4EO ] -- what files can build on :
  - node : `/N7FS/<disk>/<epoch>/<amos>/<bmw>/content` [ 0400 ] plus
    `meta/<ntime14>.<tail8>.meta` [ P7FN plain record, a fixed payload :
    name format size mtime import_ntime epoch_num source host amos bmw
    disk, optional index_chksum index_name ]. directories are 0700.
  - `<bmw>` = BMW-384 of the raw bytes, base32, 77 characters.
    `<amos>` = `amos_chksum` over the BMW TEXT [ rule
    `amos7-of-bmw384-b32` ], 7 characters. `<epoch>` = the write epoch
    [ `V7` + 5 characters, one epoch = 365 / 13 days, about 28 days ].
  - a disk is a parent-signed identity [ `.n7fs/id.record` ], with signed
    mount records, a host-side witness window and plain state records.
  - writes are immutable : temp + fsync + link \ rename. nothing is
    rewritten ; a second import of the same content adds a meta file.
  - dedup happens inside the WRITE epoch only : `_assimilate_one` checks
    `node_path` under the current epoch, so content stored in an older
    epoch gets a second node.
  - the node writer takes a source FILE PATH [ `_open_regular` ], not a
    buffer or a stream. assimilate refuses sources inside the N7FS root.
  - a reader REFUSES any unexpected entry. format 1 knows no
    `references/`, no `chunks/`, and no record kinds beyond id, mount,
    use, state and meta.
  - nothing removes a node. `remove_tree` serves temp names and the
    release of a whole epoch after a confirmed upgrade.
  - content is stored as plaintext. 'secrets enter only as ciphertext'
    is not enforced. replication to N holders is not built.
  - the host-root signer plug [ `-parent-cmd 'p7c v7-zenki.n7fs-sign'` ]
    is named, not written.
  - signed timestamp entries with tombstones are designed for nameserv
    [ TIMESTAMP-DELTA-SYNC.md ], with N7FS as a later stage 5 user.
- **no files zenka, no file-view zenka.** the older 'file zenka' idea
  [ `topic-searchable-index-and-visualization.md` : a generic file
  abstraction for non-code data in the checksum dataspace ] was never
  started.

## 1. jobs

| zenka | single job | holds | never |
|---|---|---|---|
| files | **read rights, held in one place** : attach, fetch, revoke, groups, capabilities | its own unix user with exactly the read rights it may hand out ; its N7FS disk | talks to a model ; renders ui ; holds broad rights 'just in case' |
| file-view | **what a person sees and manages** : list, inspect, tree, revoke, log | no file rights, no store ; only files' management commands | fetches content ; attaches ; imports |
| coding [ and other consumers ] | asks files, uses what fetch gives | handles it was given | reads outside the repo tree itself |
| index | searchable checksum index [ later : fed through files ] | its index state | -- |

three rules connect them :
- **authority is identity plus scope, checked by files.** knowing a
  checksum never grants anything.
- **files never reads on someone's behalf with rights they lack.** a read
  with the caller's own rights happens on the caller's side, and the
  content is handed in. a path read by files uses FILES' rights, limited
  by that caller's entry in files' own access list.
- **narrowing is free, widening needs authority.** anyone who can manage
  an attachment may shorten, narrow or revoke it. widening is a new
  attach, or a capability from someone who holds the right.

## 2. ids : content id and handle

two ids with different jobs. the owner's 'one checksum id that can be
handed over' is the **handle**.

- **content id `C`** = the N7FS `<bmw>` of the content : BMW-384 of the
  raw bytes, base32, 77 characters [ N7FS-FORMAT-1 'encodings' ]. it is
  for dedup, the node path, and integrity : the fetcher recomputes it.
  anyone who holds the content can compute it, so it is a name, not a
  secret. ONE addressing scheme : `C` is not a second id next to the
  N7FS address, it is its content part [ section 7 ].
- **handle `H`** = `key_56` of `C`, with the name prefix
  `p7 files attach v1:<nonce b32>:<scope line>` [ nonce : 32 bytes from
  `base.prng.bytes` ]. one content attached to two scopes gets two
  unrelated handles. nobody can derive a handle from the content. a
  handle names a scoped record, not bytes, so it is not an N7FS address
  and need not be one.

why these checksums :
- `amos_chksum` is about 32 bits. collisions turn likely at about 2^16
  items, and guessing is within reach. too short for an id. N7FS uses it
  only as a directory level over the bmw text, where a collision is two
  `<bmw>` siblings, not an error.
- L13 is about 65 bits, with collisions near 2^32 : fine for a display
  tag, thin for a store key.
- **why not `key_56` for `C`** [ the first draft of this file ] : with
  no name prefix, `key_56` starts from exactly the N7FS bmw string
  [ `encode_b32r bmw_384( content )`, 77 characters ] and then works on
  that string alone : cut to 56, XOR-harmonize from the 21 cut-off
  characters until `is_true`. so `key_56( content ) = harmonize( bmw )`,
  a pure function of the N7FS address. it maps one way only : a node
  cannot be found from a `key_56` value without an extra table. two ids
  where one is derived from the other buy nothing but that table. `C`
  is the bmw. the 'true value' property of `key_56` stays where it
  matters : on the handle.
- the streaming gap of the first draft is gone : N7FS already hashes
  while it copies [ `AMOS7::N7FS::Sum::bmw384_fh`, the 1M read loop in
  `Store::_v1_write_node` ]. the handle's `key_56` runs over the 77
  characters of `C`, never over content.
- short forms, never accepted as input : the 7-character N7FS amos of
  `C` [ the node's directory level ] in file-view rows, the 13-character
  L13 of a handle in log lines.

**one answer for every miss** : `files.fetch` replies
`FALSE no such attachment` for unknown, not yours, expired, revoked and
used up alike. the log line says which one. otherwise fetch would confirm
that an attachment exists. the content id goes only to callers who pass
the scope check : the attacher, a fetcher [ in the fetch reply header
and in group manifests, so it can verify ], and file-view for the people
allowed to see that record. a caller allowed to fetch gets the content
anyway, so `C` tells it nothing new. a caller who fails the check never
sees `C`.

## 3. attach

two forms, never mixed in one call :

```
files.attach+                          content handed in [ caller's own read ]
target  : coding
task    : <task id>                    optional
expires : 3600                         seconds, capped by config
fetches : 1                            optional, default unlimited until expiry
name    : notes.txt                    display only, never a path
size    : <bytes>                      exact length after decoding
                                       <- empty line
<base32r of the content, wrapped>
.

files.attach :path:<absolute path> -target coding [ -task <id> ] [ -expires <s> ]
                                       files reads with ITS rights
```

- **content in** : the caller has already read the file with its own
  rights [ `bin/coding-task -file`, a p7c client helper, a zenka that
  holds the data ]. the body is base32r, because raw bytes are not safe
  in a multi-line body [ see 'what exists' ]. `size` is required and
  compared after decoding.
- **path** : files resolves `realpath`, refuses a symlink that leaves the
  allowed prefix, opens with `O_NOFOLLOW` on the last component, checks a
  regular file, size limit, and the caller's access-list prefixes, then
  hashes while it reads. this is today's coding confinement, moved to the
  process that holds the rights. 'the caller's own unix rights' cannot be
  checked here : files does not know the uid behind a cube identity, and
  testing another uid's access needs root [ open question 4 ].
- reply : `TRUE <H> <C> <size>`. the attacher is recorded as cube named
  it [ `SOURCE_ZENKA` ], and the person too when the session belongs to
  one [ section 11 ].

an attachment record [ its fields ; how it is stored : section 7 ] :

```
handle   : <H>
content  : <C>                               the N7FS bmw
node     : <disk>/<epoch>/<amos>/<C>
size     : <bytes>
name     : <display name>
origin   : content | path:<path>
by       : <cube identity> [ person : <user> ]
target   : coding | @<caller group>          section 6
task     : <task id> | none
session  : <cube instance>:<sid> | none      optional binding
expires  : <ntime>
fetches  : <max> | none     fetched : <n>
state    : live | revoked | expired | used
parents  : [ <group handles> ]
at       : <ntime>
```

## 4. scope and the fetcher's identity

- **local zenki** : `files.fetch` \ `attach` \ `revoke` go into
  `setup.aliases.source_zenka` [ `cfg/zenki/cube/command_aliases` ], so
  files gets the caller as cube authenticated it, as the first token.
  scope check : `caller eq target`, or caller in the target caller group.
- **session binding** [ optional, `session` field ] : `SOURCE_SID` is a
  cube session number, and it repeats after a cube restart. files stores
  it together with a cube instance marker [ which marker : the one
  `*.verify-instance` uses, if it fits -- not checked here ], so a
  restarted cube never matches. a session-bound attachment dies with
  that session, which is the point of binding it.
- **task id : what it proves and what it does not.** cube proves the zenka
  name, never a task inside it. `task` is coding's own word : it keeps
  task A's handle out of task B by mistake, and away from other zenki.
  it does **not** protect against a compromised coding zenka, which can
  name any task. real per-task proof needs tasks running as child zenki
  with their own cube identity [ `coding.<child>` routing exists for
  forked children ]. then `target` names the child and `task` becomes a
  label [ open question 3 ].
- **remote callers** : over a link, a remote zenka shows up under the link
  identity cube authenticated [ AUTH-LINK-BINDING v2, LINK-ZENKI ]. a link
  identity can be a target like any name, but it never gets a `:path:`
  entry in the permanent access list. path reads for remote callers go
  through capabilities [ section 9 ].
- **files' own key** : files signs nothing a caller has to trust in
  stage 1. from stage 3 it signs fetch receipts and its log checkpoints
  with its own `<user>.base` C25519 key [ `crypt.C25519.*` ], label
  `p7 files receipt v1`.

## 5. lifetime : expiry, fetch count, revoke

- **expiry** : required, defaulting to `files.cfg.default_expiry`
  [ proposed 3600 s ], capped by `files.cfg.max_expiry` [ proposed one
  day ]. nothing lives forever : a lasting need is an `import` plus fresh
  attaches [ section 10 ].
- **fetch count** : optional. `fetches : 1` makes a one-shot handle. the
  count goes up before the reply is sent, so a dropped connection uses
  the fetch up [ fail closed ].
- **revoke** : `files.revoke <H>` by the attacher, by file-view for a
  person allowed to manage the record, by the owner \ host admin. the
  record stays as history [ `state : revoked` ]. revoking does not undo a
  fetch that already happened [ CREDENTIAL-LAYERS : revoking a copy does
  not undo exposure ].
- **content gc** : content `C` should go when no live attachment and no
  import references it. a sweep timer [ proposed 60 s ] expires records.
  removing the node is an **N7FS gap** : format 1 removes no node
  [ section 7, 'expiry and revoke against immutability' ]. access
  control does not depend on it : files refuses a dead handle whether the
  bytes are still on disk or not.

## 6. groups

two different things can be called 'groups'. this design takes both, and
keeps them apart :

- **attachment groups** -- WHAT is handed over : a named set of
  attachments and other groups, with one handle for the whole set.
- **caller groups** -- WHO may fetch : a named set of zenki, link
  identities, persons and other caller groups, usable as a `target` and
  in files' access list.

the reading taken here : attachment groups are the owner's addition
[ 'one checksum id for a group handed over as a whole' ]. caller groups
are a small config-side feature next to them. they touch at exactly one
point : a group's `target` may name a caller group [ open question 7 ].

### attachment groups

```
files.group-create <name> -target coding [ -task <id> ] [ -expires <s> ] [ <H> .. ]
files.group-add    <G> <H|G2> ..          files.group-remove <G> <H|G2> ..
files.fetch        <G>                    -> manifest
files.fetch        <G> <member path>      -> content [ e.g. <G>/<G2>/<H> ]
```

- **handle** : `G` = `key_56` with the prefix
  `p7 files group v1:<nonce>:<scope line>`. it does not depend on the
  members, so adding a member keeps the handle that was handed over.
- **manifest** : a canonical list [ sorted, one line per member : kind,
  handle, name, size, content id ]. each version is an N7FS content node
  of its own, so its bmw is the group's content id for that version
  [ section 7 ]. a fetch of `G` returns the manifest with that id, so a
  fetcher can tell 'same set as before'.
- **frozen groups** [ optional, `files.group-freeze <G>` ] : a sub-group
  line normally names the sub-group's HANDLE, so a change below does not
  ripple up. a frozen version names each sub-group's manifest bmw
  instead. its own bmw then fixes the whole tree, a checksum tree in the
  sense of N7FS-SPEC 'decisions after version 1', and is a good form for
  'handed over as a whole'.
- **in N7FS terms** : groups are manifest NODES, never directories. N7FS
  paths are checksum levels plus fixed key words, and a format 1 reader
  refuses any other entry, so a group name or a member name never
  becomes a path level. the tree that file-view draws is read from the
  manifests. the group record [ handle, scope, newest manifest bmw ] is
  a record node like an attachment record [ section 7 ]. `chunks/` in
  the spec is for splitting ONE content and is not used for groups.
- **nesting** : members may be groups. cycles are refused at add time
  [ walk the parents ]. depth is limited by `files.cfg.group_depth`
  [ proposed 7 ]. a group may sit in more than one parent [ a dag, not
  only a tree ].
- **inheritance, per path** : a fetch goes down from the handle the
  fetcher holds. along that path :
  - scope : the fetcher must pass the check at EVERY level on the path.
  - expiry : the earliest one on the path.
  - fetch count : each level counts its own fetches. `fetches` on a group
    counts manifest fetches and member fetches through it.
  - revoke : revoking `G` cuts every path through `G`. a member that also
    has its own handle stays fetchable by that handle until revoked
    itself. `files.revoke -deep <G>` also revokes every member below `G`
    that the revoker may manage [ its own attachments, or all of them
    for the admin ]. members owned by someone else stay live under their
    own handles.
- **override = narrow only.** a level may set a shorter expiry, a lower
  fetch count, a narrower target [ a member of the target caller group,
  or a task ]. it can never widen what its parent allows. a member
  attached to `coding` sitting in a group for `@coding-workers` is still
  fetchable by `coding` only. widening is a fresh attach [ open question
  6 asks whether the owner wants real widening ].
- **membership rights** : only the group's creator [ or a manager through
  file-view ] adds and removes members. adding requires that the adder
  could already fetch \ manage the member, so a group never turns
  someone else's handle into one of yours.

### caller groups

- declared in files' config, not at runtime : `cfg/zenki/files/callers`
  [ EXAMPLE only, not real config : `@coding-workers = coding coding-13
  remote-fetch` ]. a remote member is named by the identity the local
  cube authorizes for it, the host record's `link_user`
  [ LINK-ZENKI-AND-TRANSPORTS 'the name problem' ].
  members may be other `@groups`, flattened at load, with cycles refused
  at load time.
- used in `target`, and in the access list [ section 7 ]. a fetch checks
  membership at fetch time, so changing the config narrows or widens the
  live attachments that name the group. file-view shows that [ section 11 ].
- not cube's access lists : cube decides who may CALL `files.fetch` at
  all, and files decides which handles they get. the two are kept
  separate so cube's config stays readable.

## 7. storage : an N7FS disk, rights, limits, logging

- **unix user** : files drops to its own user [ proposed `p7-files` ]
  through `base.root.drop_privs` with secondary groups. the user holds
  exactly the read rights files may hand out : group memberships or POSIX
  ACLs on named trees, set up by the host setup [ HOST-SETUP.md ], never
  by files itself. on day one that is read access to the repo tree and
  coding's task dir. this split is what makes the store private : under
  the shared `<system.amos-zenka-user>` every zenka could read the store
  directly.

### the store is an N7FS disk

no store format of its own. files owns one N7FS disk, and every byte it
keeps lives in that disk as an N7FS node.

- **the disk** : created once by `n7fs init` as `p7-files` [ name
  `files`, intent `files attachment store` + host record name ], so its
  0700 directories belong to that uid alone. the n7fs host dir
  [ store key, witness ] is `p7-files`' own `~/.n/n7fs`. the parent
  signer should be host-root. its plug [ `v7-zenki.n7fs-sign` ] is not
  written yet **[ gap ]**, so until then the parent is the owner's key or
  trust on first use, as format 1 allows.
- **attached by the host setup, not by every start** : each attach writes
  a signed mount record. an on-demand zenka starting many times a day
  would grow the travel history for nothing. files checks at start that
  its disk is attached and the witness says `current`, and refuses to
  serve otherwise.
- **content** : one node per content, with one neutral meta record
  [ 'what goes into a node's meta' below ]. the fixed meta payload has
  no field for a handle or a scope, and it does not need one : scope,
  names and sources live in records.
- **records** [ attachment, group, revoke, expiry, the fetch of a
  counted handle, capability revocations ] : each version is the
  record's canonical bytes, stored as a content node of its own. a
  format 1 reader takes that as plain content, so no format step is
  needed. each version names its handle, its ntime and the bmw of the
  version before it, which makes a chain per handle. the bytes start with
  a magic + format byte in the N7FS way. the proposed `P7FH` \ label
  `p7 files record v1` is a PROPOSAL : the magic table is N7FS-FORMAT's,
  and adding a row is a change there.
- **manifests** : content nodes [ section 6 ].
- **log** : append-only chunks, each a content node naming the previous
  chunk's bmw. that hash chain is what the stage 3 signed checkpoints
  sign.
- **outside the disk, two things only** :
  - `<var_P7>/files/heads` [ 0600 ] : handle -> newest record bmw, and
    content -> the handles that reference it. it is an INDEX, rebuilt by
    walking the record nodes, and never the authority for 'newest' : a
    record chain only points backward, so a crash after a revoke or
    fetch record node and before the heads update would leave the handle
    live, or give a one-shot handle a second fetch. at every start files
    reconciles the heads against all record nodes newer than the heads
    file, and serves only after that. it exists because N7FS format 1 has no
    mutable pointer. the spec's
    `references/<ntime-dec>/<amos>/<bmw>/addr` is designed, not built
    **[ gap ]**. when references land, the heads move into the disk and
    this file goes.
  - `<var_P7>/files/spool/` : content handed in arrives over cube, but
    the node writer takes a source path, and assimilate refuses a source
    inside the N7FS root. so files spools outside the root, writes the
    node, and removes the spool file. a write from a stream or buffer in
    `AMOS7::N7FS::Store` would remove the spool **[ gap ]**.

### one addressing scheme

- `C` is the node's `<bmw>`. the other two levels follow from it or from
  where it was written : `<amos>` = `amos_chksum( C )`, and `<epoch>` =
  the write epoch. the full node path `<epoch>/<amos>/<C>` is root-free :
  the same on every disk.
- **lookup by `C`** : probe `<e>/<amos( C )>/<C>` for each epoch `e` in
  the disk's newest state record. there are few epochs, so it is cheap.
  records keep `C` as the truth and the node path only as a cache,
  because an N7FS upgrade rewrites nodes into the next epoch.
- todo 4EO's `:<content>` form, a root-free address with an empty
  holder part, is exactly `:<C>`.

### dedup

- **within the disk** : the same content is one node, however many
  handles name it. files looks the content up in every epoch first and
  references what it finds, so the format 1 limit [ dedup in the write
  epoch only ] costs nothing here : a record that points at an older
  node writes nothing into it.
- **across attachers** : one node for two attachers is the N7FS design.
  salting the content per attacher would give the same bytes two
  addresses and break the one scheme. on a private single-host disk the
  remaining signal is store size and timing [ open question 11 ].
- **across disks** [ planned, blocked by an **N7FS gap** ] :
  `files.attach :n7fs:<C> -disk <disk>` would reference content that is
  already in another N7FS disk, with nothing copied. format 1 creates
  directories 0700 and content 0400 under the creating uid, so
  `p7-files` cannot read another user's disk. POSIX ACLs do not get
  around this : per acl(5), a new object's mask is cut down to the group
  bits of its create mode, which are `---` here, and that masks out
  named-user entries [ the rule as documented, not tested on a host
  here ]. this needs an N7FS format step [ a group or a mode for shared
  read ], or the other disk created as `p7-files`. once it works :
  - revoke stops access, and the bytes in that disk are never files' to
    remove.
  - only callers whose entry allows the `n7fs` form for that disk may use
    it, because a probe by `C` would tell whether that disk holds the
    content.
  - `:n7fs:` **refuses files' own disk**. otherwise a caller could name
    any node in it by `C`, including other people's content and the
    record nodes, past scope and past the `:stored:` own-imports rule.

### what goes into a node's meta

the meta payload is fixed, and anyone who can read the node reads every
meta file on it. a node shared by several attachers would collect their
names and paths. so files writes ONE meta per node, at first write, with
neutral values : name = the content's amos, source = `files`. the real
name, source path and attacher stay in the scoped record nodes. assimilate
fills `name` and `source` from the source path, so reusing its per-file
step needs a public entry point with a meta override **[ gap ]** : today
that step is the private `_assimilate_one` with an internal signature.

### expiry and revoke against immutability

- **records are never rewritten.** revoke, expiry and a counted fetch
  each add a new record version. the newest version by ntime, checked
  against its chain, is the state. a damaged newest version makes the
  handle DEAD, with no fallback to the older one. that follows format
  1's rule for records that decide trust : a fallback is what a rollback
  wants.
- **fetch counts** : only a handle with `fetches` writes a fetch record,
  and it does so before the reply. unlimited handles log in the chunks
  only, which keeps the inode cost down [ N7FS-SPEC 'open' : small
  files ].
- **removing bytes is an N7FS gap.** three ways, none built :
  - a. **node release** [ recommended ] : a new N7FS operation
    `release <addr>` that removes a node and writes a tombstone signed
    by the store key, shaped like the TIMESTAMP-DELTA-SYNC tombstones, so
    a union sync never brings the node back. format 1 does not use the
    store key yet.
  - b. **epoch release** : the only removal in format 1, tied to a
    confirmed upgrade. with a one-day max expiry against a 28-day epoch,
    bytes would stay for up to about two epochs. it also misuses the
    upgrade path.
  - c. **a disk per period** : a fresh disk per epoch, detached and
    deleted as a whole once its last handle is dead. it works with
    format 1, but it is heavy.
- **until removal exists** : revoke and expiry are enforced by files as
  designed. the bytes of dead handles stay on the disk, readable by
  `p7-files` alone, and they are in any backup of `/N7FS`. file-view
  says so per record [ 'dead, bytes kept' ].
- **files' disk is never replicated** or union-synced with another copy
  until removal writes tombstones. a union would bring removed nodes
  back.
- **plaintext** : format 1 stores content as it comes. the unix rights
  are the only protection at rest. if content later enters as
  ciphertext, the node's bmw is over the CIPHERTEXT, and `C` as the
  plaintext id would be a second address again. two ways out : convergent
  encryption [ key from the plaintext hash : dedup and one address
  stay, but equal content stays visible as equal ], or a meta field
  `plain_bmw` that maps the plaintext id to the node [ two ids, one
  mapping ] [ open question 13 ].

### rights, limits, logging

- **read-rights list** [ `cfg/zenki/files/read-rights` -- not `access.*`,
  which names cube command-access files ], per caller or caller
  group : the forms allowed [ `content` \ `path` \ `n7fs` \ `import` ],
  the path prefixes, the N7FS disks, the allowed targets, and caps on
  size, count and expiry. the stage 1 entry for coding : `path` under the
  repo root + the task dir, target `coding` only.
- **limits** : per attach [ proposed 16M content in, 63M path ; N7FS
  sets no limit of its own ], per caller [ live bytes and count ], disk
  total. over a limit -> `FALSE` naming the limit, before anything is
  spooled.
- **cube access** : `files.attach` \ `fetch` \ `revoke` \ `group-*` go on
  per-zenka lines in `access.zenki`, for the zenki that need them, and
  never under `access.cmd.usr.*`. management commands [ `files.list` \
  `inspect` \ `log` \ `tree` \ `shorten` \ `store` ] are for `file-view`
  and the admin only.
- **logging** : one line per attach, fetch, refusal, revoke and expiry :
  identity, the handle's L13, the content's amos, size, form, the path
  for path reads, the scope, and the miss reason on refusals. a normal
  line goes to p7-log at level 1, a refusal at level 0. the same events
  go into the log chunks, which file-view reads through `files.log`.
  stage 3 : signed checkpoints over the chunk chain [ section 4 ].
- **blocking** : `AMOS7::N7FS` does plain blocking i\o [ fsync on every
  write ]. small writes stay in the zenka. large ones, and verify runs,
  go to a forked child, the way other zenki move blocking work off the
  event loop.

## 8. transfer

- **in, small** : multi-line attach with a base32r body [ about 1.6 times
  the size ], up to `files.cfg.inline_max` [ proposed 1M decoded ].
- **in, large** : not in stage 1. the code read here shows no inbound
  framing for a command payload [ multi-line is line-based ; SIZE \ STRM
  are replies and server-side streams ]. stage 2 picks one : chunked
  commands [ `files.attach-open <size>` -> upload id, `attach-chunk <id>
  <seq>` with a base32r body, `attach-close <id>` ], or a STRM that the
  CALLER opens toward files, if the protocol allows that direction
  [ open question 8 ].
- **out** : `fetch` answers `SIZE <n>` [ `mode => 'size'` ] up to
  `files.cfg.size_reply_max`, and a STRM-SIZE with the declared total
  above that. the fetcher recomputes `C` and refuses a mismatch.
- **manifests** : plain text, SIZE.

## 9. capabilities : delegation across hosts and tasks

the J5F layer : rights travel to a task, or to another host, for a while,
with no permanent entry in the access list. checked by files, never by
coding [ checks done inside coding would leave the broad rights in
coding ].

```
cap_body = pack( 'Z* a16 n/a* n/a* n/a* n/a* n/a* N N N C',
    'p7 files cap v1',
    cap_id,            16 random bytes
    issuer_key,        key id of <user>.base or host-root, as pinned
    holder,            cube identity the cap is for [ a remote : its link_user ]
    host,              host-edit record name of the files host
    path_prefix,       absolute, realpath form
    purpose,           task id or free label, logged
    not_before, expires, max_uses,     ntime seconds, ntime seconds, count
    forms )            bit 1 = path attach, bit 2 = fetch through groups
cap     = cap_body . Ed25519_sign( issuer, cap_body )
```

- **use** : `files.attach :path:<p> -cap <base32r cap> -target <t>`. files
  checks : the signature against a PINNED issuer key [ owner keys,
  host-root per HOST-ROOT-DELEGATION.md ], `host` eq its own record,
  `holder` eq the caller as cube named it, the path under `path_prefix`
  after realpath, the time window, the uses left, `cap_id` not revoked.
  the issuer must hold the right itself : the owner key for anything on
  their host, host-root for its host. files' own unix rights stay the
  outer bound no matter what a cap says.
- **holder-bound** : a stolen cap is useless to anyone cube does not name
  `holder`. replaying it by the holder itself is limited by `max_uses`
  [ counted in files ] and `expires`.
- **revoke** : `files.cap-revoke <cap_id>`, signed by the issuer, adds a
  revocation record node [ section 7 ] and an entry in the heads index.
  the entry counts until the cap's own expiry has passed.
- **attachments made through a cap** carry `cap : <cap_id>` in the record,
  and file-view lists them under the cap.
- the cap is minted on the issuer's machine [ `bin/p7-files-cap` or a
  p7-vault verb, open question 9 ], like CREDENTIAL-LAYERS' grant v1 :
  a user act, never a zenka's.

## 10. search, import, index

- **files.search** : metadata only, over what the CALLER could fetch or
  manage : name, content id, size, time, target, group path. no content
  search. it lives in files, because only files knows the scope of each
  record.
- **files.import** : puts content into files' disk under an OWNER record,
  with no fetcher and an expiry of its own [ longer, configured ], so the
  same content can be attached again later without sending it again :
  `files.attach :stored:<C> -target ..`. only callers whose access entry
  allows `import` may do it. the reply is the content id, never a handle.
  `:stored:<C>` resolves only against the CALLER's own import records,
  never against the whole disk : otherwise anyone who knows some content
  could probe whether it is stored.
- **import and N7FS assimilate** : for a path read, the node write is
  assimilate's per-file step [ lstat, `O_NOFOLLOW`, fstat equals lstat,
  hash, node, verify, re-hash the source ]. files should reuse that step
  rather than write its own, always in KEEP mode : files only reads, and
  never removes a source. it is not reusable yet : it is the private
  `_assimilate_one`, and its meta takes name and source from the path
  **[ gap : a public per-file entry point with a meta override ]**.
  moving data for good into a general, replicated N7FS disk stays the
  job of `n7fs assimilate` run by a person, not of files. the import
  record then expires in files, and the content lives on in that disk.
  files can reach it there only once the cross-disk read gap closes
  [ section 7 ].
- **files.index** : hands content to the index zenka the same way coding
  gets it : an attachment targeted at `index`, or a group for a tree.
  N7FS meta already has `index_chksum` \ `index_name` for an outside
  index [ the invoke-web image index ]. index entries for files' content
  key by `C`, so an index hit and an N7FS node are the same address.
- **the older 'file zenka' idea** [ a generic file abstraction for
  non-code data in the searchable checksum dataspace ] is a **later layer,
  not this zenka**. files is the access gate and the content-addressed
  store. indexing, dedup trees and the space.v7.ax views stay in index
  and its plugins. they become safer once index reads non-repo data
  through files instead of with its own rights [ today `feed-dir` reads
  as `<system.amos-zenka-user>` ]. the content id `C`, the N7FS bmw, is
  what joins files, N7FS and index : one address for the bytes in all
  three.

## 11. file-view : the person's side

a separate zenka, user-facing. files stays free of ui concerns : files
has no `ui-show`, no templates, no per-person rendering. note the
`*.ui-show` wildcard under `access.cmd.usr.*` : files must not define
one.

**holds nothing** : runs as `<system.amos-zenka-user>`, no file rights,
no copy of the store. everything comes from files' management commands,
over cube. it never calls `fetch`, `attach` or `import`, and its cube
access line lists only `files.list` \ `inspect` \ `tree` \ `log` \
`revoke` \ `shorten` \ `cap-list` \ `store`. a compromised file-view can see
metadata and take rights away. it cannot read content or grant anything.

**what a person sees** :
- **attachments** : list and filter [ by target, task, state, age, group,
  cap ]. inspect shows scope, expiry, fetch count used \ max, size,
  content id, origin [ the path for path reads ], who attached it, and
  its parent groups.
- **groups as a tree** : a fold tree [ CONSOLE-FOLD-TREE-PHILOSOPHY.md ]
  per group handle, members under their parents, each row showing its
  EFFECTIVE scope \ expiry along that path, and marking where a level
  narrowed it. a dag member shows up under each parent, with a 'also in'
  mark. web and console render the same tree data [ `files.tree <G>` ].
- **caller groups** : the flattened members of each `@group`, and the
  live attachments that name it, so a config change shows its effect.
- **capabilities** : the caps issued by the person's key, and the
  attachments made through each one, with uses and expiry.
- **access log** : per record, per caller, per cap. refusals are shown
  with their reason. that reason is never sent to the fetcher.
- **from N7FS** [ metadata only ]. a PERSON sees, for their own records
  only : the node address, size, format and the last `verify` result.
  never the dedup count [ it would tell them someone else holds the same
  bytes ] and never other records on the same node. everything below is
  `files.store`, which is for the **owner \ host admin only** :
  - the disk : disk id, name, intent, parent signer, the newest mount
    record, and the witness result [ current \ travelled \ refused ].
  - the state record : store format, active epochs, an unconfirmed
    upgrade.
  - per node : the address `<epoch>/<amos>/<C>`, its meta, how many live
    handles share it [ dedup ] and which records they are, and the last
    `verify` result.
  - dead handles whose bytes are still on disk [ the removal gap,
    section 7 ], with their age and size.
  - for `:n7fs:` references [ once possible ] : which foreign disk holds
    the content, and whether it is attached.
  - the log chain : the newest chunk, the checkpoint state, chain
    breaks. content is never shown.
- **actions** : revoke [ a record, a group, `-deep` ], shorten expiry,
  lower the fetch count, remove a member, revoke a cap [ the person
  signs on their own machine, file-view only forwards it ]. there are no
  widening actions.

**access control** : files sees the caller as `file-view`, not as the
person. so the per-person rule lives in file-view, which knows the person
from its own session [ web.auth \ nshell \ p7c session user ] :
- a person sees and manages the records they attached [ `by` names them
  as `person` ], the groups they created, and the caps their key issued.
- the owner \ host admin [ a role in the users record ] sees everything
  on that host.
- other people see nothing by default. sharing visibility is an open
  question [ 10 ].
- file-view passes `-for <user>` to files. files trusts that flag only
  from `file-view` [ an alias-checked caller ] and applies the same rule
  again on its side, so a forged `-for` from anyone else does nothing.
  since every action only takes rights away, a mistake there fails safe.

## 12. threat model

- **id guessing** : 280-bit handles from a random nonce. a guess also has
  to come from the right identity, and a miss gives the same answer as
  any other miss.
- **knowing the content** : computing `C` gains nothing. `C` is not
  accepted by fetch, and `:stored:<C>` resolves only against the
  caller's own imports. what remains is the shared store's size and
  timing [ open question 11 ].
- **replay** : a fetch is a cube command from an authenticated session.
  replaying a captured line needs that session [ link v2 binding ].
  one-shot handles and `max_uses` on caps cover what remains.
- **a compromised coding zenka** : it can fetch what was attached to
  `coding`, under any task id, and attach paths inside its access list.
  that list IS the blast radius, which is why stage 1 keeps it at
  today's repo tree + task dir. it cannot reach other paths, other
  zenki's handles, or files' store [ different uid ].
- **confused deputy** [ a prompt-injected task asks coding to fetch
  someone else's file ] : coding can only get what files would give
  `coding` anyway. files never acts with a caller's claimed rights, and
  path reads are bounded by the CALLER's list, not by files' full rights.
  a person attaching for coding is an explicit act, logged with their
  name.
- **compromised file-view** : metadata exposure and revocations, no
  content, no grants.
- **compromised files** : everything it can read. that is the price of
  one gate, and it is kept small : no model, no ui, no network beyond
  cube.
- **compromised cube** : it names identities, so all scope checks fall.
  this is not new to files.
- **the disk taken or copied** [ a backup, a stolen drive ] : format 1
  content is plaintext, including the bytes of dead handles [ section 7 ].
  the records give names, sources and scopes. until the removal and
  ciphertext gaps close, files' disk counts as being as sensitive as
  the trees `p7-files` may read.
- **a planted or rolled-back disk** : N7FS' attach checks [ id
  recompute, parent signature, witness window ] refuse it before files
  serves anything. a damaged newest record kills its handle and never
  revives an older one.
- **heads index stale or tampered with** : it is only an index. files
  reconciles it against the record nodes at start [ section 7 ], so a
  crash between a record write and the heads update cannot revive a
  revoked or used handle. an attacker who can write as `p7-files` can
  do more than that anyway.
- **`:n7fs:` into files' own disk** : refused. otherwise `C` alone would
  open any node there, records included.
- **node view across people** : shared nodes carry one neutral meta, and
  dedup counts are admin-only, so file-view does not tell one person
  about another person's attachments.

## 13. staged plan

each stage stands on its own. the N7FS gaps a stage depends on are named
in it. no stage invents an N7FS feature inside files.

1. **replace coding's `:file:`** : files on-demand [ `start.on-demand`,
   idle timeout ], its own unix user, its own N7FS disk [ `n7fs init`
   by the host setup, owner key or TOFU as parent ], read-rights for
   `coding` = repo tree + task dir, `attach` [ content via the spool +
   path via assimilate's per-file step -- needs its public entry point
   with a meta override, the one N7FS change pulled into stage 1 ],
   `fetch` [ SIZE ], `revoke`,
   expiry sweep, record nodes + the heads index, log chunks, source_zenka
   aliases, per-zenka access lines. `coding.input.decode` changes in two
   ways : `:file:<p>` becomes `files.attach :path:<p> -target coding
   -fetches 1` + fetch [ the confinement code leaves coding ], and a new
   `:att:<H>` prefix fetches a handle a person attached
   [ `bin/coding-task -attach` reads client-side and sends `files.attach`
   with the content ]. honest limits : coding still reads the repo
   through its own tools [ the shared uid ] -- what stage 1 removes is
   the need to ever widen coding's reach. dead bytes stay on the disk
   [ removal gap ].
2. **groups, file-view read-only, large in** : attachment groups with
   manifest nodes and `group-freeze`, `files.tree` \ `list` \ `inspect` \
   `log` \ `store`, file-view showing them, chunked upload [ or the
   open question 8 answer ], STRM-SIZE out.
3. **file-view actions, receipts, caps** : revoke \ shorten from
   file-view with the per-person rule, signed fetch receipts and log
   checkpoints, `cap v1` with pinned issuers and revocation records.
4. **N7FS steps** [ in N7FS, by its own design process, not by files ] :
   node release with signed tombstones [ files then really removes
   bytes ], `references/` [ the heads index moves into the disk ], a
   write path from a stream [ the spool goes ], the host-root parent
   plug, shared read across uids [ cross-disk `:n7fs:` ], and the files
   record magic registered in N7FS-FORMAT. each
   arrives as a format step with a converter, as N7FS requires.
5. **import, search, cross-disk, cross-host** : `import` + `:stored:`,
   `:n7fs:<C>` references to other disks [ after the stage 4 shared-read
   step ], `files.search`, caps used over
   the link by remote holders.
6. **caller groups, index feed** : `cfg/zenki/files/callers`, index fed
   through files and keyed by `C`, its own non-repo `feed-dir` reads
   retired.
7. **later** : ciphertext content [ open question 13 ] ; replication of
   files' disk, but only after stage 4's tombstones.

## open questions for the owner

1. **unix user name and rights setup** : `p7-files` ? rights by groups
   [ coarse ] or POSIX ACLs per tree [ exact, needs `acl` on the fs ] ?
   set by `bin/p7-deps install-service` or by HOST-SETUP ?
2. **defaults** : default expiry 3600 s, max one day, inline 1M, attach
   16M -- or other values ?
3. **task proof** : run coding tasks as child zenki with their own cube
   identity, so `target` can name a task for real, or keep `task` as
   coding's own label [ no protection against a compromised coding ] ?
4. **caller's own rights on the server** : for a person on the same host
   [ unix-authenticated p7c session ], should files ever check that
   person's read rights itself [ needs a root helper ], or is
   'read client-side, send content' the only form ? this design assumes
   the latter.
5. **content id in manifests** : list each member's `C` in a group
   manifest [ as designed, lets the fetcher skip content it already
   has ], or only in the fetch reply of each member ?
6. **group override** : narrow only [ as designed ], or may a level
   WIDEN for its own members [ then a group becomes a grant, and needs
   the attacher's right for every member ] ?
7. **two kinds of groups** : is the reading taken right -- attachment
   groups as the main feature, caller groups as a small config-side
   addition that only meets them in `target` ? or did 'groups' mean user
   \ zenka groups in the access lists first ?
8. **large inbound transfer** : chunked commands, or a caller-opened STRM
   toward files [ a protocol extension ] ?
9. **who mints caps** : a `bin/p7-files-cap` tool, a p7-vault verb next to
   `grant`, or the vault agent later [ Y7O ] ?
10. **file-view sharing** : may a person see records that target a zenka
    they own, or records another person shared with them -- or only their
    own plus the admin's full view ?
11. **dedup across attachers** : one N7FS node for two attachers
    reveals, through disk size and timing, that both held it. salting
    would break the one addressing scheme [ section 7 ]. accept it on a
    private single-host disk ?
12. **`C` = the N7FS bmw** [ as designed, replacing `key_56` for content ;
    the handle keeps `key_56` ] -- agreed ? or should `C` stay a
    harmonized true value, with the one-way map `key_56 = harmonize( bmw )`
    and a lookup table ?
13. **ciphertext content** : convergent encryption [ one address, equal
    content visible as equal ], a `plain_bmw` meta field [ two ids, one
    mapping ], or plaintext under unix rights for good on a private
    disk ?
14. **removing bytes** : node release with signed tombstones as an N7FS
    format step [ recommended ], epoch release, or a disk per period ?
    who signs a tombstone -- the store key, which format 1 does not use
    yet ?
    - **owner answer 2026-10-22** : two removal paths.
      - **unreferenced -> garbage, reclaimed later** : a node no live
        record references goes into a garbage state. its bytes stay and
        it can be re-referenced. it is reclaimed [ released + tombstone ]
        only when space is needed [ low-water mark, oldest unreferenced
        first ] or after a max age. a reclaim is the moment the tombstone
        is written, so union sync only learns of reclaimed nodes.
      - **instant purge** : release + tombstone at once, for content that
        must be gone now.
    - **re-reference only by content** [ design note ] : a new attach
      whose bytes hash to a garbage node's `C` revives that node [ plain
      dedup : the caller proved it holds the content ]. a revive by `C`
      alone would be the oracle and deputy that `:n7fs:` refuses on files'
      own disk [ section 7 ] : only an owner \ admin path in file-view
      [ 'recover', like the note.* xz-trash ] may do that.
    - **never recoverable needs crypto-shredding** [ design note ] :
      overwriting bytes is no proof on SSDs, journaling or copy-on-write
      filesystems, and backups of `/N7FS` keep them. so 'additionally
      protected' content is stored encrypted under a RANDOM key per
      attachment, the key held outside the disk and outside its backups
      [ keys zenka \ vault ]. purge = shred the key + release the node ;
      the remaining bytes are noise everywhere, backups included.
    - **protected content is never deduplicated** : a random key gives
      unique ciphertext, so one node per attachment, and one holder's
      purge can never destroy another holder's copy. for protected content
      `C` is over the ciphertext and the plaintext id is never stored
      [ this settles question 13 for that class ; convergent encryption
      stays possible for the plain class only ].
    - **purge with other holders** [ plain class ] : a purge removes the
      caller's references only ; bytes another live record names stay.
      an owner \ admin purge may force-revoke every handle on that `C`
      first [ logged, each holder's file-view shows 'purged by owner' ].
15. **records as content nodes** [ as designed, no format step ] or a
    dedicated N7FS record kind with its own magic and key word [ a
    format step, but readers can then tell records from content ] ? and
    may files register a magic [ proposed `P7FH` ] in N7FS-FORMAT ?
16. **one disk or two** : files' short-lived attachments and long-lived
    imports in one disk, or imports in a second disk with its own
    lifecycle [ and later its own replication policy ] ?
17. **attach per start or once** : the host setup attaches files' disk
    once [ as designed ], or files attaches and detaches with every
    on-demand start [ a mount record each time ] ?
18. **security levels, layered unlock** [ owner 2026-10-22, later stage ] :
    desktops get security levels, and higher levels add entropy to unlock
    attachment groups in layers. a shape that fits the rest of this
    design :
    - **keys follow the group tree** : a member's key is wrapped by its
      group's key ; a group at level n is wrapped by the level-n key,
      derived from the level n-1 key plus that level's own entropy
      [ phrase, token, presence ]. level n opens only with every level
      below it.
    - **shredding a group or level key** makes its whole subtree
      unrecoverable in one step [ the purge of question 14, per layer ].
    - **dropping a desktop level** zeroizes the unwrapped keys of that
      level and above ; handles into those groups fail closed until the
      level is unlocked again.
    - **where unwrapping happens** : the entropy is entered on the
      desktop, so level keys belong to the vault agent in the user's own
      process [ CREDENTIAL-LAYERS ], never held by files' uid beyond one
      fetch. open : does files decrypt for the target, or does the target
      receive a per-fetch unwrapped key and decrypt itself [ end to end :
      files never sees plaintext of protected groups ] ?
    - open : are these the same level numbers as
      UI-SHOW-SECURITY-LEVELS [ what a caller may see ], or a separate
      scale for unlock strength ?
    - **owner answers 2026-10-22** :
      - **nesting solves hosted storage** : each layer adds protection
        without breaking a chain. this holds because layers wrap KEYS,
        never content [ envelope encryption ] : content is encrypted once
        under its own key, adding or removing a layer re-wraps that key
        only, so the ciphertext, `C`, the node path and every record chain
        naming it stay unchanged. a host can hold an outer layer for
        availability work without reaching the inner ones. a layer that
        re-encrypted content would change `C` and break the chains.
      - **end to end is the default** : files hands out ciphertext + a
        per-fetch wrapped key ; the target decrypts. a user desktop
        session is just another target zenka. a FUSE mount decrypting
        generically is the deliberate plaintext exit : every process of
        that uid reads it and plaintext reaches the page cache, so a level
        drop must unmount and flush, not only zeroize keys.
      - **encryption in the base.file.* abstractions** for all sources
        [ local, N7FS, remote, files handles ], in one place. conditions :
        opaque key handles issued by the vault agent, never raw keys
        through the api ; fail closed [ a protected source without a key
        is an error, never ciphertext returned as content ] ; chunked AEAD
        with nonces derived from the chunk index and a final-chunk flag
        [ random access for FUSE, no reorder \ truncation, no nonce reuse
        by construction -- the link-upgrade nonce reuse of 2026-10-05 is
        the reason to fix this in the format ].
      - **in-process access** [ owner ] : a Tie'd handle \ scalar or a
        memory mapping for the decrypted form, where setting up the
        mapping is protected again [ a key handle from the vault agent,
        bound to that process and fetch ]. plaintext then exists in that
        process only, never on a filesystem other processes see -- the
        middle ground between end to end and FUSE.
        - tie : READ \ SEEK decrypt the chunks they touch [ chunk n \
          size ] ; only ciphertext reaches the page cache.
        - mapping : decrypt-on-fault needs userfaultfd and C ; practical
          is the ciphertext mapped [ File::Map ] + an anonymous buffer
          for plaintext, mlock'ed [ no swap ] and MADV_DONTDUMP [ no core
          dumps ] -- the two leak paths of a memory-only design.
        - UNTIE \ close \ a level drop zeroize the chunk cache. honest
          limit : perl copies strings freely, so zeroizing in pure perl is
          best effort ; a guarantee needs the plaintext buffer in XS \ C
          managed memory, handing out only the bytes read.
      - **reuse the data zenka** [ owner : the infrastructure exists ;
        not read when this design was written ] :
        - `data.mount.shm.*` : SHM \ file mappings via Sys::Mmap, paged
          with an index -- the base for the decrypted mapping.
        - `data.mount.shm.lock.memory` [ AMOS7::SHM::lock_memory ] : the
          no-swap part already exists.
        - `data.mount.shm.permission.*` : signed sticky permissions in the
          mapping header [ to, branch, rights, expiry ; owner key ; group
          and path pattern checks ] -- close to section 9's capabilities :
          one capability format for both, not two.
        - mounts : `data.mount.fuse.*` exists, but
          ALTERNATIVE-MOUNTING-OPTIONS.md finds perl Fuse tied to FUSE 2
          [ glibc conflict ] and recommends 9P [ `plan-9` zenka ] -- the
          generic decrypting mount is 9P first. NESTED-MOUNT-CHAINS.md
          gives the nested address grammar the layers can use.
        - **owner answer** : both. zenki that speak files' interface
          fetch from files directly ; zenki that need the extended
          services [ mappings, mounts, decrypted views ] go through the
          data zenka, which holds a scoped handle and maps \ decrypts.
          files stays rights + records ; plaintext of protected groups
          never enters files' uid.
      - **reuse the storage zenka + plan-9** [ owner pointer ] :
        - `storage.cmd.p7ref` + P7REF-STORAGE.md : the unified reference
          syntax `p7://<type>:<address>[@<authority>][|<segment>]` ,
          with `p7://checksum:<…>` for content. files' ids should be
          P7REF types, not a syntax of their own : `C` as a checksum
          reference [ which grants nothing by itself, as section 2
          requires ], and a new `files` type for handles `H`.
        - `plugin.storage.checksum` [ map \ lookup \ verify ] and
          `storage.cmd.lookup-checksum` : a checksum -> files index that
          already exists -- files.index \ search [ section 10 ] build on
          it instead of a new index.
        - `storage.9p.*` : a full 9P client ; `plan-9` runs a 9P SERVER
          [ plan-9.server, export-directory ]. the decrypting mount =
          plan-9 exporting a data-zenka view, no FUSE.
        - `storage.map-dirs.*` : an IO::AIO mmapped virtual tree -- a
          candidate for how file-view and data present the group tree.
      - **keys, index, fs, udev** [ owner pointer ] :
        - `keys` [ standalone, interactive console ] : passphrase key
          archives [ enc-key, user_key_archive, decrypt-archive ],
          seed-file entropy keys [ gen-file-seed-key ], backups with
          rollback, `:pass-env:` passphrases. the 'outside the disk'
          key store of question 14 and the level entropy of 18 use these
          formats and this console for setup and recovery ; the serving
          side stays the vault agent [ keys never runs as a daemon ].
        - `index` : trie addresses, lookup, search, feed-dir, persist,
          `contributions` per content checksum -- files.index feeds it
          with `C` [ stage 6 ], its own non-repo feed-dir reads retire.
        - `fs` : mount \ unmount \ re-mount \ is_mounted,
          get_filesystems -- the mount authority. files' N7FS disk on
          removable media and the plan-9 9P export [ `mount -t 9p` on the
          desktop side ] are mounted through fs, never by files or data.
        - `udev` : udevadm events matched against rules -> actions. a
          device arriving is a natural trigger : attach an N7FS disk from
          a known medium, and a hardware token as the entropy factor of a
          security level [ question 18 ] -- its removal drops the level.
        - **N7FS automounts** [ owner ] : udev sees the medium, fs mounts
          it, N7FS attaches the disk. the disk is recognized by its N7FS
          identity [ signed disk record, witness ], never by label or
          filesystem uuid [ both are trivially copied ]. an unknown disk
          or a witness that is not `current` is not attached [ or only
          read-only, for import -- the owner's choice ]. here a mount
          record per plug-in is right : each plug-in IS travel, unlike the
          on-demand starts of question 17. removal detaches the disk, and
          handles into it fail closed until it returns.
19. **actions triggered by a signed disk, code included** [ owner
    2026-10-22 : signed disks and their states make automatic
    functionality safe, e.g. updating an appliance with a signed upgrade
    stick ]. conditions for code from a disk :
    - **a signed disk is not authorized code** : the disk record proves
      which disk it is. a payload that runs carries its OWN signature by
      an identity holding that action's right [ owner \ release key ],
      with a distinct label [ e.g. `p7 upgrade v1` ] -- otherwise any
      signed data stick could execute.
    - **anti-rollback** : the payload's signed version must be newer than
      the installed one [ the signed src-ver numbers ] -- an old, validly
      signed stick must not bring back a vulnerable version.
    - **target binding** : the payload names the appliance class \ host
      record it is for.
    - **verify, copy, verify the copy, run the copy** : a hostile medium
      can answer a second read differently. apply through the existing
      upgrade path with rollback ; never execute from the medium, never
      pass disk content through a shell.
    - **below the signatures** : mounting runs the kernel's filesystem
      parser on untrusted bytes -> the first look mounts
      `ro,nosuid,nodev,noexec`, the normal mount only after the disk
      record verified ; udev rules act on the mass-storage class only
      [ a device posing as a keyboard is outside what signatures cover ].
    - **owner : a fully signed checksum tree** guards against changes,
      additions and removals. today format 1 covers changes only [ nodes
      are content-addressed, the store key signs state + meta records ] :
      nothing signs the SET of nodes, so an added or removed node goes
      unseen. the same gap is why `src/base.list.subroutines` exists : a
      deleted module restored by an attacker keeps its still valid
      signature, only the signed SET refuses it. a signed root over the
      whole node set [ checksum tree, as N7FS-SPEC's tree structures
      suggest ; a format step ] closes that, and then :
      - **verify on every read** against the tree instead of verify-then-
        trust : a medium answering a second read differently fails that
        read -- the copy step above becomes optional.
      - **the root as the authorization** : the release key signs the
        root with the upgrade label and a version -> the whole disk is
        the payload ; anti-rollback lives in the signed root.
      - **below the filesystem** : the kernel parses the filesystem
        before any tree inside it is checked. the full answer is block
        level verification, dm-verity style [ `veritysetup`, a signed
        root hash over the raw blocks ] : the filesystem parser only ever
        sees authenticated blocks. until then the
        `ro,nosuid,nodev,noexec` first look stays.

## not in this design

code, config or todo changes ; the vault agent ; the index zenka's own
redesign ; write access [ files only reads and hands out ; a write path
is a separate design if wanted ] ; the STRM unknown-total extension ;
the N7FS format steps themselves [ release, references, stream writes,
record kinds ] -- named here as gaps, designed in N7FS.

#,,.,,.,.,.,.,..,,,.,,.,.,.,.,,,.,.,,,.,.,,,.,..,,...,...,,,,,,,.,,.,,,..,,,,,
#ZJ2VHVL3AWYAD3CDIUFTB76KMHMNZFA7RP4ACCWJIUTM4N7AZDJUQLHKNUCJUV7LCPVYAK3NNSS2G
#\\\|7A55IDLJ4CIGFMWSIPB6XOXTPGQIPHE4R37GCPP5CWQMQGNSJCY \ / AMOS7 \ YOURUM ::
#\[7]XCK6234ZRAFGIHFYDKJUBJWQAUST3IMG6QR3PF4OU5SGK2BICCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
