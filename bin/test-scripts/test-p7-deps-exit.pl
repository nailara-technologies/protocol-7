#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## bin/p7-deps check \ install exit codes and the profile cache : check     ##
## exits 1 when a profile misses a package, install exits 1 when an install ##
## failed and then caches 'fail', not 'ok' [ bin/p7-install stops on it ].  ##
## runs a copy of bin/p7-deps in a temporary tree with its own              ##
## .deps/profiles.yaml [ data/lib-path/pm linked to the real one ] ;        ##
## dpkg-query and apt-get are stubs first in PATH, apt-get never installs.  ##
## also : help writes nothing into the tree [ no .deps/cache ].             ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;

use constant { TRUE => 5, FALSE => 0 };

my $root_path = abs_path(
    File::Spec->rel2abs(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
    )
);

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return TRUE;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub run_capture {
    my (@cmd) = @_;
    my $pid = open( my $pipe, '-|' ) // die "fork failed : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        exec(@cmd) or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $output = <$pipe> // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $output );
}

## the temporary tree ##

my $sandbox = tempdir( CLEANUP => 1 );
my $tree    = File::Spec->catdir( $sandbox, 'tree' );
my $stubs   = File::Spec->catdir( $sandbox, 'stub' );
my $state   = File::Spec->catfile( $sandbox, 'installed' );
my $apt_log = File::Spec->catfile( $sandbox, 'apt-get.log' );

make_path( map { File::Spec->catdir( $tree, @$_ ) } [qw| bin |],
    [qw| .deps |], [qw| data lib-path |] );
make_path($stubs);
copy( "$root_path/bin/p7-deps", "$tree/bin/p7-deps" ) or die "copy : $!";
symlink( "$root_path/data/lib-path/pm", "$tree/data/lib-path/pm" )
    or die "symlink : $!";

write_file( "$tree/.deps/profiles.yaml", <<'EOF' );
profiles:
  exit-test:
    description: "p7-deps exit code test"
    apt:
      - p7-test-package
  exit-incl:
    description: "includes exit-test"
    includes:
      - exit-test
EOF

## dpkg-query : installed when listed in the state file ##
write_file( "$stubs/dpkg-query", sprintf <<'EOF', $EXECUTABLE_NAME, $state );
#!%s
my $pkg = $ARGV[-1];
open my $fh, '<', '%s' or exit 1;
my %%have = map { chomp; $_ => 1 } <$fh>;
exit 1 if not $have{$pkg};
print 'install ok installed';
EOF

## apt-get : logs, never installs ##
write_file( "$stubs/apt-get", sprintf <<'EOF', $EXECUTABLE_NAME, $apt_log );
#!%s
open my $fh, '>>', '%s' or die;
print {$fh} "@ARGV\n";
print "E: Unable to locate package $ARGV[-1]\n";
exit 100;
EOF
chmod( 0755, "$stubs/dpkg-query", "$stubs/apt-get" );

## a host with libapt-pkg-perl probes in-process and never asks the       ##
## dpkg-query stub : an AptPkg::Cache that refuses to load comes first in ##
## PERL5LIB, debp falls back to dpkg-query [ its eval-guarded path ]      ##
my $no_aptpkg = "$stubs/no-aptpkg";
make_path("$no_aptpkg/AptPkg");
write_file( "$no_aptpkg/AptPkg/Cache.pm",
    "die qq{AptPkg hidden by the test\\n};\n" );

sub p7_deps {
    local $ENV{'PATH'}     = "$stubs:$ENV{'PATH'}";
    local $ENV{'PERL5LIB'} = join q{:}, $no_aptpkg,
        grep {length} $ENV{'PERL5LIB'} // q{};
    return run_capture( $EXECUTABLE_NAME, "$tree/bin/p7-deps", @_ );
}

my $cache_file = "$tree/.deps/cache/exit-test.cache";

## help writes nothing ##

my ( $exit, $out ) = p7_deps(qw| help |);
check 'help : exit 0',                 $exit == 0;
check 'help : no .deps/cache created', not -e "$tree/.deps/cache";

## package missing ##

( $exit, $out ) = p7_deps(qw| check exit-test |);
check 'check, package missing : exit 1', $exit == 1;
check 'check, package missing : cache says fail',
    ( slurp($cache_file) // '' ) eq 'fail';

( $exit, $out ) = p7_deps(qw| install exit-test |);
check 'install, apt-get fails : exit 1', $exit == 1;
check 'install, apt-get fails : apt-get was asked',
    ## install_apt refuses before apt-get when not root ##
    ( ( slurp($apt_log) // '' ) =~ m|install p7-test-package| or $EUID != 0 );
check 'install, apt-get fails : cache says fail, not ok',
    ( slurp($cache_file) // '' ) eq 'fail';

## package present ##

write_file( $state, "p7-test-package\n" );

( $exit, $out ) = p7_deps(qw| check exit-test |);
check 'check, package present : exit 0', $exit == 0;
check 'check, package present : cache says ok',
    ( slurp($cache_file) // '' ) eq 'ok';

unlink $apt_log;
( $exit, $out ) = p7_deps(qw| install exit-test |);
check 'install, nothing missing : exit 0',          $exit == 0;
check 'install, nothing missing : apt-get not run', not -e $apt_log;

## unknown profile still exits 1 ##

( $exit, $out ) = p7_deps(qw| install no-such-profile |);
check 'install, unknown profile : exit 1', $exit == 1;

## an included profile's packages count in -- the including profile's exit ##
## code and cache follow the included one's missing \ present              ##

my $incl_cache = "$tree/.deps/cache/exit-incl.cache";

( $exit, $out ) = p7_deps(qw| check exit-incl |);
check 'check, included profile complete : exit 0', $exit == 0;
check 'check, included profile complete : including profile cache ok',
    ( slurp($incl_cache) // '' ) eq 'ok';

unlink $state;

( $exit, $out ) = p7_deps(qw| check exit-incl |);
check 'check, included profile missing a package : exit 1', $exit == 1;
check 'check, included profile missing a package : cache not ok',
    ( slurp($incl_cache) // '' ) ne 'ok';

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,..,,,.,...,,..,,,,,,,.,...,,..,..,,,,,,..,,...,...,..,,.,,,,.,,..,,.,.,
#G4I5L7EBKIW5LJH73N4ROQ5LXGKDAOE7IHPDREB4OGV6K47QAQHXNXEBEG4MW4KF4NII36MVWBEBS
#\\\|TMR4YZKOSEIAJLWN3OUYJYRSMA2GIA6V4P5T4KMDYCZL5EPG3AO \ / AMOS7 \ YOURUM ::
#\[7]TDRLGTZ5NJ5DDG6I3IMYSO6DEGV5BAPPN5L2YSFESAJVOKYHTECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
