#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use FindBin qw| $RealBin |;
use File::Spec;
use Cwd qw| abs_path |;

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
    unshift @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | );
    $main::real_c25519 = eval { require Crypt::Ed25519; 1 } ? 1 : 0;
}

use Crypt::Misc   qw| encode_b32r decode_b32r |;
use Digest::BMW   ();
use AMOS7::CHKSUM ();
use Test::More;

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

our %code;
our %data;
our %keys;
our @INDEXCUBE;
our %c25519_vectors = (
    '806b998a3efc385fdc458ce3ffaacd51d63cd31cf67b9cc4'
        . '4af1a4d32c93bfd146534f607cff6b8ece0479163ff6caf5' =>
        '4a118c605e0465c97fe9c4d95f06d8e432a5b3d2407f7d774ae47f1e798a28d001f'
        . 'e35addc9f58a8ec60e635b44e55207b7df171cc46d94ffcc3e255bd63cf06',
    'f1d4c421eccd5bfa0f0ddbc4f5a5027d1beeb3bdd487ae48'
        . 'd7cc5306342823b56cfa5dd36ef01a723dac6cbede5c2e46' =>
        '542c18c3a78e0cd38476ec150c756b8b69e73eb4c55bf09f413c6d30312927219d6'
        . '4bcacd4a810969e527497726d2c54b81573c77014672b7b14a143bb14590d',
    'ac05afc3861e3bdc63f8706eaac7f99a3d219c780eebb33c'
        . '3824fc6be9502463ace4532a9583ec36144d9f29838731ab' =>
        'c408350e635ba13400410a48f5b9c57f46f8cedda503ba090ebcb8cb325bc3d88a5'
        . 'dee397d85b13e844d62d9216bf1af45b2d33c63232dd2be57b5cbf9313f0e',
);

## the floor perl lacks the xs module ; these are fixed ed25519 vectors ##
if ( !$main::real_c25519 ) {
    diag 'using fixed ed25519 known-answer vectors';
    no strict 'refs';
    *{'Crypt::Ed25519::generate_keypair'} = sub {
        return (
            pack( 'H*',
                      'd04ab232742bb4ab3a1368bd4615e4e6'
                    . 'd0224ab71a016baf8520a332c9778737' ),
            pack( 'H*',
                '805b920bda4cd49d251d3329144a0cf8bdaaa07502626fa87f08e80faeda'
                    . 'b15f092539815e61663c7f9c4c9c377346f5d2936875bd760f0ac5'
                    . 'c5f4f6e78a6d76' )
        );
    };
    *{'Crypt::Ed25519::sign'} = sub {
        my $digest_hex = unpack 'H*', $_[0];
        my $signature  = $c25519_vectors{$digest_hex};
        die "no ed25519 vector for $digest_hex" unless defined $signature;
        return pack 'H*', $signature;
    };
    *{'Crypt::Ed25519::verify'} = sub {
        my $digest_hex = unpack 'H*', $_[0];
        my $signature  = $c25519_vectors{$digest_hex};
        return defined $signature && $_[2] eq pack( 'H*', $signature );
    };
}

my $root_path = $main::root_path;
my $clock     = 1000;
my $key_name  = 'test.indexcube';

$code{'base.ntime'}            = sub { return sprintf '%.1f', $clock += 0.1 };
$code{'base.p7ref.self'}       = sub { return 'ORIGIN:AAAAAAA:AAAAAA' };
$code{'base.logs'}             = sub { return TRUE };
$code{'base.s_warn'}           = sub { return TRUE };
$code{'crypt.C25519.key_vars'} = sub { return { 'key_name' => $key_name } };

sub translate_code {
    my $source = shift;
    $source =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $source =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $source =~ s{<([a-z][-\w.]*)>}{
        my @parts = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @parts ) . qq|'}|
    }ge;
    return $source;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    if (   $ENV{'P7_INDEXCUBE_MODULE_DIR'}
        && $name =~ m{^base\.indexcube\.(?:push|pop)$} ) {
        $path = File::Spec->catfile( $ENV{'P7_INDEXCUBE_MODULE_DIR'}, $name );
    }
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $source = <$fh>;
    close $fh;

    $source =~ s{\n#[^\n]*\z}{\n} while $source =~ m{\n#[,\[\\|:][^\n]*\z};
    my @segments
        = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $source, -1;
    for ( my $index = 0; $index < @segments; $index += 2 ) {
        $segments[$index] = translate_code( $segments[$index] );
    }
    my $translated = join '', @segments;
    my $sub        = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

for my $module (
    qw|
    base.chk-sum.amos
    base.chk-sum.bmw.384.B32
    crypt.C25519.sign_data
    crypt.C25519.verify_sign
    base.indexcube.verify
    base.indexcube.push
    base.indexcube.pop
    |
) {
    load_module($module);
}
$code{'chk-sum.amos'}        = $code{'base.chk-sum.amos'};
$code{'chk-sum.bmw.384.B32'} = $code{'base.chk-sum.bmw.384.B32'};

sub restore_key {
    my ( $public, $private )
        = Crypt::Ed25519::generate_keypair( "\x11" x 32 );
    $keys{'C25519'}{$key_name}
        = { 'public' => $public, 'private' => $private };
}

sub build_chain {
    @INDEXCUBE = ();
    $clock     = 1000;
    restore_key();
    my @results;
    for my $p7ref (
        qw| ORIGIN:AAAAAAA:AAAAAA CUBE:BBBBBBB:BBBBBB CODING:CCCCCCC:CCCCCC |)
    {
        push @results,
            $code{'base.indexcube.push'}->( { 'p7ref' => $p7ref } );
    }
    return @results;
}

sub old_checksum {
    my $entry = shift;
    return $code{'chk-sum.amos'}->(
        sprintf '%s:%d:%d',    $entry->{'p7ref'},
        $entry->{'timestamp'}, $entry->{'depth'}
    );
}

sub refusal_preserves_stack {
    my $name   = shift;
    my $before = scalar @INDEXCUBE;
    my $result = $code{'base.indexcube.pop'}->();
    is( $result->{'mode'},  'false', "$name refused" );
    is( scalar(@INDEXCUBE), $before, "$name leaves stack unchanged" );
}

my @pushed = build_chain();
ok( ( grep { $_->{'mode'} eq 'true' } @pushed ) == 3,
    'three entries pushed with the loaded key'
);
is( $INDEXCUBE[0]{'prev'}, '', 'depth zero has an empty previous signature' );
is( $INDEXCUBE[1]{'prev'},
    $INDEXCUBE[0]{'signature'},
    'second entry links to the origin signature'
);
is( $INDEXCUBE[2]{'prev'},
    $INDEXCUBE[1]{'signature'},
    'third entry links to the second signature'
);
like( $INDEXCUBE[2]{'signature'},
    qr{^[A-Z2-7]{103}=?$}, 'entry stores a base32 c25519 signature' );
is( $code{'base.indexcube.verify'}()->{'mode'},
    'true', 'valid chain accepted' );
my $valid_pop = $code{'base.indexcube.pop'}->();
is( $valid_pop->{'mode'}, 'true', 'valid pop accepted' );
is( $valid_pop->{'data'}{'p7ref'},
    'CODING:CCCCCCC:CCCCCC', 'valid pop returns the former top entry' );
is( scalar(@INDEXCUBE), 2, 'valid pop removes exactly one entry' );

build_chain();
my $forged = { %{ $INDEXCUBE[-1] }, 'p7ref' => 'FORGED:DDDDDDD:DDDDDD' };
$forged->{'signature'} = old_checksum($forged);
$INDEXCUBE[-1] = $forged;
refusal_preserves_stack('forged entry');

build_chain();
my $inserted = {
    'p7ref'     => 'INSERT:EEEEEEE:EEEEEE',
    'timestamp' => '1000.4',
    'depth'     => 1,
    'prev'      => $INDEXCUBE[0]{'signature'},
};
$inserted->{'signature'} = old_checksum($inserted);
splice @INDEXCUBE, 1, 0, $inserted;
refusal_preserves_stack('inserted entry');

build_chain();
splice @INDEXCUBE, 1, 1;
refusal_preserves_stack('removed entry');

build_chain();
@INDEXCUBE[ 1, 2 ] = @INDEXCUBE[ 2, 1 ];
refusal_preserves_stack('reordered entries');

@INDEXCUBE = ();
$clock     = 1000;
delete $keys{'C25519'}{$key_name};
my $missing_key
    = $code{'base.indexcube.push'}
    ->( { 'p7ref' => 'ORIGIN:AAAAAAA:AAAAAA' } );
is( $missing_key->{'mode'}, 'false', 'missing key refused by push' );
is( scalar(@INDEXCUBE), 0, 'missing key refusal does not append an entry' );

done_testing();

#,,,.,...,,,,,.,,,..,,..,,.,,,,.,,.,.,...,,,,,..,,...,...,,.,,.,.,,,,,,,,,...,
#4ZZPCURXBVJASYZDAYPTWPNNSV7KDLBV72YFLHHG2OU6HSKXMZQLRR7LPGOLACNNCAHMO42PVUAUC
#\\\|VRKBFGUJX3ROIHNX2UAZNVI4QVYWU6SDMGTDYKSPKIVF6AY26L2 \ / AMOS7 \ YOURUM ::
#\[7]CMNWS3TBDNEARR3ULCYQ3R66OY2GF44YL5MZ3NH4FEWQZSI2F4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
