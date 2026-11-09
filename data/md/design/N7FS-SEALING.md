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

The head locator is BMW384 of a labelled root-key derivation. Its signed plaintext names root id, writer id, version, map blob, and journal blob. Home keeps a per-writer counter and a newest-head pin per canonical holder path; an older head is refused. Clean recovery accepts the reachable valid signed head, so a holder can withhold newer versions.

`n7fs unseal <disk> -root-key <file> -from <dir> <tree-or-address> <target>` verifies content against its local BMW address. Sealed and local tree restores call the same `AMOS7::N7FS::Tree::tree_restore` engine with a content-source callback. Preflight, symlink checks, ownership, modes, xattrs, times, and temp-then-publish are shared. `-owners` has the same meaning as for local restore.

`n7fs seal-recover -root-key <file> -from <dir> [-tree <name>] <target-dir>` needs only the root file and holder. Without `-tree` it writes verified address files. With `-tree` it restores the named sealed tree without any disk or journal on the clean host.

## local and SSH holders

`-out`, `-from`, `shred -out`, and `holder-check` accept a local directory or `ssh:<host-alias>:<absolute-dir>`. `AMOS7::N7FS::Holder` is the only transport layer. SSH aliases and directories are restricted to safe ASCII without leading dashes or shell metacharacters. Every remote path is POSIX single-quoted, `ssh` is executed as an argument list with `BatchMode=yes`, and `N7FS_SSH` can select a test implementation.

A blind holder needs only sshd, POSIX sh, and coreutils. No remote Perl, N7FS code, key material, passphrase, plaintext name, or nonce is used. SSH receives exactly one remote command string with connect/server-alive options. Uploads append to a ciphertext-named `.upload` temporary from its reported size, with five bounded attempts and configurable backoff. Node ids and keys are wrapped under the root keys in root-state pending storage until the map commit. A process failure on rerun produces the same ciphertext and continues the same temporary. Spooled files are deleted only after confirmation; non-content temporary uploads are discarded before retry.

Head and map readback must match the local ciphertext. Content checks include total size and sampled whole-chunk readback using `tail` and `head`, never byte-wise `dd`. Restore streams into a resumable local spool instead of slurping the blob. `holder-check -samples <n>` checks every blob's size, then authenticates 16 chunks by default across the holder using node keys, without downloading whole blobs or writing plaintext. Missing files are distinct from transport failure; a pinned holder with no head refuses to become clean. SIGPIPE is ignored and checked, stdout/stderr are drained concurrently, and diagnostics are bounded.

Uploads use `sync` when available, with a warning otherwise, then atomic `mv`. Content is published before map, journal, and head; the head is always last. Existing confirmed blobs are skipped. Old, truncated, deleted, or wrong holder data is refused.

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

#,,.,,...,.,,,,,,,,,,,,.,,,.,,,.,,..,,...,.,.,..,,...,...,...,,..,..,,...,,,.,
#C75YGYOBIRYTCRMXK25HOO5TNVAD2JYRLW4CPVKEQ7OIY3AIMDKKABWLP5LQ7GA6Y7BA5V7OKATTE
#\\\|PR2PA6CKJI753DLVZKUELXW24RGMD22OO7NEKSMHTXUGK4YBRD7 \ / AMOS7 \ YOURUM ::
#\[7]GNEMMO66LQY4U23QCOSUDRMRGOIEJPPRW2CJKY5QYD73TZU5LSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
