# inline C objects : who may trust the ~/.7/inline-code cache

draft 2026-10-29 [ todo RCM ]. the trust problem of the compiled Inline
objects every AMOS7 process can load, the options for processes other than
bin/p7-sign-agent, and what each option actually stops. implementation here
: NONE -- part 1 of todo RCM [ the signing agent ] is implemented
[ `$AMOS7::INLINE::force_pure_perl`, set in the agent's BEGIN block ] ; this
note is the analysis for everything else. see also
data/md/design/VAULT-AGENT-SIGNING.md and data/md/design/CREDENTIAL-LAYERS.md.

## the problem

`AMOS7::INLINE` compiles small C oracles [ `bit_string_to_num`,
`num_to_bit_string`, `true_int`, `true_float`, `inline_elf` ] from sources
inside the signed AMOS7 modules, via `Inline->bind`, into a per-user cache :

    ~/.7/inline-code/<subroutine>.<source-chksum>/lib/auto/.../*.so

three facts together make that cache an attack surface :

1. it is USER-OWNED and user-writable [ mode 0755 dirs, built under the
   running user's home ]. nothing verifies a .so before dlopen -- the cache
   is covered by no AMOS7 signature [ the C SOURCE is signed, the compiled
   OBJECT is not, and nothing re-derives one at load ].
2. every AMOS7 process loads it : `AMOS7::13`, `AMOS7::Assert::Truth`,
   `AMOS7::CHKSUM::ELF`, `AMOS7::CHKSUM` compile at `use` time and dynaload
   the objects. four .so files map into a plain `use AMOS7::13` process.
3. a SAME-UID process needs no privilege to replace a .so : the coding
   models run as this user, so any generated code [ or anything else
   same-uid ] can rewrite `inline_elf.so` and wait for the next process
   that maps it. `dlopen` runs attacker code in the victim's address
   space with the victim's privileges and memory.

the worst victim is a process holding UNLOCKED KEY MATERIAL. the prime one
was bin/p7-sign-agent [ unlocked proto-7.sourcecode signing key in memory ]
-- fixed in part 1 : the agent sets `$AMOS7::INLINE::force_pure_perl` before
the first AMOS7 module compiles, loads no .so at all [ asserted via
/proc/<pid>/maps in bin/test-scripts/test-p7-sign-agent-binding.pl ], and
the parity of both paths is pinned by
bin/test-scripts/test-amos7-inline-pureperl-parity.pl. the OTHER key-holder
is the sourcecode CONSOLE zenka [ `sourcecode.console.update-signatures`
loads the same key into `$keys{...}` for the signing run ] and the vault-side
zenki holding decrypted user keys : anything that ever has key material
unlocked should carry the same BEGIN-block switch. that list is the cheap,
immediate part.

the question this note is about : what to do for ALL the other processes
[ zenki and standalone scripts that load AMOS7 but hold no keys ].

## what a same-uid attacker can and cannot do

useful baseline, because several options below only make sense against it :

- CAN : read and write every file the user can [ including anything in
  ~/.7 and ~/.n except the few 0600/0700 spots -- same uid passes those
  permission checks too ], ptrace same-uid processes, and read /proc/<pid>/
  maps of anything the user runs. 'root-owned file' and '0700 directory'
  are cross-uid barriers only.
- CANNOT [ without root ] : write a root-owned file, clear an immutable
  flag, write another user's cache, or sign with the user's private keys
  [ the key material itself stays in ~/.n/user-keys / the vault -- the
  signing key lives ONLY in the sign agent's memory by design ].

so the goal for non-key processes is narrower than for the agent : keep
attacker code OUT of the address space of processes whose CONTENT or
DECISIONS matter [ checksums, truth assertions, what gets signed, what a
zenka believes ], or at least make tamper evident and non-persistent.

## options

### 0. per-process opt-out [ implemented for the agent -- todo RCM part 1 ]

`$AMOS7::INLINE::force_pure_perl = TRUE` in a BEGIN block before the first
`use AMOS7::..`. pure-perl alternatives, no dlopen, zero build cost.
verified byte-identical results across 3714 vectors [ parity test ] and
measured key_32 unlock time is the SAME on both paths [ ~13 ms median :
the derivation cost lives in the perl entropy loops, not the oracles ].

- stops : everything, for the processes that set it. free.
- does not stop : anything for processes that forget. the switch is only
  as good as the discipline of setting it -- correct for the FEW
  key-holding processes, unrealistic as the answer for every zenka.
- note : bin/test-scripts/test-truth-fallback.pl already pins the raw
  oracle fallbacks bit-identically ; the new parity test pins the
  DISPATCH level [ calc_true / is_true ] and key_32 end-to-end.

### 1. root-owned per-user cache [ privileged builder ]

the cache dir is owned by root [ or a dedicated build uid ], mode 0755 /
files 0644 : readable by everyone, writable by nobody. a privileged helper
[ sudo rule on the build command, a setuid wrapper, or a tiny systemd unit ]
runs the compile once [ install time, or on perl/compiler upgrade ], as
root, into the user's cache path. `AMOS7::INLINE::compile_inline_source`
already takes `uid` / `gid` parameters for the make_path call -- the
plumbing anticipates this.

- stops : the same-uid .so swap for every process at once, cross-uid
  tamper included. the strongest general answer that keeps runtime
  compile.
- cost : a privileged builder path to maintain and audit [ a setuid
  helper that compiles and installs arbitrary-derived objects needs care
  -- build in a user-owned staging dir, then root moves it in ]; cache
  invalidation becomes a root operation [ perl upgrade, compiler change,
  AMOS7 source change -> new chksum-keyed dir -> root rebuild ].
- caveat : a same-uid attacker can still make the RUNTIME take the
  pure-perl fallback [ point Inline elsewhere via environment, fill the
  disk, etc ] -- that is availability, not code execution ; acceptable.

### 2. compile at install time as root, ship read-only [ package model ]

variant of option 1 with no runtime compiler at all : the .so set is built
when the repo/profile is installed [ as root, like the p7c binary ], and
AMOS7::INLINE only ever LOADS.

- stops : same as option 1, plus removes the runtime cc requirement and
  the 'first user to run pays the compile' behavior.
- cost : the XS ABI problem -- compiled objects are keyed to perl version
  AND arch [ the chksum-keyed path names exist precisely because a .so is
  only valid for one perl ]. a shipped cache works for exactly one
  perl/arch matrix ; the repo supports floor-perl 5.32 through local
  5.42, so EITHER the matrix is installed alongside [ one cache dir per
  perl, keyed as today ] or hosts with a non-matching perl fall back to
  pure-perl / runtime build. needs build infra in the installer.

### 3. fresh 0700 temp dir, rebuild per process

every process compiles into its own unpredictable temp dir [ File::Temp,
0700 ], loads, and unlinks on exit. no stable cache path exists to
pre-seed with a trojan.

- stops : pre-planted persistent trojans and CROSS-UID injection
  completely.
- does NOT stop same-uid : same uid walks through the 0700 dir
  permissions, and an attacker that can watch the process can race the
  build-then-dlopen window [ short, but same-uid debuggers exist ]. the
  random path only removes the STABLE TARGET, not the capability.
- cost : the heaviest of all -- a C compiler invoked per process start [
  seconds per zenka child, lock contention when many start at once ],
  temp-dir lifecycle handling, and it still rebuilds on every start
  because Inline needs the .so present at load. poor fit for a system
  that forks zenki constantly.

### 4. host-local manifest of .so checksums

after a build, record a checksum list [ BMW-512 over each .so ] in a
manifest ; the loader re-verifies before dlopen.

- stops : accidental corruption and sloppy tampering.
- does NOT stop same-uid, alone : the manifest lives where the attacker
  writes [ same ~/.7 ], so the trojan update is `.so` PLUS `manifest` in
  one rename -- a same-uid attacker rewrites such a manifest exactly as
  easily as the .so. a manifest only earns its keep when IT is
  unwritable to the user [ root-owned or signed with a key the user
  cannot use -- which collapses into option 1/2 with extra steps ].
- cost : check-then-dlopen TOCTOU unless the check happens around an
  fd-based load [ perl's DynaLoader cannot dlopen from a verified fd
  portably ]; a stale manifest after legitimate rebuilds becomes an
  operational burden. useful only as a tripwire ON TOP of option 1/2,
  not as the control.

### 5. immutable flag [ chattr +i ]

mark the cache tree immutable after build [ files AND the dirs, so no new
entries either ]. kernel-enforced : clearing +i needs CAP_LINUX_IMMUTABLE,
which the same-uid attacker does not have.

- stops : same-uid .so swap and cache poisoning, cleanly and cheaply,
  where supported.
- cost : cache invalidation needs root [ every perl/AMOS7 change that
  re-keys the dir names means a root round-trip to +i the new entries and
  clean the old ]; unsupported on tmpfs/overlay and several network
  filesystems [ $HOME on those quietly loses the protection ]; and it
  protects the TREE, not the process -- a trojan already IN a writable
  cache from before the flag is set stays until rebuilt.
- fit : a good LOCAL hardening layer on top of option 1, not a design.

### 6. drop Inline::C by default for all processes

the parity is now pinned by tests, and the measured cost for the
agent-shaped workload is zero. flip the default : every process takes
pure-perl unless it opts IN to compiled oracles.

- stops : the whole class, for every process, no per-process discipline.
- cost : the real throughput loss on the workloads the C oracles were
  written for -- `inline_elf` over large buffers and the bit conversions
  in tight loops are genuinely faster in C [ the C elf loop vs the
  perl codepoint loop on multi-hundred-byte inputs ]. zenki that
  checksum large streams would pay it continuously. the policy question
  is whether any current hot path justifies the cache existing at all;
  a benchmark of elf_chksum / bit_string_to_num throughput both ways
  should answer it before this is chosen.

## what each option actually stops [ summary ]

| option | same-uid .so swap | cross-uid | runtime cc needed | root ops | verdict |
|---|---|---|---|---|---|
| 0 per-process opt-out | for opting processes | yes | no | none | keep for key-holders [ done ] |
| 1 root-owned cache | yes | yes | yes [ build time ] | on invalidation | best general fix |
| 2 install-time build | yes | yes | no | at install | best if ABI matrix handled |
| 3 per-process temp | no | yes | yes, per start | none | heavy, weak vs same-uid |
| 4 checksum manifest | no [ alone ] | no [ alone ] | no | none | tripwire only, on top of 1/2 |
| 5 immutable flag | yes | yes | no | per invalidation | hardening layer on 1 |
| 6 pure-perl default | yes | yes | no | none | policy call : costs throughput |

## recommendation shape [ for a later slice ]

1. now : extend the BEGIN-block opt-out to every process that holds
   unlocked key material [ sourcecode console zenka's update-signatures
   path, vault-side decryption processes ] -- same pattern, same tests.
2. then : option 1 or 2 for the general cache [ root-owned, runtime load
   only ], keeping the chksum-keyed dir names so multiple perl/arch
   entries coexist ; option 5 where the filesystem allows.
3. never rely on option 4 alone ; treat option 3 as a last resort for
   the paranoid single-process case, not the system design.
4. if a benchmark ever shows the compiled oracles no longer matter for
   the hot paths, option 6 retires this whole note.

## target architecture [ user 2026-10-29 ] : attested binaries

the options above only move the problem ; the complete answer makes every
compiled object traceable to reviewed source, with NO private key on the
verifying host :

1. reproducible builds : bit-for-bit identical output from the same inputs
   [ fixed flags -- -ffile-prefix-map, --build-id=none, no timestamps --
   and a normalized build path ; the cache path and build id are embedded
   today, so two honest builds never match yet ]
2. an input manifest per build : checksums of the exact headers [ gcc -MD,
   incl. perl CORE/*.h ], toolchain binaries + versions, linked libraries
   [ readelf NEEDED + package versions ], flags. toolchain integrity
   against the distribution [ dpkg --verify \ debsums ]
3. cross-host agreement : the same source compiled on remote hosts ; no
   match -> a vm with the host's exact toolchain versions rebuilds it
4. source changed -> the inline C diff goes to review [ llm \ consensus ].
   output changed with unchanged source -> the manifest diff backtraces it
   to the changed inputs [ a header, gcc, a library ] -- their upstream
   diffs join the review list, scoped to what the object uses [ imported
   symbols, included headers ]. the chain is clean only when every change
   is reviewed, checked by before \ after checksums
5. an attestation : 'output checksum X came from manifest Y, its changes
   covered by reviews Z', signed ONCE by any trusted key [ reviewer, build
   host, owner ] -- content-addressed, valid on every host that sees the
   same bytes
6. verification needs public keys only : a host checksums its local object
   and checks the attestations ; a compromised host can fail to verify, it
   cannot create trust. the agent loads an object only with a passing
   attestation [ today : none at all, option 0 ]
7. a trust threshold, not one key : the owner key alone, or k of n matching
   build hosts, or a consensus review [ llm.service.consensus_vote ] + a
   human -- per consumer [ the signing agent strictest ], the policy
   itself a signed file. a growing network adds witnesses without key
   handling

shares its mechanism with todo 7SE [ reproducible inference ] and the
distributed re-signing of VERSION-BRANCHES.md : independent hosts produce
the same bytes from checksummed inputs.

## evidence pointers

- no .so in the sign agent : /proc/<pid>/maps assertion in
  bin/test-scripts/test-p7-sign-agent-binding.pl [ agents 1 and 3,
  plus a contrast probe showing an unguarded perl maps 4 ].
- both paths byte-identical : bin/test-scripts/
  test-amos7-inline-pureperl-parity.pl [ 3714 vectors over
  bit_string_to_num, true_int/true_float in-contract, calc_true, is_true,
  elf_chksum, key_32 ] ; raw-oracle bit-identity already pinned by
  bin/test-scripts/test-truth-fallback.pl.
- known raw-oracle boundary : the compiled `true_int` clamps input past
  2**64 to UV_MAX where the pure-perl dispatcher takes its exact long-
  number path -- calc_true's guard exists precisely to keep out-of-
  contract input away from the compiled sub, so the DISPATCH surface is
  the one that must [ and does ] agree everywhere.

#,,.,,...,,,,,..,,.,,,...,,,.,...,.,,,.,,,..,,..,,...,...,,,,,,..,,,,,...,,.,,
#3K3BUKOUEYOQDUTBC6J5BQLGOMHSI4542DMHAJYYBHLNKDNFKHGJHUF2FUXYZGIJJOHZC2RQIQJ5C
#\\\|Z2HU7XPV27LQZJSKCIO4RJIH4YPWS3ZYK32Z5ZZ3NQOA7OLD3JF \ / AMOS7 \ YOURUM ::
#\[7]KBBM2CPXDD6SSNPLBDBRYJJWGVZJWUMD6L6BSWY7EUEP5UB6YGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
