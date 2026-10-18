#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

##        Test bin/dev/update-amos-versions module source versions          ##
##                                                                          ##
##        runs the tool against a TEMP copy of a few AMOS7 modules :        ##
##                                                                          ##
##        1. compute .., versions are written in the uniform form           ##
##        2. -check ... finds outdated after a source edit [exit 1]         ##
##        3. replace ., running the tool updates the version                ##
##        4. -check ... clean again [exit 0]                                ##
##        5. exclusion ., editing the $VERSION line or the signature        ##
##        footer does NOT change the version                                ##

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use English;
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use English;
use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Copy qw| copy |;
use File::Path qw| make_path |;

my $up_dir    = File::Spec->updir;
my $root_path = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up_dir, $up_dir ) ) );
my $tool_path = abs_path(
    File::Spec->catdir( $root_path, qw| bin dev update-amos-versions | ) );

my $tests_run    = 0;
my $tests_passed = 0;
my @failures;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
    } else {
        push( @failures, $label );
        say sprintf( '[ FAIL ] %s', $label );
    }
    return $condition;
}

sub run_tool {
    my @args  = @ARG;
    my $quiet = qx| perl $tool_path @args 2>/dev/null |;
    return ( $quiet, $CHILD_ERROR >> 8 );
}

sub slurp {
    my $path = shift;
    open( my $fh, qw| <:raw |, $path ) or return undef;
    my $content = join '', <$fh>;
    close($fh);
    return $content;
}

sub module_version {
    my $path    = shift;
    my $content = slurp($path) // return undef;
    return $1
        if $content
        =~ m,^\s*our\s+\$VERSION\s*=\s*qw\|\s*(AMOS7::[\w:]+-VERSION\.[0-9A-Z]{7})\s*\|,ms;
    return undef;
}

##[ TEMP MODULE TREE ]########################################################

my $temp_root = tempdir(qw| CLEANUP 1 |);
my $amos7_dir
    = File::Spec->catdir( $temp_root, qw| data lib-path pm AMOS7 | );
make_path( File::Spec->catdir( $amos7_dir, qw| 13 | ) );

my @module_list = qw|
    AMOS7/Backup.pm
    AMOS7/Graph.pm
    AMOS7/Util.pm
    AMOS7/13/Compression.pm
    |;

foreach my $module (@module_list) {
    my $target_path = File::Spec->catdir( $amos7_dir, $module );
    ( my $target_dir = $target_path ) =~ s|/[^/]+$||;
    make_path($target_dir);
    copy( File::Spec->catdir( $root_path, qw| data lib-path pm |, $module ),
        $target_path )
        or die sprintf ':: copy failed : %s [ %s ]', $module, $OS_ERROR;
}

my %module_path
    = map { $_ => abs_path( File::Spec->catdir( $amos7_dir, $_ ) ) }
    @module_list;

my $version_re = qr,^AMOS7::[\w:]+-VERSION\.[0-9A-Z]{7}$,;

##  1  ##  compute : versions written in the uniform form  ##

## tamper one version so the compute run has a change to report  ##
{
    my $backup_content = slurp( $module_path{'AMOS7/Backup.pm'} );
    $backup_content
        =~ s{^(\s*our\s+\$VERSION\s*=\s*qw\|).*?(\|\s*;)}{$1 . q| AMOS7::Backup-VERSION.0000000 | . $2}em;
    open( my $tamper_fh, qw| >:raw |, $module_path{'AMOS7/Backup.pm'} )
        or die sprintf ':: open failed [ %s ]', $OS_ERROR;
    print {$tamper_fh} $backup_content;
    close($tamper_fh);
}

my ( $output, $exit_code ) = run_tool( qw| -root |, $temp_root );

check( 'compute run exits clean',         $exit_code == 0 );
check( 'compute reports changed modules', $output =~ m|AMOS7::Backup| );

foreach my $module (@module_list) {
    my $version = module_version( $module_path{$module} );
    check(
        sprintf( 'uniform version written : %s', $module ),
        ( defined $version and $version =~ $version_re )
    );
}

my %written_version
    = map { $_ => module_version( $module_path{$_} ) } @module_list;

check( 'placeholder versions replaced',
    $written_version{'AMOS7/Graph.pm'} ne qw| AMOS7::Graph-0.01 | );
check( 'missing version inserted',
    $written_version{'AMOS7/Util.pm'} =~ $version_re );

##  2  ##  -check finds outdated after a source edit  ##

my $backup_content = slurp( $module_path{'AMOS7/Backup.pm'} );
$backup_content
    =~ s|^(package\s+[\w:]+\s*;.*\n)|${1}## truth-fallthrough edit ##\n|m;
open( my $append_fh, qw| >:raw |, $module_path{'AMOS7/Backup.pm'} )
    or die sprintf ':: open failed [ %s ]', $OS_ERROR;
print {$append_fh} $backup_content;
close($append_fh);

( $output, $exit_code ) = run_tool( qw| -root |, $temp_root, qw| -check | );

check( '-check exits 1 on outdated version', $exit_code == 1 );
check( '-check names outdated module', $output =~ m|AMOS7::Backup-VERSION| );
check(
    '-check leaves file untouched',
    module_version( $module_path{'AMOS7/Backup.pm'} ) eq
        $written_version{'AMOS7/Backup.pm'}
);

##  3  ##  replace : running the tool updates the version  ##

( undef, $exit_code ) = run_tool( qw| -root |, $temp_root );

check( 'replace run exits clean', $exit_code == 0 );
check(
    'source edit changes version',
    module_version( $module_path{'AMOS7/Backup.pm'} ) ne
        $written_version{'AMOS7/Backup.pm'}
);

##  4  ##  -check clean again  ##

( $output, $exit_code ) = run_tool( qw| -root |, $temp_root, qw| -check | );

check( '-check exits 0 when current', $exit_code == 0 );

##  5  ##  reflow invariance : whitespace-only changes keep the version  ##

my $util_path = $module_path{'AMOS7/Util.pm'};
my $util_orig = slurp($util_path);

my $reflow_split_done = 0;
my $reflowed          = join "\n", map {
    my $line = $ARG;
    if ( not $reflow_split_done and length $line > 40 and $line =~ m{ } ) {
        $line =~ s|^(.{30,}?) |$1\n        |;    ## split one long line  ##
        $reflow_split_done = 1;
    }
    '    ' . $line . '   ';    ## re-indent + trailing whitespace  ##
} split "\n", $util_orig;
$reflowed =~ s{\n}{\n\n\n}g;    ## blank line runs  ##

check( 'reflow fixture splits a line', $reflow_split_done );

open( my $reflow_fh, qw| >:raw |, $util_path )
    or die sprintf ':: open failed [ %s ]', $OS_ERROR;
print {$reflow_fh} $reflowed;
close($reflow_fh);

check( 'reflow applied [ ' . 'whitespace only ]',
    slurp($util_path) ne $util_orig );

( $output, $exit_code ) = run_tool( qw| -root |, $temp_root, qw| -check | );

check( 'whitespace-only reflow keeps the version', $exit_code == 0 );
check( 'reflowed module version unchanged',
    module_version($util_path) eq $written_version{'AMOS7/Util.pm'} );

open( my $restore_fh, qw| >:raw |, $util_path )
    or die sprintf ':: open failed [ %s ]', $OS_ERROR;
print {$restore_fh} $util_orig;
close($restore_fh);

##  6  ##  exclusion : $VERSION line and footer are not checksummed  ##

my $graph_path    = $module_path{'AMOS7/Graph.pm'};
my $graph_content = slurp($graph_path);

my $edited = $graph_content;
$edited
    =~ s{^(\s*our\s+\$VERSION\s*=\s*qw\|.*?\|\s*;.*)$}{$1 . q| ## EDIT-VALUE|}em;
$edited =~ s|^(#,,.*)$|${1}EDIT|m;    ## signature footer line  ##

open( my $edit_fh, qw| >:raw |, $graph_path )
    or die sprintf ':: open failed [ %s ]', $OS_ERROR;
print {$edit_fh} $edited;
close($edit_fh);

check( 'edit applied to version line', slurp($graph_path) =~ m|EDIT-VALUE| );
check( 'edit applied to footer',       slurp($graph_path) =~ m|^#,,.*EDIT|m );

( $output, $exit_code ) = run_tool( qw| -root |, $temp_root, qw| -check | );

check( 'version unchanged by version-line \ footer edits', $exit_code == 0 );
check( '-check names no module after exclusion edits',
    $output !~ m|AMOS7::Graph-VERSION| );
my $graph_after = slurp($graph_path);
check(
    'check mode preserved edited version line',
    (           $graph_after =~ m|\Q$written_version{'AMOS7/Graph.pm'}\E|
            and $graph_after =~ m|EDIT-VALUE|
    )
);

##[ SUMMARY ]#################################################################

say '';
if ( @failures == 0 ) {
    say sprintf '[ PASS ] %d of %d checks', $tests_passed, $tests_run;
    exit 0;
} else {
    say sprintf '[ FAIL ] %d of %d checks failed',
        scalar @failures, $tests_run;
    exit 1;
}

#,,,,,.,,,,..,,,.,...,.,.,,,.,,,.,..,,,..,.,.,.,.,...,...,...,.,.,,,,,,,.,,,,,
#3KOHOJKCN5BHO7TEV5DASXTWPWDEDM5G6GXGMZUTYV4SABBIEWSVVSK3JTTL2WUYJTSD4DVEU5Z54
#\\\|Y4PV5APZMR3BVEEVZV43U6SFO3H42RSJZBL6QXQIT6BZQTAFUKL \ / AMOS7 \ YOURUM ::
#\[7]C4YC5X2NQIKFHA4HOVKP2HQO37HVDHU5FGDY3F663UFEWICFG2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
