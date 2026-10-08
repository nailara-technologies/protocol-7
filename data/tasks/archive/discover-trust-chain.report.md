# discover : HOST packets carry the delegation CHAIN -- implementation report

implemented 2026-10-08 against base @ 859a69f04. no zenka restarted, no
running process touched, nothing committed. stubs-only testing via
`bin/test-scripts/test-discover-delegation.pl`.

## per-file changes

- `src/discover.format_discover_mcast_packet` [ send ]
  - reads the WHOLE `.dlg` now [ `read` cap 2060 bytes, content refused
    when > 2052 ], parsed with `trust.chain` `file` [ the one parser ].
  - the LEAF is verified under its own issuer [ `trust.verify`, subject =
    the host key's public ] -- failing : no `dlg:` field, exactly as the
    old not-readable case [ same level 1 `<discover.dlg.last_state>` line ].
  - the whole chain is verified under its top issuer ; valid -> `dlg:` =
    `trust.chain` `join` of the whole chain [ leaf first on the wire ] ;
    invalid -> the leaf alone + ONE level 0 line per change, tracked in
    `<discover.dlg_chain_note>` [ the `<auth.dlg_chain_note>` pattern ].
- `src/discover.handler.incoming_packet`
  - the `dlg:` regex is `[A-Z2-7.]{1,2048}` now [ `.` admitted ].
- `src/discover.process_incoming_packet`
  - both `dlg:` regexes `[A-Z2-7.]{1,2048}` ; the field is handed on as
    the raw string, unchanged.
- `src/discover.process_host_packet` [ verify ]
  - `trust.chain` `split` first [ refusal -> drop reason -> packet
    dropped + level 0 log, as before ].
  - distrust from `auth.client.distrust_list` on
    `<usr_home>/.n/remote-keys` [ unreadable/malformed -> drop, fail
    closed ] ; passed to both `trust.verify` calls.
  - verify under the LEAF's issuer fp [ + distrust ] ; `root_fp` stays
    the LEAF's issuer fingerprint [ the host-root ].
  - trust states : `pinned` [ host pin, wins over owner ] ; NEW `owner`
    [ not pinned, `trust.verify` with anchors = the owner pins accepts
    the chain -- its anchor IS an owner pin by construction ] ;
    `offered` ; `unverified` ; `invalid`.
  - root change : ADOPTED [ level 0 line, entry updated with
    root_fp/delegated_name/trust/`since`, nodes notified by the common
    path ] only when owner-trusted AND the delegated name is the SAME
    AND the certifying statement's not_before [`$chain->[-2]` when the
    owner-verified depth >= 2, else the leaf -- the `trust.pin_decide`
    rule ] is strictly LATER than the stored `since` [ 0 when never
    owner-verified, kept from the previous entry otherwise ].
    anything else : drop + invalid, byte-identical to the old behavior
    [ old root kept, flood-capped log, nodes told invalid ].
  - `owner_fp` is stored on the host entries when trust is `owner`.
- `src/discover.cmd.host_details`
  - `owner_fp` printed verbatim, in two halves [ `substr` split like
    `keys.console.owner-pin` ], the second half aligned at the same
    column the `root_fp` line uses.
- `bin/test-scripts/test-discover-delegation.pl`
  - compiles `auth.client.owner_pins` + `auth.client.distrust_list` [
    `trust.chain` already compiled ; `trust.pin_decide` NOT needed ].
  - owner key [ seed 06 ] + `owner_dlg` / `chain_pair` builders ;
    owner-pin + distrust file helpers ; `make_packet` takes the whole
    `.dlg` content [ one statement per line ] ; NEW `make_raw_packet`
    builds a signed packet with a RAW `dlg:` field [ the sender itself
    now drops malformed chains, so receiver-side refusals are fed raw ].
  - the three old 'invalid' cases [ bad sig / subject mismatch /
    unparsable ] switched from sender packets to raw packets -- the
    sender no longer ships a leaf that fails its own issuer.
  - new blocks : sender chain join + expired-owner leaf-alone [ level 0
    once per change ] ; owner / pinned-wins / offered trust states via a
    two-statement field ; reversed field ; `..` / leading / trailing `.`
    / 5 statements ; distrusted host-root ; malformed distrust file ;
    rotation adopt / equal-since drop / other-name drop / no-owner-pin
    drop ; `host_details` owner + two-half fingerprint.

## test

    bin/test-scripts/test-discover-delegation.pl

    passed : 69  failed : 0

`bin/format-code -c` : syntax valid on all five touched src files [
the four reformatted ones were rewritten by `bin/format-code` itself
until check-clean ].

## git status note [ checked before finishing ]

`git status --short` also shows modifications under `cfg/zenki/keys/`
and `cfg/zenki/v7-zenki/` plus untracked `keys.console.*` /
`test-trust-management.pl` -- a CONCURRENT session's keys-console work,
not this task's : none of my tools write cfg [ `bin/format-code` only
touches its argv files ] and every edit I made is listed above. left
untouched.

## open questions

1. `host_details` '[ two halves at the level the root fp uses ]' was
   read as the root_fp column in the details output ; discover does NOT
   additionally log the owner fingerprint at level 0 the way
   `auth.client.server_pin.check` logs a pinned host-root -- say the
   word if that level-0 log line is wanted too.
2. fail-closed distrust applies when the remote-keys dir is resolvable ;
   a host with no `<usr_home>` has no distrust store at all and is
   treated as 'no file : empty' [ the `auth.client.distrust_list`
   semantic ], not as a refusal.
3. send-side refusals [ oversized \ unparsable file, leaf not verifying
   under its own issuer ] share the level 1 'not readable' line with the
   missing-file case -- kept the existing `<discover.dlg.last_state>`
   pattern per the task ; a distinct reason per refusal could be added.
4. rotation with a PINNED new host-root [ not owner-trusted ] is dropped
   per the task letter [ adoption requires owner trust ] -- a pinned new
   root therefore needs the pin removed \ rewritten out of band first.

#,,.,,..,,.,,,...,.,,,.,.,,,,,,.,,.,,,...,.,,,..,,...,...,,..,.,.,..,,,,,,.,,,
#ZKZG4RI2BRNVZZILFOA4RGCITULNNCMQGTOGN5BAYHNOHTK7PH5PLLFXUFOFO3QOYVVOULZXFNCFA
#\\\|F6OK74B3P7LPSRAAYYEFBZVKTZA7HQCLAZC5OLRK24HGV7AFENC \ / AMOS7 \ YOURUM ::
#\[7]TM2WEDOAVAQPG2VURZ62WP32TVXRMEJUCJGUQPHDJ5KNL236NAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
