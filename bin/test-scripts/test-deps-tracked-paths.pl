#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                     ###
##  tracked-package list : the two previously unrecorded install paths   ##
###                                                                     ###

## drives the REAL translated module sources against an in-process %data /  ##
## %code stub environment :                                                 ##
## - src/os-pkg.handler.install_reply [ packages that INSTALLED OK are      ##
## recorded with source os-pkg, the backend type and the requesting zenka ; ##
## failed packages are never recorded ] + src/os-pkg.cmd.install            ##
## [ an optional zenka=<name> token is carried into the reply params ]      ##
## - src/base.perlmod.autoload + src/base.perlmod.load [ v7-zenki stage 2   ##
## auto-install branch : actually-installed debian \ cpan packages are      ##
## recorded with source perlmod-autoload, the real type and                 ##
## <system.zenka.name> ; a record failure [ unwritable var dir ] never      ##
## fails the install path ; nothing is recorded when the installer          ##
## installed nothing ]                                                      ##

## the installer itself is stubbed [ the stub  physically writes a real pm ##
## file so the post-install retry-load succeeds ] -- every assertion       ##
## re-reads var/sys-deps/tracked.yaml from disk MUTATION-CHECK : drop      ##
## either AMOS7::deps::tracked::record call site [                         ##
## os-pkg.handler.install_reply, base.perlmod.autoload,  base.perlmod.load ##
## ] and the matching assertions below FAIL                                ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;

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

use YAML::Tiny;
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use AMOS7::deps::tracked;

##[ p7 runtime environment stubs ]############################################

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;

my @LOGS;       ## [ level, message ] ##
my @REPLIES;    ## base.callback.cmd_reply [ reply_id, reply_hash ] ##
my @ROUTES;     ## protocol-7.route-send parameter hashes ##

%code = (
    'base.log'  => sub { push @LOGS, [ shift // 0, shift // '' ]; TRUE },
    'base.logs' => sub {
        my $lvl = shift // 0;
        my $msg = shift // '';
        $msg = sprintf( $msg, @_ ) if @_;
        push @LOGS, [ $lvl, $msg ];
        return TRUE;
    },
    'base.s_warn' => sub {
        my $msg = shift // '';
        $msg = sprintf( $msg, @_ ) if @_;
        push @LOGS, [ 0, $msg ];
        return TRUE;
    },
    'base.str.eval_error'     => sub { return "$EVAL_ERROR" },
    'base.format_error'       => sub { my $e = shift // ''; return "$e" },
    'base.ntime.b32'          => sub { return qw| FAKETIME32 | },
    'base.callback.cmd_reply' => sub {
        my ( $reply_id, $reply ) = @ARG;
        push @REPLIES, [ $reply_id, $reply ];
        return TRUE;
    },
    'protocol-7.route-send' => sub {
        my $param = shift;
        push @ROUTES, $param;
        return TRUE;
    },
    'base.perlmod.load'   => sub { return TRUE },
    'base.perlmod.loaded' =>
        sub { my $m = shift; return $main::LOADED{$m} // 0 },
    'base.perlmod.register_loaded_module'   => sub {TRUE},
    'base.perlmod.unregister_loaded_module' => sub {TRUE},
);

##[ stubbed installer : writes a REAL pm file so the retry-load succeeds ]####

my $install_lib = tempdir( CLEANUP => 1 );
unshift @INC, $install_lib;

## module => hashref returned by base.perlmod.install ##
our %INSTALL_RESULT;

$code{'base.perlmod.install'} = sub {
    my $module = shift;

    ## physically install the module into the temp lib           ##
    ## [ the real installer makes the retry-load below succeed ] ##
    my $rel = $module;
    $rel =~ s|::|/|g;
    my $pm_path = File::Spec->catfile( $install_lib, "$rel.pm" );
    make_path( ( File::Spec->splitpath($pm_path) )[1] );
    open my $fh, '>', $pm_path or die "stub install of $module : $OS_ERROR";
    print {$fh} "package $module;\n1;\n";
    close $fh;

    return $INSTALL_RESULT{$module}
        // { 'installed_deb' => [], 'installed_cpan' => [] };
};

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

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

compile_module($_) foreach qw|
    os-pkg.handler.install_reply
    os-pkg.cmd.install
    base.perlmod.autoload
    base.perlmod.load
    |;

##[ data initialization ]#####################################################

$data{'system'}{'root_path'}             = $main::root_path;
$data{'system'}{'zenka'}{'name'}         = 'v7-zenki';
$data{'system'}{'amos-zenka-user'}       = 'nobody';
$data{'base'}{'perlmod'}{'auto_install'} = TRUE;

my $sandbox = tempdir( CLEANUP => 1 );

## fresh temp root with an empty var/sys-deps directory ##

sub fresh_root {
    my $root = File::Spec->catdir( $sandbox,
        'root-' . $PID . '-' . int( rand 1_000_000_000 ) );
    make_path( File::Spec->catdir( $root, qw| var sys-deps | ) );
    return $root;
}

## entries exactly as they sit on disk [ re-parse, never trust returns ] ##

sub entries_on_disk {
    my ($root) = @_;
    my $yaml = eval {
        YAML::Tiny->read( AMOS7::deps::tracked::track_file($root) );
    };
    return undef unless defined $yaml && ref $yaml->[0] eq 'HASH';
    return $yaml->[0]->{'tracked'} // [];
}

## single entry for a package [ undef when absent ] ##

sub entry_for {
    my ( $root, $pkg ) = @_;
    my ($entry)
        = grep { ref $_ eq 'HASH' and ( $_->{'pkg'} // '' ) eq $pkg }
        @{ entries_on_disk($root) // [] };
    return $entry;
}

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ 1 : os-pkg.handler.install_reply records the OK packages ]################

say ': os-pkg.handler.install_reply [ TRUE reply ]';

my $os_root = fresh_root();
$data{'system'}{'root_path'} = $os_root;

@REPLIES = ();
$code{'os-pkg.handler.install_reply'}->(
    {   'cmd'       => qw| TRUE |,
        'call_args' => { 'args' => 'installed : libone-perl libtwo-perl' },
        'params'    => {
            'packages' => [qw| libone-perl libtwo-perl |],
            'backend'  => qw| debian |,
            'zenka'    => 'weather',
            'reply_id' => 42
        }
    }
);

ok( ( scalar @{ entries_on_disk($os_root) // [] } ) == 2,
    'TRUE reply : both installed packages land on disk'
);

my $entry = entry_for( $os_root, 'libone-perl' );
ok(
    (           defined $entry
            and $entry->{'type'} eq 'debian'
            and $entry->{'source'} eq 'os-pkg'
            and $entry->{'zenka'} eq 'weather'
            and $entry->{'installed_at'} eq 'FAKETIME32'
            and not $entry->{'declared'}
    ),
    'recorded entry keeps source os-pkg, backend type, zenka + timestamp'
);

$entry = entry_for( $os_root, 'libtwo-perl' );
ok( ( defined $entry and $entry->{'type'} eq 'debian' ),
    'second package recorded with the backend type'
);

ok(
    (           scalar @REPLIES == 1
            and $REPLIES[0][0] == 42
            and $REPLIES[0][1]{'mode'} eq qw| true |
    ),
    'the deferred reply still completes the original caller'
);

##[ 2 : a FALSE reply records nothing ]#######################################

say ': os-pkg.handler.install_reply [ FALSE reply ]';

@REPLIES = ();
$code{'os-pkg.handler.install_reply'}->(
    {   'cmd'       => qw| FALSE |,
        'call_args' => { 'args' => 'install failed [ exit 1 ]' },
        'params'    => {
            'packages' => [qw| libbad-perl |],
            'backend'  => qw| debian |,
            'zenka'    => 'weather',
            'reply_id' => 43
        }
    }
);

ok( ( not defined entry_for( $os_root, 'libbad-perl' ) ),
    'FALSE reply : the failed package is never recorded'
);
ok( ( scalar @{ entries_on_disk($os_root) // [] } ) == 2,
    'FALSE reply : the tracked list is untouched'
);
ok( ( scalar @REPLIES == 1 and $REPLIES[0][1]{'mode'} eq qw| false | ),
    'FALSE reply : the deferred reply reports the failure'
);

##[ 3 : os-pkg.cmd.install carries an optional zenka=<name> ]#################

say ': os-pkg.cmd.install [ zenka=<name> pass-through ]';

$data{'os-pkg'}{'backend_type'} = 'debian';
$data{'os-pkg'}{'os_release'}   = { 'ID' => 'debian' };

@ROUTES = ();
my $cmd_reply = $code{'os-pkg.cmd.install'}
    ->( { 'args' => 'libone-perl zenka=weather', 'reply_id' => 7 } );

ok( ( $cmd_reply->{'mode'} eq qw| deferred | and scalar @ROUTES == 1 ),
    'install with zenka= : deferred, one route sent' );

my $rparams = $ROUTES[0]->{'reply'}{'params'} // {};
ok(
    (           ( $rparams->{'zenka'} // '' ) eq 'weather'
            and grep { $_ eq 'libone-perl' } @{ $rparams->{'packages'} // [] }
            and not grep {m|^zenka=|} @{ $rparams->{'packages'} // [] }
    ),
    'zenka= is carried in the reply params, not treated as a package'
);

@ROUTES = ();
$code{'os-pkg.cmd.install'}->( { 'args' => 'libone-perl', 'reply_id' => 8 } );
ok( ( not defined $ROUTES[0]->{'reply'}{'params'}{'zenka'} ),
    'install without zenka= : the reply params carry an undefined zenka'
);

##[ 4 : perlmod auto-install records debian + cpan with the real type ]#######

say ': base.perlmod.autoload [ stage 2 auto-install ]';

my $pm_root = fresh_root();
$data{'system'}{'root_path'} = $pm_root;

%INSTALL_RESULT = (
    'TrackedTest::ViaApt' => {
        'installed_deb'  => ['libtracked-apt-perl'],
        'installed_cpan' => []
    },
    'TrackedTest::ViaCpan' => {
        'installed_deb'  => [],
        'installed_cpan' => ['TrackedTest::ViaCpan']
    },
);

my $auto_result = $code{'base.perlmod.autoload'}->('TrackedTest::ViaApt');
ok( $auto_result,
    'autoload : the retry-load succeeds after the stubbed install' );

$entry = entry_for( $pm_root, 'libtracked-apt-perl' );
ok(
    (           defined $entry
            and $entry->{'type'} eq 'debian'
            and $entry->{'source'} eq 'perlmod-autoload'
            and $entry->{'zenka'} eq 'v7-zenki'
            and $entry->{'installed_at'}
            =~ m|^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$|
    ),
    'apt-installed package recorded as '
        . 'type debian [ source perlmod-autoload ]'
);

$code{'base.perlmod.load'}->('TrackedTest::ViaCpan');
$entry = entry_for( $pm_root, 'TrackedTest::ViaCpan' );
ok(
    (           defined $entry
            and $entry->{'type'} eq 'cpan'
            and $entry->{'source'} eq 'perlmod-autoload'
            and $entry->{'zenka'} eq 'v7-zenki'
            and $entry->{'family'} eq 'cpan'
    ),
    'cpanm-installed module recorded as type cpan via the load path'
);

##[ 5 : nothing recorded when the installer installed nothing ]###############

say ': perlmod auto-install [ install happened = empty ]';

%INSTALL_RESULT = (
    'TrackedTest::NoInstall' => {
        'installed_deb'  => [],
        'installed_cpan' => []
    },
);

my $before = scalar @{ entries_on_disk($pm_root) // [] };
$code{'base.perlmod.autoload'}->('TrackedTest::NoInstall');
ok( ( scalar @{ entries_on_disk($pm_root) // [] } ) == $before,
    'an install that added nothing records nothing [ shared module guard ]'
);

##[ 6 : a record failure never fails the install path ]#######################

say ': perlmod auto-install [ unwritable var dir ]';

if ( $UID == 0 ) {
    say '  skip : record-failure scenario needs a non-root test user';
} else {
    my $ro_root = fresh_root();
    my $ro_dir  = File::Spec->catdir( $ro_root, qw| var sys-deps | );
    chmod 0555, $ro_dir or die "chmod : $OS_ERROR";
    $data{'system'}{'root_path'} = $ro_root;

    @LOGS = ();

    ## the install reports a REAL cpan install : the record attempt runs ##
    ## against the unwritable var dir and must only log + go on          ##
    $INSTALL_RESULT{'TrackedTest::FailRec'} = {
        'installed_deb'  => [],
        'installed_cpan' => ['TrackedTest::FailRec']
    };

    $code{'base.perlmod.load'}->('TrackedTest::FailRec');

    ok( ( not defined entry_for( $ro_root, 'TrackedTest::FailRec' ) ),
        'unwritable var dir : nothing lands on disk' );
    ok( ( scalar grep { $ARG->[0] == 1 } @LOGS ) > 0,
        'unwritable var dir : the failure is logged at level 1'
    );

    ## the retry-load result itself is untouched : the install path only ##
    ## logs and goes on -- proven by the module now loading cleanly      ##
    $main::LOADED{'TrackedTest::FailRec'} = 0;
    my $retry_ok = $code{'base.perlmod.load'}->('TrackedTest::FailRec');
    ok( $retry_ok,
        'unwritable var dir : the install path itself did not fail' );

    chmod 0755, $ro_dir or die "chmod : $OS_ERROR";
    $data{'system'}{'root_path'} = $pm_root;
}

## summary ##

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,..,,,.,,..,,...,,.,,.,.,,,.,,,.,,.,,.,,,..,,...,..,,...,..,,,.,,,.,,.,.,
#RE6T27BT2GUAPNGR2J7DMUTP3IGH3VKQUVBU2SGVA7BKHQN35O3BR6ZDWVSVL475SSBJNPC6JZCEE
#\\\|TQFPPQ2WCE7A4GV5JXGLEY2YT3ABTKJJ44BWVFQ2GD6BYGTGCM3 \ / AMOS7 \ YOURUM ::
#\[7]AX5NKMEFCU5K5SRULGOUITERYLJE3ZZQGUI2BCZ276Q5CC66YIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
