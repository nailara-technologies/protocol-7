## [:< ##

# name  = task: keyring namespace key derivation — phase 1
# descr = implement the key derivation chain that makes the dot-separated
#         namespace a C25519 key tree. parent key + path component →
#         child key, deterministic and one-way. lazy registry with
#         session-scoped cache. sign and verify operations.

## context

every namespace path in protocol-7 is already a key derivation path.
`base.net.connect` means: derive K_base, then derive K_base_net,
then derive K_base_net_connect — each step one-way from parent.

design doc: `data/md/design/KEY-TREE-AUTHORITY-FIELD.md`
reasoning template: `data/yaml/reasoning-templates/key-tree-authority-field.yaml`

existing codebase: `modules/crypt.C25519.*` — Curve25519 operations already
present. this task adds HKDF-based namespace key derivation on top.

## phase 1 scope

```
keyring.derive          derive and cache key for a namespace path
keyring.sign            sign a datum with the key at a given path
keyring.verify          verify a signature against a path's key
keyring.distance        resonance distance between two namespace paths
keyring.cmd.show        show key metadata for a namespace path (no raw key output)
keyring.cmd.distance    compute and display distance between two paths
```

**not in phase 1**: authorization check, attractor/antenna field,
visual proximity integration, ring routing integration.

## key derivation specification

### HKDF-SHA256 for child derivation

```perl
use Crypt::Mac::HMAC;   # or equivalent in codebase

sub derive_child_key {
    my ( $parent_key_bytes, $path_component ) = @_;

    # HKDF-Expand: PRK = parent_key, info = path_component
    # L = 32 bytes output (256-bit child key)
    my $child = hkdf_expand(
        prk  => $parent_key_bytes,
        info => $path_component,
        len  => 32,
    );
    return $child;
}
```

### full path derivation

```perl
sub derive_path_key {
    my ( $root_key, $dot_path ) = @_;
    my $current = $root_key;
    for my $component ( split /\./, $dot_path ) {
        $current = derive_child_key( $current, $component );
    }
    return $current;
}
```

the derivation is composable: deriving `base.net.connect` from root gives
the same result as deriving `connect` from the already-derived `base.net` key.

## data tree layout

```
$data{keyring}{namespace}{<dot-path>}{key}       = <32 bytes>
$data{keyring}{namespace}{<dot-path>}{depth}     = <integer>
$data{keyring}{namespace}{<dot-path>}{derived_at} = <ntime>

$data{keyring}{root}{key}    = <root key bytes — loaded from keys store>
$data{keyring}{root}{loaded} = TRUE/FALSE
```

## modules

### `keyring.init`

load root key from the session owner's key material (crypt.C25519 or
equivalent). populate `$data{keyring}{root}`. called from zenka init.

### `keyring.derive`

```
( $dot_path ) → derived key bytes (32 bytes)
```

checks `$data{keyring}{namespace}{$dot_path}{key}` — if cached, return it.
otherwise: split path, derive chain from root, cache each intermediate,
return leaf key. never exposes key material in return value for cmd callers
(only for internal use).

### `keyring.sign`

```
( $dot_path, $datum ) → signature bytes
```

derives key for path, signs `$datum` using that key.
signature format: HMAC-SHA256(key=K_path, data=$datum).
returns 32-byte signature.

### `keyring.verify`

```
( $dot_path, $datum, $signature ) → TRUE/FALSE
```

derives key for path, verifies HMAC-SHA256 signature.
returns TRUE if signature matches, FALSE otherwise.

### `keyring.distance`

```
( $path_A, $path_B ) → integer
```

computes lowest common ancestor depth, returns combined distance:

```perl
sub path_distance {
    my ( $path_a, $path_b ) = @_;
    my @a = split /\./, $path_a;
    my @b = split /\./, $path_b;
    my $common = 0;
    $common++ while @a && @b && $a[$common] eq $b[$common];
    return ( scalar @a - $common ) + ( scalar @b - $common );
}
```

distance 0 = same path, distance 1 = parent/child or sibling,
higher = less related.

### `keyring.cmd.show`

```
( $dot_path ) → SIZE reply
```

shows: path, depth, derived_at timestamp, distance from session root.
does NOT show raw key bytes. safe for whitelisted access.

### `keyring.cmd.distance`

```
( $path_a $path_b ) → SIZE reply
```

shows distance between two paths + their common ancestor path.

## start config integration

add to a keyring zenka start config (or load into an existing zenka):

```
modules.load = keyring.init keyring.derive keyring.sign keyring.verify
               keyring.distance keyring.cmd.show keyring.cmd.distance
[keyring.init]
```

or load as a library into cube / base zenka for network-wide availability.

## validation

```bash
# after init:
p7c keyring.show base.net.connect
# → path: base.net.connect, depth: 3, derived_at: <ntime>

p7c keyring.distance base.net.connect base.net.listen
# → distance: 2 (siblings under base.net)

p7c keyring.distance base.net.connect httpd.request
# → distance: 4 (no common ancestor below root)

p7c keyring.distance base.net.connect base.net.connect
# → distance: 0 (same path)
```

internal validation (unit test):
```perl
# sign + verify round trip
my $sig = keyring_sign( 'base.net.connect', 'test datum' );
die unless keyring_verify( 'base.net.connect', 'test datum', $sig );
die if     keyring_verify( 'base.net.connect', 'wrong datum', $sig );

# child derivation is path-composable
my $k1 = derive_path_key( $root, 'base.net.connect' );
my $k2 = derive_child_key( derive_path_key( $root, 'base.net' ), 'connect' );
die unless $k1 eq $k2;
```

## dispatch prompt

implement phase 1 of the keyring namespace key derivation system.
read `data/md/design/KEY-TREE-AUTHORITY-FIELD.md` for full context first.

create:
- `modules/keyring.init`
- `modules/keyring.derive`
- `modules/keyring.sign`
- `modules/keyring.verify`
- `modules/keyring.distance`
- `modules/keyring.cmd.show`
- `modules/keyring.cmd.distance`

use HMAC-SHA256 as the derivation and signing primitive (available via
`Crypt::Mac::HMAC` or equivalent — check what's already used in
`modules/crypt.C25519.*` and the AMOS7 module for hash/HMAC primitives).

verify the path-composability property and sign/verify round-trip
before marking complete.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,,,,,.,,,.,.,,,.,,,..,,,.,,,..,..,,,,,,...,..,,...,...,.,,,...,,.,,,..,...,
#J4Z6AJD5XE4P3H6JVIEJWOQXSQKEA5UMIBM7ONI6YOUB7ITCT3CY337T4TQD7BKD5ZZHHVXCSTYT4
#\\\|MJLSE54B2ELDS7EDOQCFM46QHLZXBFYSZ6PGPGIQJ2FBHZZYIYI \ / AMOS7 \ YOURUM ::
#\[7]5BL2YGV3QKM437GLXXEEVK7LGK54TL7NHJBUUP52MYQNL6DBX4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
