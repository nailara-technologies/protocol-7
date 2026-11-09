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

## shredding and local encryption

`n7fs shred <disk> -root-key <file> -out <dir> <address>` implements step 1 only: it journals removal of the node's wrap from the current map and advances the signed head. Other nodes still recover. Local plaintext, ciphertext blobs, old sealed maps, and old heads are retained. Steps 2 and 3 are not implemented.

`local_encryption cascade` is **not implemented**. Sealing a node whose effective policy is cascade is refused. The older `n7fs category` warning remains accurate: storing that policy does not encrypt the home copy.

## verification

`bin/test-scripts/test-n7fs-seal.pl` drives the real CLI for root operations, sealing, unsealing, tree restore, clean recovery, and shredding. It covers empty, exactly 16 MiB, and 16 MiB+1 content; fixed known-answer and counter-rollover vectors; independent entropy draws and ciphertext; holder plaintext/hash opacity; wrong passphrases; tamper, truncation, chunk reorder, blob swap, and old heads; idempotence; crash/resume at every seal fault point; cascade refusal; and shred isolation. Four sealing mutations in `fixtures/n7fs/mutate.pl` guard final-flag authentication, wrap counters, decrypt order, and rollback refusal.

## honest limits

This is one local holder directory at a time, not replication or placement. No pack format exists. Clean recovery cannot detect withheld newer heads. Old maps defeat step-1 shredding if retained with their keys. Map JSON and individual 16 MiB chunks are held in memory; very large maps are not yet streamed.

#,,.,,,,.,.,,,,,.,,..,.,,,.,.,,,.,.,,,.,,,.,,,..,,...,...,...,..,,,,.,,,,,,,,,
#X37MNXNRV4XH4QQ6JTIGPRKLC3ZBJFZZCCTSJMQZSO57FXCOVM5PS6TUSY4YL2UMPFRZ55MRY7ISG
#\\\|MJV3EG3TLF53XHDZJPJRPGCFZD5UQGM2IPBLSKL7I2PFT5T76XU \ / AMOS7 \ YOURUM ::
#\[7]5MJJP2G3MH4QFOCKSO2UUGZ4EVJCD7VOAECGDTRHB4DJXVIA22AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
