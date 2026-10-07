#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## plugin.auth.auth-keypair.load-authorized-users REBUILDS the authorized  ##
## table on every call : a replaced key file [ client key rotation ] and a ##
## removed one [ revocation ] apply on the next call [ reinit ], an        ##
## unreadable \ missing directory authorizes nobody. the REAL loader is    ##
## compiled [ runtime pragmas ] against a File::Temp auth dir. no zenka.   ##

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

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval
        "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $tmp      = tempdir( CLEANUP => 1 );
my $auth_dir = catfile( $tmp,      'authorized' );
my $cube_dir = catfile( $auth_dir, 'cube' );
mkdir $auth_dir or die;
mkdir $cube_dir or die;

my @logged;
$code{'base.logs'}  = sub { push @logged, [@ARG]; return };
$code{'base.log'}   = sub { push @logged, [@ARG]; return };
$code{'base.ntime'} = sub { return 'NTIME' };
$code{'file.slurp'} = sub {
    open( my $fh, '<', $ARG[0] ) or return \undef;
    local $INPUT_RECORD_SEPARATOR;
    my $c = readline($fh);
    close($fh);
    return \$c;
};
$code{'crypt.C25519.key_vars'} = sub { return { auth_dir => $auth_dir } };
$data{'system'}{'zenka'}{'name'} = 'cube';

sub put_pub {
    my ( $user, $byte ) = @ARG;
    my $b32  = encode_b32r( chr($byte) x 32 );
    my $path = catfile( $cube_dir, "$user.public" );
    open( my $fh, '>', $path ) or die;
    print {$fh} "$b32\n";
    close($fh);
    return $b32;
}

my $load = compile_module('plugin.auth.auth-keypair.load-authorized-users');
my $auth = sub { $keys{'authorized-remote'} };

say ':: plugin.auth.auth-keypair.load-authorized-users';

my $alice_a = put_pub( 'alice', 0x11 );
my $bob     = put_pub( 'bob',   0x22 );
put_pub( 'skipped', 0x33 );
rename catfile( $cube_dir, 'skipped.public' ),
    catfile( $cube_dir, 'skipped.public.bak' );

ok( $load->() == 2, 'startup : 2 users loaded' );
ok( $auth->()->{'alice'}{'public_b32'} eq $alice_a
        && length( $auth->()->{'alice'}{'public'} ) == 32,
    '  :.. alice : b32 + 32 byte key'
);
ok( !exists $auth->()->{'skipped'}, '  :.. a .public.bak is not a key' );

## rotation + revocation, then the reinit call ##
my $alice_b = put_pub( 'alice', 0x44 );
unlink catfile( $cube_dir, 'bob.public' ) or die;
ok( $load->() == 1, 'reload : 1 user loaded' );
ok( $auth->()->{'alice'}{'public_b32'} eq $alice_b,
    '  :.. rotated alice : the NEW key' );
ok( !exists $auth->()->{'bob'}, '  :.. revoked bob : gone' );

## an invalid key file is skipped, the others stay ##
open( my $bad, '>', catfile( $cube_dir, 'mallory.public' ) ) or die;
print {$bad} "not-a-key\n";
close $bad;
ok( $load->() == 1 && !exists $auth->()->{'mallory'},
    'invalid key file : skipped' );

## unreadable directory : nobody authorized, logged at level 0 ##
SKIP: {
    if ( $EUID == 0 ) {
        say '  skip : running as ' . 'root [ chmod 0 readable ]';
        last SKIP;
    }
    chmod 0000, $cube_dir;
    @logged = ();
    ok( $load->() == 0 && !keys $auth->()->%*,
        'unreadable directory : nobody authorized'
    );
    ok( scalar( grep { $ARG->[0] eq '0' } @logged ),
        '  :.. logged at level 0' );
    chmod 0755, $cube_dir;
}

## missing directory : nobody authorized ##
ok( $load->() == 1, 'readable again : alice back' );
rename $cube_dir, "$cube_dir.gone" or die;
ok( $load->() == 0 && !keys $auth->()->%*,
    'missing directory : nobody authorized'
);

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,,,,.,,,,.,,..,,,,.,..,,..,,.,,,..,,,.,,..,,...,...,,,.,..,,,,.,,..,.,,,
#IRCT5ZRBWFPZYITNJGPZVVNV6CHJB4BBKU33M4PQOSXZBEXF7DUHDYKJQUFVDGHTWGU22SZSZV7SM
#\\\|CJ6C6PWBGBBYYRG3U3QH6VYRUHGTPQMSSVJQ5UVITYMZSKWF57D \ / AMOS7 \ YOURUM ::
#\[7]Z6PKCJYF5BV3E32OP7MTUWBBO5S7C35OO4Z6LBIM2WQZGEAAXMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
