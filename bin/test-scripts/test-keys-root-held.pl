#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## host-root delegation, lane 2 [ HOST-ROOT-DELEGATION.md, "root-held keys" ##
## + "resolver API" ] : the REAL keys.console.* \ keys.backup.* \           ##
## p7-log.anon.key modules are compiled against a STUB of the resolver      ##
## crypt.C25519.key_path [ API as in the spec ]. checks :                   ##
## - `list` groups root-held keys, names + files as root, only a note as    ##
## non-root [ and never opens the root dir then ]                           ##
## - every operation on a root-held key refuses as non-root, BEFORE any     ##
## password prompt \ key load \ file change                                 ##
## - a user key is never refused, root passes the guard                     ##
## - keys.backup.list includes root/ only as root, restore keeps owner \    ##
## mode and refuses a cross-directory restore                               ##
## - p7-log.anon.key resolves its secret through the resolver the process   ##
## cannot become root : in the compiled sources the effective uid variable  ##
## is swapped for $main::fake_euid [ test-only rewrite ].  every key dir is ##
## a File::Temp tempdir. no zenka started \ reloaded.                       ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use File::Temp            qw| tempdir |;
use List::Util            qw| max uniq |;

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
use Crypt::Misc qw| encode_b32r decode_b32r |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;
our %colors;

our $fake_euid = 1000;

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
## a bare list-context stat or a sysread on a default handle fails here too ##
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
    ## test-only : the effective uid is faked, see header ##
    $translated =~ s{\$EFFECTIVE_USER_ID}{\$main::fake_euid}g;
    ## the runtime : File::stat object stat + :utf8 default open layer ##
    my $cref = eval "$runtime_pragmas sub {\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## run a compiled module with stdout captured, trapping base.exit ##
sub run_module {
    my ( $module_name, @args ) = @ARG;
    my $out = '';
    open( my $fh, '>', \$out ) or die;
    my $old = select($fh);
    my @ret = eval { $code{$module_name}->(@args) };
    my $err = $EVAL_ERROR;
    select($old);
    close($fh);
    return ( \@ret, $err, $out );
}

## --- tempdir key tree : <backend>/user-keys [ user ] and /root [ root ] ##
my $tmp      = tempdir( CLEANUP => 1 );
my $user_dir = catfile( $tmp,      'user-keys' );
my $root_dir = catfile( $user_dir, 'root' );
mkdir($user_dir)         or die;
mkdir( $root_dir, 0700 ) or die;

sub put_file {
    my ( $path, $content, $mode ) = @ARG;
    open( my $fh, '>', $path ) or die "cannot write $path : $!";
    print $fh $content;
    close($fh);
    chmod( $mode // 0600, $path );
}

put_file( catfile( $user_dir, 'tester.base.public' ),  "PUBUSER\n" );
put_file( catfile( $user_dir, 'tester.base.private' ), "PRIVUSER\n" );
put_file( catfile( $root_dir, 'host-root.public' ),    "PUBROOT\n", 0644 );
put_file( catfile( $root_dir, 'host-root.secret' ),         "SECROOT\n" );
put_file( catfile( $root_dir, 'AAAB.host-root.secret' ),    "OLDSECROOT\n" );
put_file( catfile( $user_dir, 'AAAC.tester.base.private' ), "OLDPRIV\n" );

sub same {    ## deep compare of two snapshot hashes ##
    my ( $x, $y ) = @ARG;
    return FALSE if keys %$x != keys %$y;
    foreach my $k ( keys %$x ) {
        return FALSE if not exists $y->{$k} or $x->{$k} ne $y->{$k};
    }
    return TRUE;
}

sub snapshot {    ## every file under the tree : name => mode:content ##
    my %snap;
    foreach my $dir ( $user_dir, $root_dir ) {
        opendir( my $dh, $dir ) or next;
        foreach my $name ( sort readdir($dh) ) {
            my $path = catfile( $dir, $name );
            next if not -f $path;
            open( my $fh, '<', $path ) or next;
            local $/;
            my $content = <$fh>;
            close($fh);
            $snap{$path} = sprintf '%04o:%s', ( stat($path) )[2] & 07777,
                $content;
        }
        closedir($dh);
    }
    return \%snap;
}

## --- stubs ---------------------------------------------------------- ##
my @logged;
$code{'base.logs'}       = sub { push @logged, [@ARG]; return };
$code{'base.log'}        = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}     = sub { push @logged, [@ARG]; return };
$code{'base.str.os_err'} = sub { return 'os-error' };
$code{'base.cnt_s'}      = sub { return $ARG[0] == 1 ? '' : 's' };
$code{'base.exit'}       = sub { die sprintf "EXIT:%s\n", $ARG[0] // '' };
$code{'base.sort'}       = sub {
    my $first = $ARG[0];
    return sort keys %$first if ref $first eq 'HASH';
    return sort @$first      if ref $first eq 'ARRAY';
    return sort @ARG;
};
$code{'base.reverse-sort'} = sub { return reverse sort @ARG };
$code{'base.ntime.b32'}    = sub {
    state $n = 0;
    return 'ZZ' . ( 'A' .. 'Z' )[ $n++ ];    ## base32 letters only ##
};
$code{'base.ntime.B32_2_unix'} = sub { return 1 };
$code{'base.perlmod.load'}     = sub {return};
$code{'file.slurp'}            = sub {
    my $path = shift;
    open( my $fh, '<', $path ) or return undef;
    local $/;
    my $content = <$fh>;
    close($fh);
    return \$content;
};

## the resolver stub, per the spec API : holder 'root' when <name> is a ##
## root-held key [ test table ], key_dir / key_filename inside the tree ##
my %holder_of = ( 'host-root' => 'root' );
my $unresolvable;
my @key_path_calls;
$code{'crypt.C25519.root_key_dir'} = sub { return $root_dir };
$code{'crypt.C25519.key_path'}     = sub {
    my $name = shift;
    push @key_path_calls, $name;
    return undef if defined $unresolvable and $name eq $unresolvable;
    my $holder = $holder_of{$name} // 'user';
    my $dir    = $holder eq 'root' ? $root_dir : $user_dir;
    my $base   = catfile( $dir, $name );
    return {
        key_dir      => $dir,
        key_basepath => $base,
        key_filename => {
            secret  => "$base.secret",
            private => "$base.private",
            public  => "$base.public",
            virtual => "$base:seed-phrase",
        },
        holder => $holder,
    };
};
my @key_vars_calls;
$code{'crypt.C25519.key_vars'} = sub {
    my $name = shift;
    push @key_vars_calls, $name;
    die "PASSED_GUARD\n" if $main::stop_at_key_vars;
    my $kp = $code{'crypt.C25519.key_path'}->( $name // 'tester.base' );
    return { %$kp, usr_name => 'tester' };
};
our $stop_at_key_vars = 0;

## anything a guarded operation must NOT reach before refusing : counted ##
my %reached;
foreach my $name (
    qw| encrypted_key load_keypair write_keys key_is_virtual
    list_key_signature_names chk_key_dir load_keys_from_secret
    del_keys_hash_entry unload_key |
) {
    $code{"crypt.C25519.$name"} = sub {
        $reached{$name}++;
        die "PASSED_GUARD\n";
    };
}
$code{'crypt.C25519.clear_chksums'} = sub {return};
my %exists;
$code{'crypt.C25519.key_exists'} = sub { return $exists{ $ARG[0] } // TRUE };
$code{'crypt.C25519.signature_exists'}  = sub { return 3 };
$code{'crypt.C25519.validate_keyname'}  = sub { return 1 };
$code{'crypt.C25519.key_name_and_type'} = sub {
    return ( $1, $2 ) if $ARG[0] =~ m{^(.+)\.(secret|private|public)$};
    return undef;
};
$code{'crypt.C25519.get_keyname'} = sub {
    return $1 if $ARG[0] =~ m{^(.+)\.(?:secret|private|public)$};
    return $1 if $ARG[0] =~ m{^([^/]+):seed-phrase$};
    return undef;
};
$code{'keys.get_keyfiles'} = sub {
    return map { catfile( $user_dir, $ARG ) }
        grep { -f catfile( $user_dir, $ARG ) } do {
        opendir( my $dh, $user_dir ) or die;
        sort readdir($dh);
        };
};
$code{'keys.list_remote_keys'} = sub { return {} };
$code{'file.all_files'}        = sub {
    my $dir = shift;
    push @main::scanned_dirs, $dir;
    opendir( my $dh, $dir ) or return undef;
    my @files = map { catfile( $dir, $ARG ) }
        grep { -f catfile( $dir, $ARG ) } sort readdir($dh);
    closedir($dh);
    return \@files;
};
our @scanned_dirs;

$data{'keys'}{'regex'} = {
    key_files => qr{\.(?:secret|private|public)},
    key_file  => {
        public  => qr{^(.+)\.public$},
        private => qr{^(.+)\.private$},
        secret  => qr{^(.+)\.secret$},
    },
    key_sig => { signature => qr{^NOSIG(.)(.)$} },
};
$data{'crypt'}{'C25519'}{'regex'}{'key_name'} = qr{[a-z0-9\.\-]+};
$data{'keys'}{'bin_path'}{'shred'} = '';

## prompts : proof that a refusal comes first ##
my $prompted = 0;
{
    no warnings qw| redefine once |;
    *AMOS7::TERM::read_password_single   = sub { $prompted++; return 'pw' };
    *AMOS7::TERM::read_password_repeated = sub { $prompted++; return 'pw' };
}
{
    no strict 'refs';
    *{'main::last_existing_directory'} = sub { return $ARG[0] };
}

## compile the real modules -------------------------------------------- ##
my @console_modules = qw|
    change-passwd enc-key dec-key downgrade-enc-status split-keypair
    get-encoded-key enc-key-chksum remove remove-type remove-signature
    sign-key rename duplicate decrypt-archive list encoding-upgrade
    |;
compile_module("keys.console.$ARG") for @console_modules;
compile_module("keys.backup.$ARG")
    for qw| create restore rollback remove list |;
compile_module('p7-log.anon.key');

## === 1. operations : refusal as non-root, pass otherwise ============= ##
say '';
say ':: guard : every operation on a root-held key';

## module, args, what the root-held name is in the args ##
my @ops = (
    [ 'keys.console.change-passwd',        ['host-root'],      'host-root' ],
    [ 'keys.console.enc-key',              ['host-root'],      'host-root' ],
    [ 'keys.console.dec-key',              ['host-root'],      'host-root' ],
    [ 'keys.console.downgrade-enc-status', ['host-root'],      'host-root' ],
    [ 'keys.console.split-keypair',        ['host-root'],      'host-root' ],
    [ 'keys.console.get-encoded-key',      ['host-root'],      'host-root' ],
    [ 'keys.console.enc-key-chksum',       ['host-root'],      'host-root' ],
    [ 'keys.console.remove',               ['host-root'],      'host-root' ],
    [ 'keys.console.remove-type',      ['host-root secret'],   'host-root' ],
    [ 'keys.console.remove-signature', ['host-root sk'],       'host-root' ],
    [ 'keys.console.sign-key',         ['rk host-root'],       'host-root' ],
    [ 'keys.console.sign-key',         ['host-root x'],        'host-root' ],
    [ 'keys.console.rename',           ['host-root new-name'], 'host-root' ],
);
my $before = snapshot();

foreach my $op (@ops) {
    my ( $mod, $args, $root_name ) = @$op;
    my $label = sprintf '%s [ %s ]', $mod, $args->[0];

    ## non-root, root-held : refused before anything else ##
    $fake_euid        = 1000;
    %reached          = ();
    $prompted         = 0;
    $stop_at_key_vars = 0;
    my ( $ret, $err, $out ) = run_module( $mod, @$args );
    ok( scalar( $err =~ m{^EXIT:00?20\n} ),
        "$label : non-root " . "refused [ exit 0020 ]" )
        or say "       err=[$err] out=[$out]";
    ok( scalar( $out =~ m{root-held : refused} ), "$label : clear message" );
    ok( !%reached && !$prompted, "$label : nothing reached before refusal" );

    ## root, root-held : guard passes ##
    $fake_euid        = 0;
    %reached          = ();
    $stop_at_key_vars = 1;
    ( $ret, $err, $out ) = run_module( $mod, @$args );
    ok( scalar( $err =~ m{^PASSED_GUARD\n} ),
        "$label : root passes the guard"
    ) or say "       err=[$err] out=[$out]";

    ## non-root, user key [ same module, other name ] : not refused ##
    $fake_euid = 1000;
    %reached   = ();
    my @user_args = map {s{host-root}{tester.base}gr} @$args;
    ( $ret, $err, $out ) = run_module( $mod, @user_args );
    ok( scalar( $err =~ m{^PASSED_GUARD\n} ),
        "$label : user key not refused"
    ) or say "       err=[$err] out=[$out]";

    ## key path not resolvable : refused, even as root ##
    $fake_euid        = 0;
    $unresolvable     = 'host-root';
    $stop_at_key_vars = 0;
    ( $ret, $err, $out ) = run_module( $mod, @$args );
    ok( scalar( $err =~ m{^EXIT:} ) && scalar( $out =~ m{not resolvable} ),
        "$label : unresolvable key path refused" )
        or say "       err=[$err] out=[$out]";
    undef $unresolvable;
}
$fake_euid = 1000;
ok( same( snapshot(), $before ),
    'key tree unchanged by ' . 'all refused operations' );

## sign-key : the signer position is guarded too is covered above [ both ##
## argument orders ]                                                     ##

## duplicate : a root-held SOURCE is refused for everyone ##
say '';
say ':: duplicate : root-held source never copied';
foreach my $euid ( 1000, 0 ) {
    $fake_euid = $euid;
    $exists{'new-name'} = 0;
    my ( $ret, $err, $out )
        = run_module( 'keys.console.duplicate', 'host-root new-name' );
    ok( scalar( $err =~ m{^EXIT:0020} )
            && scalar( $out =~ m{cannot be duplicated} ),
        "duplicate host-root : refused at euid $euid"
    ) or say "       err=[$err] out=[$out]";
}

## encoding-upgrade : root-held keys are not its business, for everyone ##
say '';
say ':: encoding-upgrade : root-held name refused';
foreach my $euid ( 1000, 0 ) {
    $fake_euid = $euid;
    my ( $ret, $err, $out )
        = run_module( 'keys.console.encoding-upgrade', 'host-root' );
    ok( scalar( $err =~ m{^EXIT:0020} )
            && scalar( $out =~ m{not handled by encoding-upgrade} ),
        "encoding-upgrade host-root : refused at euid $euid"
    ) or say "       err=[$err] out=[$out]";
}
$fake_euid        = 1000;
$stop_at_key_vars = 1;
$exists{'other'}  = 0;
{
    my ( $ret, $err, $out )
        = run_module( 'keys.console.duplicate', 'tester.base other' );
    ok( scalar( $err =~ m{^PASSED_GUARD} ),
        'duplicate of a ' . 'user key not refused'
    ) or say "       err=[$err] out=[$out]";
}
$stop_at_key_vars = 0;
%exists           = ();

## remove 'known:' category : a pin is not a key of the root dir ##
{
    $fake_euid        = 1000;
    $stop_at_key_vars = 1;
    my ( $ret, $err, $out )
        = run_module( 'keys.console.remove', 'known:host-root' );
    ok( scalar( $err =~ m{^PASSED_GUARD} ),
        'remove known:<name> ' . 'is not refused'
    ) or say "       err=[$err] out=[$out]";
    $stop_at_key_vars = 0;
}

## rename : uses the SOURCE key's vars, not the base key's ##
{
    @key_vars_calls   = ();
    $fake_euid        = 1000;
    $stop_at_key_vars = 1;
    run_module( 'keys.console.rename', 'tester.base other' );
    ok( ( grep { defined $ARG and $ARG eq 'tester.base' } @key_vars_calls )
            == 1,
        'rename : key_vars is asked for the source key by name'
    );
    $stop_at_key_vars = 0;
}

## decrypt-archive : an entry named like a root-held key is refused ##
say '';
say ':: decrypt-archive';
{
    my $archive = catfile( $tmp, 'archive.bin' );
    put_file( $archive, "x\n" );
    $data{'crypt'}{'C25519'}{'keys'}{'sizetype'}{32} = {};
    my $entries = { 'host-root.secret' => 'x' x 32 };
    $code{'keys.read_key_archive'}    = sub { return $entries };
    $code{'keys.select_archive_path'} = sub { return $archive };
    foreach my $euid ( 1000, 0 ) {
        $fake_euid        = $euid;
        $stop_at_key_vars = 0;
        my $b = snapshot();
        my ( $ret, $err, $out )
            = run_module( 'keys.console.decrypt-archive', $archive );
        ok( scalar( $err =~ m{^EXIT:0110} ),
            "archive naming a root-held key refused at euid $euid" )
            or say "       err=[$err] out=[$out]";
        ok( ( same( snapshot(), $b ) ), '  no file written' );
    }
    ## a normal entry is not refused by the root-held rule ##
    $entries          = { 'tester.base.secret' => 'y' x 32 };
    $fake_euid        = 1000;
    $stop_at_key_vars = 1;
    my ( $ret, $err, $out )
        = run_module( 'keys.console.decrypt-archive', $archive );
    ok( scalar( $err =~ m{^PASSED_GUARD} ),
        'archive of user ' . 'keys passes the rule'
    ) or say "       err=[$err] out=[$out]";
    $stop_at_key_vars = 0;
}

## === 2. listing ====================================================== ##
say '';
say ':: list : root-held group';

{
    $fake_euid    = 0;
    @scanned_dirs = ();
    my ( $ret, $err, $out ) = run_module( 'keys.console.list', ':nosums:' );
    ok( !$err, 'list as root runs' ) or say "       err=[$err]";
    ok( scalar( $out =~ m{'host-root' \[ root-held \]} ),
        'root : host-root listed as its own [ root-held ] group'
    );
    ok( scalar( $out =~ m{host-root\.secret} )
            && scalar( $out =~ m{host-root\.public} ),
        'root : root-held key files shown'
    );
    ok( scalar( $out =~ m{'tester\.base'} ),
        'root : user keys still listed' );
    my ($user_part) = $out =~ m{^(.*?)^[^\n]*\[ root-held \]}ms;
    ok( defined $user_part && $user_part !~ m{host-root},
        'root : root-held files are not mixed into the user group'
    );
    ok( $out !~ m{not readable}, 'root : no "not readable" note' );

    $fake_euid = 1000;
    ( $ret, $err, $out ) = run_module( 'keys.console.list', ':nosums:' );
    ok( !$err, 'list as non-root runs' ) or say "       err=[$err]";
    ok( scalar( $out =~ m{root-held : not readable as tester} ),
        'non-root : "root-held : not readable as <user>"'
    );
    ok( $out !~ m{host-root}, 'non-root : no root-held key name shown' );
    ok( !( grep { $ARG eq $root_dir } @scanned_dirs ),
        'non-root : the root dir is never listed'
    );
}

## === 3. backups ====================================================== ##
say '';
say ':: backups';

{
    $fake_euid    = 1000;
    @scanned_dirs = ();
    my $list = $code{'keys.backup.list'}->();
    ok( ( grep { $ARG->{'key_name'} eq 'tester.base' } @$list ) == 1
            && !( grep { $ARG->{'key_name'} eq 'host-root' } @$list ),
        'non-root : backup list has user backups only'
    );
    ok( !( grep { $ARG eq $root_dir } @scanned_dirs ),
        'non-root : root dir not scanned by the backup list'
    );
    my $root_named = $code{'keys.backup.list'}->('host-root');
    ok( ref $root_named eq 'ARRAY' && !@$root_named,
        'non-root : backups of a root-held name : empty, nothing read' );

    $fake_euid = 0;
    $list      = $code{'keys.backup.list'}->();
    ok(
        (   grep {
                        $ARG->{'key_name'} eq 'host-root'
                    and $ARG->{'holder'} eq 'root'
            } @$list
            ) == 1
            && (
            grep {
                        $ARG->{'key_name'} eq 'tester.base'
                    and $ARG->{'holder'} eq 'user'
            } @$list
            ) == 1,
        'root : backup list includes root/ with holder tags'
    );
    $list = $code{'keys.backup.list'}->('host-root');
    ok( @$list == 1 && $list->[0]{'holder'} eq 'root',
        'root : backups filtered to a root-held name'
    );

    ## non-root : create \ restore \ rollback \ remove refuse ##
    $fake_euid = 1000;
    my $b = snapshot();
    ok( !defined $code{'keys.backup.create'}->( 'host-root', [qw| secret |] ),
        'non-root : backup create of a root-held key refused'
    );
    ok( !defined $code{'keys.backup.restore'}->( 'host-root', 'secret' ),
        'non-root : backup restore refused' );
    ok( !defined $code{'keys.backup.remove'}
            ->( 'host-root', 'secret', 'AAAB.host-root.secret' ),
        'non-root : backup remove refused'
    );
    ok( !$code{'keys.backup.rollback'}->(
            'host-root',
            { secret => catfile( $root_dir, 'AAAB.host-root.secret' ) }
        ),
        'non-root : backup rollback refused'
    );
    ok( same( snapshot(), $b ), 'non-root : nothing on disk changed' );

    ## root : create + restore stay inside root/, owner [ us ] and mode ##
    $fake_euid = 0;
    my $paths
        = $code{'keys.backup.create'}->( 'host-root', [qw| secret public |] );
    ok( ref $paths eq 'HASH'
            && keys %$paths == 2
            && !( grep { index( $ARG, "$root_dir/" ) != 0 } values %$paths ),
        'root : backups of a root-held key are made inside root/'
    );
    ok( !-e catfile( $root_dir, 'host-root.secret' ),
        '  live file moved aside [ rename, never copy ]'
    );
    my $restored = $code{'keys.backup.restore'}
        ->( 'host-root', 'secret', ( $paths->{'secret'} =~ s|^.*/||r ) );
    ok( defined $restored
            && $restored eq catfile( $root_dir, 'host-root.secret' ),
        'root : restore puts the file back in root/'
    );
    ok( ( stat($restored) )[2] % 01000 == 0600,
        '  restore keeps the 0600 mode [ rename ]'
    );
    ok( ( stat($restored) )[4] == $UID, '  restore keeps the owner' );

    ## cross-directory restore refused : a user-dir backup of a name that ##
    ## is root-held                                                       ##
    put_file( catfile( $user_dir, 'AAAD.host-root.secret' ), "SHADOW\n" );
    $b        = snapshot();
    $restored = $code{'keys.backup.restore'}
        ->( 'host-root', 'secret', 'AAAD.host-root.secret' );
    ok( !defined $restored,
        'restore refused when the ' . 'backup is in another directory' );
    ok( same( snapshot(), $b ), '  nothing moved' );
    ## the same with a list that DOES offer the foreign-directory entry ##
    {
        my $real_list = $code{'keys.backup.list'};
        my $shadow    = catfile( $user_dir, 'AAAD.host-root.secret' );
        $code{'keys.backup.list'} = sub {
            return [
                {   key_name => 'host-root',
                    type     => 'secret',
                    basename => 'AAAD.host-root.secret',
                    path     => $shadow,
                }
            ];
        };
        $restored = $code{'keys.backup.restore'}
            ->( 'host-root', 'secret', 'AAAD.host-root.secret' );
        $code{'keys.backup.list'} = $real_list;
        ok( !defined $restored && -f $shadow,
            'restore refuses a backup from another directory [ offered ]' );
        ok( same( snapshot(), $b ), '  nothing moved' );
    }
    unlink catfile( $user_dir, 'AAAD.host-root.secret' );
}

## === 4. p7-log.anon.key goes through the resolver ==================== ##
say '';
say ':: p7-log.anon.key';

{
    my $secret_path = catfile( $user_dir, 'logger.base.secret' );
    put_file( $secret_path, encode_b32r( 'U:' . ( 'k' x 32 ) ) . "\n" );
    $data{'p7-log'}{'anon'}{'key_name'} = 'logger.base';
    delete $data{'p7-log'}{'anon'}{'key32'};
    @key_path_calls = ();
    my $key = $code{'p7-log.anon.key'}->();
    ok( defined $key && length($key) == 32,
        'secret read from ' . 'the resolved path'
    );
    ok( ( grep { $ARG eq 'logger.base' } @key_path_calls ) == 1,
        '  the resolver was asked for the key name'
    );

    ## a root-held name : the resolved path is in root/, absent here ##
    $holder_of{'logger.base'} = 'root';
    delete $data{'p7-log'}{'anon'}{'key32'};
    my $none = $code{'p7-log.anon.key'}->();
    ok( !defined $none,
        'a root-held key name resolves ' . 'into root/ : no key used' );
    delete $holder_of{'logger.base'};
}

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,,,,,,.,..,,.,,,,.,,,,,,...,,,.,,.,,,..,..,,...,...,,.,,,,,,,,.,,,.,.,,,
#QNTQHLTYGGHTDYKV44GSPKFPOGBCY2DPPQJ7QRRUFM4YFVS5T7V7RGTZTWAB64HO3CO4B7UBMXRQA
#\\\|X3OI74V6VL3ESXIHMJZ7P3D3ESFGGBV7KWIOWLF3KCKZ7WG7OR7 \ / AMOS7 \ YOURUM ::
#\[7]MBHRRGOP6H34I2IWMUGBCRRIP6XSDVMBDFQX2WMGIF7HP5JKBECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
