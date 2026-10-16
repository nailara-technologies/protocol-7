#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                ###
##  sys-deps zenka : no in-process probes                           ##
###                                                                ###

## drives the four real translated command modules                          ##
## [ sys-deps.cmd.check, .install, .missing, .state ] against an in-process ##
## %data / %code stub environment. sys-deps is a long-running zenka : it    ##
## must NEVER 'require' a probed perl module [                              ##
## AMOS7::deps::module::probe_module loads the module + its signal handlers ##
## into the zenka ] and must never build an in-process AptPkg::Cache        ##
## [ debp::probe_apt : ~0.4 s, ~70 MB, stale after any install ]. the       ##
## commands must use probe_module_file and pass the fresh flag to           ##
## probe_os_pkg -> debp::probe_apt_fresh. covers:                           ##
## - a declared pm dep that IS installed but NOT loaded stays OUT of %INC   ##
## while every command reports it present [ real probe_module_file ]        ##
## - AMOS7::deps::debp::probe_apt is stubbed to DIE : all four commands     ##
## still answer correctly -> the fresh path is used [ real dpkg-query ]     ##
## - MUTATION-CHECK : probe_module back in one command loads the module     ##
## [ the %INC assertion WOULD fail ] ; the fresh flag dropped in one        ##
## command hits the dying stub [ the stub-die assertion WOULD fail ]        ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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
use AMOS7::deps::module;
use AMOS7::deps::os_package;
use AMOS7::deps::debp;

##[ p7 runtime environment stubs ]############################################

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;

my $fail_count = 0;
my @LOGS;      ## [ level, message ] ##
my @ROUTES;    ## route-send parameter hashes ##

%code = (
    'base.logs' => sub {
        my $lvl = shift // 0;
        my $msg = shift // '';
        $msg = sprintf( $msg, @_ ) if @_;
        push @LOGS, [ $lvl, $msg ];
        return TRUE;
    },
    'protocol-7.route-send' => sub {
        my $param = shift;
        push @ROUTES, $param;
        return TRUE;
    },
);

##[ real-state probes : pick the fixtures from what is ACTUALLY here ]########

## an installed-but-NOT-loaded core module : all %INC assertions are on it ##
my $PRESENT_MODULE;
my @PM_CANDIDATES = qw|
    Text::Abbrev Text::ParseWords Search::Dict Pod::Escapes
    Term::Complete I18N::Collate Class::Struct
    |;
foreach my $candidate (@PM_CANDIDATES) {
    ( my $file = $candidate ) =~ s|::|/|g;
    $file .= '.pm';
    ## already loaded : cannot prove anything ##
    next if exists $INC{$file};
    next unless AMOS7::deps::module::probe_module_file($candidate);
    $PRESENT_MODULE = $candidate;
    last;
}
die "no installed-but-unloaded perl module found on this system"
    unless defined $PRESENT_MODULE;

( my $PM_FILE = $PRESENT_MODULE ) =~ s|::|/|g;
$PM_FILE .= '.pm';

## an installed debian package : the fresh-probe assertions are on it ##
my $PRESENT_PKG;
my @PKG_CANDIDATES
    = qw| perl-base dpkg coreutils libc6 base-files perl-modules-5.36 |;
foreach my $candidate (@PKG_CANDIDATES) {
    next unless AMOS7::deps::debp::probe_apt_fresh($candidate);
    $PRESENT_PKG = $candidate;
    last;
}
die "no installed debian package found on this system"
    unless defined $PRESENT_PKG;

##[ the cached apt probe must NEVER be used : it dies, the fresh one counts ]#

my $FRESH_CALLS = 0;
{
    no warnings 'redefine';
    my $real_probe_apt_fresh = \&AMOS7::deps::debp::probe_apt_fresh;
    *AMOS7::deps::debp::probe_apt = sub {
        die 'cached apt probe [ AptPkg::Cache ] used in-process';
    };
    *AMOS7::deps::debp::probe_apt_fresh = sub {
        $FRESH_CALLS++;
        return $real_probe_apt_fresh->(@_);
    };
}

##[ declared dependency state ]###############################################

my $MISSING_MODULE = 'Acme::Does::Not::Exist::P7Test';
my $MISSING_PKG    = 'libp7-probe-test-not-real';

my %PM_DEPS = (
    $PRESENT_MODULE => [ 'demo', 'clear' ],
    $MISSING_MODULE => ['demo'],
);
my %OS_DEPS = (
    'debian' => {
        $PRESENT_PKG => [ 'demo', 'clear' ],
        $MISSING_PKG => ['demo'],
    },
    'binary' => { 'sh' => ['demo'] },
);

$data{'system'}{'root_path'} = $main::root_path;
$data{'sys-deps'}{'pm_deps'} = \%PM_DEPS;
$data{'sys-deps'}{'os_deps'} = \%OS_DEPS;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

sub module_source {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    return $src;
}

sub compile_source {
    my ( $module_name, $src ) = @_;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    return $cref;
}

sub compile_module {
    my $module_name = shift;
    my $cref = compile_source( $module_name, module_source($module_name) );
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($_) foreach qw|
    sys-deps.cmd.check
    sys-deps.cmd.install
    sys-deps.cmd.missing
    sys-deps.cmd.state
    |;

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub module_still_unloaded {
    return not exists $INC{$PM_FILE};
}

##[ 1 : cmd.check -- reports present, module NOT loaded ]#####################

say ': sys-deps.cmd.check';

my $check_reply = $code{'sys-deps.cmd.check'}->( { 'args' => 'demo' } );
my $check_data  = $check_reply->{'data'} // '';

ok( ( $check_reply->{'mode'} // '' ) eq qw| size |,
    'check : reply mode is size' );
ok( index( $check_data, sprintf( ":    %-40s installed", $PRESENT_MODULE ) )
        >= 0,
    "check : $PRESENT_MODULE reported installed"
);
ok( index( $check_data, sprintf( ":    %-40s missing", $MISSING_MODULE ) )
        >= 0,
    "check : $MISSING_MODULE reported missing"
);
ok( index( $check_data, sprintf( ":    %-40s installed", $PRESENT_PKG ) )
        >= 0,
    "check : $PRESENT_PKG reported installed"
);
ok( index( $check_data, sprintf( ":    %-40s missing", $MISSING_PKG ) ) >= 0,
    "check : $MISSING_PKG reported missing"
);
ok( index( $check_data, ':  2 missing' ) >= 0,
    'check : two missing in total' );
ok( module_still_unloaded(),
    "check : $PRESENT_MODULE stayed OUT of %INC [ no in-process require ]" );

##[ 2 : cmd.missing -- only the absent ones listed, module NOT loaded ]#######

say ': sys-deps.cmd.missing';

my $missing_reply = $code{'sys-deps.cmd.missing'}->();
my $missing_data  = $missing_reply->{'data'} // '';

ok( index( $missing_data, ':  perl modules (1):' ) >= 0
        && index( $missing_data, ":    $MISSING_MODULE" ) >= 0,
    'missing : only the absent module is listed'
);
ok( index( $missing_data, $PRESENT_MODULE ) < 0,
    "missing : $PRESENT_MODULE NOT listed as missing"
);
ok( index( $missing_data, ':  OS packages (1):' ) >= 0
        && index( $missing_data, ":    $MISSING_PKG" ) >= 0,
    'missing : only the absent package is listed'
);
ok( index( $missing_data, ':  binaries (0):' ) < 0,
    'missing : no binary section header when nothing is missing' );
ok( module_still_unloaded(), "missing : $PRESENT_MODULE stayed OUT of %INC" );

##[ 3 : cmd.state -- counts, module NOT loaded ]##############################

say ': sys-deps.cmd.state';

my $state_reply = $code{'sys-deps.cmd.state'}->();
my $state_data  = $state_reply->{'data'} // '';

ok( index( $state_data, ':  perl modules declared: 2' ) >= 0,
    'state : two perl modules declared' );
ok( index( $state_data, ':  OS packages declared: 3' ) >= 0,
    'state : three OS packages declared [ debian x2 + binary x1 ]'
);
ok( index( $state_data, ':  missing perl modules: 1' ) >= 0,
    'state : one perl module missing' );
ok( index( $state_data, ':  missing OS packages: 1' ) >= 0,
    'state : one OS package missing' );
ok( index( $state_data, ':  missing binaries: 0' ) >= 0,
    'state : no missing binaries [ probe_binary path untouched ]'
);
ok( module_still_unloaded(), "state : $PRESENT_MODULE stayed OUT of %INC" );

##[ 4 : cmd.install [ zenka=clear ] -- nothing missing, nothing routed ]######

say ': sys-deps.cmd.install';

my $fresh_calls_before = $FRESH_CALLS;
my $install_reply
    = $code{'sys-deps.cmd.install'}->( { 'args' => 'zenka=clear' } );

ok( ( $install_reply->{'mode'} // '' ) eq qw| true |
        && ( $install_reply->{'data'} // '' ) eq 'no missing debian packages',
    'install [ clear zenka ] : nothing missing'
);
ok( scalar(@ROUTES) == 0,
    'install : no route-send -- no install was requested' );
ok( $FRESH_CALLS > $fresh_calls_before,
    'install : the fresh apt probe path was used' );
ok( module_still_unloaded(), "install : $PRESENT_MODULE stayed OUT of %INC" );

## the dying cached probe was never hit : every answer above came from the ##
## fresh path [ a single probe_apt call anywhere would have died the run ] ##

##[ 5 : MUTATION-CHECK -- the assertions really bite ]########################

say ': mutation-check';

## mutation A : probe_module_file -> probe_module in cmd.check [ in-memory ##
## recompile of the mutated source : the file on disk is never touched ]   ##
my $mut_a;
{
    my $src   = module_source('sys-deps.cmd.check');
    my $count = ( $src =~ s|probe_module_file|probe_module|g );
    die 'mutation A setup : expected exactly one probe_module_file call'
        unless $count == 1;
    $mut_a = compile_source( 'sys-deps.cmd.check', $src );
}
eval { $mut_a->( { 'args' => 'clear' } ) };
ok( exists $INC{$PM_FILE},
    "MUTATION A [ probe_module ] : $PRESENT_MODULE "
        . "GOT LOADED -- the %INC assertion WOULD have failed"
);
delete $INC{$PM_FILE};    ## restore the not-loaded state ##

## mutation B : the fresh flag dropped in cmd.missing -> probe_os_pkg falls ##
## back to the cached probe -> the stub dies                                ##
my $mut_b;
{
    my $src = module_source('sys-deps.cmd.missing');
    my $count
        = ( $src
            =~ s|probe_os_pkg\( \$pkg, \$type, 1 \)|probe_os_pkg( \$pkg, \$type )|g
        );
    die 'mutation B setup : expected exactly one fresh-flagged probe'
        unless $count == 1;
    $mut_b = compile_source( 'sys-deps.cmd.missing', $src );
}
my $mut_b_lived = eval { $mut_b->(); 1 };
ok( ( not $mut_b_lived ) and $EVAL_ERROR =~ m|cached apt probe.*in-process|,
    'MUTATION B [ fresh flag dropped ] : the cached probe_apt '
        . 'was hit and died -- the stub-die assertion WOULD have failed'
);

## restore : the real compiled commands still pass their %INC assertion ##
my $restore_reply = $code{'sys-deps.cmd.check'}->( { 'args' => 'demo' } );
ok( index( $restore_reply->{'data'} // '',
        sprintf( ":    %-40s installed", $PRESENT_MODULE ) ) >= 0
        && module_still_unloaded(),
    'restore : the un-mutated commands answer correctly and keep %INC clean'
);

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,,,,,,.,.,.,,.,,.,.,,,,,,..,,.,,.,.,..,,..,,...,...,,..,,,,,,,,,..,,,,,,
#3YA66PGRLOVGI3FFSPUN762A5J2ACW3GYJMJ7DCFCV4LHODNM3OMQPCDZRRZ4BFGWOWNPIQE56BF4
#\\\|YNATMUEWMZDHXPZF2ZM57CMUB3MVWMLDZIFPKNVLCCMLNIM225X \ / AMOS7 \ YOURUM ::
#\[7]DWRDX2DNAOZ3YDASCZAQS3SJA5YAIG3JNJIHRHWPDWPWPIVHWICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
