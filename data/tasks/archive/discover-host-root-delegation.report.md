# report : discover carries the host-root delegation [ web session ]

branch `discover-host-root-delegation`, base `b7ffad700`
[ = the task's cited code base `e3c3ee371` plus the commit that added
`data/tasks/discover-host-root-delegation.md` itself ; HEAD was already at
`b7ffad700` as instructed, so the work is on the intended code state ].

implemented against the code + spec, tested with stubs. no backend run.

## what changed

discover packets no longer carry the old `.sig.*` raw-pubkey signature
lines. instead a HOST packet carries the sender's host-root delegation
statement `<S>.dlg` as a single signed field, and the receiver verifies
it, classifies the host-root trust, stores it on the host entry, and
passes `root_fp` + `trust` to the `nodes` zenka.

### sender

- **`src/discover.format_discover_mcast_packet`**
  - reads the host's `.dlg` [ `crypt.C25519.delegation_file` -> path, then
    one line, `<= 2048` b32 chars ] FRESH on every packet [ not cached in
    the per-type header ], so renewals \ rotations take effect.
  - ships it as a 3-space `   dlg:<wire>\n` field between the header line
    and the payload, so it sits inside `signed_data` and is covered by the
    existing packet signature.
  - **DROPS** the `.sig.*` emission entirely [ no compatibility ] ; the
    cached header is now just `[:<|TYPE|<hostkey>\n`.
  - no `.dlg` readable -> sent without it, **level 1 log once per change** ;
    a newly seen \ renewed statement is noted once at level 2
    [ `<discover.dlg.last_state>` tracks the change ].

### receiver

- **`src/discover.process_incoming_packet`**
  - the packet regex's `signatures` group is replaced by an optional
    `(?<delegation>(?: {3}+dlg:[A-Z2-7]{1,2048}\n)?)` group ; the bare wire
    is extracted and handed on in `$matched_field->{'delegation'}`.
  - the whole per-`.sig.*`-signature verification loop is removed ; the
    existing packet-signature check under the hostkey is unchanged and
    still runs FIRST.
- **`src/discover.handler.incoming_packet`**
  - the buffer FRAMING regex is migrated the same way [ the `.sig.*` group
    -> the optional `dlg:` field ] so complete packets still frame.
- **`src/discover.process_host_packet`**
  - after the packet signature is verified, the delegation is classified
    with the packet's hostkey as the subject [ the hostkey IS the
    announced S ] :
    - `unverified` : no delegation field.
    - parse [ `trust.statement parse_wire` ] -> fingerprint the issuer ->
      `trust.verify` under the statement's OWN issuer [ sig, the time
      window, subject eq the announced hostkey, name, empty leaf scope ].
    - `invalid` : parse \ verify fails -> **the packet is DROPPED** before
      any host entry is touched, level 0 log.
    - valid -> `pinned` if `root_fp` is in the client pin store, else
      `offered`.
  - `root_fp` CHANGE between packets for one host key : the new root is
    never silently adopted -- the old `root_fp` \ `delegated_name` are
    kept, `trust` is set `invalid`, and `host-root changed for <host>` is
    logged once at level 0 [ state in `$data{'discover.host-root'}` ].
  - `root_fp` [ 77 ], `delegated_name`, `trust` are stored on every host
    entry [ a bare `unverified` carries no root ].
- **`src/discover.read_host_root_pins`** [ NEW ]
  - returns the set of pinned host-root fingerprints from
    `<home>/.n/remote-keys/servers/*.public` [ the client pin store ].
    **read only -- discover NEVER writes a pin.** an old 52-char [ S ]
    pin, a symlink, or any malformed \ unreadable file is skipped
    [ fail closed ]. same store + 77-char format as
    `auth.client.server_pin.check`.
  - registered in `cfg/zenki/discover/subroutines.load-early`.
- **`src/discover.cmd.host_details`**
  - shows `root_fp`, `delegated_name`, `trust`. these three print VERBATIM
    [ the other values keep the existing uppercasing ] so a case-sensitive
    delegated name and the lowercase trust vocabulary are not corrupted.

### nodes [ store + show, no trust decisions yet ]

- **`src/discover.process_host_packet`** sends `online <host> <root_fp|->
  <trust>` on the nodes route [ `<discover.cfg.nodes.host_status_command>`
  = `cube.nodes.host-status` ].
- **`src/nodes.cmd.host-status`** parses the optional trailing
  `<root_fp> <trust>` [ strict : a 77-char b32 fp or `-`, and one of
  `pinned|offered|unverified|invalid` ] and stashes it in
  `<nodes.local-network.host-trust>` [ a known host re-announcing is also
  updated in place ]. the plain `online <host>` form still parses, so
  other host-status consumers are unaffected.
- **`src/nodes.handler.discover_details_reply`** stores `trust`, `root_fp`,
  `delegated_name` on the node entry -- taken from the details reply
  [ authoritative : `discover.cmd.host_details` now carries them ] with the
  host-status stash as the fallback.
- **`src/nodes.init_code`** adds `trust` + `root_fp` to the `lan-nodes`
  display mask.

## retired / kept

**retired** [ the `.sig.*` readers that only served discover ] :
- the `.sig.*` emission in `discover.format_discover_mcast_packet`.
- the `.sig.*` parsing + per-signature verification in
  `discover.process_incoming_packet`.
- the `<[crypt.C25519.load_all_signatures]>` call in
  `discover.post_init` -- `%signatures` was populated ONLY there.

**kept + why** [ the "else list the remaining users and leave them"
branch of the task -- these are NOT discover-only, or sit in modules that
run for every zenka and are outside the allowed touch set ] :
- **`crypt.C25519.sign_keys` + `crypt.C25519.sig_fnames`** -- still used by
  `src/keys.console.sign-key` [ the interactive key cross-signing command,
  registered in `cfg/zenki/keys/subroutines.load-early` ]. not discover-
  only, and outside the allowed touch set, so left in place.
- **`crypt.C25519.post_init`'s `.spk`/`.sig` glob + the `{root}` subtree**
  -- no reader of that subtree was found anywhere, so it is effectively
  dead, BUT `post_init` runs for EVERY zenka and is not discover-scoped ;
  per the task's "else leave them", it is left untouched to keep the
  change discover-scoped. candidate for a separate cleanup.

**now orphaned by this change** [ noted for a follow-up, left in place to
avoid touching load lists \ the big subroutine registry for removal ] :
- **`crypt.C25519.load_all_signatures`** -- its only caller was
  `discover.post_init` [ removed ], so it now has no caller.
- **`crypt.C25519.key_signatures_list`** -- already had no live caller ;
  it only reads `%signatures`, which nothing populates anymore.
- so the whole `%signatures` subsystem is now dead. a later commit can
  delete these two modules [ + their registry \ load-list lines ] and the
  `post_init` glob once host-root delegation is confirmed live.

note : `work.parent.fix_versions` matched an early `grep signatures{` but
uses a LOCAL `%commit_signatures` [ git commit AMOS7 sigs ], NOT the global
`%signatures` -- it is unrelated and untouched.

## scope

touched only `src/discover.*`, `src/nodes.*`, the new module's load-list
line, and the new test -- within the task's allowed set. no files signed
[ the user signs locally ]. nothing committed to `base`.

## test

NEW **`bin/test-scripts/test-discover-delegation.pl`** [ harness pattern :
`bin/test-scripts/test-host-root-delegation.pl` ] : compiles the real
discover \ nodes \ trust modules and drives sender -> receiver with stubs.
covers a valid `.dlg` round-trip [ build -> parse -> verify ] ; each trust
state ; pinned detection from a tempdir pin store [ incl. an old 52-char
pin ignored ] ; invalid [ bad sig \ subject mismatch \ unparsable ] ->
dropped + level 0 log ; `root_fp` change -> invalid + kept-old + logged ;
`.sig.*` lines gone + a `dlg:` field present ; `host_details` output ; and
the nodes route carrying `root_fp` + `trust`. uses the spec test-vector
keys [ host-root `\x03`x32, S `\x02`x32 ].

### what actually ran in this session -- and what did not

this sandbox has **no `Crypt::Ed25519`, `Digest::BMW`, `List::MoreUtils` or
`PPI`**, and CPAN + GitHub-web are blocked by the egress proxy, so they
could not be installed. honest status :

- **`bin/format-code -c` / `bin/format-code` : NOT RUN** -- `format-code`
  itself needs `List::MoreUtils` + `PPI`. style rules were applied + checked
  by hand instead : every touched file is `<= 78` columns, `$ARG` not `$_`,
  lowercase comments, `[ ]` not `( )`. **please run `format-code` locally.**
- **`test-discover-delegation.pl` [ full behavioural run ] : NOT RUN** --
  needs `Crypt::Ed25519` + `Digest::BMW`. it passes `perl -c` [ syntax OK ].
  **please run it locally** [ it will exercise the sign \ verify \
  fingerprint \ pin \ trust-state behaviour end to end ] :
  `perl bin/test-scripts/test-discover-delegation.pl`

- **what DID run here, with the REAL modules [ no faked crypto ] :**
  - all 10 touched modules compile cleanly [ P7-syntax translate +
    `perl` compile ], no warnings.
  - `trust.statement build` == the spec `statement_hex` **byte for byte** ;
    statement round-trips [ build -> wire -> parse_wire ].
  - the REAL `discover.format_discover_mcast_packet` emits the 3-space
    `dlg:<wire>` field and **no** `.sig.*` lines ; the REAL
    `process_incoming_packet` regex matches that packet and extracts the
    same wire, with `type` \ `hostkey` \ `payload` captured correctly.
  these cover the highest-risk piece [ the sender<->receiver wire contract
  and the statement bytes ] ; only the Ed25519 \ BMW-dependent behaviour
  awaits the local run.

## open questions / decisions taken

1. **`root_fp` change does not DROP the packet** -- the spec DROPs only a
   parse \ verify-invalid delegation. a changed-but-valid root is a
   different case : the host entry is kept with the OLD root and
   `trust = invalid` [ and the address data still updates ], as the spec's
   "keep the old entry ... mark trust = invalid" says. if a changed root
   should also drop the packet, say so.
2. **a host that STOPS sending a delegation** [ had one, now none ] is
   classified `unverified`, and the remembered good `root_fp` is kept in
   `$data{'discover.host-root'}` [ not cleared ], so a later different root
   is still caught as a change. absence is not treated as a root change.
   confirm this is the intended fail-closed reading.
3. **nodes trust propagation fires on `entry_added`** [ the existing nodes
   notify trigger ], so a pure trust transition with no (re)appearance
   [ e.g. offered -> pinned after a pin is added out of band ] is not
   pushed to nodes until the host re-appears. nodes takes no trust
   decisions yet, so this is cosmetic for now, but worth a follow-up.
4. **`lan-nodes` mask now shows a 77-char `root_fp` column** -- wide ; a
   shortened display filter may be wanted later.
5. the orphaned `%signatures` modules [ above ] are left for a dedicated
   cleanup commit rather than removed here, to keep this change scoped and
   avoid editing the shared subroutine registry \ load lists for removals.

## review [ local, 2026-10-07 ]

- BLOCKER fixed : `cfg/zenki/discover/zenka.v7` modules.load lacked
  `trust` -> trust.* were never loaded in discover at runtime [ the
  load-early list already had them ] ; the test compiles modules directly
  and could not see it
- decision 1 [ user ] : a root_fp change now DROPS the packet [ no address
  update ], keeps the old entry and marks every host entry of that key
  `invalid`. the remembered root stays until discover restarts [ the new
  root must be re-pinned out of band ]
- flood protection [ user ] : both drop paths log with an adaptive level
  per sender key -- 0 the first time, then 1, 2, 3 [ capped ] ; an
  accepted packet resets it [ `$data{'discover.host-root-log'}` ]
- format-code applied to all touched files ; syntax valid ; test 33 ok
- decisions 2-5 accepted as written ; 3 [ trust transitions reach nodes
  only on re-appearance ] + 5 [ orphaned %signatures modules ] are
  follow-ups

#,,..,,..,.,.,.,,,.,.,,..,,..,.,.,.,.,.,,,,..,..,,...,.,.,...,,..,.,.,..,,.,,,
#45TX2G7GLPRU2DL5VXPGORJSVPMPIYW6JGAU5MR3L7DRLZMCDCVNUEZE2Y3YJFQFKFU5FHYZNNSKG
#\\\|YSB6RAOBBRFXHAYE7UDRCG3OQAZBXGIZP5MXH7VM6GPFI5OOVTS \ / AMOS7 \ YOURUM ::
#\[7]AVNA4CVSPCCNRBHBRP5LG4WQWKVKX7YF7LECVBU6GERPH3BSKSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
