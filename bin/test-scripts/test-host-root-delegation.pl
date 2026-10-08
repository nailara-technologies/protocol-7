#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## host-root delegation [ 2026-10-06, data/md/design/HOST-ROOT-             ##
## DELEGATION.md ] : compiles the REAL modules and drives them with stubs.  ##
## the resolver [ crypt.C25519.key_path : holder detection, every           ##
## ownership-rule violation, symlinks, non-root ], key_vars \ key_exists \  ##
## keyfiles \ load_keypair \ write_keys through it, host_root.create via    ##
## post_init, trust.statement [ the spec test vector, every field ],        ##
## trust.verify, v7-zenki.delegation.issue [ renewal, atomic write ],       ##
## auth.auth_select [ the 4th field ], the client pin and the cube key id   ##
## command.                                                                 ##
##                                                                          ##
## runs as a normal user : uid 0 ownership is FAKED [ lstat \ stat \ chown  ##
## overridden for the compiled modules only, inside a File::Temp tree ] ;   ##
## $EUID \ $EGID of the modules under test are rewritten to test variables. ##
## no real key dir is read, nothing is chown'ed, no zenka started,          ##
## restarted or reloaded, no network.                                       ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use Socket     qw| AF_UNIX SOCK_STREAM PF_UNSPEC |;
use IO::Socket;
use Fcntl;

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
use Crypt::Misc               qw| encode_b32r decode_b32r |;
use Crypt::Ed25519;
use Digest::BMW;
use File::Spec::Functions qw| catfile catdir |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## the faked identity of the modules under test ##
our $fake_euid = 0;
our $fake_egid = '0 0';

## $prefix : source prepended inside the compiled sub [ the .cmd. header ]  ##
## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## a bare list-context stat or a sysread on a default handle fails here too ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    ## the running identity is a test variable here ##
    $src =~ s{\$EUID\b}{\$main::fake_euid}g;
    $src =~ s{\$EGID\b}{\$main::fake_egid}g;
    ## sources call CORE::[l]stat [ production imports File::stat ] : route ##
    ## them to the faking overrides below                                   ##
    $src =~ s{\bCORE::(l?stat)\b}{CORE::GLOBAL::$1}g;
    my $translated = p7_syntax__translate($src);
    ## the runtime : File::stat object stat + :utf8 default open layer ##
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

## ---------------------------------------------------------------------- ##
## the temp tree : <home>/.n/user-keys [ + root/ ]                        ##

my $home     = tempdir( 'p7-hrd-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $user_dir = catdir( $home,     qw| .n user-keys | );
my $root_dir = catdir( $user_dir, 'root' );
system( 'mkdir', '-p', $user_dir ) == 0 or die 'mkdir';
chmod 0700, $user_dir;

## uid 0 faked for root/ [ path or the held fd path ] and directory handles ##
## ; $real_uid_re keeps the real owner for matching paths                   ##
our $fake_root        = TRUE;
our $real_uid_re      = undef;
our $real_uid_handles = FALSE;

sub fake_owner {
    my ( $st, $target ) = @ARG;
    return if not @$st or not $fake_root;
    if ( ref $target or ref \$target eq 'GLOB' ) {
        $st->[4] = 0 if not $real_uid_handles;
        return;
    }
    return
        if index( $target, $root_dir ) != 0 and $target !~ m{^/proc/self/fd/};
    return if defined $real_uid_re and $target =~ $real_uid_re;
    $st->[4] = 0;
    return;
}
{
    no warnings 'once';
    *CORE::GLOBAL::lstat = sub (;*) {
        my @st = CORE::lstat( $_[0] );
        fake_owner( \@st, $_[0] );
        return wantarray ? @st : scalar @st;
    };
    *CORE::GLOBAL::stat = sub (;*) {
        my @st = CORE::stat( $_[0] );
        fake_owner( \@st, $_[0] );
        return wantarray ? @st : scalar @st;
    };
    *CORE::GLOBAL::chown = sub (@) {
        my ( $uid, $gid, @targets ) = @_;
        return scalar @targets if $uid == 0 and $fake_euid == 0;
        return CORE::chown( $uid, $gid, @targets );
    };
}

## ---------------------------------------------------------------------- ##
## generic stubs                                                          ##

my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'}      = sub { return '[ test ]' };
$code{'base.ntime.b32'}   = sub { return 'NTIME' };
$code{'base.get_homedir'} = sub { return $home };
$code{'base.sort'}        = sub {
    return sort keys $_[0]->%* if ref $_[0] eq 'HASH';
    return sort @ARG;
};
$code{'file.last_existing_dir_path'} = sub { return $home };
$code{'chk-sum.bmw.L13-str'}         = sub { return 'L13' };

sub logged_at {
    my ( $level, $pattern ) = @ARG;
    return scalar grep {
                defined $ARG->[0]
            and $ARG->[0] eq $level
            and do {
            no warnings;
            sprintf( $ARG->[1] // '', @{$ARG}[ 2 .. $ARG->$#* ] );
            }
            =~ $pattern
    } @logged;
}

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

my $me = getpwuid($UID);
$data{'system'}{'amos-zenka-user'}       = $me;
$data{'crypt'}{'C25519'}{'usr_name'}     = $me;
$data{'crypt'}{'C25519'}{'key_usr_home'} = $home;
$data{'crypt'}{'C25519'}{'key_dir'}      = $user_dir;
$data{'crypt'}{'C25519'}{'regex'}{'key_files'}
    = qr{(\.secret|\.private|\.public|:seed-phrase)};

my $b32 = sub { Crypt::Misc::encode_b32r(shift) };

## fixed-seed throwaway keys [ the spec vector : host-root \x03, S \x02 ] ##
my ( $hr_pub, $hr_priv ) = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
my ( $s_pub,  $s_priv )  = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
my ( $x_pub,  $x_priv )  = Crypt::Ed25519::generate_keypair( "\x05" x 32 );
my ( $fr_pub, $fr_priv ) = Crypt::Ed25519::generate_keypair( "\x04" x 32 );

compile_module('trust.statement');
compile_module('trust.key_id');
compile_module('trust.verify');
compile_module('trust.chain');
my $statement = $code{'trust.statement'};
my $key_id    = $code{'trust.key_id'};
my $verify    = $code{'trust.verify'};

######################################################################
say ': test vector [ trust.statement, data/md/design/HOST-ROOT-DELEGATION ]';

my %vector = (
    statement_hex => '70372064656c65676174696f6e20763100ed4928c628d1c2c6eae90'
        . '338905995612959273a5c63f93636c14614ac8737d1813977'
        . '0ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5'
        . 'b8fc9b394000e746573742d686f73742e637562656553f100'
        . '657b7e000000',
    sig_b32 => 'LAL3UIQD4LJVCGNJWXL3TO7DZUD2PCAJ43B2XXPTNWQAQZDDX7G'
        . 'PYH3DYOFIJZUJEUDB2MKQSBZ4HSXBGCQX4GM5LOA4IOSEBMPFQAQ',
    wire => 'OA3SAZDFNRSWOYLUNFXW4IDWGEAO2SJIYYUNDQWG5LUQGOEQLGKWCKKZE45FYY7Z'
        . 'GY3MCRQUVSDTPUMBHF3Q5KD5C5PVNI2UM3BUY7WMZOGYVENU5Y32EXPWB5'
        . 'NY7SNTSQAA45DFON2C22DPON2C4Y3VMJSWKU7RABSXW7QAAAAFQF52EIB6'
        . 'FU2RDGU3LV5ZXPR42B5HRAE6NQ5L3XZW3IAIMRR37TH4D5R4HCUE42ESKB'
        . 'Q5GFIJA46DZLQTBIL6DGOVXAOEHJCAWHSYAI',
    key_id => 'ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3A'
        . 'WUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G',
);
my %vec_fields = (
    issuer_pub  => $hr_pub,
    subject_pub => $s_pub,
    name        => 'test-host.cube',
    not_before  => 1700000000,
    not_after   => 1702592000,
    scope       => '',
);
my $vec_st = $statement->( 'build', {%vec_fields} );
ok( defined $vec_st && unpack( 'H*', $vec_st ) eq $vector{'statement_hex'},
    'statement hex' );
ok( pack(
        'Z* a32 a32 n/a* N N n/a*',
        'p7 delegation v1',
        @vec_fields{
            qw| issuer_pub subject_pub name
                not_before not_after scope |
        }
    ) eq ( $vec_st // '' ),
    '  :.. == an independent hand-written pack'
);
my $vec_sig = Crypt::Ed25519::sign( $vec_st, $hr_pub, $hr_priv );
ok( $b32->($vec_sig) eq $vector{'sig_b32'}, 'sig b32' );
ok( ( $statement->( 'wire', $vec_st, $vec_sig ) // '' ) eq $vector{'wire'},
    'wire b32' );
ok( ( $key_id->($hr_pub) // '' ) eq $vector{'key_id'},
    'key id [ 77 chars ]' );
ok( length( $vector{'key_id'} ) == 77, '  :.. 77 chars' );
{
    my $p = $statement->( 'parse_wire', $vector{'wire'} );
    ok( ref $p eq 'HASH'
            && $p->{'statement'} eq $vec_st
            && $p->{'sig'} eq $vec_sig
            && !grep( { $p->{$ARG} ne $vec_fields{$ARG} } keys %vec_fields ),
        'parse_wire round trip : every field, statement, sig'
    );
}

######################################################################
say ': trust.statement refuses invalid fields';

sub build_with {
    my %over = @ARG;
    my %f    = ( %vec_fields, %over );
    delete @f{
        grep { !defined $over{$ARG} && exists $over{$ARG} }
            keys %over
    };
    return $statement->( 'build', \%f );
}
ok( !defined build_with( issuer_pub  => 'x' x 31 ), 'issuer_pub 31 bytes' );
ok( !defined build_with( issuer_pub  => 'x' x 33 ), 'issuer_pub 33 bytes' );
ok( !defined build_with( subject_pub => 'x' x 31 ), 'subject_pub 31 bytes' );
ok( !defined build_with( subject_pub => "\x{100}" x 32 ),
    'subject_pub wide characters' );
ok( !defined build_with( name       => '' ),     'name empty' );
ok( !defined build_with( name       => 'a b' ),  'name with a space' );
ok( !defined build_with( name       => "a\nb" ), 'name with a newline' );
ok( !defined build_with( name       => undef ),  'name missing' );
ok( !defined build_with( scope      => 'a b' ),  'scope with a space' );
ok( !defined build_with( scope      => undef ),  'scope missing' );
ok( !defined build_with( not_before => -1 ),     'not_before negative' );
ok( !defined build_with( not_before => '1e9' ),  'not_before not digits' );
ok( !defined build_with( not_after  => 4294967296 ), 'not_after > 2**32-1' );
ok( !defined build_with( not_after  => 1699999999 ),
    'not_after before not_before' );
ok( defined build_with( not_after => 1700000000 ),
    'not_after == not_before : built' );
ok( !defined $statement->( 'build', 'not a hash' ), 'fields not a hash' );
ok( !defined $statement->('nonsense'),              'unknown mode' );
{
    my $r = $statement->( 'build', { %vec_fields, name => '' } );
    ok( !defined $r, 'scalar context refusal : undef [ never a reason ]' );
    my @r = $statement->( 'build', { %vec_fields, name => '' } );
    ok( @r == 2 && !defined $r[0] && $r[1] =~ m{name},
        'list context : ( undef, reason )' );
}

say ': trust.statement parse is exact';
{
    ok( !defined $statement->( 'parse', $vec_st . "\0" ), 'trailing byte' );
    ok( !defined $statement->( 'parse', substr( $vec_st, 0, -1 ) ),
        'truncated' );
    ( my $other_label = $vec_st ) =~ s{^p7 delegation v1}{p7 delegation v2};
    ok( !defined $statement->( 'parse', $other_label ),  'other label' );
    ok( !defined $statement->( 'parse', 'x' . $vec_st ), 'leading byte' );
    my $long_name = $vec_st;
    substr( $long_name, 17 + 64, 2, pack( 'n', 0xffff ) );
    ok( !defined $statement->( 'parse', $long_name ),
        'name length beyond the end' );
    ok( defined $statement->( 'parse',       $vec_st ), 'the vector parses' );
    ok( !defined $statement->( 'parse_wire', $vector{'wire'} . 'A' ),
        'wire : one char more [ not canonical ]' );
    ok( !defined $statement->( 'parse_wire', lc $vector{'wire'} ),
        'wire : lowercase' );
    ok( !defined $statement->( 'parse_wire', 'A' x 2049 ),
        'wire : over 2048 chars' );
    ok( !defined $statement->( 'parse_wire', $b32->( 'x' x 64 ) ),
        'wire : sig only' );
    ok( !defined $statement->( 'parse_wire', undef ), 'wire : undef' );
}

######################################################################
say ': trust.verify';

sub dlg {    ## a delegation wire, signed by $issuer [ default host-root ] ##
    my %o = @ARG;
    my ( $i_pub, $i_priv ) = ( $o{'issuer'} // [ $hr_pub, $hr_priv ] )->@*;
    my $st = $statement->(
        'build',
        {   issuer_pub  => $i_pub,
            subject_pub => $o{'subject'}    // $s_pub,
            name        => $o{'name'}       // 'test-host.cube',
            not_before  => $o{'not_before'} // 1700000000,
            not_after   => $o{'not_after'}  // 1702592000,
            scope       => $o{'scope'}      // '',
        }
    );
    die 'dlg build' if not defined $st;
    my $sig = Crypt::Ed25519::sign( $st, $i_pub, $i_priv );
    $sig = ~$sig if $o{'bad_sig'};
    return $statement->( 'wire', $st, $sig );
}
my $hr_fp = $key_id->($hr_pub);
my $now   = 1701000000;

sub v {
    my ( $chain, %o ) = @ARG;
    return $verify->(
        {   chain   => $chain,
            anchors => $o{'anchors'} // [$hr_fp],
            subject => $o{'subject'} // $s_pub,
            now     => $o{'now'}     // $now,
        }
    );
}
{
    my $r = v( [ dlg() ] );
    ok( ref $r eq 'HASH'
            && $r->{'name'} eq 'test-host.cube'
            && $r->{'anchor'} eq $hr_fp
            && $r->{'not_after'} == 1702592000
            && $r->{'depth'} == 1,
        'valid : { name, anchor, not_after, depth }'
    );
    my @r = v( [ dlg() ], anchors => [ $key_id->($fr_pub) ] );
    ok( !defined $r[0] && $r[1] =~ m{no pinned anchor}, 'wrong key id' );
    @r = v( [ dlg( bad_sig => 1 ) ] );
    ok( !defined $r[0] && $r[1] =~ m{signature}, 'bad signature' );
    @r = v( [ dlg() ], now => 1702592001 );
    ok( !defined $r[0] && $r[1] =~ m{expired}, 'expired [ not_after + 1 ]' );
    ok( ref v( [ dlg() ], now => 1702592000 ) eq 'HASH',
        'now == not_after : valid [ inclusive ]'
    );
    @r = v( [ dlg() ], now => 1699999999 );
    ok( !defined $r[0] && $r[1] =~ m{not yet valid}, 'not yet valid' );
    ok( ref v( [ dlg() ], now => 1700000000 ) eq 'HASH',
        'now == not_before : valid [ inclusive ]'
    );
    @r = v( [ dlg() ], subject => $x_pub );
    ok( !defined $r[0] && $r[1] =~ m{subject mismatch}, 'subject mismatch' );
    @r = v( [ dlg( scope => 'test-host.*' ) ] );
    ok( !defined $r[0] && $r[1] =~ m{leaf scope}, 'leaf scope not empty' );
    @r = v( [ dlg( scope => '*' ) ] );
    ok( !defined $r[0] && $r[1] =~ m{scope pattern not valid},
        'statement carrying scope * : refused' );
    @r = v( [ dlg( name => '-bad' ) ] );
    ok( !defined $r[0] && $r[1] =~ m{name}, 'name charset [ leading - ]' );
    ## two hops : host-root -> S [ scope '' ] -> X : scope violation ##
    @r = v(
        [   dlg( scope  => '' ),
            dlg( issuer => [ $s_pub, $s_priv ], subject => $x_pub )
        ],
        subject => $x_pub
    );
    ok( !defined $r[0] && $r[1] =~ m{statement 2 : issuer scope is empty},
        'scope violation [ two hops, issuer scope empty ]' );
    ## scope '*' is never issued : statement 1 refuses at the pattern ##
    @r = v(
        [   dlg( scope  => '*' ),
            dlg( issuer => [ $s_pub, $s_priv ], subject => $x_pub )
        ],
        subject => $x_pub
    );
    ok( !defined $r[0] && $r[1] =~ m{statement 1 : scope pattern not valid},
        'two hops, statement carrying scope * : refused' );
    ## 'cube' is now a valid EXACT scope : the second name is outside it ##
    @r = v(
        [   dlg( scope  => 'cube' ),
            dlg( issuer => [ $s_pub, $s_priv ], subject => $x_pub )
        ],
        subject => $x_pub
    );
    ok( !defined $r[0] && $r[1] =~ m{statement 2 : name outside issuer scope},
        'name outside an exact issuer scope : refused'
    );
    ## statement 1 valid [ scope 'cube' ] : statement 2's issuer must be ##
    ## its subject -- a foreign issuer breaks the chain link             ##
    @r = v(
        [   dlg( scope  => 'cube' ),
            dlg( issuer => [ $fr_pub, $fr_priv ], subject => $x_pub )
        ],
        subject => $x_pub
    );
    ## scalar assignment : a failing =~ in list context would silently ##
    ## vanish from the ok() argument list [ false positive ]           ##
    my $mismatch = !defined $r[0] && $r[1] =~ m{previous subject};
    ok( $mismatch, 'second issuer != first subject' );
    my $scalar = v( [ dlg( bad_sig => 1 ) ] );
    ok( !defined $scalar,
        'scalar context refusal : ' . 'undef [ never a reason ]' );
    ok( !defined v( [] ), 'empty chain' );
    ok( !defined v( [ dlg() ], anchors => [] ),     'no anchors' );
    ok( !defined v( [ dlg() ], now     => 'soon' ), 'now not a number' );
    ok( !defined v( [ dlg() ], subject => 'x' ),    'subject not 32 bytes' );
}

######################################################################
say ': trust.verify : shared chain vectors [ TRUST-CHAIN-STEP2 ]';

## the SAME cases bin/p7-auth-keypair-helper.pl self-tests verify_chain   ##
## with [ bin/test-scripts/trust-chain-vectors.pl ] -- both must give the ##
## same accept \ refuse [ and reason, but the 'refuse' wildcard ]         ##
{
    my $build = do(
        catfile(
            $main::root_path, 'bin',
            'test-scripts',   'trust-chain-vectors.pl'
        )
    );
    die "trust-chain-vectors.pl : $EVAL_ERROR $OS_ERROR"
        if ref $build ne 'CODE';
    foreach my $case ( $build->()->@* ) {
        my ( $r, $why ) = $verify->(
            {   chain   => [ map { $b32->($ARG) } $case->{'chain'}->@* ],
                anchors => $case->{'anchors'},
                subject => $case->{'subject'},
                now     => $case->{'now'},
                ( distrust => $case->{'distrust'} ) x !!$case->{'distrust'},
            }
        );
        if ( $case->{'expect'} eq 'ok' ) {
            ok( ref $r eq 'HASH'
                    && $r->{'name'} eq $case->{'name'}
                    && $r->{'anchor'} eq $case->{'anchor'}
                    && $r->{'depth'} == $case->{'depth'},
                "shared : $case->{'label'}"
            );
        } elsif ( $case->{'expect'} eq 'refuse' ) {
            ok( !defined $r, "shared : $case->{'label'}" );
        } else {
            ok( !defined $r && defined $why && $why eq $case->{'expect'},
                "shared : $case->{'label'}" );
        }
    }
}

######################################################################
say ': trust.pin_decide : shared pin vectors [ TRUST-CHAIN-STEP2 ]';

## the SAME cases bin/p7-auth-keypair-helper.pl self-tests pin_decide with ##
## [ bin/test-scripts/trust-pin-vectors.pl ]                               ##
compile_module('trust.pin_decide');
compile_module('auth.client.owner_pins');
compile_module('auth.client.distrust_list');
{
    my $build = do(
        catfile(
            $main::root_path, 'bin',
            'test-scripts',   'trust-pin-vectors.pl'
        )
    );
    die "trust-pin-vectors.pl : $EVAL_ERROR $OS_ERROR"
        if ref $build ne 'CODE';
    foreach my $case ( $build->()->@* ) {
        my ( $r, $why ) = $code{'trust.pin_decide'}->( {
                (   map { $ARG => $case->{$ARG} }
                        qw| subject now host_pin owners distrust strict |
                ),
                chain => [ map { $b32->($ARG) } $case->{'chain'}->@* ],
            }
        );
        my $got
            = defined $r
            ? join( ' ',
            ( map { $r->{$ARG} // '-' } qw| verdict fp name | ),
            ( $r->{'owner'} ? 1 : 0 ),
            ( map { $r->{$ARG} // '-' } qw| since write | ) )
            : $why // '?';
        my $want
            = $case->{'expect'} =~ m|\APIN_|
            ? join( ' ',
            map { $case->{$ARG} } qw| expect fp name owner since write | )
            : $case->{'expect'};
        ok( $got eq $want, "pin : $case->{'label'}" );
        say "    got  : $got\n    want : $want" if $got ne $want;
    }
}

######################################################################
say ': crypt.C25519.key_path [ resolver ]';

compile_module('crypt.C25519.root_key_dir');
compile_module('crypt.C25519.delegation_file');
compile_module('crypt.C25519.key_path');
my $key_path = $code{'crypt.C25519.key_path'};

sub put {    ## a file with content + mode ##
    my ( $path, $mode, $content ) = @ARG;
    unlink $path;
    open( my $fh, '>', $path ) or die "$path : $OS_ERROR";
    print {$fh} $content // "x\n";
    close($fh);
    chmod $mode, $path;
    return $path;
}

sub reset_root {
    system( 'rm', '-rf', $root_dir );
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};
    return;
}

ok( ( $code{'crypt.C25519.root_key_dir'}->() // '' ) eq $root_dir,
    'root_key_dir : <backend key dir>/root' );
ok( ( $code{'crypt.C25519.delegation_file'}->('protocol-7.base') // '' ) eq
        catfile( $user_dir, 'protocol-7.base.dlg' ),
    'delegation_file : <backend key dir>/<S>.dlg'
);
ok( !defined $code{'crypt.C25519.delegation_file'}->('../x'),
    'delegation_file : refuses a path' );

reset_root();
{
    my $r = $key_path->('alpha');
    ok( ref $r eq 'HASH'
            && $r->{'holder'} eq 'user'
            && $r->{'key_dir'} eq $user_dir
            && $r->{'key_filename'}{'public'} eq "$user_dir/alpha.public"
            && $r->{'key_filename'}{'virtual'} eq
            "$user_dir/alpha:seed-phrase",
        'no root/ : holder user, today\'s key dir'
    );
    ok( !defined $key_path->('a/b'), 'name with / : refused' );
    ok( !defined $key_path->('..'),  'name .. : refused' );
    ok( !defined $key_path->(''),    'empty name : refused' );
    ok( !defined $key_path->( 'alpha', { holder => 'user' } ),
        'unknown holder value : refused' );
    ok( !defined $key_path->( 'alpha', { other => 1 } ),
        'unknown option : refused' );
}

mkdir $root_dir, 0700 or die;
chmod 0700, $root_dir;
put( "$root_dir/host-root.public",  0644 );
put( "$root_dir/host-root.private", 0600 );
put( "$root_dir/host-root.secret",  0600 );
{
    my $r = $key_path->('host-root');
    ok( ref $r eq 'HASH' && $r->{'holder'} eq 'root',
        'host-root in root/ : holder root [ detected ]'
    );
    ok( ref $r eq 'HASH'
            && $r->{'key_dir_fd'} =~ m{^/proc/self/fd/\d+$}
            && $r->{'key_filename'}{'secret'}
            =~ m{^/proc/self/fd/\d+/host-root\.secret$}
            && $r->{'key_dir'} eq $root_dir,
        '  :.. paths through the held directory fd'
    );
    my @st_via  = CORE::stat( $r->{'key_filename'}{'secret'} );
    my @st_real = CORE::stat("$root_dir/host-root.secret");
    ok( @st_via && $st_via[1] == $st_real[1],
        '  :.. the fd path reaches the real file'
    );
    ok( ( $key_path->('alpha') // {} )->{'holder'} eq 'user',
        'other name : still user' );
    my $forced = $key_path->( 'new-key', { holder => 'root' } );
    ok( ref $forced eq 'HASH' && $forced->{'holder'} eq 'root',
        'holder root forced for a new name' );

    ## the held directory is swapped : the fd path still leads to the ##
    ## checked directory, a re-check refuses the impostor             ##
    my $fd_path = $r->{'key_filename'}{'secret'};
    rename $root_dir, "$root_dir.moved" or die;
    mkdir $root_dir, 0700;
    put( "$root_dir/host-root.secret", 0600, "impostor\n" );
    open( my $via, '<', $fd_path ) or die;
    ok( readline($via) eq "x\n",
        'swapped root/ : the held fd path still reads the checked directory'
    );
    close $via;
    my $again
        = ( $key_path->('host-root') // {} )->{'key_filename'}{'secret'};
    my $again_fh;
    ok( defined $again
            && open( $again_fh, '<', $again )
            && readline($again_fh) eq "impostor\n",
        '  :.. a new call re-opens [ the new directory, checked anew ]'
    );
    system( 'rm', '-rf', $root_dir );
    rename "$root_dir.moved", $root_dir or die;
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};
}

say ': key_path : every ownership-rule violation is refused';

sub refused_with {
    my ( $label, $setup, $undo ) = @ARG;
    $setup->();
    @logged = ();
    my $r = $key_path->('host-root');
    ok( !defined $r, $label );
    ok( logged_at( 0, qr{REFUSED|root key directory missing|changed} ),
        '  :.. logged at level 0' );
    $undo->();
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};
    return;
}
refused_with(
    'root/ not owned by uid 0',
    sub { $real_uid_re = qr{^\Q$root_dir\E$}; $real_uid_handles = TRUE },
    sub { $real_uid_re = undef;               $real_uid_handles = FALSE }
);
refused_with(
    'root/ mode 0750',
    sub { chmod 0750, $root_dir },
    sub { chmod 0700, $root_dir }
);
refused_with(
    'root/ mode 0701',
    sub { chmod 0701, $root_dir },
    sub { chmod 0700, $root_dir }
);
refused_with(
    'root/ a symlink to a uid 0 0700 directory',
    sub {
        rename $root_dir, "$root_dir.real" or die;
        symlink "$root_dir.real", $root_dir or die;
    },
    sub { unlink $root_dir; rename "$root_dir.real", $root_dir or die }
);
refused_with(
    'secret not owned by uid 0',
    sub { $real_uid_re = qr{host-root\.secret$} },
    sub { $real_uid_re = undef }
);
refused_with(
    'private mode 0640',
    sub { chmod 0640, "$root_dir/host-root.private" },
    sub { chmod 0600, "$root_dir/host-root.private" }
);
refused_with(
    'secret mode 0644',
    sub { chmod 0644, "$root_dir/host-root.secret" },
    sub { chmod 0600, "$root_dir/host-root.secret" }
);
refused_with(
    'public mode 0664',
    sub { chmod 0664, "$root_dir/host-root.public" },
    sub { chmod 0644, "$root_dir/host-root.public" }
);
refused_with(
    'secret a symlink',
    sub {
        rename "$root_dir/host-root.secret", "$root_dir/s.real" or die;
        symlink "$root_dir/s.real", "$root_dir/host-root.secret" or die;
    },
    sub {
        unlink "$root_dir/host-root.secret";
        rename "$root_dir/s.real", "$root_dir/host-root.secret" or die;
    }
);
refused_with(
    'public a directory',
    sub {
        rename "$root_dir/host-root.public", "$root_dir/p.real" or die;
        mkdir "$root_dir/host-root.public", 0600 or die;
    },
    sub {
        rmdir "$root_dir/host-root.public";
        rename "$root_dir/p.real", "$root_dir/host-root.public" or die;
    }
);
{
    chmod 0600, "$root_dir/host-root.public";
    ok( ref $key_path->('host-root') eq 'HASH',
        'public mode ' . '0600 : accepted'
    );
    chmod 0644, "$root_dir/host-root.public";
    ok( ref $key_path->('host-root') eq 'HASH',
        'public mode ' . '0644 : accepted'
    );
    my $saved = $root_dir;
    rename $root_dir, "$root_dir.gone" or die;
    @logged = ();
    ok( !defined $key_path->( 'host-root', { holder => 'root' } ),
        'forced root, root/ missing : refused' );
    rename "$root_dir.gone", $root_dir or die;
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};
}

say ': key_path as non-root [ root/ 0700, not ours to look into ]';
{
    ## a real EACCES : the directory unreadable to us [ mode 0000 ] ##
    $fake_root = FALSE;
    chmod 0000, $root_dir;
    my @probe = CORE::lstat("$root_dir/host-root.public");
SKIP: {
        if (@probe) {
            say '  skip : root/ still readable [ running as root ]';
            last SKIP;
        }
        @perl_warnings = ();
        @logged        = ();
        my $r = $key_path->('host-root');
        ok( ref $r eq 'HASH' && $r->{'holder'} eq 'user',
            'root-held name as non-root : holder user [ kernel decides ]' );
        ok( !@perl_warnings && !logged_at( 0, qr{.} ),
            '  :.. quiet : no warning, no level 0 log'
        );
        ok( !defined $key_path->( 'host-root', { holder => 'root' } ),
            'forced root as non-root : refused' );
    }
    chmod 0700, $root_dir;
    $fake_root = TRUE;
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};
}

######################################################################
say ': key_vars \ key_exists \ keyfiles \ load_keypair through the resolver';

compile_module('crypt.C25519.key_vars');
compile_module('crypt.C25519.key_exists');
compile_module('crypt.C25519.keyfiles');
compile_module('crypt.C25519.load_keypair');
$code{'file.all_files'} = sub {
    my $dir = shift;
    opendir( my $dh, $dir ) or return [];
    my @f = map {"$dir/$ARG"} grep { -f "$dir/$ARG" } readdir $dh;
    return \@f;
};
$code{'crypt.C25519.get_keyname'} = sub {
    ( my $f = shift ) =~ s{^.*/}{};
    $f =~ s{(\.secret|\.private|\.public|:seed-phrase)$}{};
    return $f;
};
put( "$user_dir/alpha.public",    0640 );
put( "$user_dir/alpha.private",   0600 );
put( "$user_dir/$me.base.public", 0640 );
{
    my $kv = $code{'crypt.C25519.key_vars'}->('host-root');
    ok( ref $kv eq 'HASH'
            && $kv->{'holder'} eq 'root'
            && $kv->{'uid'} == 0
            && $kv->{'gid'} == 0
            && $kv->{'key_filename'}{'secret'}
            =~ m{^/proc/self/fd/\d+/host-root\.secret$},
        'key_vars( host-root ) : root paths, owner 0'
    );
    $kv = $code{'crypt.C25519.key_vars'}->('alpha');
    ok( ref $kv eq 'HASH'
            && $kv->{'holder'} eq 'user'
            && $kv->{'key_filename'}{'public'} eq "$user_dir/alpha.public",
        'key_vars( alpha ) : user paths'
    );
    $kv = $code{'crypt.C25519.key_vars'}->('/abs/path/x.public');
    ok( ref $kv eq 'HASH' && !defined $kv->{'key_filename'},
        'key_vars( a path ) : no key file paths [ encrypted_key compat ]'
    );

    chmod 0640, "$root_dir/host-root.secret";
    ok( !defined $code{'crypt.C25519.key_vars'}->('host-root'),
        'key_vars : root-held rule violated -> undef [ no user fallback ]'
    );
    ok( !$code{'crypt.C25519.load_keypair'}->( 'host-root', undef, FALSE ),
        'load_keypair : refused root-held key -> FALSE, no die'
    );
    ok( !defined $code{'crypt.C25519.key_exists'}->('host-root'),
        'key_exists : refused root-held key -> undef'
    );
    chmod 0600, "$root_dir/host-root.secret";
    delete $data{'crypt'}{'C25519'}{'root_dir_held'};

    my $ke = $code{'crypt.C25519.key_exists'};
    ok( $ke->('host-root') == TRUE, 'key_exists( ' . 'host-root ) : TRUE' );
    ok( $ke->('host-root.secret') == TRUE,
        'key_exists( ' . 'host-root.secret )'
    );
    ok( $ke->('host-root:seed-phrase') == FALSE,
        'key_exists( host-root:seed-phrase ) : FALSE'
    );
    ok( $ke->('alpha') == TRUE, 'key_exists( alpha ) : TRUE' );
    ok( $ke->('alpha.secret') == FALSE,
        'key_exists( ' . 'alpha.secret ) : FALSE' );
    ok( $ke->('nothing') == FALSE, 'key_exists( ' . 'nothing ) : FALSE' );
    put( "$user_dir/virt:seed-phrase", 0600 );
    ok( $ke->('virt') == 4, 'key_exists( virtual ) : 4' );

    for my $as ( 0, $UID || 1000 ) {
        local $fake_euid = $as;
        my @all = $code{'crypt.C25519.keyfiles'}->();
        ok( @all
                && !
                grep( { index( $ARG, $root_dir ) == 0 || m{/proc/self/fd/} }
                @all ),
            "keyfiles() [ euid $as ] : USER dir only, nothing from root/"
        );
        ok( !grep( {m{host-root}} @all ), '  :.. no host-root file' );
        my @hr = $code{'crypt.C25519.keyfiles'}->('host-root');
        ok( !@hr, "keyfiles( host-root ) [ euid $as ] : nothing" );
    }
}

######################################################################
say ': write_keys : root-held';

compile_module('crypt.C25519.write_keys');
$code{'crypt.C25519.unload_key'}
    = sub { delete $keys{'C25519'}{ $ARG[0] }; return TRUE };
{
    reset_root();
    mkdir $root_dir, 0700;
    $keys{'C25519'}{'host-root'} = {
        'secret'  => "\x03" x 32,
        'private' => $hr_priv,
        'public'  => $hr_pub
    };
    local $fake_euid = 1000;
    ok( !$code{'crypt.C25519.write_keys'}
            ->( 'host-root', undef, FALSE, { holder => 'root' } ),
        'non-root : root-held key NOT written'
    );
    ok( !-e "$root_dir/host-root.secret", '  :.. nothing on disk' );
    $fake_euid = 0;
    my $ok = $code{'crypt.C25519.write_keys'}
        ->( 'host-root', undef, TRUE, { holder => 'root' } );
    ok( $ok, 'root : written' );

    for my $type (qw| secret private public |) {
        my @st = CORE::stat("$root_dir/host-root.$type");
        ok( @st && ( $st[2] & 07777 ) == 0600, "  :.. $type mode 0600" );
    }
    ok( !-e "$user_dir/host-root.public", '  :.. nothing in the user dir' );
    ok( !exists $keys{'C25519'}{'host-root'}, '  :.. erased from memory' );
    my @tmp = glob("$root_dir/*NTIME*");
    ok( !@tmp, '  :.. no temp files left' );
    my $kp = $key_path->('host-root');
    ok( ref $kp eq 'HASH', '  :.. passes the ownership rule' );
    ## read back through the held fd paths [ what load_keypair reads ] ##
    my $slurp = sub {
        open( my $fh, '<', shift ) or return '';
        my $l = readline($fh) // '';
        close $fh;
        chomp $l;
        return $l;
    };
    ok( ref $kp eq 'HASH'
            && decode_b32r( $slurp->( $kp->{'key_filename'}{'public'} ) ) eq
            $hr_pub
            && decode_b32r( $slurp->( $kp->{'key_filename'}{'private'} ) ) eq
            "U:$hr_priv",
        '  :.. public + private read back through the fd paths'
    );
}

######################################################################
say ': post_init -> host_root.create';

compile_module('crypt.C25519.host_root.create');
compile_module('crypt.C25519.post_init');
my @gen;
$code{'crypt.C25519.gen_keys'} = sub {
    push @gen, [@ARG];
    $keys{'C25519'}{ $ARG[0] } = {
        'secret'  => "\x03" x 32,
        'private' => $hr_priv,
        'public'  => $hr_pub
    };
    return;
};
$code{'crypt.C25519.chk_key_dir'}              = sub { return $user_dir };
$code{'base.cfg_bool'}                         = sub { return FALSE };
$code{'crypt.C25519.generate_session_keypair'} = sub {return};

sub run_post_init {
    my ( $zenka, $euid ) = @ARG;
    reset_root();
    delete $keys{'C25519'}{'host-root'};
    @gen                                       = ();
    @logged                                    = ();
    $data{'system'}{'zenka'}{'name'}           = $zenka;
    $data{'crypt'}{'C25519'}{'auto_load_keys'} = 0;
    delete $data{'crypt'}{'C25519'}{'key_vars'};
    local $fake_euid = $euid;
    return $code{'crypt.C25519.post_init'}->();
}
{
    my $ret = run_post_init( 'v7-zenki', 0 );
    ok( defined $ret && $ret eq '0' || ( defined $ret && !$ret ),
        'v7-zenki, root, auto_load_keys 0 : post_init returns'
    );
    ok( @gen == 1 && $gen[0][0] eq 'host-root', '  :.. host-root generated' );
    my @dst = CORE::lstat($root_dir);
    ok( @dst && -d _ && ( $dst[2] & 07777 ) == 0700,
        '  :.. root/ ' . 'created 0700' );
    ok( -f "$root_dir/host-root.secret" && -f "$root_dir/host-root.public",
        '  :.. host-root written to root/' );

    ## second start : present, nothing generated ##
    @gen = ();
    delete $keys{'C25519'}{'host-root'};
    {
        local $fake_euid = 0;
        $code{'crypt.C25519.host_root.create'}->();
    }
    ok( !@gen, 'second start : host-root present, not regenerated' );

    run_post_init( 'v7-zenki', 1000 );
    ok( !@gen && !-e $root_dir, 'v7-zenki as non-root : skipped, no root/' );
    ok( logged_at( 1, qr{not running as root} ), '  :.. logged at level 1' );

    run_post_init( 'cube', 0 );
    ok( !@gen && !-e $root_dir, 'cube [ root ] : not created' );

    ## a hostile root/ is never adopted ##
    reset_root();
    mkdir $root_dir, 0755;
    chmod 0755, $root_dir;
    @gen = ();
    {
        local $fake_euid = 0;
        $data{'system'}{'zenka'}{'name'} = 'v7-zenki';
        ok( !$code{'crypt.C25519.host_root.create'}->(),
            'existing root/ 0755 : refused' );
    }
    ok( !@gen && !-e "$root_dir/host-root.secret", '  :.. nothing written' );
    reset_root();
}

######################################################################
say ': v7-zenki.delegation.issue';

compile_module('v7-zenki.backend.run');
compile_module('v7-zenki.backend.read_small');
compile_module('v7-zenki.delegation.issue');
my $issue    = $code{'v7-zenki.delegation.issue'};
my $s_name   = "$me.base";
my $dlg_file = catfile( $user_dir, "$s_name.dlg" );
my $s_file   = catfile( $user_dir, "$s_name.public" );
$code{'crypt.C25519.load_keypair'} = sub {
    $keys{'C25519'}{ $ARG[0] }
        = { 'public' => $hr_pub, 'private' => $hr_priv }
        if $ARG[0] eq 'host-root';
    return TRUE;
};
$data{'system'}{'node'}{'name'} = 'TestHost';

sub setup_host_root {
    reset_root();
    mkdir $root_dir, 0700;
    put( "$root_dir/host-root.public",  0644, $b32->($hr_pub) . "\n" );
    put( "$root_dir/host-root.private", 0600 );
    put( "$root_dir/host-root.secret",  0600 );
    return;
}

sub read_dlg {
    open( my $fh, '<', $dlg_file ) or return undef;
    my $l = readline($fh);
    close($fh);
    chomp $l if defined $l;
    return $l;
}
{
    setup_host_root();
    put( $s_file, 0640, $b32->($s_pub) . "\n" );
    unlink $dlg_file;
    local $fake_euid = 0;
    my $t0 = time;
    ok( $issue->(), 'first issue : TRUE' );
    my $wire = read_dlg();
    my $r
        = defined $wire
        ? $verify->(
        {   chain   => [$wire],
            anchors => [$hr_fp],
            subject => $s_pub,
            now     => time
        }
        )
        : undef;
    ok( ref $r eq 'HASH', '  :.. the .dlg verifies under host-root for S' );
    ok( ref $r eq 'HASH' && $r->{'name'} eq 'testhost.cube',
        '  :.. name <system.node.name lowercased>.cube'
    );
    my $p = $statement->( 'parse_wire', $wire // '' );
    ok( ref $p eq 'HASH'
            && $p->{'not_after'} - $p->{'not_before'} == 30 * 86400 + 300
            && abs( $p->{'not_before'} - ( $t0 - 300 ) ) <= 2
            && $p->{'scope'} eq '',
        '  :.. 30 days from now, not_before 5 min back, scope empty'
    );
    my @st = CORE::stat($dlg_file);
    ok( @st && ( $st[2] & 07777 ) == 0644 && $st[4] == $UID,
        '  :.. mode 0644, owner the backend user'
    );
    ok( $fake_euid == 0 && $fake_egid eq '0 0',
        '  :.. root regained after the backend-user section' );
    ok( !exists $keys{'C25519'}{'host-root'}, '  :.. host-root unloaded' );
    ok( !glob("$dlg_file.*"),                 '  :.. no temp file left' );

    ## kept while valid and not due ##
    ok( $issue->() && read_dlg() eq $wire, 'second issue : kept unchanged' );

    ## renewal threshold ##
    my $mk = sub {
        my $left = shift;
        my $st   = $statement->(
            'build',
            {   issuer_pub  => $hr_pub,
                subject_pub => $s_pub,
                name        => 'testhost.cube',
                not_before  => time - 86400,
                not_after   => time + $left,
                scope       => ''
            }
        );
        put($dlg_file,
            0644,
            $statement->(
                'wire', $st,
                Crypt::Ed25519::sign( $st, $hr_pub, $hr_priv )
                )
                . "\n"
        );
        return read_dlg();
    };
    my $w8 = $mk->( 8 * 86400 );
    $issue->();
    ok( read_dlg() eq $w8, '8 days left : kept' );
    my $w6 = $mk->( 6 * 86400 );
    $issue->();
    ok( read_dlg() ne $w6, '6 days left : renewed' );

    ## S rotated : the old statement no longer fits -> reissued ##
    $wire = read_dlg();
    put( $s_file, 0640, $b32->($x_pub) . "\n" );
    $issue->();
    $r = $verify->(
        {   chain   => [ read_dlg() ],
            anchors => [$hr_fp],
            subject => $x_pub,
            now     => time
        }
    );
    ok( ref $r eq 'HASH', 'S rotated : reissued for the new S at once' );
    put( $s_file, 0640, $b32->($s_pub) . "\n" );
    $issue->();

    ## owner chain [ TRUST-CHAIN-STEP2.md ] : <user dir>/host-root.dlg ##
    my ( $ow_pub, $ow_priv )
        = Crypt::Ed25519::generate_keypair( "\x06" x 32 );
    my $ow_fp      = $key_id->($ow_pub);
    my $owner_file = catfile( $user_dir, 'host-root.dlg' );
    my $owner_st   = sub {
        my ( $scope, $not_after ) = @ARG;
        my $st = $statement->(
            'build',
            {   issuer_pub  => $ow_pub,
                subject_pub => $hr_pub,
                name        => 'testhost',
                not_before  => time - 86400,
                not_after   => $not_after // time + 365 * 86400,
                scope       => $scope
            }
        );
        return $statement->(
            'wire', $st, Crypt::Ed25519::sign( $st, $ow_pub, $ow_priv )
        );
    };
    my $slurp = sub {
        open( my $fh, '<', $dlg_file ) or return '';
        local $INPUT_RECORD_SEPARATOR = undef;
        my $all = readline($fh);
        close($fh);
        return $all;
    };
    my $leaf_before = read_dlg();
    my $owner_wire  = $owner_st->('testhost.*');
    put( $owner_file, 0644, "$owner_wire\n" );
    ok( $issue->(), 'owner chain : issue TRUE' );
    ok( $slurp->() eq "$leaf_before\n$owner_wire\n",
        '  :.. .dlg = leaf [ kept ] + owner statement, leaf first' );
    my $chain = $code{'trust.chain'}->( 'file', $slurp->() );
    $r = $verify->(
        {   chain   => $chain,
            anchors => [$ow_fp],
            subject => $s_pub,
            now     => time
        }
    );
    ok( ref $r eq 'HASH' && $r->{'depth'} == 2 && $r->{'anchor'} eq $ow_fp,
        '  :.. verifies under the owner, depth 2' );
    ok( $issue->() && $slurp->() eq "$leaf_before\n$owner_wire\n",
        '  :.. second issue : unchanged' );

    @logged = ();
    put( $owner_file, 0644, $owner_st->('other.*') . "\n" );
    ok( $issue->() && $slurp->() eq "$leaf_before\n",
        'owner scope not covering the leaf : dropped, leaf alone' );
    ok( logged_at( 0, qr{owner chain dropped} ), '  :.. logged at level 0' );

    @logged = ();
    put( $owner_file, 0644, $owner_st->( 'testhost.*', time - 60 ) . "\n" );
    ok( $issue->() && $slurp->() eq "$leaf_before\n",
        'owner statement expired : dropped'
    );
    ok( logged_at( 0, qr{owner chain dropped.*expired} ),
        '  :.. logged at level 0 [ expired ]'
    );

    put( $owner_file, 0644, "$owner_wire\n" );
    $issue->();
    unlink $owner_file;
    ok( $issue->() && $slurp->() eq "$leaf_before\n",
        'owner file removed : back to the leaf alone [ step 1 bytes ]' );

    ## atomic write : a planted symlink at the temp name is not followed ##
    my $victim = put( catfile( $home, 'victim' ), 0600, "victim\n" );
    unlink $dlg_file;
    symlink $victim, "$dlg_file.$PID.tmp" or die;
    ok( !$issue->(), 'planted temp symlink : refused' );
    open( my $vfh, '<', $victim ) or die;
    ok( readline($vfh) eq "victim\n", '  :.. the symlink target untouched' );
    close $vfh;
    unlink "$dlg_file.$PID.tmp";

    ## the .dlg itself a symlink : replaced by rename, target untouched ##
    symlink $victim, $dlg_file or die;
    ok( $issue->() && !-l $dlg_file, '.dlg a symlink : replaced by a file' );
    open( $vfh, '<', $victim ) or die;
    ok( readline($vfh) eq "victim\n", '  :.. the symlink target untouched' );
    close $vfh;

    ## S public a symlink : not read ##
    unlink $dlg_file;
    rename $s_file, "$s_file.real";
    symlink "$s_file.real", $s_file;
    ok( !$issue->() && !-e $dlg_file, 'S public file a symlink : refused' );
    unlink $s_file;
    rename "$s_file.real", $s_file;

    ## no hostname : nothing issued ##
    delete $data{'system'}{'node'}{'name'};
    @logged = ();
    ok( !$issue->() && !-e $dlg_file, '<system.node.name> unset : refused' );
    ok( logged_at( 0, qr{system\.node\.name} ), '  :.. logged at level 0' );
    $data{'system'}{'node'}{'name'} = 'TestHost';

    ## host-root only in the user dir [ root/ renamed away ] : refused ##
    reset_root();
    put( "$user_dir/host-root.public", 0640, $b32->($hr_pub) . "\n" );
    ok( !$issue->() && !-e $dlg_file,
        'host-root not root-held [ user dir only ] : refused' );
    unlink "$user_dir/host-root.public";

    setup_host_root();
    $fake_euid = 1000;
    ok( !$issue->() && !-e $dlg_file, 'not running as root : skipped' );
    $fake_euid = 0;
    ok( $issue->(), 'restored : issued' );
}

######################################################################
say ': auth.auth_select [ the 4th field ]';

compile_module('auth.auth_select');
my @sent;
$code{'base.net.send_to_socket'} = sub { push @sent, $ARG[1]; return TRUE };
$code{'auth.auth_list'}          = sub { return "auth-keypair\n" };
$code{'base.reverse-sort'}       = sub { return reverse sort @ARG };
$code{'base.list_matches'}       = sub {
    my ( $list, $re ) = @ARG;
    return grep {m{$re}} $list->@*;
};
$code{'base.code.call_optional'} = sub { return FALSE };
$code{'base.prng.bytes'}         = sub { return "\x66" x $ARG[0] };
$code{'crypt.C25519.key_vars'}   = sub { return { 'key_name' => $s_name } };
$keys{'C25519'}{$s_name}         = { 'public' => $s_pub };

sub select_now {
    @sent = ();
    $data{'session'}{7} = { 'handle' => 'H', 'auth' => {} };
    my $ret = $code{'auth.auth_select'}->( 7, 'auth-keypair' );
    return $ret;
}
{
    local $fake_euid = 0;
    setup_host_root();
    unlink $dlg_file;
    $issue->();
    my $wire = read_dlg();
    ok( select_now() && $sent[0] eq sprintf( "TRUE %s %s %s\n",
            $b32->($s_pub), $b32->( "\x66" x 32 ), $wire ),
        'valid .dlg : TRUE <S> <nonce> <delegation>'
    );
    ok( $data{'session'}{7}{'auth'}{'server_nonce'} eq "\x66" x 32,
        '  :.. nonce stored' );

    my $refused = sub {
        my $label = shift;
        @logged = ();
        my $ret = select_now();
        ok( !$ret
                && $sent[0] =~ m{^FALSE}
                && !exists $data{'session'}{7}{'auth'}{'server_nonce'},
            "$label : refused, no nonce stored"
        );
        ok( logged_at( 0, qr{auth-keypair} ), '  :.. logged at level 0' );
    };
    unlink $dlg_file;
    $refused->('missing .dlg');
    put( $dlg_file, 0644, "NOT B32 !\n" );
    $refused->('unparsable .dlg');
    put( $dlg_file, 0644, ( 'A' x 2100 ) . "\n" );
    $refused->('.dlg over 2048 chars');
    my $exp_st = $statement->(
        'build',
        {   issuer_pub  => $hr_pub,
            subject_pub => $s_pub,
            name        => 'testhost.cube',
            not_before  => 1700000000,
            not_after   => 1700000001,
            scope       => ''
        }
    );
    put($dlg_file,
        0644,
        $statement->(
            'wire', $exp_st,
            Crypt::Ed25519::sign( $exp_st, $hr_pub, $hr_priv )
            )
            . "\n"
    );
    $refused->('expired .dlg');
    my $other_st = $statement->(
        'build',
        {   issuer_pub  => $hr_pub,
            subject_pub => $x_pub,
            name        => 'testhost.cube',
            not_before  => time - 10,
            not_after   => time + 86400,
            scope       => ''
        }
    );
    put($dlg_file,
        0644,
        $statement->(
            'wire', $other_st,
            Crypt::Ed25519::sign( $other_st, $hr_pub, $hr_priv )
            )
            . "\n"
    );
    $refused->('.dlg for another S [ subject mismatch ]');
    my $bad_st = $statement->(
        'build',
        {   issuer_pub  => $hr_pub,
            subject_pub => $s_pub,
            name        => 'testhost.cube',
            not_before  => time - 10,
            not_after   => time + 86400,
            scope       => ''
        }
    );
    put( $dlg_file, 0644, $statement->( 'wire', $bad_st, 'z' x 64 ) . "\n" );
    $refused->('.dlg with a bad signature');
    my $saved = delete $code{'trust.verify'};
    put( $dlg_file, 0644, "$wire\n" );
    $refused->('trust modules not loaded');
    $code{'trust.verify'} = $saved;
}

######################################################################
say ': client pin [ auth.client.server_pin.check ]';

compile_module('auth.client.server_pin.check');
my $pin         = $code{'auth.client.server_pin.check'};
my $client_home = tempdir( 'p7-hrc-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
{
    local $code{'base.get_homedir'} = sub { return $client_home };
    my $pin_file = "$client_home/.n/remote-keys/servers/h.example_7.public";
    my $d        = sub {
        my ( $subject, %o ) = @ARG;
        return dlg(
            subject    => $subject,
            not_before => time - 10,
            not_after  => time + 86400,
            %o
        );
    };
    ok( $pin->( 'h.example', 7, $s_pub, $d->($s_pub) ),
        'first contact ' . ': accepted' );
    open( my $pfh, '<', $pin_file ) or die "pin : $OS_ERROR";
    my $content = join '', readline($pfh);
    close $pfh;
    ok( $content eq "$hr_fp\ntest-host.cube\n0\n",
        '  :.. pin = host-root key id + the leaf name + since 0' );
    ok( $pin->( 'h.example', 7, $x_pub, $d->($x_pub) ),
        'rotated S, same host-root : ACCEPTED'
    );
    ok( !$pin->(
            'h.example', 7, $s_pub,
            $d->( $s_pub, issuer => [ $fr_pub, $fr_priv ] )
        ),
        'different host-root : refused'
    );
    ok( !$pin->( 'h.example', 7, $x_pub, $d->($s_pub) ),
        'announced S != delegated subject : refused'
    );
    ok( !$pin->( 'h.example', 7, $s_pub, undef ), 'no delegation : refused' );
    my $first = "$client_home/.n/remote-keys/servers/new.example_7.public";
    ok( !$pin->( 'new.example', 7, $s_pub, $d->( $s_pub, bad_sig => 1 ) )
            && !-e $first,
        'first contact, bad delegation : refused, NOTHING pinned'
    );

    ## owner pins, rotation, distrust [ TRUST-CHAIN-STEP2.md 'pins' ] -- ##
    ## the file io around trust.pin_decide [ verdicts :                  ##
    ## trust-pin-vectors.pl ]                                            ##
    my ( $ow_pub, $ow_priv )
        = Crypt::Ed25519::generate_keypair( "\x06" x 32 );
    my ( $nr_pub, $nr_priv )
        = Crypt::Ed25519::generate_keypair( "\x08" x 32 );
    my $keys_dir = "$client_home/.n/remote-keys";
    my $field    = sub { $code{'trust.chain'}->( 'join', [@ARG] ) };
    my $o2h      = $d->(
        $hr_pub,
        issuer => [ $ow_pub, $ow_priv ],
        name   => 'test-host',
        scope  => 'test-host.*'
    );
    my $o2n = $d->(
        $nr_pub,
        issuer => [ $ow_pub, $ow_priv ],
        name   => 'test-host',
        scope  => 'test-host.*'
    );
    my $n2s  = $d->( $s_pub, issuer => [ $nr_pub, $nr_priv ] );
    my $read = sub {
        open( my $fh, '<', shift ) or return '';
        local $INPUT_RECORD_SEPARATOR = undef;
        my $all = readline($fh) // '';
        close($fh);
        return $all;
    };

    ## step 1 pin [ no name ] : valid, gains its name ##
    my $o_pin = "$keys_dir/servers/o.example_7.public";
    put( $o_pin, 0600, "$hr_fp\n" );
    ok( $pin->( 'o.example', 7, $s_pub, $field->( $o2h, $d->($s_pub) ) ),
        'step 1 pin, owner chain offered : accepted' );
    ok( $read->($o_pin) eq "$hr_fp\ntest-host.cube\n0\n",
        '  :.. the pin gained its name' );

    ## rotation without an owner pin : refused ##
    ok( !$pin->( 'o.example', 7, $s_pub, $field->( $o2n, $n2s ) ),
        'host-root rotated, no owner pin : refused' );

    mkdir "$keys_dir/owners", 0700;
    put( "$keys_dir/owners/test.public", 0600, $key_id->($ow_pub) . "\n" );
    ok( $pin->( 'o.example', 7, $s_pub, $field->( $o2n, $n2s ) ),
        'host-root rotated, owner pinned, same name : accepted'
    );
    my $o2n_since = $statement->( 'parse_wire', $o2n )->{'not_before'};
    ok( $read->($o_pin) eq $key_id->($nr_pub)
            . "\ntest-host.cube\n$o2n_since\n",
        '  :.. pin rewritten to the new host-root, since = its certification'
    );
    ok( !$pin->( 'o.example', 7, $s_pub, $field->( $o2h, $d->($s_pub) ) ),
        'rotate BACK to the old host-root [ same since ] : refused'
    );
    ok( ( ( stat $o_pin )[2] & 07777 ) == 0600, '  :.. mode 0600' );

    ## owner-certified first contact : host pin written, never the owner ##
    my $n_pin = "$keys_dir/servers/n.example_7.public";
    ok( $pin->( 'n.example', 7, $s_pub, $field->( $o2h, $d->($s_pub) ) )
            && $read->($n_pin)
            =~ m|\A\Q$hr_fp\E\ntest-host\.cube\n[0-9]+\n\z|,
        'owner-certified first contact : host pin + name + since'
    );
    my $n_before = $read->($n_pin);
    ok( $pin->(
            'n.example', 7, $s_pub, $d->( $s_pub, name => 'other.cube' )
            )
            && $read->($n_pin) eq $n_before,
        'same host-root, other leaf name : accepted, pinned name KEPT'
    );

    ## distrust ##
    put( "$keys_dir/distrust", 0600, "# local\n$hr_fp\n" );
    ok( !$pin->( 'n.example', 7, $s_pub, $d->($s_pub) ),
        'distrusted host-root : refused' );
    put( "$keys_dir/distrust", 0600, "garbage\n" );
    ok( !$pin->( 'n.example', 7, $s_pub, $d->($s_pub) ),
        'malformed distrust file : refused [ fail closed ]'
    );
    unlink "$keys_dir/distrust";
    ok( $pin->( 'n.example', 7, $s_pub, $d->($s_pub) ),
        'distrust removed : accepted again' );

    ## malformed chain fields ##
    ok( !$pin->( 'n.example', 7, $s_pub, $d->($s_pub) . '..' . $o2h ),
        'chain field with an empty statement : refused' );
}

######################################################################
say ': cube command crypt.C25519.cmd.host-root-id';

compile_module( 'crypt.C25519.cmd.host-root-id', $cmd_header );
{
    local $fake_euid = 0;
    setup_host_root();
    unlink $dlg_file;
    $issue->();
    my $r = $code{'crypt.C25519.cmd.host-root-id'}->( {} );
    ok( $r->{'mode'} eq 'true' && $r->{'data'} eq $hr_fp,
        'returns the host-root key id from the .dlg'
    );
    unlink $dlg_file;
    $r = $code{'crypt.C25519.cmd.host-root-id'}->( {} );
    ok( $r->{'mode'} eq 'false', 'no .dlg : false' );
}

######################################################################
say ': v7-zenki command owner-statement [ install \ drop ]';

compile_module('keystore.remote_keys_dir');
compile_module('keystore.trash.stash');
compile_module( 'v7-zenki.cmd.owner-statement', $cmd_header );
{
    local $fake_euid = 0;
    setup_host_root();
    put( $s_file, 0640, $b32->($s_pub) . "\n" );
    unlink $dlg_file;
    $issue->();
    my $leaf   = read_dlg();
    my $target = catfile( $user_dir, 'host-root.dlg' );
    unlink $target;

    my ( $o_pub, $o_priv ) = Crypt::Ed25519::generate_keypair( "\x06" x 32 );
    my $owner_wire = sub {
        my ($scope) = @ARG;
        my $st = $statement->(
            'build',
            {   issuer_pub  => $o_pub,
                subject_pub => $hr_pub,
                name        => 'testhost',
                not_before  => time - 100,
                not_after   => time + 86400,
                scope       => $scope
            }
        );
        return $statement->(
            'wire', $st, Crypt::Ed25519::sign( $st, $o_pub, $o_priv )
        );
    };
    my $cmd   = $code{'v7-zenki.cmd.owner-statement'};
    my $slurp = sub {
        open( my $fh, '<', shift ) or return '';
        local $INPUT_RECORD_SEPARATOR = undef;
        my $all = readline($fh);
        close($fh);
        return $all;
    };
    my $good = $owner_wire->('testhost.*');

    my $r = $cmd->( { args => "install $good" } );
    ok( $r->{'mode'} eq 'true' && $slurp->($target) eq "$good\n",
        'install : host-root.dlg holds the owner statement'
    );
    ok( ( ( stat $target )[2] & 07777 ) == 0644, '  :.. mode 0644' );
    ok( $slurp->($dlg_file) eq "$leaf\n$good\n",
        '  :.. re-issued at once : the .dlg is leaf + owner' );
    ok( $fake_euid == 0, '  :.. root regained' );

    $r = $cmd->( { args => "install $good" } );
    ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m|already installed|,
        'install again : already installed' );

    $r = $cmd->( { args => 'install ' . $owner_wire->('other.*') } );
    ok( $r->{'mode'} eq 'false'
            && $r->{'data'} =~ m|name outside issuer scope|
            && $slurp->($target) eq "$good\n",
        'scope not covering this host : refused, file untouched'
    );

    $r = $cmd->( { args => 'install AAAA..AAAA' } );
    ok( $r->{'mode'} eq 'false', 'malformed chain field : refused' );

    my $other = $owner_wire->('testhost.*');    ## a later statement ##
    sleep 1;
    $other = $owner_wire->('testhost.*');
    $r     = $cmd->( { args => "install $other" } );
    ok( $r->{'mode'} eq 'true' && $slurp->($target) eq "$other\n",
        'a newer statement replaces the installed one'
    );
    ok( scalar(
            () = glob(
                "$home/.n/remote-keys/trash/" . "owner-statement/host-root.*"
            )
        ) == 1,
        '  :.. the replaced one is in the backend user\'s trash'
    );

    $r = $cmd->( { args => 'drop' } );
    ok( $r->{'mode'} eq 'true' && !-e $target,
        'drop : host-root.dlg into the trash'
    );
    ok( $slurp->($dlg_file) eq "$leaf\n",
        '  :.. re-issued : the .dlg is the leaf alone again' );
    $r = $cmd->( { args => 'drop' } );
    ok( $r->{'mode'} eq 'false', 'drop again : nothing installed' );

    $r = $cmd->( { args => 'bogus' } );
    ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m|usage|,
        'bad action : ' . 'usage' );

    local $fake_euid = 1000;
    $r = $cmd->( { args => "install $good" } );
    ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m|not running as root|,
        'not root : refused' );
}

my @unexpected = grep { !m{no read permissions|non existant} } @perl_warnings;
ok( !@unexpected, 'no unexpected perl warnings' );
say "         $ARG" for @unexpected;

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,...,,,.,,.,,,,.,...,.,.,..,,...,..,,.,.,..,,...,..,,..,,,..,..,,,..,,,,,
#KRHM66IFYSCNQOTL3LVY5TUCIOQQ474IJFTXAMPAX5OBRSFXQ3RBSF6BJAB22BMKSILULRHLNBPL2
#\\\|QIWQ2YXVAHDTDR4YNQCOWPPE73R6SLD6IINQ2EEWBOT42KHWWPY \ / AMOS7 \ YOURUM ::
#\[7]ATWYZS4MH4GXZVKSIH2FG5FGZXEUN65EIZO5MZUFAQC45MXTLGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
