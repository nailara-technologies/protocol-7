#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                ###
## OS-family backend interface + dispatch in  AMOS7::deps::os_package ##
###                                                                ###

## covers, with REAL STATE ONLY [ return values, %INC, stub call logs ] :
## - the debian backend calls reach AMOS7::deps::debp with the right args
## [ probe $fresh selection, install pass-through ] and the results pass
## through unchanged
## - probe_os_pkg \ install_os_pkgs dispatch by FAMILY NAME : a TEST-ONLY
## backend module [ AMOS7::deps::backend::testfam, written into a temp dir on
## @INC at run time ] works with NO mention of its family in os_package.pm
## - unknown family : probe -> 0, install -> { ok => [], failed => [], manual
## => [@pkgs] }
## - family names like '../x' or 'Debian;rm' are refused BEFORE any require
## [ %INC snapshot identical, no backend file loaded ]
## - detect_os on fixture os-release files
## [ debian, ubuntu ID_LIKE=debian, nixos, unknown ]
## - MUTATION-CHECK : a re-added 'debian' shortcut that bypasses the backend
## breaks the testfam dispatch assertions ; the family-name validation dropped
## lets a refused name load its backend file -- both mutations restored after
## the check

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
}

use AMOS7::deps::os_package;
use AMOS7::deps::debp;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## flat hashref compare : scalar values or arrayref values ##
sub result_eq {
    my ( $got, $expected ) = @_;
    return _flat_eq( $got, $expected );
}

sub _flat_eq {
    my ( $got, $expected ) = @_;
    if ( ref $expected eq 'ARRAY' ) {
        return 0
            unless ref $got eq 'ARRAY'
            and scalar(@$got) == scalar(@$expected);
        for my $i ( 0 .. $#$expected ) {
            return 0 unless _flat_eq( $got->[$i], $expected->[$i] );
        }
        return 1;
    }
    if ( ref $expected eq 'HASH' ) {
        return 0 unless ref $got eq 'HASH';
        my @keys = sort keys %$expected;
        return 0
            unless join( chr(0), @keys ) eq join( chr(0), sort keys %$got );
        for my $key (@keys) {
            return 0 unless _flat_eq( $got->{$key}, $expected->{$key} );
        }
        return 1;
    }
    return 0 if ref $got;
    return ( $got // '' ) eq ( $expected // '' );
}

sub write_fixture {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return 1;
}

##[ debp stub : every call logged, nothing touches the system ]###############

my @DEBP_CALLS;
{
    no warnings 'redefine';
    *AMOS7::deps::debp::probe_apt = sub {
        push @DEBP_CALLS, [ 'probe_apt', @_ ];
        return 1;
    };
    *AMOS7::deps::debp::probe_apt_fresh = sub {
        push @DEBP_CALLS, [ 'probe_apt_fresh', @_ ];
        return 1;
    };
    *AMOS7::deps::debp::install_apt = sub {
        push @DEBP_CALLS, [ 'install_apt', @_ ];
        return { ok => [@_], failed => [] };
    };
}

sub last_debp_call {
    return @DEBP_CALLS ? $DEBP_CALLS[-1] : undef;
}

##[ fixture dir on @INC : a whole new family appears without touching ]#######
##[ os_package.pm -- plus a backend file a REFUSED name would load     ]######

my $fixture_dir = tempdir( CLEANUP => 1 );
my $backend_dir
    = File::Spec->catdir( $fixture_dir, qw| AMOS7 deps backend | );
make_path($backend_dir);

write_fixture(
    File::Spec->catfile( $backend_dir, 'testfam.pm' ),
    <<'EOT'
package AMOS7::deps::backend::testfam;
sub name       { return 'testfam' }
sub needs_root { return 0 }
sub probe      { my ($pkg) = @_; return $pkg eq 'present-pkg' ? 1 : 0 }
sub install {
    my (@pkgs) = @_;
    return { ok => [], failed => [], manual => [@pkgs] };
}
sub refresh { return 1 }
1;
EOT
);

## loaded ONLY when the family-name validation is bypassed [ mutation ] ##
write_fixture(
    File::Spec->catfile( $backend_dir, 'Evil.pm' ),
    <<'EOT'
package AMOS7::deps::backend::Evil;
sub name       { return 'Evil' }
sub needs_root { return 0 }
sub probe      { return 1 }
sub install    { return { ok => [], failed => [], manual => [@_] } }
sub refresh    { return 1 }
1;
EOT
);

unshift( @INC, $fixture_dir );

##[ 1 : debian backend -- direct interface ]##################################

say ': debian backend interface';

ok( AMOS7::deps::os_package::backend_available('debian') == 1,
    'backend_available : debian backend module found'
);

my $debian_probe
    = AMOS7::deps::os_package::_backend_method( 'debian', 'probe' );
ok( ref $debian_probe eq 'CODE',
    'backend method lookup : debian probe resolves to a coderef' );

require AMOS7::deps::backend::debian;

ok( AMOS7::deps::backend::debian::name() eq 'debian',
    'debian::name returns debian' );
ok( AMOS7::deps::backend::debian::needs_root() == 1,
    'debian::needs_root returns 1' );
ok( AMOS7::deps::backend::debian::refresh() == 1,
    'debian::refresh is the documented no-op [ returns 1 ]'
);

##[ 2 : dispatch by family -- debian reaches debp with the right args ]#######

say ': dispatch by family [ debian, debp stubbed ]';

my $calls_before = scalar @DEBP_CALLS;

AMOS7::deps::os_package::probe_os_pkg( 'demo-pkg', 'debian' );
ok( result_eq( last_debp_call(), [ 'probe_apt', 'demo-pkg' ] ),
    'probe [ no fresh flag ] -> debp::probe_apt with the package name'
);

AMOS7::deps::os_package::probe_os_pkg( 'demo-pkg', 'debian', 1 );
ok( result_eq( last_debp_call(), [ 'probe_apt_fresh', 'demo-pkg' ] ),
    'probe [ fresh flag ] -> debp::probe_apt_fresh with the package name'
);

ok( AMOS7::deps::os_package::probe_os_pkg( 'demo-pkg', 'debian' ) == 1,
    'probe result passes through unchanged [ stub returned 1 ]'
);

my $install_result
    = AMOS7::deps::os_package::install_os_pkgs( 'debian', 'pkg-a', 'pkg-b' );
ok( result_eq( last_debp_call(), [ 'install_apt', 'pkg-a', 'pkg-b' ] ),
    'install -> debp::install_apt with all packages' );
ok( result_eq(
        $install_result, { ok => [ 'pkg-a', 'pkg-b' ], failed => [] }
    ),
    'install result passes through unchanged [ { ok, failed } contract ]'
);

ok( result_eq(
        AMOS7::deps::os_package::install_os_pkgs('debian'),
        { ok => [], failed => [] }
    ),
    'install with no packages keeps the early { ok => [], failed => [] }'
);

ok( AMOS7::deps::os_package::probe_os_pkg( '', 'debian' ) == 0,
    'probe with an empty package stays 0 without any backend call'
);
ok( scalar(@DEBP_CALLS) == $calls_before + 4,
    'empty-package probe made no backend call'
);

ok( AMOS7::deps::os_package::probe_os_pkg( 'sh', 'binary' ) == 1,
    "'binary' stays probe_binary [ sh found ]" );

##[ 3 : a new family -- testfam, unknown to os_package.pm ]###################

say ': new family via fixture backend [ testfam ]';

ok( AMOS7::deps::os_package::probe_os_pkg( 'present-pkg', 'testfam' ) == 1,
    'testfam probe dispatches by family name [ present-pkg -> 1 ]'
);
ok( AMOS7::deps::os_package::probe_os_pkg( 'other-pkg', 'testfam' ) == 0,
    'testfam probe [ other-pkg -> 0 ]' );
ok( result_eq(
        AMOS7::deps::os_package::install_os_pkgs( 'testfam', 'pkg-x' ),
        { ok => [], failed => [], manual => ['pkg-x'] }
    ),
    'testfam install returns manual -- no os_package.pm change needed'
);
ok( exists $INC{'AMOS7/deps/backend/testfam.pm'},
    'testfam backend was loaded from the fixture dir on @INC' );

##[ 4 : unknown family ]######################################################

say ': unknown family';

ok( AMOS7::deps::os_package::probe_os_pkg( 'pkg', 'nosuchfam' ) == 0,
    'unknown family probe -> 0' );
ok( result_eq(
        AMOS7::deps::os_package::install_os_pkgs(
            'nosuchfam', 'pkg-y', 'pkg-z'
        ),
        { ok => [], failed => [], manual => [ 'pkg-y', 'pkg-z' ] }
    ),
    'unknown family install -> everything manual'
);
ok( !exists $INC{'AMOS7/deps/backend/nosuchfam.pm'},
    'unknown family loaded no backend file'
);

##[ 5 : family-name validation -- refused BEFORE any require ]################

say ': family-name validation';

my %inc_snapshot = map { $ARG => 1 } keys %INC;

for my $bad_name ( '../x', 'Debian;rm', 'Evil' ) {
    ok( AMOS7::deps::os_package::probe_os_pkg( 'pkg', $bad_name ) == 0,
        "probe with '$bad_name' refused -> 0" );
    ok( result_eq(
            AMOS7::deps::os_package::install_os_pkgs( $bad_name, 'pkg' ),
            { ok => [], failed => [], manual => ['pkg'] }
        ),
        "install with '$bad_name' refused -> manual"
    );
}

my $inc_clean = 1;
for my $key ( keys %INC ) {
    $inc_clean = 0 if !exists $inc_snapshot{$key};
}
ok( $inc_clean,
    '%INC untouched -- no require attempted for the refused names' );

##[ 6 : detect_os on fixture os-release files ]###############################

say ': detect_os fixtures';

my $os_fixture_dir = tempdir( CLEANUP => 1 );

my %os_fixture = (
    'debian'  => "ID=debian\n",
    'ubuntu'  => "ID=ubuntu\nID_LIKE=debian\n",
    'nixos'   => "ID=nixos\n",
    'unknown' => "ID=plan9\n",
);

my %os_expected = (
    'debian'  => 'debian',
    'ubuntu'  => 'debian',
    'nixos'   => 'nixos',
    'unknown' => 'unknown',
);

for my $name ( sort keys %os_fixture ) {
    my $path = File::Spec->catfile( $os_fixture_dir, "os-release.$name" );
    write_fixture( $path, $os_fixture{$name} );
    ok( AMOS7::deps::os_package::detect_os($path) eq $os_expected{$name},
        "detect_os fixture $name -> $os_expected{$name}" );
}

ok( defined AMOS7::deps::os_package::detect_os(),
    'detect_os with no args still detects this host'
);

##[ 7 : MUTATION-CHECK -- the assertions really bite ]########################

say ': mutation-check';

## mutation A : the old debian shortcut back in probe_os_pkg \           ##
## install_os_pkgs, bypassing the backend dispatch -- testfam falls into ##
## the old return-0 \ failed-only fallbacks                              ##
{
    no warnings 'redefine';
    local *AMOS7::deps::os_package::probe_os_pkg = sub {
        my ( $pkg, $os_type, $fresh ) = @_;
        return 0 unless defined $pkg && length $pkg;
        return AMOS7::deps::os_package::probe_binary($pkg)
            if $os_type eq 'binary';
        return AMOS7::deps::debp::probe_apt_fresh($pkg)
            if $os_type eq 'debian' and $fresh;
        return AMOS7::deps::debp::probe_apt($pkg) if $os_type eq 'debian';
        return 0;
    };
    local *AMOS7::deps::os_package::install_os_pkgs = sub {
        my ( $os_type, @pkgs ) = @_;
        return { ok => [], failed => [] } unless @pkgs;
        return AMOS7::deps::debp::install_apt(@pkgs)
            if $os_type eq 'debian';
        return { ok => [], failed => [@pkgs] };
    };

    ok( AMOS7::deps::os_package::probe_os_pkg( 'present-pkg', 'testfam' )
            == 0,
        'MUTATION A [ debian shortcut ] : testfam probe fell into the old '
            . 'return-0 fallback -- the dispatch assertion WOULD have failed'
    );
    ok( result_eq(
            AMOS7::deps::os_package::install_os_pkgs( 'testfam', 'pkg-x' ),
            { ok => [], failed => ['pkg-x'] }
        ),
        'MUTATION A [ debian shortcut ] : testfam install lost '
            . 'its manual list -- the assertion WOULD have failed'
    );
}

## restore : the real dispatch answers again ##
ok( AMOS7::deps::os_package::probe_os_pkg( 'present-pkg', 'testfam' ) == 1,
    'restore : testfam dispatch works again after the mutation block'
);

## mutation B : the family-name validation dropped from the backend lookup ##
## -- the refused name 'Evil' now reaches require and loads                ##
{
    no warnings 'redefine';
    local *AMOS7::deps::os_package::_backend_method = sub {
        my ( $family, $method ) = @_;

        my $mod  = "AMOS7::deps::backend::$family";
        my $file = "AMOS7/deps/backend/$family.pm";

        eval { require $file } or return undef;

        return $mod->can($method);
    };

    my $mut_probe = AMOS7::deps::os_package::probe_os_pkg( 'pkg', 'Evil' );
    ok( $mut_probe == 1 && exists $INC{'AMOS7/deps/backend/Evil.pm'},
        'MUTATION B [ validation dropped ] : Evil.pm got required '
            . 'and answered -- the %INC refusal assertion WOULD have failed'
    );
}

## summary ##

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,,..,..,,,.,,.,,,..,,..,,,..,..,,,..,..,,...,..,,.,,,,,.,,.,,...,,,,,
#K7FUTPK36HXZD2Y26BLW7GFQJATYJRSOJUG3OMVCK45CTBFU5LTPRM2NSTKIL7CVFP4OGDS7CAUAK
#\\\|TDM3YKAA6YB3NEPTDMMQL7W4CGTUDXDVYEKH5NERXEDQ5JAVA77 \ / AMOS7 \ YOURUM ::
#\[7]KCK56DS5XTENOM77VXHGRWBBJF3E6HLGC3DCYIUJC5JUP2HIQEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
