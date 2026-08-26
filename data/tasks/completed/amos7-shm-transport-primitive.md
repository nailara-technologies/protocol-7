# task: AMOS7::SHM::Transport — the shape-1 "one-shot bounded-scalar transport" primitive

## status [ 2026-06-22 ]

design is settled across `data/tasks/amos7-shm-coding-zenka-prompt-transport.md`
and `data/tasks/amos7-shm-use-case-taxonomy.md` [ shape 1 — build order: after
shape 3 `Live`, which has already landed, `data/lib-path/pm/AMOS7/SHM/Live.pm` ].
read `data/tasks/amos7-shm-paging-feedback.md` first [ phases 1-3, landed,
live-verified — this composes only already-landed primitives ].

## the shape, precisely

a **bounded scalar, moved once, pull-and-verify-done.** the writer pages a
finite payload into a segment, announces a compact descriptor [ path + page
count + checksum + signed grant ], the reader pulls every page immediately and
verifies the announced checksum. there is **no ordering concern across calls
and no exactly-once concern** — if it fails, the caller retries the whole
thing. **uses no phase-3 `Feedback` atom at all** — this is the asymmetric,
simplest-correctness-bar shape, distinct from `Live` [ no transfer, no done ]
and from shape 2's `Channel` [ continuous, ack-tracked ].

## API — `data/lib-path/pm/AMOS7/SHM/Transport.pm`, a new standalone-loadable sibling

same hybrid style as `Page.pm` / `Feedback.pm` / the just-landed `Live.pm` —
no `<[...]>` zenka-bracket syntax in it, works identically standalone or
in-zenka. `use AMOS7::SHM; use AMOS7::SHM::Page;` [ this composes `Page`,
unlike `Live` which deliberately does not — confirm you understand why before
writing code: `Page`'s create()-time immutable `total_pages` + whole-content
checksum model is exactly what a one-shot, fully-known-up-front payload needs,
the opposite of `Live`'s live-mutation case ].

### `shm_announce( $options )`

`$options` keys: `owner_pubkey`, `owner_privkey` [ to sign the reader's grant ],
`reader_pubkey` [ who may read — the grant target ], `content_ref` [ scalar
ref to the payload — no extra copy ], `checksum` [ **required, precomputed by
the caller** — see "the checksum gap" below, do not try to compute this
inside `Transport.pm` ], `page_size` [ optional, default
`AMOS7::SHM::Page::DEFAULT_PAGE_SIZE()` ], `sub_path` [ optional namespacing
under the pubkey ], `rights` [ optional, default `['read']` ], `expiry`
[ optional, default `time() + 3600` ], `time_source` [ optional, passed
through to `shm_create` ].

composes, in order:
1. `AMOS7::SHM::Page::create( $owner_pubkey, length($$content_ref), $page_size,
   $checksum, { time_source => ..., mlock => ... } )` — sizes the segment for
   header + page index + all pages [ + no feedback region, this shape never
   uses `Feedback`, confirm `Page::create`'s own `FEEDBACK_SIZE` addition is
   harmless here even though it's never used — it always reserves that region
   regardless of caller, that's `Page::create`'s existing behavior, not
   something to work around ].
2. `AMOS7::SHM::Page::write_page` for each page, writing `$$content_ref` in
   `$page_size`-sized slices.
3. build a permission grant and sign it — **there is no standalone
   `add_permission`-style helper to call**, `src/data.mount.shm.permission.add`
   is a zenka-only wrapper that inlines this sequence itself. mirror its logic
   directly in `Transport.pm` using already-exported `AMOS7::SHM` subs : build
   `{ to => $reader_pubkey, branch => $sub_path // '', rights => [...],
   expiry => ..., granted => time() }`, call
   `AMOS7::SHM::sign_permission($perm, $owner_privkey)` and set `$perm->{'sig'}`
   to the result, `push @{ $header->{'permissions'} }, $perm` [ respecting
   `AMOS7::SHM::MAX_PERMISSIONS()`, already exported, reuse it — do not
   redefine the constant locally the way the zenka wrapper does ], then
   `AMOS7::SHM::header_write( $mount->{'mmap_ptr'}, $header )`.
4. return a compact descriptor hashref : `{ shm_path, total_pages, page_size,
   content_size, checksum, owner_pubkey, sub_path }` — small, well under any
   wire cap, this is what a caller would pass to a remote receiver [ though
   wiring this onto an actual cube command is a separate future task, not this
   one — this task is the primitive only ].

### `shm_receive( $options )`

`$options` keys: `shm_path` [ or `owner_pubkey` + `sub_path` — accept either,
`shm_open` already handles both forms via `parse_shm_path` ], `reader_privkey`,
`verify_checksum` [ default true ].

composes:
1. `AMOS7::SHM::shm_open( $shm_path, { mode => 'read', rights => ['read'] },
   $reader_privkey )` — **read-only**, the already-landed mode [ confirm the
   current line number yourself, `SHM.pm` has had no edits near `shm_open`
   this session but re-check rather than trust a stale citation ]. this runs
   `permission_verify` internally — a caller without a valid signed grant gets
   `{ error => 'access_denied' }` [ or whatever `shm_open` actually returns for
   a failed `permission_verify`, confirm the exact error key from source ] and
   never sees a byte.
2. `AMOS7::SHM::Page::read_index` → `AMOS7::SHM::Page::read_page` for
   `0 .. total_pages-1`, concatenated [ `read_page` already clips the final
   partial page to the real content length via the mount header's
   `data_size` ].
3. if `verify_checksum`, recompute the **same algorithm the announced checksum
   used** over the reassembled content and compare — **this is where the
   checksum gap below matters**: `shm_receive` cannot know which algorithm
   produced the announced checksum unless it's told, or unless this task
   picks one fixed algorithm and documents the constraint plainly. resolve
   this explicitly, do not leave it implicit — see next section.
4. return `{ ok => TRUE, content_ref => \$reassembled, pages => N }` on
   success, or `{ ok => FALSE, error => '...' }` — `access_denied` /
   `checksum_mismatch` / `segment_not_found` / whatever `shm_open` itself
   already reports, passed through.

## the checksum gap — read before writing code, this is a real, not cosmetic, decision

`AMOS7::SHM::Page::create` takes `$checksum` as an **external parameter** — it
has never computed checksums itself, in any landed phase. the project's
established standard elsewhere is **bmw-L13** [ 13-char base32, ~65 bits — see
`coding.cmd.summarize-context:85`'s `<[chk-sum.bmw.L13-str]>` usage ], but
**there is no standalone-loadable bmw-L13 implementation in any `AMOS7::*`
package** — confirmed this session: `AMOS7::CHKSUM` exports only `amos_chksum`
/ `amos_template_chksum`, neither of which is bmw-L13. **do not invent a new
standalone bmw-L13 port for this task** — that is real, separate scope.
instead:

- `shm_announce` takes `checksum` as a **required caller-supplied parameter**,
  exactly mirroring `Page::create`'s own existing contract — `Transport.pm`
  computes nothing itself, same division of responsibility already
  established at the layer below it.
- `shm_receive`'s `verify_checksum` step must therefore use **whatever
  checksum function the test / caller actually used to produce the announced
  value** — for this task's own verification script, use
  `AMOS7::CHKSUM::amos_chksum` [ already standalone-loadable, already a
  dependency, already proven elsewhere in this codebase — `bin/amos-chksum`
  is the standalone precedent ] as the concrete algorithm, and **say so
  explicitly in the module's own documentation comment** : "checksum algorithm
  is caller's choice; this package never assumes bmw-L13 specifically." do not
  silently pick bmw-L13 and then fail to provide it.

## scope — do not go beyond this

- **no checksum algorithm implementation** [ see above — caller-supplied only ]
- **no `Feedback` atom** [ no notify-FIFO, no position/ack region — this shape
  doesn't use phase 3 at all ]
- **no wiring into `coding.cmd.submit` / `web.cmd.process_template_ipc`** — the
  prompt-transport doc's actual zenka-side integration is separate, larger,
  future work; this task is the standalone primitive only
- do not touch `Page.pm`, `Feedback.pm`, `Live.pm`, `Channel`-anything, or any
  `data.mount.shm.*` zenka module
- do not wire anything into `data.cmd.shm-self-test`

## verification — standalone, cross-process required for the access-control claim

write `bin/dev/script-scratchpad/test-shm-transport.pl`:

1. generate two distinct pubkey/privkey-shaped strings [ "owner" and "reader" —
   same fixture pattern every prior test script in this series uses, no real
   crypto needed, this project's `derive_pubkey`/`sign_permission` are
   structural, not real asymmetric crypto, confirm this from
   `AMOS7::SHM::derive_pubkey`'s actual implementation before assuming ].
2. compute a real checksum [ `AMOS7::CHKSUM::amos_chksum` ] over a multi-page
   payload [ pick a size that spans at least 3 pages at a small page_size,
   e.g. `page_size => 4096`, content a few times that ].
3. `shm_announce` with the owner's keys, granting the reader. confirm the
   returned descriptor's `total_pages`/`content_size`/`checksum` match.
4. `shm_receive` **as the reader** — confirm `ok => TRUE`, reassembled content
   byte-identical to the original, checksum verified.
5. **cross-process, proven via fork + timing gap** [ the phase-3 lesson,
   restated every time this series needs it : a same-process check can give a
   false positive ] : fork a child that calls `shm_receive` as the reader ;
   parent has already announced before the fork, so this proves the segment
   and its permission grant are visible and correctly verifiable from a
   genuinely separate process, not just re-read in the same process that
   wrote it.
6. **access control, the actual point of the signed-grant model** : attempt
   `shm_receive` using a **third, ungranted** pubkey/privkey pair — confirm
   `ok => FALSE` / `error => 'access_denied'` [ or whatever the real error key
   is — confirm from source, don't guess ], and that **no content is
   returned** [ check the actual hash, not just a truthy/falsy ok flag ].
7. corrupt one byte of the reassembled content **before** the checksum compare
   step [ simulate the page-write path delivering wrong bytes — directly poke
   the mmap'd region after announce, before receive, the same kind of direct
   `substr`-on-`mmap_ptr` technique every prior test script in this series
   already uses ] and confirm `shm_receive` reports `checksum_mismatch` rather
   than silently returning corrupted content as success.
8. print a clear pass/fail summary, run it for real, paste the output.

## style / pitfalls

same binding list as every prior `AMOS7::SHM` task this session: no
`<[...]>` / `<dotted.data>` syntax in `Transport.pm`. do not touch any
existing file's trailing signature block. do not add a fake stub to the new
file. when done, state plainly: the exact subs added with their signatures,
the test script's full output, which claims were proven cross-process [ item 5
specifically ] vs single-process, and confirm explicitly that the checksum-
algorithm-is-caller's-choice decision is documented in the module itself, not
just in this task doc.

#,,,,,..,,.,,,,,.,.,,,.,,,.,.,,,.,.,.,..,,.,.,..,,...,...,...,...,...,,.,,,,.,
#6IWKC73FQNGJUHQW7BPES4J3E2CTAJWH77EBFCQ67UD3VWKOK523RLOUMOPNZB5I5BMUPSZD32HCK
#\\\|UP6GX4OUB5FG4N67QUQPMYOSCLU7RCYXLERIWO6CLSC2VFWWUEI \ / AMOS7 \ YOURUM ::
#\[7]2SW4F6DD2UQYHKWXXE26PFLVOYKTWWL5GS3WOOKU6QDF6TWZDCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
