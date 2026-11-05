#!/usr/bin/perl

use v5.24;
use strict;
use English;
use warnings;
use FindBin qw| $RealBin |;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use AMOS7::SHM qw| shm_create shm_open pack_shm_header unpack_shm_header
    header_write permission_verify sign_permission |;
use AMOS7::SHM::Page      ();
use AMOS7::SHM::Transport qw| shm_announce |;
use Crypt::Misc           qw| encode_b32r |;
use Crypt::Ed25519        ();
use Test::More;

sub fixture_seed {
    return substr( shift() . ( "\0" x 32 ), 0, 32 );
}

my $owner_seed  = fixture_seed('owner');
my $reader_seed = fixture_seed('reader');
my $wrong_seed  = fixture_seed('wrong');

sub pub_b32 {
    my $encoded = encode_b32r( AMOS7::SHM::derive_pubkey(shift) );
    $encoded =~ s{=+\z}{};
    return $encoded;
}

my $owner_b32  = pub_b32($owner_seed);
my $reader_pub = AMOS7::SHM::derive_pubkey($reader_seed);
my $wrong_b32  = pub_b32($wrong_seed);
my $sub_path   = 'grant-test';

sub new_segment {
    my $created = shift // 1000.5;
    return shm_create(
        $owner_b32,
        256,
        {   'mlock'       => 0,
            'sub_path'    => $sub_path,
            'time_source' => sub { return $created }
        }
    );
}

sub new_grant {
    my $segment = shift;
    my $perm    = {
        'to'      => $reader_pub,
        'branch'  => '*',
        'rights'  => [ 'read', 'write' ],
        'expiry'  => time() + 3600,
        'granted' => 12345,
    };
    $perm->{'sig'}
        = sign_permission( $perm, $owner_seed, $segment->{'header'},
        $segment->{'sub_path'} );
    return $perm;
}

sub verifies {
    my ( $segment, $perm ) = @_;
    return permission_verify( $segment->{'header'}, $reader_pub,
        $segment->{'sub_path'},
        ['read'], {} );
}

my $mount = new_segment();
ok( defined $mount, 'segment created with a real ed25519 owner key' );
my $valid = new_grant($mount);
$mount->{'header'}{'permissions'} = [$valid];
ok( verifies( $mount, $valid ), 'valid grant accepted' );
ok( defined header_write( $mount->{'mmap_ptr'}, $mount->{'header'} ),
    'valid grant written before open' );

my $opened = shm_open( $mount->{'path'}, { 'mode' => 'read' }, $reader_seed );
ok( defined $opened && !exists $opened->{'error'},
    'valid grant accepted through shm_open'
);

my ( $owner_public, $owner_private )
    = Crypt::Ed25519::generate_keypair($owner_seed);
my $expanded_grant = {%$valid};
$expanded_grant->{'sig'}
    = sign_permission( $expanded_grant,
    { 'private' => $owner_private, 'public' => $owner_public },
    $mount->{'header'}, $mount->{'sub_path'} );
$mount->{'header'}{'permissions'} = [$expanded_grant];
ok( verifies( $mount, $expanded_grant ),
    'expanded owner private key signs with its paired public key' );
my ( $reader_public, $reader_private )
    = Crypt::Ed25519::generate_keypair($reader_seed);
is( AMOS7::SHM::derive_pubkey(
        { 'private' => $reader_private, 'public' => $reader_public }
    ),
    $reader_pub,
    'expanded reader key pair resolves to the granted public key'
);
$mount->{'header'}{'permissions'} = [$valid];

for my $case (
    [ 'random signature refused',         '00' x 64 ],
    [ 'old hash-style signature refused', 'DEADBEEF' ],
) {
    my $tampered = { %$valid, 'sig' => $case->[1] };
    $mount->{'header'}{'permissions'} = [$tampered];
    ok( !verifies( $mount, $tampered ), $case->[0] );
}

my $missing = {%$valid};
delete $missing->{'sig'};
$mount->{'header'}{'permissions'} = [$missing];
ok( !verifies( $mount, $missing ), 'missing signature refused' );

$mount->{'header'}{'permissions'} = [$valid];
ok( !permission_verify(
        $mount->{'header'}, $reader_pub, 'another-path', ['read'], {}
    ),
    'grant copied to another sub_path refused'
);

for my $field (qw| rights expiry to branch |) {
    my $tampered = {%$valid};
    if ( $field eq 'rights' ) {
        $tampered->{'rights'} = ['admin'];
    } elsif ( $field eq 'expiry' ) {
        $tampered->{'expiry'}++;
    } elsif ( $field eq 'to' ) {
        $tampered->{'to'} = AMOS7::SHM::derive_pubkey($wrong_seed);
    } else {
        $tampered->{'branch'} = 'other';
    }
    $mount->{'header'}{'permissions'} = [$tampered];
    ok( !verifies( $mount, $tampered ), "tampered $field refused" );
}

my $wrong_grant = {%$valid};
$wrong_grant->{'sig'}
    = sign_permission( $valid, $wrong_seed, $mount->{'header'},
    $mount->{'sub_path'} );
$mount->{'header'}{'permissions'} = [$wrong_grant];
ok( !verifies( $mount, $wrong_grant ), 'wrong signer refused' );

my $original_created = $mount->{'header'}{'created'};
unlink( $mount->{'path'} );
my $recreated = new_segment( $original_created + 1 );
$recreated->{'header'}{'permissions'} = [$valid];
ok( !verifies( $recreated, $valid ),
    'grant copied into a re-created segment refused' );

$mount                             = new_segment(2000);
$valid                             = new_grant($mount);
$mount->{'header'}{'permissions'}  = [$valid];
$mount->{'header'}{'owner_pubkey'} = $wrong_b32;
ok( defined header_write( $mount->{'mmap_ptr'}, $mount->{'header'} ),
    'rewritten owner header is structurally writable' );
my $wrong_owner_open
    = shm_open( $mount->{'path'}, { 'mode' => 'read' }, $reader_seed );
ok( ref($wrong_owner_open) eq 'HASH'
        && ( $wrong_owner_open->{'error'} // '' ) eq 'ownership_mismatch',
    'header owner differing from path owner refused'
);
unlink( $mount->{'path'} );

$mount = new_segment(3000);
my @grants;
for my $index ( 1 .. AMOS7::SHM::MAX_PERMISSIONS() ) {
    my $seed  = fixture_seed( sprintf( 'reader-%02d', $index ) );
    my $grant = {
        'to'      => AMOS7::SHM::derive_pubkey($seed),
        'branch'  => '*',
        'rights'  => ['read'],
        'expiry'  => time() + 3600,
        'granted' => 3000 + $index,
    };
    $grant->{'sig'}
        = sign_permission( $grant, $owner_seed, $mount->{'header'},
        $mount->{'sub_path'} );
    push @grants, $grant;
}
$mount->{'header'}{'permissions'} = \@grants;
my $packed = pack_shm_header( $mount->{'header'} );
ok( defined $packed && length($packed) == AMOS7::SHM::SHM_HEADER_SIZE(),
    'maximum grant count fits the v2 header' );
my $unpacked = unpack_shm_header($packed);
ok( defined $unpacked
        && @{ $unpacked->{'permissions'} } == AMOS7::SHM::MAX_PERMISSIONS(),
    'all maximum-count grants survive pack and unpack'
);
ok( defined header_write( $mount->{'mmap_ptr'}, $mount->{'header'} ),
    'maximum-count header written before overflow attempt'
);

push @{ $mount->{'header'}{'permissions'} }, $grants[0];
my $before_overflow = $packed;
ok( !defined pack_shm_header( $mount->{'header'} ),
    'grant-count overflow refused' );
ok( !defined header_write( $mount->{'mmap_ptr'}, $mount->{'header'} ),
    'header_write refuses grant-count overflow' );
is( substr( ${ $mount->{'mmap_ptr'} }, 0, AMOS7::SHM::SHM_HEADER_SIZE() ),
    $before_overflow, 'overflow leaves every existing grant byte unchanged' );
pop @{ $mount->{'header'}{'permissions'} };

my $large = { %{ $grants[0] }, 'branch' => 'x' x 5000 };
$mount->{'header'}{'permissions'} = [$large];
ok( !defined pack_shm_header( $mount->{'header'} ),
    'byte-size overflow refused without dropping grants'
);
$mount->{'header'}{'permissions'} = \@grants;

my $v1_raw = $packed;
substr( $v1_raw, 5, 1 ) = '1';
ok( !defined unpack_shm_header($v1_raw), 'version 1 header refused' );
unlink( $mount->{'path'} );

my $content            = 'transport overflow';
my $transport_overflow = shm_announce(
    {   'owner_pubkey'  => $owner_b32,
        'owner_privkey' => $owner_seed,
        'reader_pubkey' => $reader_pub,
        'content_ref'   => \$content,
        'checksum'      => '1234567890123',
        'sub_path'      => 'transport-overflow',
        'rights'        => [ 'x' x 5000 ],
        'mlock'         => 0,
    }
);
ok( ref($transport_overflow) eq 'HASH'
        && ( $transport_overflow->{'error'} // '' ) eq 'header_overflow',
    'transport returns header_overflow instead of dropping a grant'
);
unlink( '/dev/shm/p7:M:' . $owner_b32 . ':transport-overflow' );

done_testing();

#,,,.,,..,.,.,,,.,,,.,,,.,,.,,,.,,.,,,.,.,,..,..,,...,..,,,,,,,,.,,,.,,.,,,.,,
#YPZQW57TFFPFGZJROXACO7KMW6ESQKO4YG3PIBPFV3ZTPKP25DYC7UI7BOW3A6NIEN5ASMF4QR6CG
#\\\|BFFV33C2EU5KWJ2TUA4VEARLU32JCNKOW4OG2AFNIZ5QWF4PL3G \ / AMOS7 \ YOURUM ::
#\[7]7CHMWVQ2MBM6OSGMI4JX4Y36TBOR6B7Y5W6BBS5ESQJTZNXX2SAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
