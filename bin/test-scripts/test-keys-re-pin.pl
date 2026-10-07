#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## keys.console.re-pin : replace the TOFU pin of an already authorized      ##
## remote client key [ incoming/<user>.public ] with a new key, keeping the ##
## old pin as incoming/<user>.public.<time>.bak. the REAL module is         ##
## compiled [ runtime pragmas ] ; key_vars \ key_path \ file.slurp are      ##
## stubbed onto File::Temp directories. no zenka.                           ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use File::Temp            qw| tempdir |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Misc               qw| encode_b32r |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $test_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## no bytes : the harness's own 'use bytes' must not leak into the modules  ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

## $prefix : source prepended inside the compiled sub [ the .cmd. header ] ##
sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- tempdir : incoming + authorized + user-keys dirs ------------------- ##
my $tmp           = tempdir( CLEANUP => 1 );
my $incoming_dir  = catfile( $tmp, qw| remote-keys incoming  | );
my $auth_base_dir = catfile( $tmp, qw| remote-keys authorized | );
my $key_dir       = catfile( $tmp, qw| user-keys | );

mkdir catfile( $tmp, qw| remote-keys | ) or die;
mkdir $incoming_dir                      or die;
mkdir $auth_base_dir                     or die;
mkdir $key_dir                           or die;

my @logged;
$code{'base.logs'}       = sub { push @logged, [@ARG]; return };
$code{'base.log'}        = sub { push @logged, [@ARG]; return };
$code{'base.str.os_err'} = sub { return "$OS_ERROR" };
$code{'base.exit'}       = sub { die sprintf "EXIT:%s\n", join '', @ARG };
$code{'file.slurp'}      = sub {
    open( my $fh, '<', $ARG[0] ) or return \undef;
    local $INPUT_RECORD_SEPARATOR;
    my $c = readline($fh);
    close($fh);
    return \$c;
};
$code{'crypt.C25519.key_vars'} = sub {
    return {
        incoming_dir => $incoming_dir,
        auth_dir     => $auth_base_dir,
    };
};
## like the real resolver : the only option is holder => root ##
$code{'crypt.C25519.key_path'} = sub {
    return undef if defined $ARG[1];
    my $base = catfile( $key_dir, $ARG[0] );
    return {
        key_dir      => $key_dir,
        key_basepath => $base,
        key_filename => { map { $ARG => "$base.$ARG" } qw| secret public | },
        holder       => 'user',
    };
};

compile_module(qw| keys.console.re-pin |);

## --- helpers ------------------------------------------------------------ ##
my $key_A = encode_b32r( chr(0x41) x 32 );
my $key_B = encode_b32r( chr(0x42) x 32 );
my $key_C = encode_b32r( chr(0x43) x 32 );

sub put_pin {
    my ( $username, $b32 ) = @ARG;
    my $pin_file = catfile( $incoming_dir, "$username.public" );
    open( my $fh, '>', $pin_file ) or die;
    print {$fh} $b32, "\n";
    close($fh);
    return $pin_file;
}

sub put_local_key {
    my ( $name, $b32 ) = @ARG;
    my $path = catfile( $key_dir, "$name.public" );
    open( my $fh, '>', $path ) or die;
    print {$fh} $b32, "\n";
    close($fh);
    return;
}

sub authorize {
    my ( $zenka, $username, $target ) = @ARG;
    my $zenka_dir = catfile( $auth_base_dir, $zenka );
    mkdir $zenka_dir if not -d $zenka_dir;
    my $link = catfile( $zenka_dir, "$username.public" );
    symlink( $target, $link ) or die;
    return $link;
}

sub slurp_pin {
    my ($path) = @ARG;
    open( my $fh, '<', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    my $c = readline($fh);
    close($fh);
    return $c;
}

## runs the command with captured stdout, converting base.exit into a code ##
sub run_cmd {
    my ($arg) = @ARG;
    my $stdout = '';
    local *STDOUT;
    open( STDOUT, '>', \$stdout ) or die;
    my $ok  = eval { $code{'keys.console.re-pin'}->($arg); 1 };
    my $err = $EVAL_ERROR;
    return { 'out' => $stdout, 'code' => $ok ? undef : $err };
}

## scalar context wrapper : a bare match in a comma list flattens away !   ##
sub exit_code {
    my ($result) = @ARG;
    my $code_str = $result->{'code'} // '';
    my $match    = $code_str =~ m|^EXIT:(\d+)|;
    return $match ? $1 : undef;
}

say ':: keys.console.re-pin';

## --- the authorized identity 'cube:taeki' with pin key A ---------------- ##
my $pin_file  = put_pin( 'taeki', $key_A );
my $auth_link = authorize( 'cube', 'taeki', $pin_file );

## success : literal b32 input ##
my $result    = run_cmd("cube:taeki $key_B");
my $succeeded = not defined $result->{'code'};
ok( $succeeded, 'literal b32 : command succeeded' );
my $printed = $result->{'out'} =~ m|re-pinned 'cube:taeki'|;
ok( $printed,                              '  :.. result line printed' );
ok( slurp_pin($pin_file) eq $key_B . "\n", '  :.. pin replaced' );
my $pin_mode_ok = ( ( CORE::stat($pin_file) )[2] & 07777 ) == 0640;
ok( $pin_mode_ok, '  :.. new pin mode 0640' );
my $link_ok = readlink($auth_link) eq $pin_file
    && slurp_pin($auth_link) eq $key_B . "\n";
ok( $link_ok, '  :.. authorized symlink resolves to the new key' );
my ($bak_file) = glob catfile( $incoming_dir, 'taeki.public.*.bak' );
my $bak_ok
    = defined $bak_file
    && $bak_file =~ m|taeki\.public\.\d+\.bak$|
    && slurp_pin($bak_file) eq $key_A . "\n";
ok( $bak_ok, '  :.. .bak holds the old pin content' );

## success : local key name input [.bak name is unix-time based] ##
sleep 1;
put_local_key( 'lain.base', $key_C );
$result    = run_cmd('cube:taeki lain.base');
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'local key name : command succeeded' );
ok( slurp_pin($pin_file) eq $key_C . "\n", '  :.. pin replaced' );
my @baks = glob catfile( $incoming_dir, 'taeki.public.*.bak' );
ok( 2 == scalar @baks, '  :.. a second .bak kept' );

## refusal : same key already pinned ##
$result = run_cmd('cube:taeki lain.base');
my $refused   = exit_code($result) eq '0010';
my $reason_ok = $result->{'out'} =~ m|already pinned|;
ok( $refused && $reason_ok, 'same key : refused [ already pinned ]' );
$result = run_cmd("cube:taeki $key_C");
ok( exit_code($result) eq '0010', '  :.. literal form refused too' );

## refusals : argument format ##
$result = run_cmd(undef);
ok( exit_code($result) eq '0110', 'no arg : refused 0110' );
$result = run_cmd('');
ok( exit_code($result) eq '0110', 'empty arg : refused 0110' );
$result = run_cmd('cube:taeki');
ok( exit_code($result) eq '0110', 'missing key : refused 0110' );
$result = run_cmd( 'cubetaeki ' . $key_B );
ok( exit_code($result) eq '0113', 'bad <zenka>:<username> format : 0113' );
$result = run_cmd( 'cu/be:taeki ' . $key_B );
ok( exit_code($result) eq '0113', "'/' in zenka : refused 0113" );
$result = run_cmd("cube:tai/ki $key_B");
ok( exit_code($result) eq '0113', "'/' in username : refused 0113" );

## refusal : not authorized [ no authorized symlink ] ##
my $no_link = !-e catfile( $auth_base_dir, 'cube', 'nouser.public' );
ok( $no_link, 'not-authorized : no symlink present' );
$result    = run_cmd("cube:nouser $key_B");
$refused   = exit_code($result) eq '0010';
$reason_ok = $result->{'out'} =~ m|not authorized|;
ok( $refused && $reason_ok, '  :.. refused 0010' );
$no_link = !-e catfile( $incoming_dir, 'nouser.public' );
ok( $no_link, '  :.. no pin created for the new name' );

## authorized entry linking straight to a key file [ test-auth-keypair ] ##
my $other_pin  = put_pin( 'other', $key_A );
my $stray_file = catfile( $tmp, 'stray.public' );
open( my $sfh, '>', $stray_file ) or die;
print {$sfh} $key_A, "\n";
close($sfh);
my $other_link = authorize( 'cube', 'other', $stray_file );
$result = run_cmd("cube:other $key_B");
my $ok_other = !defined exit_code($result);
ok( $ok_other, 'authorized link to a key file : re-pinned' );
ok( slurp_pin($other_pin) eq $key_B . "\n",
    '  :.. the pin ' . 'holds the new key'
);
open( my $sfr, '<', $stray_file ) or die;
my $stray_now = readline($sfr);
close($sfr);
ok( $stray_now eq $key_A . "\n", '  :.. the linked key file untouched' );

## refusal : not authorized at all for a second zenka ##
$result = run_cmd("otherz:taeki $key_B");
ok( exit_code($result) eq '0010', 'unknown zenka : refused 0010' );

## refusals : invalid key ##
$result    = run_cmd('cube:taeki !!!not-b32!!!');
$refused   = exit_code($result) eq '0010';
$reason_ok = $result->{'out'} =~ m|not a valid base32|;
ok( $refused && $reason_ok, 'not base32 : refused 0010' );
my $short_b32 = encode_b32r( chr(0x44) x 16 );
$result = run_cmd("cube:taeki $short_b32");
ok( exit_code($result) eq '0010', 'wrong length : refused 0010' );
$result = run_cmd('cube:taeki no-such-local-key');
ok( exit_code($result) eq '0010', 'unresolvable name, not b32 : refused' );
ok( slurp_pin($pin_file) eq $key_C . "\n", '  :.. pin untouched' );

## refusal : backup name already exists ##
my $now = time;
foreach my $epoch ( $now, $now + 1 ) {
    my $taken = sprintf qw| %s.%d.bak |, $pin_file, $epoch;
    open( my $fh, '>', $taken ) or die;
    print {$fh} "taken\n";
    close($fh);
}
$result    = run_cmd("cube:taeki $key_B");
$refused   = exit_code($result) eq '0010';
$reason_ok = $result->{'out'} =~ m|already exists|;
ok( $refused && $reason_ok, 'existing .bak name : refused 0010' );
ok( slurp_pin($pin_file) eq $key_C . "\n", '  :.. pin untouched' );

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,.,..,,,.,.,,.,,,,..,.,.,.,..,,.,,,,,.,,..,.,,,,.,,,..,,,.,..,.,,,,.,,,,.,,,

#,,.,,.,.,,.,,..,,.,.,.,.,.,.,.,.,.,,,,.,,,,.,..,,...,...,...,,.,,.,.,,,,,,,.,
#6MVVTWL3DMNDSSWMHPOGRX7J6UG6O7AYUYI5SWA6DRCPRBU3NTEN7MPNX7TUVTZ5PBOQZRG53EMGG
#\\\|ALAYGBSKCZZR5RRIPAKBWWVJDQHHY5YUCS6CBOLKJHRIPBVJP52 \ / AMOS7 \ YOURUM ::
#\[7]RSN3AKQRJCRWGHKWQ63PJ3AGQ6TVTDU7SWCZDTNGUCGLFENT5YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
