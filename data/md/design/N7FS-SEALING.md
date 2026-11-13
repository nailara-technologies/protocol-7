# N7FS sealing : stage 4 part 1 as built

Local, standalone sealed holders. No network, ssh, packs, placement, category rotation, or root rotation is implemented.

## suite and records

Format suite byte `1` means Twofish-CTR inside ChaCha20-Poly1305 outside. No AES is used. Each node, category, and root has two independent 32-byte keys drawn separately from OS entropy. Node keys are not derived from content. Content blobs are named by BMW384 of the complete ciphertext, so a blind holder cannot confirm a known plaintext.

Binary records start with `P7RK`, `P7SW`, or `P7SB` and suite byte `1`. Root parameters and wrapped keys carry their own lengths and counters. Maps, journals, and heads are canonical JSON inside the same two-layer suite. Every map and head names the root id. The root id is BMW384 of a labelled Ed25519 public key; independent roots and future k-of-n shares do not require a record-layout change.

The Twofish counter block is `56-bit chunk index || 8-bit final flag || 64-bit block counter`, big-endian. `Crypt::Mode::CTR->new( 'Twofish', 1, 8 )` confines carry to the low 64 bits. The ChaCha nonce is labelled by layer and contains the same chunk index and final flag. The outer AAD also authenticates suite, chunk index, and final flag. Outer authentication succeeds before Twofish decryption. Chunks are 16 MiB, including a single empty chunk for an empty node. Truncation, reorder, and non-final size changes are refused.

Wrap nonces are BMW384-derived from a labelled domain, the wrapped key's random 128-bit id, and its 64-bit re-wrap counter. Head, map, and journal nonces and AAD include a random 128-bit home writer id and a monotonic version. The writer id is carried in clear in those records. Losing state or copying the root file therefore cannot repeat a long-lived-key nonce. Home-side `<root-file>.state/reservations/<version>` journals the next version before any use; the next version is the maximum of state, every reservation, and the visible holder head, plus one. Two independent writers can safely write version one to different holders. A new writer on a clean holder reports that no newer head was visible. Re-wrap counters are present in the format; no re-wrap command is in this part.

## root file

`n7fs root init <file>` generates the root keypair and Ed25519 seed, then wraps them with the suite under a 64-byte Argon2id result split into independent layer keys. Defaults are `m=262144` KiB, `t=3`, `p=1`; `-argon-m`, `-argon-t`, and `-argon-p` override them and the chosen values are stored in the file. Salt and wrap id come from OS entropy. The unwrapped root is never written to disk. The file mode is 0600 and group/other-readable files are refused.

Passphrases are read with terminal echo disabled, or from `-pass-fd <n>` for automation. They are never accepted in argv. Init asks twice. `n7fs root export-check <file>` copies the file to a temporary directory and proves the supplied passphrase opens that copy.

## map, journal, and head

`n7fs seal <disk> -root-key <file> -out <dir>` accepts addresses, `-category`, repeatable `-tree`, or `-all-trees`. Disk `-root` remains independent. Tree selection seals the manifest and every file node and stores `trees : { name : { manifest, created } }`. Category selection includes manifests of live trees containing selected files. Each content blob header and map entry carries `layout : { mode, chunk_size, header_size }`; restore requires them to agree. Only `complete`, 16 MiB, zero is accepted. `segment` and `catalog` are reserved and refused.

The holder has no plaintext names, local addresses, plaintext hashes, keys, or map sizes. Ciphertext lengths reveal chunk rounding. Plaintext BMW is checked while sealing, with short-read-safe streaming, before an entry can be mapped. One journal replay and one reference pass select all nodes; category reports are not repeated per node. The map and head commit every 1 GiB or 1000 new nodes and at the end, so a resume keeps earlier batches.

The envelope is node key <- category key <- root key. A deduplicated node referenced by several categories has one wrap under each in `wraps`. The strictest category policy controls cascade refusal. Re-running an already mapped address seals nothing and writes no new head.

The head locator is BMW384 of a labelled root-key derivation. Its signed plaintext names root id, writer id, version, map blob, and journal blob. New heads append `P7SH\x01` and a detached Ed25519 signature over the clear version, writer and complete sealed head; a blind receiver verifies this outer signature without symmetric keys, while home still accepts heads written before it. Home keeps a per-writer counter and a newest-head pin per canonical holder path; an older head is refused. Clean recovery accepts the reachable valid signed head, so a holder can withhold newer versions.

`n7fs unseal <disk> -root-key <file> -from <dir> <tree-or-address> <target>` verifies content against its local BMW address. Sealed and local tree restores call the same `AMOS7::N7FS::Tree::tree_restore` engine with a content-source callback. Preflight, symlink checks, ownership, modes, xattrs, times, and temp-then-publish are shared. `-owners` has the same meaning as for local restore.

`n7fs seal-recover -root-key <file> -from <dir> [-tree <name>] <target-dir>` needs only the root file and holder. Without `-tree` it writes verified address files. With `-tree` it restores the named sealed tree without any disk or journal on the clean host.

## local and SSH holders

`-out`, `-from`, `shred -out`, and `holder-check` accept a local directory, legacy `ssh:<host-alias>:<absolute-dir>`, or restricted `ssh-receiver:<host-alias>:<absolute-dir>`. `AMOS7::N7FS::Holder` is the only transport layer. SSH aliases and directories are restricted to safe ASCII without leading dashes or shell metacharacters. `ssh` is executed as an argument list with `BatchMode=yes`, and `N7FS_SSH` can select a test implementation.

A legacy blind holder needs only sshd, POSIX sh, and coreutils. Its uploads append to a ciphertext-named `.upload` temporary from its reported size, with five bounded attempts and configurable backoff. Every destructive legacy call warns that it uses the full-shell path. A receiver holder instead needs Perl and `bin/n7fs-receive` on the holder, reached through the ssh `command=` option; no shell command, key material, passphrase, or plaintext name is sent.

Head and map readback must match the local ciphertext. Content checks include total size and sampled whole-chunk readback. Restore streams into a resumable local spool instead of slurping the blob. `holder-check -samples <n>` checks every blob's size, then authenticates chunks drawn by bytes — a large pack is sampled proportionally more often than a small one — using node keys, without downloading whole blobs or writing plaintext. `-full` authenticates every chunk ; `-scrub` verifies every mapped blob's checksum name on the holder instead, keyless, and also yields a `full` receipt — it proves ciphertext integrity for every byte the holder keeps, not the map's key material. Missing files are distinct from transport failure; a pinned holder with no head refuses to become clean. SIGPIPE is ignored and checked, stdout/stderr are drained concurrently, and diagnostics are bounded.

Uploads and directory entries are synced before success. Content is published before map, journal, and head; the head is always last. Existing confirmed blobs are skipped. Old, truncated, deleted, or wrong holder data is refused.

### forced receiver requests [ review finding 2, addressed ]

`bin/n7fs-receive` accepts only these requests, never an arbitrary shell command:

- `list [ dir ]` : names, sizes and mtimes for blobs, or names and mtimes for root/trash day directories. it serves the holder, one `r-<tag>/`, `.trash/`, or one day below either
- `has <name>..`, `get-range <name> <offset> <length>`, `free`, and streamed `scrub [ -nonce <b32> ] [ <name>.. ]` : read-only, with trash invisible to blob reads and scrub
- `put <name> <size>` : streamed and add-only; the bytes must match the checksum name. `mkdir` and `sync` are implicit in this and every other write
- `put-head <name> <size> <record>` : verifies the new head's detached outer signature, exact signed byte digest, clear writer/version and increasing version, then atomically replaces it. `put-list` similarly authenticates replacement of a fixed-name relay list
- `move <from> <to> <record>` : only a live blob to `.trash/<day>/` in the same holder or root directory, or the reverse. moves are rename-only and never overwrite. trashing and restoring are non-destructive, but both are signed anyway : this gives one authorization and replay rule for every name removal and prevents a stolen ssh key from hiding live blobs in trash
- `migrate <name> <r-tag> <record>` : the separate flat-to-per-root rename needed by `holder-migrate`; it is not a general move request
- `purge-day <path> <record>` and `delete <name> <record>` : actual deletion, always root-signed

The signed record is domain-separated canonical JSON with an Ed25519 signature, transported as base32 payload plus base32 signature. It names the operation, full root id, holder id derived from the canonical `ssh-receiver:` spec, exact operation arguments, a monotonic counter and a 128-bit nonce. Home durably reserves the next counter per root and holder before sending. The authorized_keys options `-holder-id`, repeatable `-root-pub`, and repeatable `-head-name` install only verification material. The receiver locks each root's counter file, verifies signature, target, operation and arguments, rejects a counter at or below the last accepted one, then performs the operation and syncs the new counter. A signed change is not blindly retried after a lost reply; a fresh home run uses a new counter and idempotent operations.

A stolen home ssh key can list, read and scrub ciphertext and add valid blobs [ including storage exhaustion within quota ]. It cannot replace heads or lists, move or migrate blobs, hide them in trash, purge or delete. Those operations need the root signing key. A holder administrator can still destroy or withhold its own storage and roll back holder-side counters; this transport does not make a malicious holder honest.

Migration of an existing holder :

1. run `n7fs holder-receiver-line <name> -root-key <key>` and append the printed `command="..../n7fs-receive <dir> -holder-id .. -root-pub .. -head-name ..",restrict` prefix to the home key's authorized_keys entry, followed by its key type and key as usual. add one `-root-pub` and `-head-name` pair per root that may write
2. test reads and `holder-check` through the forced key, then run `n7fs holder receiver <name> -root-key <key>`. this verifies the same head under `ssh-receiver:` before changing the registry and moving the pin
3. run `holder-check` again for a receipt bound to the new spec. preserve `.n7fs-receive/` counter state on the holder and the root's `receiver/` counter state at home; resetting only one side blocks later requests rather than allowing replay. the legacy `ssh:` spec remains available as an explicit fallback

`bin/test-scripts/test-n7fs-holder.pl` uses a POSIX-sh fake SSH in a sandbox, never a real host. It covers clean tree recovery with metadata, upload interruption and process resume, readback corruption, persistent failure, old heads, alias rejection, argv secrecy, publication ordering, and deleted/corrupted blobs. Mutants cover head-before-blobs, removed readback, and path quoting.

## shredding and local encryption

`n7fs shred <disk> -root-key <file> -out <dir> <address>` implements step 1 only: it journals removal of the node's wrap from the current map and advances the signed head. Other nodes still recover. Local plaintext, ciphertext blobs, old sealed maps, and old heads are retained. Steps 2 and 3 are not implemented.

`local_encryption cascade` is **not implemented**. Sealing a node whose effective policy is cascade is refused. The older `n7fs category` warning remains accurate: storing that policy does not encrypt the home copy.

## verification

`bin/test-scripts/test-n7fs-seal.pl` drives the real CLI for root operations, sealing, unsealing, tree restore, clean recovery, and shredding. It covers empty, exactly 16 MiB, and 16 MiB+1 content; fixed known-answer and counter-rollover vectors; independent entropy draws and ciphertext; holder plaintext/hash opacity; wrong passphrases; tamper, truncation, chunk reorder, blob swap, and old heads; idempotence; crash/resume at every seal fault point; cascade refusal; and shred isolation. Four sealing mutations in `fixtures/n7fs/mutate.pl` guard final-flag authentication, wrap counters, decrypt order, and rollback refusal.

## honest limits

This is one local or SSH holder at a time, not replication or placement. No pack format exists. Clean recovery cannot detect withheld newer heads. Old maps defeat step-1 shredding if retained with their keys. Map JSON and individual 16 MiB chunks are held in memory; very large maps are not yet streamed. Restore spool storage is one blob, while network reads and holder-check authentication are chunked. **No real SSH server has been tested yet**; all SSH acceptance coverage uses the sandboxed POSIX-sh fake.

## real holder test

2026-11-09, one owned host over real ssh, throwaway key and scratch tree : seal, repeat run sends nothing, clean recovery of a named tree with only the root file and the holder [ bytes identical, modes identical, timestamps within the known microsecond limit ], ssh killed during a 400 MB upload and resumed by the retry, `holder-check`. the holder listing held ciphertext names only and no plaintext marker. this supersedes any statement above that no real server was tested ; foreign hosts and the owner's real root key are still untested.

## vault roots

`-root-key` and `root init` also accept `vault:<name>`, a note entry titled `n7fs root <name>` in a p7-vault [ `-vault-dir`, `P7_VAULT_DIR`, default `~/.n/vault` ], unlocked with the vault passphrase and locked again after use. `n7fs root convert <from> <to>` moves a root between a passphrase file and the vault in either direction. only the wrapping of the 96-byte root changes : blobs, maps, heads and holders are untouched and no data is re-encrypted. the source stays until the owner removes it, so one conversion leaves two ways to open the same data. the counter and holder pins carry over and the writer id does not, so both copies may be used safely. a vault root keeps its state in `<host-dir>/seal-roots/<root-id>.state`. `root export-check` takes files only : convert a vault root to a file for the offline copies, then check those.

## packs [ stage 4 part 3 ]

a sealed node of at most 1 MiB is not uploaded on its own : it is appended to a pack blob of about 16 MiB, starting `P7SP` and suite byte `1`, which is named by BMW384 of its whole content like every other blob. each node inside keeps its own node keys, nonces and node header, so packing changes no crypto. its map entry names the pack in `blob`, its own ciphertext checksum in `node`, and `offset` and `length` inside the pack. entries without `node` are whole-blob nodes as before. a pack is written before the map commit that references it.

recovery reads only a packed node's range from a local holder. from an ssh holder it fetches each pack once per command into the spool and cuts the nodes out locally ; the copies are removed when the command ends. each cut range is checked against its `node` checksum before it is opened. `holder-check` takes one listing of the holder for every size, then authenticates random chunks by computed offset, so it no longer costs ssh calls per node. a pack upload is confirmed by size and two random ranges.

measured against a real owned holder over ssh : 500 small files sealed in 15 s as one pack [ about 33 minutes before ], recovered in 3.2 s [ 2 minutes 44 with one range read per node ]. shredding a packed node drops its wrap ; its bytes stay in the pack until a repack.

## holder-gc, trash and the per-root layout [ 2026-11-13, review finding 2 ]

`n7fs holder-gc <holder> -root-key <key> [ -only-root ] [ -delete ] [ -grace <age> ]` collects the blobs the current head no longer references : superseded maps and journals, and node blobs dropped from the map. it never deletes. a blob younger than the grace age [ default 1 day, holder-side mtime, one listing ] is always kept, so a seal, relay or push in flight cannot lose its bytes to a concurrent gc. with `-delete` each old unreferenced blob is MOVED to `.trash/<YYYY-MM-DD>/<name>` inside the holder directory [ rename, same filesystem, local and ssh ], never `rm`. the listing is one batched call, local or over ssh.

the trash is useful, so :

- `n7fs holder-trash-restore <holder> -root-key <key> <name>..` moves blobs back [ or `-all-since <YYYY-MM-DD>` ]. a blob already back at the holder is skipped, never overwritten.
- `n7fs holder-trash-purge <holder> -root-key <key> [ -older <age> ] [ -delete ]` removes trash day directories older than the age [ default 7 days, the receipt age ]. dry run unless `-delete`.
- `has` and `scrub` never read `.trash/` : a blob present only in trash counts as missing everywhere [ placement, holder-check, scrub ].

one holder subdirectory per root : a holder in the new layout keeps each root's head, map, journal and blobs in `<holder>/r-<tag>/`, the tag seven characters of the root id [ short, stable, no secret ]. `holder-gc` then lists only that root's subdirectory, so `-only-root` is structural there -- the flag is still accepted and warned redundant. a holder with the old flat layout keeps working read-only and for gc as today, and still requires `-only-root` : a second root added later on the same holder would otherwise have its blobs collected by the first root's gc. detection is by existence : the subdirectory present and no flat head means the per-root layout ; a flat head means the old layout, even mid-migration. new holders start per-root ; every writer [ seal, place, relay, push, n7fs-receive put, drain ] writes into the subdirectory.

`n7fs holder-migrate <holder> -root-key <key> [ -delete ]` moves a flat holder into the per-root layout : this root's referenced blobs, its map, journal and head, rename-only, idempotent, resumable after an interruption [ the head moves last, as the commit point ]. dry run by default. unreferenced flat blobs stay and are reported -- they may belong to another root. reads refuse while a migrate is interrupted midway [ missing blob ] until a rerun finishes it ; gc and migrate itself stay safe throughout. it takes the same host lock as gc.

receiver names use the same fixed `r-<tag>/<name>` form : one level, no `..`, no other path. the subdirectory is created implicitly on the first put or signed migrate. relay lists name the subdirectory, so `n7fs-push` reads and writes the right directory on both ends. all receiver gc, restore, purge and migrate changes use the signed requests above.

it must not run while a seal to the same holder is in progress [ the host lock of 2026-11-11 covers every holder-writing command ]. a holder that ignores a signed delete is still what shredding covers. **review finding 2 is fully addressed** ; `test-n7fs-receiver.pl` exercises the whole workflow and refusal cases against the forced-command fixture.

#,,.,,..,,..,,.,.,...,,.,,.,.,,.,,,.,,.,,,,,.,..,,...,...,...,,,.,...,.,.,..,,
#SUWYYPZEE65KYK6IV7KXMZPSIJOALVOEVFCDT3XVPSSB5QLU4S3KQP6SMICZM2KDZN2BXL3DTQ2S6
#\\\|W54TLVJTMULZMVF4PMB5DTVFEGPPK3JO7XBSOCPKNHPILFTXXCC \ / AMOS7 \ YOURUM ::
#\[7]SZJUQP3YX46JAXKA2GRLOXFWYWJMUTQBYZYFSAKIRBPBYBNHP4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
