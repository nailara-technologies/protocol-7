#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## host-root key creation [ 25a60f33b, 2026-10-05 ] : compiles the REAL   ##
## crypt.C25519.gen_keys with the real base.prng.* modules it needs [     ##
## reseed \ entropy_pool \ add_entropy \ bytes ] and checks the fresh     ##
## random path, the deterministic passphrase path and the error branches. ##
## then compiles the REAL crypt.C25519.post_init with recorder stubs for  ##
## gen_keys \ write_keys \ key_exists and checks the host-root decision.  ##
## every key dir is a File::Temp tempdir ; nothing is written to disk by  ##
## the code under test [ write_keys is a recorder ]. no zenka started,    ##
## restarted or reloaded.                                                 ##

use File::Spec;
use Cwd          qw| abs_path |;
use FindBin      qw| $RealBin |;
use File::Temp   qw| tempdir |;
use Scalar::Util qw| refaddr |;

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
use AMOS7::13;
use AMOS7::Assert::Truth;
use Crypt::Misc qw| encode_b32r |;
use Crypt::Ed25519;
use Crypt::PRNG::Fortuna;
use Digest::BMW;
use IO::AIO;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

sub truth {    ## both truth checks gen_keys requires of a public key ##
    my $public = shift;
    return 0 if not defined $public;
    my $b32 = encode_b32r($public);
    return scalar( AMOS7::Assert::Truth::is_true( \$public, FALSE, TRUE ) )
        && scalar( AMOS7::Assert::Truth::is_true( \$b32,    FALSE, TRUE ) );
}

## stubs : base.* \ event.* \ prng support ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'}         = sub { return '[ test ]' };
$code{'base.ntime'}          = sub { return '3225760654008' };
$code{'base.assert.harmony'} = sub { return 1 };
$code{'base.sleep'}          = sub {return};
$code{'base.time'}
    = sub { require Time::HiRes; return sprintf '%.9f', Time::HiRes::time() };
$code{'base.ntime.b32'} = sub { return 'NTIME' };
$code{'event.once'}     = sub {return};

## key_vars echoes the explicit name, as the real one does ##
my $key_tmp = tempdir( CLEANUP => 1 );
$code{'crypt.C25519.key_vars'} = sub {
    my $name = shift;
    return { 'key_name' => $name, 'key_dir' => $key_tmp };
};

compile_module('base.prng.entropy_pool');
compile_module('base.prng.reseed');
compile_module('base.prng.add_entropy');
compile_module('base.prng.bytes');
compile_module('crypt.C25519.gen_keys');

my $gen_keys = $code{'crypt.C25519.gen_keys'};

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @ARG };

$code{'base.prng.reseed'}->();

say ': gen_keys : fresh random path [ host-root ]';

my ( $entry, $name ) = $gen_keys->(qw| host-root |);
my $stored = $keys{'C25519'}{'host-root'};

ok( defined $stored && ref $stored eq 'HASH' && $name eq 'host-root',
    "returns the entry + name, stored under \$keys{C25519}{'host-root'}"
);
ok( defined $entry && refaddr($entry) == refaddr($stored),
    'returned entry is the stored entry' );
ok( length( $stored->{'secret'} // '' ) == 32, 'secret  : 32 bytes' );
ok( length( $stored->{'private'} // '' ) == 64,
    'private : 64 ' . 'bytes [ ed25519 ]'
);
ok( length( $stored->{'public'} // '' ) == 32, 'public  : 32 bytes' );
ok( Crypt::Ed25519::eddsa_public_key( $stored->{'secret'} ) eq
        $stored->{'public'},
    'public == ed25519 public key of the secret'
);
{
    my ( $pub, $priv )
        = Crypt::Ed25519::generate_keypair( $stored->{'secret'} );
    ok( $pub eq $stored->{'public'} && $priv eq $stored->{'private'},
        'generate_keypair( secret ) reproduces public + private'
    );
}
{
    my $message   = 'host-root test message';
    my $signature = Crypt::Ed25519::sign( $message, $stored->{'public'},
        $stored->{'private'} );
    ok( Crypt::Ed25519::verify( $message, $stored->{'public'}, $signature ),
        'the pair signs and verifies' );
}
ok( truth( $stored->{'public'} ),
    'public passes the harmonic truth check [ raw + b32r ]' );
ok( $stored->{'time-loaded'} eq 'NTIME', 'time-loaded set' );
ok( !grep( { ( $ARG->[1] // '' ) =~ m{no kernel random bytes} } @logged ),
    'no fortuna-only fallback : /dev/random contributed' );

say ': gen_keys : fresh generations differ';

my ( %secrets, %publics );
for my $round ( 1 .. 8 ) {
    delete $keys{'C25519'}{'host-root'};
    $gen_keys->(qw| host-root |);
    my $key = $keys{'C25519'}{'host-root'};
    $secrets{ $key->{'secret'} }++;
    $publics{ $key->{'public'} }++;
    ok( truth( $key->{'public'} ), "round $round : public passes truth" );
}
ok( keys(%secrets) == 8, '8 generations : 8 distinct secrets' );
ok( keys(%publics) == 8, '8 generations : 8 distinct public keys' );
ok( !exists $secrets{ $stored->{'secret'} },
    'none repeats the first generation'
);

say ': gen_keys : passphrase path is deterministic';

delete $keys{'C25519'}{'pp-test'};
$gen_keys->( qw| pp-test |, 'correct horse battery staple' );
my %first = $keys{'C25519'}{'pp-test'}->%*;
delete $keys{'C25519'}{'pp-test'};
$gen_keys->( qw| pp-test |, 'correct horse battery staple' );
my %second = $keys{'C25519'}{'pp-test'}->%*;
ok( $first{'secret'} eq $second{'secret'}
        && $first{'public'} eq $second{'public'}
        && $first{'private'} eq $second{'private'},
    'same passphrase + name twice -> same key'
);
ok( truth( $first{'public'} ), 'passphrase key passes truth' );
delete $keys{'C25519'}{'pp-test'};
$gen_keys->( qw| pp-test |, 'another passphrase' );
ok( $keys{'C25519'}{'pp-test'}{'secret'} ne $first{'secret'},
    'other passphrase -> other key' );

say ': gen_keys : error branches';

@warnings = ();
my @ret = $gen_keys->( qw| bad-len |, undef, 'x' x 31 );
ok( @ret == 1 && !defined $ret[0] && !exists $keys{'C25519'}{'bad-len'},
    '31-byte secret -> undef, nothing stored' );
ok( grep( {m{must be 32 bytes}} @warnings ), '  :.. warns : 32 bytes' );

@warnings = ();
@ret      = $gen_keys->( qw| both |, 'a passphrase', 'y' x 32 );
ok( @ret == 1 && !defined $ret[0] && !exists $keys{'C25519'}{'both'},
    '32-byte secret + passphrase -> undef, nothing stored'
);
ok( grep( {m{mutually exclusive}} @warnings ),
    '  :.. warns : mutually exclusive'
);

@complaints = ();
my $before      = $keys{'C25519'}{'host-root'};
my %before_copy = $before->%*;
@ret = $gen_keys->(qw| host-root |);
ok( @ret == 1 && defined $ret[0] && $ret[0] == FALSE,
    'already loaded name -> FALSE' );
ok( refaddr( $keys{'C25519'}{'host-root'} ) == refaddr($before)
        && $keys{'C25519'}{'host-root'}{'secret'} eq $before_copy{'secret'}
        && $keys{'C25519'}{'host-root'}{'public'} eq $before_copy{'public'}
        && $keys{'C25519'}{'host-root'}{'private'} eq $before_copy{'private'},
    '  :.. existing key unchanged'
);
ok( grep( {m{already loaded}} @complaints ),
    '  :.. complains via base.s_warn'
);

say ': gen_keys : explicit 32-byte secret [ observation ]';

## a secret whose public key FAILS the truth check -- what happens to it ##
my $untrue_secret;
for ( 1 .. 1000 ) {
    my $candidate = Crypt::Misc::random_bytes(32);
    if ( not truth( Crypt::Ed25519::eddsa_public_key($candidate) ) ) {
        $untrue_secret = $candidate;
        last;
    }
}
my $true_secret;
for ( 1 .. 1000 ) {
    my $candidate = Crypt::Misc::random_bytes(32);
    if ( truth( Crypt::Ed25519::eddsa_public_key($candidate) ) ) {
        $true_secret = $candidate;
        last;
    }
}
delete $keys{'C25519'}{'explicit'};
$gen_keys->( qw| explicit |, undef, $true_secret );
ok( defined $true_secret
        && $keys{'C25519'}{'explicit'}{'secret'} eq $true_secret,
    'explicit secret with a TRUE public key : kept as given'
);
delete $keys{'C25519'}{'explicit'};
$gen_keys->( qw| explicit |, undef, $untrue_secret );
my $kept = defined $untrue_secret
    && $keys{'C25519'}{'explicit'}{'secret'} eq $untrue_secret;
say '         explicit secret with an UNTRUE public key : '
    . ( $kept ? 'kept as given' : 'REPLACED by a fresh random secret' );
ok( truth( $keys{'C25519'}{'explicit'}{'public'} ),
    '  :.. stored key passes truth either way'
);
delete $keys{'C25519'}{'explicit'};

my @perl_warnings
    = grep { !m{must be 32 bytes|mutually exclusive} } @warnings;
ok( !@perl_warnings, 'no unexpected perl warnings in gen_keys' );
say "         $ARG" for @perl_warnings;

## ------------------------------------------------------------------------ ##

say ': post_init : host-root decision';

my %called;
my %key_exists_answer;
my $pi_tmp = tempdir( CLEANUP => 1 );
my $pi_kv  = {
    'uid'          => $UID,
    'gid'          => $GID + 0,
    'usr_name'     => 'test-usr',
    'usr_home'     => $pi_tmp,
    'key_dir'      => $pi_tmp,
    'key_name'     => 'test-usr.base',
    'key_basepath' => File::Spec->catfile( $pi_tmp, 'test-usr.base' ),
    'key_filename' => {
        'private' => File::Spec->catfile( $pi_tmp, 'test-usr.base.private' ),
        'public'  => File::Spec->catfile( $pi_tmp, 'test-usr.base.public' ),
    },
};

## the real gen_keys is saved ; post_init sees recorders ##
my $real_gen_keys = $code{'crypt.C25519.gen_keys'};

$code{'crypt.C25519.key_vars'}    = sub { return $pi_kv };
$code{'crypt.C25519.chk_key_dir'} = sub { return TRUE };
$code{'base.cfg_bool'}            = sub { return FALSE };
$code{'crypt.C25519.load_keypair'}
    = sub { push $called{'load_keypair'}->@*, [@ARG]; return };
$code{'file.slurp'} = sub { my $s = ''; return \$s };
$code{'crypt.C25519.generate_session_keypair'} = sub {return};
$code{'crypt.C25519.key_exists'}               = sub {
    push $called{'key_exists'}->@*, [@ARG];
    return $key_exists_answer{ $ARG[0] } // FALSE;
};
$code{'crypt.C25519.gen_keys'} = sub {
    push $called{'gen_keys'}->@*, [@ARG];
    $keys{'C25519'}{ $ARG[0] } = { 'public' => 'p', 'private' => 'q' };
    return ( $keys{'C25519'}{ $ARG[0] }, $ARG[0] );
};
$code{'crypt.C25519.write_keys'}
    = sub { push $called{'write_keys'}->@*, [@ARG]; return TRUE };

compile_module('crypt.C25519.post_init');
my $post_init = $code{'crypt.C25519.post_init'};

sub run_post_init {
    my %param = @ARG;
    %data                                                   = ();
    %keys                                                   = ();
    %called                                                 = ();
    %key_exists_answer                                      = ();
    $data{'system'}{'zenka'}{'name'}                        = $param{'zenka'};
    $data{'crypt'}{'C25519'}{'auto_load_keys'}              = TRUE;
    $data{'crypt'}{'C25519'}{'cfg'}{'create_host_root_key'} = $param{'create'}
        if exists $param{'create'};
    $key_exists_answer{'host-root'} = $param{'on_disk'}
        if exists $param{'on_disk'};
    $keys{'C25519'}{'host-root'} = { 'public' => 'P', 'private' => 'Q' }
        if $param{'in_keys'};
    my $ret = $post_init->();
    return $ret;
}

sub host_root_calls {
    my $type = shift;
    return
        scalar grep { ( $ARG->[0] // '' ) eq 'host-root' }
        ( $called{$type} // [] )->@*;
}

my $ret = run_post_init( 'zenka' => 'v7-zenki' );
ok( defined $ret && $ret eq '0', 'v7-zenki : post_init returns 0' );
ok( ( $called{'gen_keys'} // [] )->@* == 1
        && host_root_calls('gen_keys') == 1
        && $called{'gen_keys'}[0]->@* == 1,
    "v7-zenki, nothing on disk : gen_keys('host-root') once [ no secret ]"
);
ok( ( $called{'write_keys'} // [] )->@* == 1
        && host_root_calls('write_keys') == 1,
    "  :.. write_keys('host-root') once"
);
ok( host_root_calls('key_exists') == 1, '  :.. key_exists consulted' );
ok( ( $data{'crypt'}{'C25519'}{'cfg'}{'create_host_root_key'} // 0 ) == TRUE,
    '  :.. create_host_root_key defaults to TRUE'
);

for my $zenka (qw| cube httpd |) {
    run_post_init( 'zenka' => $zenka );
    ok( !$called{'gen_keys'} && !$called{'write_keys'},
        "$zenka : neither gen_keys nor write_keys"
    );
}

run_post_init( 'zenka' => 'v7-zenki', 'on_disk' => TRUE );
ok( !$called{'gen_keys'} && !$called{'write_keys'},
    'v7-zenki, host-root on disk : neither called'
);

run_post_init( 'zenka' => 'v7-zenki', 'on_disk' => 4 );
ok( !$called{'gen_keys'} && !$called{'write_keys'},
    'v7-zenki, host-root virtual [ key_exists 4 ] : neither called' );

run_post_init( 'zenka' => 'v7-zenki', 'create' => FALSE );
ok( !$called{'gen_keys'} && !$called{'write_keys'},
    'v7-zenki, create_host_root_key FALSE : neither called'
);
ok( !$called{'key_exists'},
    '  :.. key_exists not even consulted [ short-circuit ]' );

run_post_init( 'zenka' => 'v7-zenki', 'in_keys' => TRUE );
ok( !$called{'gen_keys'}
        && ( $called{'write_keys'} // [] )->@* == 1
        && host_root_calls('write_keys') == 1,
    'v7-zenki, host-root in %keys but not on disk : write_keys only'
);

## and the real gen_keys behind the decision : what v7-zenki would write ##
run_post_init( 'zenka' => 'v7-zenki' );
%keys = ();
$code{'crypt.C25519.key_vars'} = sub {
    return { 'key_name' => shift, 'key_dir' => $key_tmp };
};
$code{'base.prng.reseed'}->();    ## %data was reset by run_post_init ##
$real_gen_keys->( $called{'gen_keys'}[0]->@* );
ok( truth( $keys{'C25519'}{'host-root'}{'public'} )
        && length( $keys{'C25519'}{'host-root'}{'secret'} ) == 32,
    'the recorded gen_keys call, replayed on the real gen_keys : valid key'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,..,,.,,,,.,,,.,,..,,.,.,.,.,..,,,..,,.,,..,,...,...,,,,,,,,,.,.,.,,,,,.,
#EKJ7CHGZMGZQ6C3DAWGWCCGUZVJFU4DF4UMBXZIGVIXGULUEC6PQ54SXMRTP7OLXJJ6UFRDSOVAO6
#\\\|AX655Y2KRRG2W6FMAU2SFY3GLRN5DOBREZPFTMOQIOSEWXXZN7J \ / AMOS7 \ YOURUM ::
#\[7]Q6ZYYLPBM43IGQM23NHAATUYW5YVPE6QKDL7L6WLWE5JGS6N3AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
