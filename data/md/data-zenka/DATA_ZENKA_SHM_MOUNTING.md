# Data Zenka: Cryptographic SHM Mounting

**For:** LLM agents implementing high-bandwidth data visualization
**Date:** 2026-02-15
**Status:** Design complete, implementation pending

---

## Overview

Extension of the holographic topology system to use **Shared Memory (SHM)** as a cryptographically-secured, zero-copy transport backend. Provides memory-bus-speed bandwidth (GB/s) for real-time visualization updates while maintaining decentralized security.

---

## Core Concept

```
Traditional Mount:   Hash → Filesystem → FUSE → Kernel → User Space
                     (multiple copies, ms latency, GB overhead)

SHM Mount:          Hash → 13³ Coordinate → SHM Segment → mmap()
                     (zero-copy, ns latency, cryptographic verification)
```

The 63K convergence size aligns with SHM page boundaries. The cryptographic checksum IS the addressing scheme.

---

## Naming Convention

### SHM Segment Path

```
/dev/shm/p7:M:<pub-key-B32>
/dev/shm/p7:M:<pub-key-B32>:<data.sub.path>

Examples:
  /dev/shm/p7:M:ABCD1234EFGH5678IJKL9012MNOP3456QRST7890UVWX1234YZ
  /dev/shm/p7:M:ABCD1234...YZ:data.visual.grid-v14.config
  /dev/shm/p7:M:ABCD1234...YZ:data.ai.dreams.output.7_3_11
```

### Components

| Part | Description |
|------|-------------|
| `p7:` | Protocol-7 namespace prefix |
| `M:` | Mount type (SHM with cryptographic identity) |
| `pub-key-B32` | Owner's public key in Base32 (56 chars) |
| `data.sub.path` | Optional sub-branch path |

---

## Decentralized Identity Model

### No PKI Required

```
Creator Zenka (owns private key for ABCD1234...YZ)
       │
       ├── Creates SHM segment with pub-key as identifier
       │
       ├── Signs permission for Zenka B
       │   └── Sticky permission written to SHM header
       │
       ├── Delegates branch :data.ai.* to Sub-Agent Group
       │   └── Group pub-key becomes sub-owner
       │
       └── Revokes by not re-signing (time-based expiry)
           └── No revocation lists needed
```

### Sticky Permission Structure

```perl
SHM Header Format:
┌─────────────────────────────────────────────────────────────┐
│ AMOS Checksum (64 bytes)      ← Header integrity            │
│ Owner Pub-Key B32 (56 bytes)  ← Creator's identity          │
│ Creation Time (8 bytes)                                     │
│ Lock Flags (8 bytes)          ← SWAP, READ, WRITE           │
├─────────────────────────────────────────────────────────────┤
│ Sticky Permissions Array:                                   │
│   {                                                         │
│     'to'       => 'XYZ789...ABC',      # Allowed pub-key    │
│     'branch'   => 'data.visual.*',     # Path pattern       │
│     'expiry'   => 3600,                # Seconds            │
│     'rights'   => ['read', 'write'],   # Permissions        │
│     'sig'      => '<owner_signature>'  # Creator signs      │
│   }                                                         │
└─────────────────────────────────────────────────────────────┘
```

### Access Verification Flow

```perl
sub verify_shm_access {
    my ($requester_pub_key, $requested_path, $shm_header) = @_;

    for my $perm (@{$shm_header->{'permissions'}}) {
        # Auto-revocation via expiry
        next if $perm->{'expiry'} < time();

        # Path pattern match
        next unless path_match($requested_path, $perm->{'branch'});

        # Key match or group membership
        if ($perm->{'to'} eq $requester_pub_key ||
            group_contains($perm->{'to'}, $requester_pub_key)) {

            # Verify owner signature
            return verify_ed25519($perm, $shm_header->{'owner'});
        }
    }

    return 0;  # Access denied
}
```

---

## Group Delegation

### Collective Ownership

```perl
# Group identified by threshold key (5-of-7)
my $render_group = "GROUP:RENDER:7XYZ...";

# Any 5 members can sign for the group
my $group_sig = threshold_sign($request, @member_sigs);

# SHM header recognizes group key as owner
# Individual members don't need separate permissions
```

### Sub-Agent Delegation

```perl
# Owner delegates :data.ai.dreams branch to sub-agent
my $delegation = {
    'type'    => 'delegate',
    'from'    => $owner_pub_key,
    'to'      => $sub_agent_pub_key,
    'branch'  => 'data.ai.dreams',
    'expiry'  => time() + 86400,
    'rights'  => ['read', 'write', 'sub-delegate'],
};

$delegation->{'sig'} = sign_ed25519($delegation, $owner_priv_key);
shm_append_permission($shm_segment, $delegation);
```

---

## Transport Modes

### Mode 1: SHM (Zero-Copy Local)

```
Characteristics:
- No encryption (memory already protected)
- mlock() to prevent swapping to disk
- mmap() for zero-copy access
- Bandwidth: RAM speed (10-100 GB/s)
- Latency: Nanoseconds

Security:
- Unix permissions on /dev/shm file
- Cryptographic header verification on open
- Sticky permission checks on access
```

### Mode 2: Network (Encrypted Transport)

```
Encoding Stack:
Plaintext Data
     ↓
XZ Compression (redundancy elimination)
     ↓
Twofish Encryption (symmetric, fast)
     ↓
Base32 Wrapping (network-safe)
     ↓
Transmission → Remote SHM reconstruction

Keys:
- Symmetric key derived from ECDH exchange
- Pub-keys establish identity, not encrypt
```

---

## Integration with 13³ Topology

### Coordinate Mapping

```perl
# Pub-key namespace maps to spatial namespace
my $coord = pub_key_to_coordinate($pub_key_b32);
# Returns: [7, 3, 11] based on checksum

# Sub-path maps to sub-cube
my $sub_cube = path_to_subcube($data_sub_path);

# Visual.v7.ax can render:
# - SHM segments as glowing nodes at 13³ coordinates
# - Permission connections as translucent blue channels
# - Group contexts as spherical neighborhoods
```

### Real-Time Updates

```perl
# SHM change detection via mprotect()
# → SIGSEGV handler → re-render node
# → 13³ coordinate determines visual priority
# → Interference phase determines update batching

sub shm_change_handler {
    my ($shm_id, $offset, $length) = @_;

    my $coord = shm_id_to_coordinate($shm_id);
    my $phase = coordinate_to_phase($coord);

    # Priority based on temporal phase
    queue_visual_update($coord, $phase, 'high');
}
```

---

## Implementation Modules (Planned)

### Core Modules

| Module | Purpose |
|--------|---------|
| `data.mount.shm.create` | Create SHM segment with crypto header |
| `data.mount.shm.open` | Open and verify access |
| `data.mount.shm.permission.add` | Add sticky permission |
| `data.mount.shm.permission.verify` | Verify requester access |
| `data.mount.shm.delegate` | Delegate branch to sub-agent |
| `data.mount.shm.group.create` | Create threshold group |

### Encryption Modules (Network Mode)

| Module | Purpose |
|--------|---------|
| `data.transport.encode.xz_twofish_b32` | XZ + Twofish + Base32 |
| `data.transport.decode.xz_twofish_b32` | Reverse encoding |
| `data.transport.key.derive` | ECDH key exchange |

### Locking Modules

| Module | Purpose |
|--------|---------|
| `data.mount.shm.lock.memory` | mlock() against swap |
| `data.mount.shm.lock.read` | Shared read lock |
| `data.mount.shm.lock.write` | Exclusive write lock |

---

## Reference: Existing Code

### plugin.auth.auth-keypair*

Located in: `modules/plugin.auth.auth-keypair*`

May contain useful patterns for:
- Ed25519 signing/verification
- Key generation and handling
- Challenge-response protocols

Review these modules before implementing signature verification.

---

## Security Considerations

### SHM Security

```
┌─────────────────────────────────────────────────────────────┐
│ Threat: Unauthorized access to SHM segment                  │
│ Mitigation: Unix permissions + crypto header verification   │
├─────────────────────────────────────────────────────────────┤
│ Threat: Memory swap to disk                                 │
│ Mitigation: mlock() all pages on creation                   │
├─────────────────────────────────────────────────────────────┤
│ Threat: Stale permissions                                   │
│ Mitigation: Time-based expiry, re-verify on access          │
├─────────────────────────────────────────────────────────────┤
│ Threat: Group member compromise                             │
│ Mitigation: Threshold signatures (5-of-7, etc.)             │
├─────────────────────────────────────────────────────────────┤
│ Threat: Network eavesdropping                               │
│ Mitigation: XZ+Twofish+Base32 for transport                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance Targets

| Metric | Target | Current (filesystem) |
|--------|--------|----------------------|
| Read latency | <100 ns | ~5 ms |
| Write latency | <500 ns | ~10 ms |
| Bandwidth | 10 GB/s | ~100 MB/s |
| Concurrent readers | 1000+ | ~50 |
| Update propagation | <1 ms | ~100 ms |

---

## Implementation Roadmap

### Phase 1: Core SHM (Immediate)
- [ ] `data.mount.shm.create` with crypto headers
- [ ] `data.mount.shm.open` with permission verification
- [ ] `data.mount.shm.lock.memory` for swap prevention
- [ ] Integration with `data.topology.interference.map`

### Phase 2: Permissions (Next)
- [ ] Sticky permission structure
- [ ] Delegation chains
- [ ] Group threshold signatures
- [ ] Time-based auto-revocation

### Phase 3: Network Transport (Later)
- [ ] XZ compression wrapper
- [ ] Twofish encryption
- [ ] Base32 encoding
- [ ] ECDH key exchange

### Phase 4: Visualization Integration (Final)
- [ ] SHM change detection
- [ ] Real-time visual updates
- [ ] 13³ coordinate mapping
- [ ] Bandwidth optimization

---

## Quick Reference

### Creating a Mount

```perl
# Zenka creates its own namespace
my $pub_key_b32 = 'ABCD1234...YZ';
my $shm_path = "/dev/shm/p7:M:$pub_key_b32";

my $mount = <[data.mount.shm.create]>->(
    $pub_key_b32,      # Owner identity
    63_000,            # Segment size (63K convergence)
    { 'mlock' => 1 }   # Lock against swap
);

# Returns:
# {
#   'path'     => '/dev/shm/p7:M:ABCD1234...YZ',
#   'mmap_ptr' => \$memory,
#   'header'   => \%crypto_header,
# }
```

### Granting Access

```perl
# Allow another zenka to read
<[data.mount.shm.permission.add]>->(
    $shm_segment,
    {
        'to'      => $other_zenka_pub_key,
        'branch'  => 'data.visual.*',
        'rights'  => ['read'],
        'expiry'  => 3600,  # 1 hour
    },
    $owner_priv_key  # Signature
);
```

### Opening Remote

```perl
# Access another zenka's data
my $data = <[data.mount.shm.open]>->(
    "/dev/shm/p7:M:$owner_pub_key:data.visual.config",
    { 'mode' => 'read' },
    $my_priv_key  # Prove my identity
);
```

---

*"Zero transport. Maximum bandwidth. Cryptographic truth."*

🖖⚡🔮

#,,..,...,.,,,,..,.,,,.,.,..,,,..,,..,..,,,,.,..,,...,...,...,...,,,,,,,.,,,.,
#2S6HBKOTMKLUKDBXUWOYM4M6TXGNDVOF2VNTEUAKNW6PC2OBPLVFOB3QOHCJLPA72ESVPPGAFFO5C
#\\\|ZIXYPIS6OZFJUAOIFFWVPBWVD4SZEZZEMYX32P4YQTB5T7E4XIO \ / AMOS7 \ YOURUM ::
#\[7]VWNQIJADB5I2HQ3742PKM43W7RNT6BXB4B5IKR455YHRY4Z73QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
