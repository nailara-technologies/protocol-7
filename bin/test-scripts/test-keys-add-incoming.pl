#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## keys.console.add-incoming : write incoming/<username>.public for a      ##
## not-yet-seen user [ literal base32 key, key file or stdin ], optionally ##
## authorizing it for a zenka via the shared keys.authorize_link helper.   ##
## also covers the ownership logic of keys.owned_dir \ keys.console.       ##
## authorize [ refactored onto the same helpers ]. the REAL modules are    ##
## compiled [ runtime pragmas ] ; key_vars \ file.slurp are stubbed onto   ##
## File::Temp directories. no zenka, no real key registry touched.         ##

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

## --- tempdir : incoming + authorized dirs ##
## --------------------------------         ##
my $tmp           = tempdir( CLEANUP => 1 );
my $remote_dir    = catfile( $tmp, qw| remote-keys | );
my $incoming_dir  = catfile( $tmp, qw| remote-keys incoming  | );
my $auth_base_dir = catfile( $tmp, qw| remote-keys authorized | );

## remote-keys/ is deliberately NOT created here : add-incoming must create ##
## it itself [ mode 0750, owned by the key user ]                           ##

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

## the key user is the invoking user [ tests run unprivileged ] ##
my $test_uid = $UID + 0;
my $test_gid = ( $GID =~ m|^(\d+)| )[0] + 0;

$code{'crypt.C25519.key_vars'} = sub {
    return {
        incoming_dir => $incoming_dir,
        auth_dir     => $auth_base_dir,
        uid          => $test_uid,
        gid          => $test_gid,
    };
};

compile_module(qw| keys.root_registry_note |);
compile_module(qw| keys.owned_dir |);
compile_module(qw| keys.authorize_link |);
compile_module(qw| keys.console.authorize |);
compile_module(qw| keys.console.add-incoming |);

## --- helpers ------------------------------------------------------------ ##
my $key_A = encode_b32r( chr(0x41) x 32 );
my $key_B = encode_b32r( chr(0x42) x 32 );
my $key_C = encode_b32r( chr(0x43) x 32 );

sub pin_path {
    my ($username) = @ARG;
    return catfile( $incoming_dir, "$username.public" );
}

sub slurp_pin {
    my ($path) = @ARG;
    open( my $fh, '<', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    my $c = readline($fh);
    close($fh);
    return $c;
}

## runs a console command with captured stdout/stdin, converting base.exit ##
## into a code ; $stdin undef keeps the test's own stdin                   ##
sub run_cmd {
    my ( $module, $arg, $stdin ) = @ARG;
    my $stdout = '';
    local *STDOUT;
    open( STDOUT, '>', \$stdout ) or die;
    my $ok_eval;
    my $err = do {
        if ( defined $stdin ) {
            local *STDIN;
            open( STDIN, '<', \$stdin ) or die;
            $ok_eval = eval { $code{$module}->($arg); 1 };
        } else {
            $ok_eval = eval { $code{$module}->($arg); 1 };
        }
        $EVAL_ERROR;
    };
    return { 'out' => $stdout, 'code' => $ok_eval ? undef : $err };
}

## scalar context wrapper : a bare match in a comma list flattens away !   ##
sub exit_code {
    my ($result) = @ARG;
    my $code_str = $result->{'code'} // '';
    my $match    = $code_str =~ m|^EXIT:(\d+)|;
    return $match ? $1 : undef;
}

sub file_uid_gid {
    my ($path) = @ARG;
    my @stat = CORE::stat($path);
    return @stat ? ( $stat[4], $stat[5] ) : ();
}

sub path_mode {
    my ($path) = @ARG;
    my @stat = CORE::stat($path);
    return @stat ? ( $stat[2] & 07777 ) : undef;
}

say ':: keys.console.add-incoming';

## --- valid key string : file created with content, mode, ownership ##
## -------                                                           ##
my $result    = run_cmd( 'keys.console.add-incoming', "alice $key_A" );
my $succeeded = not defined $result->{'code'};
ok( $succeeded, 'key string : command succeeded' );
ok( $result->{'out'} =~ m|added incoming key for 'alice'|,
    '  :.. result line printed' );
my $alice_pin = pin_path('alice');
ok( -f $alice_pin,                          '  :.. pin file exists' );
ok( slurp_pin($alice_pin) eq $key_A . "\n", '  :.. pin holds the key' );
ok( path_mode($alice_pin) == 0640,          '  :.. pin mode 0640' );

if ( $UID != 0 ) {
    my ( $uid, $gid ) = file_uid_gid($alice_pin);
    ok( $uid == $test_uid && $gid == $test_gid,
        '  :.. pin owned by the test user'
    );
}
ok( path_mode($incoming_dir) == 0700, '  :.. incoming/ mode 0700' );
ok( path_mode($remote_dir) == 0750,   '  :.. remote-keys/ mode 0750' );
{
    my ( $uid, $gid ) = file_uid_gid($incoming_dir);
    ok( $uid == $test_uid && $gid == $test_gid,
        '  :.. incoming/ owned by the test user'
    );
}

## --- key from file                                        ##
## -------------------------------------------------------- ##
my $key_file = catfile( $tmp, 'taeki.base.public' );
{
    open( my $fh, '>', $key_file ) or die;
    print {$fh} "$key_B\n";
    close($fh);
}
$result    = run_cmd( 'keys.console.add-incoming', "bob $key_file" );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'key file : command succeeded' );
ok( slurp_pin( pin_path('bob') ) eq $key_B . "\n",
    '  :.. pin holds the file content' );

## --- key from stdin                                      ##
## ------------------------------------------------------- ##
$result    = run_cmd( 'keys.console.add-incoming', "carol -", "$key_C\n" );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'stdin : command succeeded' );
ok( slurp_pin( pin_path('carol') ) eq $key_C . "\n",
    '  :.. pin holds the stdin content' );

## --- refusals : argument format              ##
## ------------------------------------------- ##
$result = run_cmd( 'keys.console.add-incoming', undef );
ok( exit_code($result) eq '0110', 'no arg : refused 0110' );
$result = run_cmd( 'keys.console.add-incoming', '' );
ok( exit_code($result) eq '0110', 'empty arg : refused 0110' );
$result = run_cmd( 'keys.console.add-incoming', 'alice' );
ok( exit_code($result) eq '0110', 'missing key : refused 0110' );
$result = run_cmd( 'keys.console.add-incoming', "al/ice $key_A" );
ok( exit_code($result) eq '0113', "'/' in username : refused 0113" );
$result = run_cmd( 'keys.console.add-incoming', "al:ice $key_A" );
ok( exit_code($result) eq '0113', 'username with colon : refused 0113' );
$result = run_cmd( 'keys.console.add-incoming', "alice $key_A cu/be" );
ok( exit_code($result) eq '0113', "'/' in zenka : refused 0113" );

## --- refusals : invalid key                       ##
## ------------------------------------------------ ##
$result = run_cmd( 'keys.console.add-incoming', 'dave !!!not-b32!!!' );
my $refused   = exit_code($result) eq '0010';
my $reason_ok = $result->{'out'} =~ m|not a valid base32|;
ok( $refused && $reason_ok, 'not base32 : refused 0010' );
ok( !-e pin_path('dave'),   '  :.. no pin created' );
my $short_b32 = encode_b32r( chr(0x44) x 16 );
$result = run_cmd( 'keys.console.add-incoming', "dave $short_b32" );
ok( exit_code($result) eq '0010', 'wrong length : refused 0010' );
ok( !-e pin_path('dave'),         '  :.. no pin created' );

## --- idempotent : same key twice            ##
## ------------------------------------------ ##
$result    = run_cmd( 'keys.console.add-incoming', "alice $key_A" );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'same key twice : succeeded [ idempotent ]' );
ok( $result->{'out'} =~ m|already present|,
    '  :.. reported as already present'
);
ok( slurp_pin($alice_pin) eq $key_A . "\n", '  :.. pin content unchanged' );

## --- refusal : different key, pin untouched ##
## --------------------------------           ##
$result  = run_cmd( 'keys.console.add-incoming', "alice $key_B" );
$refused = exit_code($result) eq '0010';
ok( $refused, 'different key : refused 0010' );
$reason_ok = $result->{'out'} =~ m|re-pin|;
ok( $reason_ok, '  :.. points at p7-keys re-pin' );
ok( slurp_pin($alice_pin) eq $key_A . "\n", '  :.. pin content unchanged' );

## --- with <zenka> : link created, pointing at the incoming file ##
## ------------                                                   ##
$result    = run_cmd( 'keys.console.add-incoming', "erin $key_A cube" );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'with zenka : command succeeded' );
ok( $result->{'out'} =~ m|authorized 'erin' for 'cube'|,
    '  :.. authorization reported' );
my $erin_link = catfile( $auth_base_dir, qw| cube erin.public | );
ok( -l $erin_link, '  :.. authorized symlink exists' );
ok( readlink($erin_link) eq pin_path('erin'),
    '  :.. symlink points at the incoming pin'
);
ok( slurp_pin($erin_link) eq $key_A . "\n",
    '  :.. resolves to the added key'
);
ok( path_mode( catfile( $auth_base_dir, 'cube' ) ) == 0700,
    '  :.. authorized/<zenka>/ mode 0700' );
ok( path_mode($auth_base_dir) == 0700, '  :.. authorized/ mode 0700' );
{
    my ( $uid, $gid ) = file_uid_gid($erin_link);
    ok( $uid == $test_uid && $gid == $test_gid,
        '  :.. authorized tree owned by the test user'
    ) if $UID != 0;
}

## repeated add-incoming with <zenka> : same pin already linked = success ##
$result    = run_cmd( 'keys.console.add-incoming', "erin $key_A cube" );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'with zenka repeated : command succeeded' );
ok( readlink($erin_link) eq pin_path('erin'), '  :.. link unchanged' );

## --- keys.console.authorize : refactored, still functional ##
## ------------------                                        ##
$result    = run_cmd( 'keys.console.authorize', 'cube:bob' );
$succeeded = not defined $result->{'code'};
ok( $succeeded, 'authorize : command succeeded' );
my $bob_link = catfile( $auth_base_dir, qw| cube bob.public | );
ok( -l $bob_link && readlink($bob_link) eq pin_path('bob'),
    '  :.. link created via the shared helper'
);

## authorize refusal : nothing pending ##
$result  = run_cmd( 'keys.console.authorize', 'cube:nobody' );
$refused = exit_code($result) eq '0010';
ok( $refused && $result->{'out'} =~ m|nothing to authorize|,
    '  :.. unknown user refused [ nothing to authorize ]'
);

## authorize refusal : already authorized ##
$result  = run_cmd( 'keys.console.authorize', 'cube:bob' );
$refused = exit_code($result) eq '0010';
ok( $refused && $result->{'out'} =~ m|already authorized|,
    '  :.. already-authorized refused' );

## --- ownership : keys.owned_dir unit checks [ stubbed uid\gid ]          ##
## ------------- an existing directory owned by someone else : as non-root ##
## the helper must refuse, naming the directory and its owner              ##
## [ cannot chown unprivileged ]                                           ##
if ( $UID != 0 ) {
    $code{'crypt.C25519.key_vars'} = sub {
        return {
            incoming_dir => $incoming_dir,
            auth_dir     => $auth_base_dir,
            uid          => 0,
            gid          => 0,
        };
    };
    my $stdout = '';
    {
        local *STDOUT;
        open( STDOUT, '>', \$stdout ) or die;
        my $ok_dir
            = eval { $code{'keys.owned_dir'}->( $incoming_dir, 0700, 0, 0 ); };
        ok( !$ok_dir, 'owned_dir : mismatched owner refused as non-root' );
    }
    my $names_dir = $stdout =~ m|\Q$incoming_dir\E|
        && $stdout =~ m|owned by|;
    ok( $names_dir, '  :.. error names the directory and its owner' );

    ## an already-authorized user still gets the ownership walk         ##
    ## [ a repeated call is how a root-made tree gets repaired ] -- the ##
    ## walk runs before the already-authorized answer                   ##
    $result = run_cmd( 'keys.console.authorize', 'cube:bob' );
    ok( $result->{'out'} =~ m|owned by|
            && $result->{'out'} !~ m|already authorized|,
        'already authorized : ownership walked first'
    );

    ## a root-created directory is fixed when the helper runs as root --   ##
    ## the fix path itself needs root ; verified here only for the refusal ##
    ## side                                                                ##
    $code{'crypt.C25519.key_vars'} = sub {
        return {
            incoming_dir => $incoming_dir,
            auth_dir     => $auth_base_dir,
            uid          => $test_uid,
            gid          => $test_gid,
        };
    };
    $stdout = '';
    {
        local *STDOUT;
        open( STDOUT, '>', \$stdout ) or die;
        my $ok_dir = eval {
            $code{'keys.owned_dir'}->(
                catfile( $tmp, qw| remote-keys incoming | ),
                0700, $test_uid, $test_gid
            );
        };
        ok( $ok_dir, 'owned_dir : matching owner accepted without changes' );
    }
    ok( $stdout !~ m|fixed ownership|, '  :.. no fix warning when owner ok' );

    ## the owner decides : a group set on purpose [ protocol-7:<admin> ] is ##
    ## accepted as it is and never rewritten                                ##
    my ($other_gid) = grep { $ARG != $test_gid } split ' ', $GID;
    if ( defined $other_gid ) {
        my $group_dir = catfile( $tmp, qw| group-kept | );
        mkdir $group_dir, 0750 or die;
        chown -1, $other_gid, $group_dir or die;
        $stdout = '';
        my $ok_dir;
        {
            local *STDOUT;
            open( STDOUT, '>', \$stdout ) or die;
            $ok_dir = eval {
                $code{'keys.owned_dir'}
                    ->( $group_dir, 0700, $test_uid, $test_gid );
            };
        }
        ok( $ok_dir, 'owned_dir : own dir with another group accepted' );
        ok( ( file_uid_gid($group_dir) )[1] == $other_gid,
            '  :.. its group is kept' );
    } else {
        say ':: skip : no supplementary group for the group-kept check';
    }
}

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,..,,.,,,,,,,.,,.,.,..,,,,.,,,.,..,,,,,,.,.,...,...,.,.,.,,,,,.,...,...,
#K33ZDGVL5JAMCUT5VIEUKCZZ3U2TCG3AHH6VOFO6HHWE7D6T5EB6IIZQF7YTIVYP6CC33RKZB4RZM
#\\\|P64Z2ZTBRFHFNFMT5NOHLCKSR2CRFYPSQPOIPUBTTDIDEWPWS65 \ / AMOS7 \ YOURUM ::
#\[7]Y3H3JEHTBPBIAXQEN3TJJNQ5Z3MKELKVJNLOCOAOP4VMIYLLSEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
