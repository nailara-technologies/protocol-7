#!/usr/bin/perl
use v5.32;
use strict;
use warnings;
use English;

use Cwd qw| abs_path |;
use File::Spec;
use FindBin     qw| $RealBin |;
use Time::HiRes qw| time |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | );
    $main::root_path = $root_path;
}

use AMOS7;
use AMOS7::CHKSUM;
use AMOS7::B32 qw| encode_b32r decode_b32r |;
use AMOS7::Assert::Truth;
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Ed25519            ();
use Digest::BMW               ();

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our %keys;

my $iterations = 100;
if ( @ARGV and $ARGV[0] =~ m{^--iterations=([1-9][0-9]*)$} ) {
    $iterations = 0 + $1;
    shift @ARGV;
}

$data{'source'}{'chksum_bitsize'} = 384;
$data{'chk-sum'}{'bmw'} = { map { $ARG => undef } 224, 256, 384, 512 };
$data{'source'}{'C25519'}{'signature_key_name'} = 'proto-7.sourcecode';
$data{'source'}{'sign_template'}                = <<'EOT';
#..........,..........,..........,..........,..........,..........,..........,
#_____________________________________________________________________________
#\\\|___________________________________________________ \ / AMOS7 \ YOURUM ::
#\[7]____________________________________________________ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
EOT

%code = (
    'base.log'    => sub { return TRUE },
    'base.logs'   => sub { return TRUE },
    'base.s_warn' => sub { return TRUE }
);

sub compile_module {
    my ( $module_name, $code_name ) = @ARG;
    $code_name //= $module_name;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open my $fh, '<', $src_path or die "cannot read $src_path : $OS_ERROR";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$code_name} = $cref;
}

compile_module($_) foreach qw|
    source.extract_sig_body
    source.generated_envelope
    source.signature_valid
    source.verify_and_strip
    source.restore_payload_endline_state
    amos7.decode_octal_bit_header
    base.get_homedir
    base.chk-sum.from_substr
    crypt.C25519.key_vars
    crypt.C25519.verify_sign
    |;
compile_module( 'base.chk-sum.elf.inline', 'chk-sum.elf.inline' );
compile_module( 'base.chk-sum.elf',        'chk-sum.elf' );
compile_module( 'base.chk-sum.bmw.ctx',    'chk-sum.bmw.ctx' );
compile_module( 'base.chk-sum.bmw.strsum', 'chk-sum.bmw.strsum' );
compile_module( 'base.chk-sum.bmw.encode_digest',
    'chk-sum.bmw.encode_digest' );

$keys{'C25519'}{'proto-7.sourcecode'}{'public'}
    = decode_b32r(qw| JXA7AXE6PUORNNRI2F6PEFQKZSGUL2PKIOTXIGMHDUI6GHA4YWRA |);

my @fixtures = @ARGV;
@fixtures = (
    qw| src/keyring.init_code |,
    qw| src/coding.helper.calculate_safe_context |,
    qw| data/web-root/vhosts/jobsite.vhost/index.html |
) if not @fixtures;

sub read_file {
    my $path = shift;
    open my $fh, '<', $path or die "read $path : $OS_ERROR";
    binmode $fh;
    my $content = join '', <$fh>;
    close $fh;
    return $content;
}

sub elapsed {
    my ( $operation, $count ) = @ARG;
    local $SIG{'__WARN__'} = sub { return TRUE };
    my $start = time;
    $operation->() for 1 .. $count;
    return time - $start;
}

say ": signed-file verification benchmark [ $iterations iterations ]";
for my $relative_path (@fixtures) {
    my $path    = File::Spec->rel2abs( $relative_path, $main::root_path );
    my $payload = read_file($path);
    my $input   = $payload;
    my $result  = do {
        local $SIG{'__WARN__'} = sub { return TRUE };
        $code{'source.verify_and_strip'}->( \$input );
    };
    die "$relative_path : not valid : " . ( $result->{'error'} // 'unknown' )
        if $result->{'status'} ne 'valid';

    elapsed( sub { $code{'chk-sum.bmw.strsum'}->( \$payload, 384 ) }, 3 );
    my $bmw_seconds
        = elapsed( sub { $code{'chk-sum.bmw.strsum'}->( \$payload, 384 ) },
        $iterations );
    elapsed(
        sub {
            my $copy = $payload;
            $code{'source.verify_and_strip'}->( \$copy );
        },
        3
    );
    my $verify_seconds = elapsed(
        sub {
            my $copy = $payload;
            $code{'source.verify_and_strip'}->( \$copy );
        },
        $iterations
    );

    my $size         = length $payload;
    my $bmw_us       = $bmw_seconds * 1_000_000 / $iterations;
    my $verify_us    = $verify_seconds * 1_000_000 / $iterations;
    my $bmw_mbs      = $size * $iterations / $bmw_seconds / 1_000_000;
    my $verify_mbs   = $size * $iterations / $verify_seconds / 1_000_000;
    my $verify_ratio = $verify_seconds / $bmw_seconds;
    printf ": %s\n",                               $relative_path;
    printf ":   bytes %d\n",                       $size;
    printf ":   verify %9.1f us/op  %8.2f MB/s\n", $verify_us, $verify_mbs;
    printf ":   BMW384 %9.1f us/op  %8.2f MB/s\n", $bmw_us,    $bmw_mbs;
    printf ":   verify / BMW384     %8.2f x\n",    $verify_ratio;
}

#,,..,,,.,..,,.,.,..,,,,.,,.,,,.,,.,,,...,,,,,..,,...,...,,,,,.,.,,,,,.,,,,,.,
#WMCKE5YVGHGINPQO5F3WD62PWOIW76OTTTDE4OOOEWVUX5RCG76VDSXVGYL5TIDP32AYAWL6K7J4W
#\\\|JYK2HHDHWCL4ICZI5BGIK56J7H3F4Y6OKIF7HJBNKWWSNJOS3G4 \ / AMOS7 \ YOURUM ::
#\[7]RYP46AY2AUTKKYFFWBQQ35QISMF4CVS2BS5ABESUSVJBONZDNICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
