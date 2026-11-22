#!/usr/bin/perl
use v5.32;
use strict;
use warnings;
use English;
use File::stat;
use User::pwent;

use Cwd qw| abs_path |;
use File::Spec;
use FindBin qw| $RealBin |;

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

my $fixture = File::Spec->catfile( $main::root_path,
    qw| src httpd.parse_range_header | );
open my $fh, '<', $fixture or die "read $fixture : $OS_ERROR";
my $signed = join '', <$fh>;
close $fh;

my $failures = 0;

my $current_user  = CORE::getpwuid($EUID);
my $expected_home = ( CORE::getpwnam($current_user) )[7];
my $resolved_home = $code{'base.get_homedir'}->($current_user);
say +(
    defined $resolved_home
        and defined $expected_home
        and $resolved_home eq $expected_home
    ? '  ok   : passwd overrides retain CORE list semantics'
    : '  FAIL : passwd overrides retain CORE list semantics'
);
$failures++
    if not defined $resolved_home
    or not defined $expected_home
    or $resolved_home ne $expected_home;

sub check {
    my ( $condition, $label ) = @ARG;
    say $condition ? "  ok   : $label" : "  FAIL : $label";
    $failures++ if not $condition;
}

my $payload = $signed;
my $result  = $code{'source.verify_and_strip'}->( \$payload );
check( $result->{'status'} eq 'valid', 'repository signature verifies' );
check(
    $result->{'report'}{'AMOS-chksum-matches'},
    'repository AMOS checksum matches'
);
check(
    $result->{'report'}{'bmw-chksum-matches'},
    'repository BMW checksum matches'
);
check(
    $result->{'report'}{'signature-is-valid'},
    'repository C25519 signature matches'
);
check(
    $result->{'report'}{'entire-payload'}{4}
        && $result->{'report'}{'entire-payload'}{7},
    'repository ELF truth checks match'
);
check(
    $result->{'body'}->$* !~ m{DATA SIGNATURE},
    'verified payload has no signature footer'
);
my $unsigned = $result->{'body'}->$*;

my $tampered = $signed;
$tampered =~ s{return undef}{return 0};
check( $tampered ne $signed, 'tamper fixture changed signed content' );
$result = $code{'source.verify_and_strip'}->( \$tampered );
check( $result->{'status'} eq 'invalid', 'tampered content is rejected' );
check( length $result->{'error'}, 'rejection identifies a failed check' );

$result = $code{'source.verify_and_strip'}->( \$unsigned );
check( $result->{'status'} eq 'unsigned',  'stripped payload is unsigned' );
check( $result->{'body'}->$* eq $unsigned, 'unsigned payload is unchanged' );

say $failures ? ": FAIL [ $failures ]" : ': all tests passed';
exit( $failures ? 1 : 0 );

#,,.,,,,,,..,,,..,..,,.,,,..,,,.,,.,,,..,,.,.,..,,...,...,..,,,.,,,,.,...,,..,
#WIPLZ3S2DLC6GOVNYKU5UYJIPNE65BZ5VTP2J4NUH3VRBNBFPP5POPTL6CT7AGRKT6MAR7WM7RVMO
#\\\|TCNMHHHRNDZLOM4KIS5R2LBZ6EYVM5TQUK7SOF3ZXXWKV2N5M4X \ / AMOS7 \ YOURUM ::
#\[7]TIKXWAKWS55E2PR5KSDZQPTDSSFTWELVQYAZN3U6UU6TUEANI6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
