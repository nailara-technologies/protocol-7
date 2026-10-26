#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;

## Test bin/ned on a real pty [ IO::Pty ] : the file-oriented secure editor
## driver around AMOS7::TERM::Editor. Tests : edit + ctrl-x writes the file
## and reports 'saved', an untouched buffer reports 'unchanged', ctrl-c aborts
## without touching the file, a new file is created mode 0600, an existing
## file keeps its mode, the change guard refuses an externally modified file [
## both at the mtime filter and at the elf fingerprint level with a forged
## mtime ], the refused edit is preserved in a rescue file and the target is
## left as the other writer left it, editing through a symlink updates the
## target and keeps the link, preflight refuses a read-only file and an
## over-sized file before the editor opens. skipped when IO::Pty is not
## installed

##[ LOCAL PM LIB PATH ]#######################################################

my $local_lib_path;
my $ned_path;

BEGIN {
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
    $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    $ned_path = File::Spec->catfile( $root_path, qw| bin ned | );
}

use POSIX       qw| WNOHANG setsid |;
use File::Temp  qw| tempdir |;
use Time::HiRes qw| time stat utime |;

if ( !eval { require IO::Pty; 1 } ) {
    say '=== skipped : IO::Pty not installed ===';
    exit 0;
}

say '=== testing bin/ned on a pty ===';

my $tests_run    = 0;
my $tests_passed = 0;

sub check {
    my ( $label, $ok ) = @ARG;
    $tests_run++;
    $tests_passed++ if $ok;
    say sprintf '[ %s ] %s', ( $ok ? 'ok' : 'FAIL' ), $label;
    return;
}

my $tmp_dir = tempdir( CLEANUP => 1 );

sub read_bytes {
    my $path = shift;
    my $text = '';
    if ( open my $fh, '<', $path ) {
        local $INPUT_RECORD_SEPARATOR;
        $text = <$fh>;
    }
    return $text // '';
}

sub file_mode {
    return ( stat(shift) )[2] & 07777;
}

## the ned child on a pty : the real bin/ned, hermetic clipboard ##
sub run_ned {
    my ( $name, $path, $script ) = @ARG;
    my $pty = IO::Pty->new;
    $pty->set_winsize( 30, 100 ) if $pty->can('set_winsize');

    my $pid = fork // die "fork : $OS_ERROR";
    if ( !$pid ) {
        setsid();
        my $slave = $pty->slave;
        close $pty;
        open STDIN,  '<&', $slave;
        open STDOUT, '>&', $slave;
        open STDERR, '>&', $slave;
        $ENV{'P7_EDITOR_NO_CLIP'} = 1;
        {
            exec $EXECUTABLE_NAME, "-I$local_lib_path", $ned_path, $path;
        }
        POSIX::_exit(127);
    }
    $pty->close_slave;

    my $output = '';
    my $drain  = sub {
        my $until = time() + shift;
        while ( time() < $until ) {
            if ( !defined fileno($pty) ) {
                select( undef, undef, undef, $until - time() );
                last;
            }
            my $rin = '';
            vec( $rin, fileno($pty), 1 ) = 1;
            next if !select( $rin, undef, undef, 0.05 );
            my $n = sysread( $pty, my $buf, 65536 );
            last if !$n;
            $output .= $buf;
        }
    };

    ## wait for the editor's frame before touching keys : a ctrl-c sent while
    ## perl is still compiling lands on a cooked tty [ ISIG ] and kills the
    ## child [ pty discipline lesson from the editor tests ]
    my $deadline = time() + 5;
    until ( $output =~ m{\.\:\[} or time() > $deadline ) {
        $drain->(0.1);
    }

    $script->( $pty, $pid, $drain );
    $drain->(1.0);

    my $exited = 0;
    for ( 1 .. 30 ) {
        if ( waitpid( $pid, WNOHANG ) > 0 ) { $exited = 1; last }
        $drain->(0.1);
    }
    if ( !$exited ) { kill 'KILL', $pid; waitpid( $pid, 0 ) }
    my $status = $CHILD_ERROR >> 8;

    return ( $status, $output );
}

##[ edit + save ]#############################################################

my $target = "$tmp_dir/edit-save.txt";
{ open my $fh, '>', $target or die; print $fh "hello\n"; }

my ( $status, $output ) = run_ned(
    qw| editsave |,
    $target,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";    ## ctrl-x : save + quit ##
    }
);

my $case_ok
    = $status == 0
    && read_bytes($target) eq "Xhello\n"
    && index( $output, 'saved' ) >= 0;
check( 'edit + ctrl-x : file written, saved pill, exit 0', $case_ok );

##[ unchanged ]###############################################################

( $status, $output ) = run_ned(
    qw| unchanged |,
    $target,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\x18";    ## nothing typed ##
    }
);

$case_ok
    = $status == 0
    && read_bytes($target) eq "Xhello\n"
    && index( $output, 'unchanged' ) >= 0;
check( 'ctrl-x with no edits : file untouched, unchanged pill', $case_ok );

##[ abort ]###################################################################

( $status, $output ) = run_ned(
    qw| abort |,
    $target,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'Z';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x03";    ## ctrl-c : abort ##
    }
);

$case_ok
    = $status == 1
    && read_bytes($target) eq "Xhello\n"
    && index( $output, 'aborted' ) >= 0;
check( 'ctrl-c abort : nothing written, aborted report, exit 1', $case_ok );

##[ new file : mode 0600 ]####################################################

my $fresh = "$tmp_dir/fresh.txt";

( $status, $output ) = run_ned(
    qw| newfile |,
    $fresh,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'abc';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    }
);

$case_ok
    = $status == 0
    && read_bytes($fresh) eq "abc\n"
    && file_mode($fresh) == 0600;
check( 'new file : created mode 0600 with the typed content + final newline',
    $case_ok );

##[ existing mode preserved ]#################################################

chmod 0640, $target;
run_ned(
    qw| modekeep |,
    $target,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'Q';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    }
);

$case_ok = file_mode($target) == 0640 && read_bytes($target) eq "QXhello\n";
check( 'existing file : mode 0640 preserved across the atomic save',
    $case_ok );
chmod 0644, $target;

##[ change guard : mtime filter ]#############################################

my $guarded = "$tmp_dir/guarded.txt";
{ open my $fh, '>', $guarded or die; print $fh "one\n"; }

( $status, $output ) = run_ned(
    qw| guard |,
    $guarded,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'U';
        select( undef, undef, undef, 0.3 );
        ## an external writer lands mid-session ##
        { open my $fh, '>', $guarded or die; print $fh "two\n" }
        syswrite $pty, "\x13";    ## ctrl-s : the guard must refuse ##
        select( undef, undef, undef, 0.5 );
        syswrite $pty, "\x18";    ## ctrl-x : refused again, rescue ##
    }
);

my @rescue_files = glob "$guarded.ned-rescue-*";
$case_ok
    = $status == 2
    && read_bytes($guarded) eq "two\n"
    && index( $output, 'file changed on disk' ) >= 0
    && @rescue_files == 1
    && read_bytes( $rescue_files[0] ) eq "Uone\n";
check(
    'change guard : external edit refuses overwrite '
        . '[ ctrl-s + ctrl-x ], rescue file holds the edit',
    $case_ok
);

unlink $rescue_files[0] if @rescue_files;

##[ change guard : elf fingerprint under a forged mtime ]#####################

my $forged = "$tmp_dir/forged.txt";
{ open my $fh, '>', $forged or die; print $fh "aaa\n"; }
my @orig_stat = stat($forged);

( $status, $output ) = run_ned(
    qw| forged |,
    $forged,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'Z';
        select( undef, undef, undef, 0.3 );
        ## same size, content changed, mtime restored to the nanosecond : only
        ## the elf pair can see this one
        { open my $fh, '>', $forged or die; print $fh "bbb\n" }
        utime $orig_stat[8], $orig_stat[9], $forged;
        syswrite $pty, "\x18";
    }
);

my @forged_rescue = glob "$forged.ned-rescue-*";
$case_ok
    = $status == 2
    && read_bytes($forged) eq "bbb\n"
    && index( $output, 'file changed on disk' ) >= 0
    && @forged_rescue == 1
    && read_bytes( $forged_rescue[0] ) eq "Zaaa\n";
check(
    'change guard : same-size content change with a '
        . 'restored mtime still caught by the elf fingerprint',
    $case_ok
);

unlink $forged_rescue[0] if @forged_rescue;

##[ symlink : the target is edited, the link survives ]#######################

my $real_file = "$tmp_dir/real.txt";
{ open my $fh, '>', $real_file or die; print $fh "real\n"; }
my $link_file = "$tmp_dir/link.txt";
symlink $real_file, $link_file;

( $status, $output ) = run_ned(
    qw| symlink |,
    $link_file,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'S';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    }
);

$case_ok
    = $status == 0
    && read_bytes($real_file) eq "Sreal\n"
    && -l $link_file
    && readlink($link_file) eq $real_file;
check( 'symlink : target updated through the link, the link itself intact',
    $case_ok );

##[ preflight : read-only file ]##############################################

my $readonly = "$tmp_dir/readonly.txt";
{ open my $fh, '>', $readonly or die; print $fh "ro\n"; }
chmod 0444, $readonly;

( $status, $output ) = run_ned( qw| readonly |, $readonly, sub { } );

$case_ok
    = $status == 2
    && index( $output, 'not writable' ) >= 0
    && index( $output, '.:[' ) < 0
    && read_bytes($readonly) eq "ro\n";
check( 'preflight : read-only file refused before the editor opens',
    $case_ok );

chmod 0644, $readonly;

##[ preflight : size cap ]####################################################

my $huge = "$tmp_dir/huge.txt";
{ open my $fh, '>', $huge or die }
truncate $huge, 11 * 1024 * 1024;

( $status, $output ) = run_ned( qw| huge |, $huge, sub { } );

$case_ok
    = $status == 2
    && index( $output, 'MiB' ) >= 0
    && index( $output, '.:[' ) < 0;
check( 'preflight : a file above 10 MiB refused before the editor opens',
    $case_ok );

unlink $huge;

##[ relative name without a slash ]###########################################

## the parent-dir extraction must treat bare names as living in the cwd --
## both preflight branches and the temp-file placement

my $rel_dir = "$tmp_dir/relcwd";
mkdir $rel_dir, 0755 or die "mkdir : $OS_ERROR";
my $old_cwd = do {qx|pwd|};
chomp $old_cwd;
chdir $rel_dir or die "chdir : $OS_ERROR";

( $status, $output ) = run_ned(
    qw| relnew |,
    'relnew.txt',
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'rel';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    }
);

my $rel_new_ok = $status == 0 && read_bytes('relnew.txt') eq "rel\n";

( $status, $output ) = run_ned(
    qw| relsave |,
    'relnew.txt',
    sub {
        my ($pty) = @ARG;
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    }
);

$rel_new_ok
    = $rel_new_ok
    && $status == 0
    && read_bytes('relnew.txt') eq "Xrel\n";
chdir $old_cwd or die "chdir back : $OS_ERROR";

check( 'bare relative name : new + existing file in the cwd', $rel_new_ok );

##[ non-tty refusal ]#########################################################

open my $pipe_fh, '-|', "$EXECUTABLE_NAME $ned_path $target 2>&1"
    or die "pipe : $OS_ERROR";
my $pipe_out = do { local $INPUT_RECORD_SEPARATOR; <$pipe_fh> };
close $pipe_fh;
my $pipe_status = $CHILD_ERROR >> 8;

$case_ok = $pipe_status == 2
    && index( $pipe_out, 'requires a tty' ) >= 0;
check( 'non-tty : ned refuses to run as a filter', $case_ok );

##[ no leftovers ]############################################################

my @leftovers = glob "$tmp_dir/.ned-*.tmp";
check( 'no temp files left behind in the target directory', @leftovers == 0 );

##[ summary ]#################################################################

say sprintf '=== %d/%d ned pty tests passed ===', $tests_passed, $tests_run;
exit( $tests_passed == $tests_run ? 0 : 1 );

#,,..,.,.,,.,,.,,,..,,,,.,,,,,,..,.,,,,.,,,..,..,,...,...,.,.,,,,,,..,,..,.,.,
#OQLNLU5KVIMEDAL4YZA2ZQDFCC6SDVZHGUJWJHYM7KJXLOGL75E2ENQFTFAFS7QJAFK5GY7G5NXFY
#\\\|RXSJIRVA646Z45YQSWNHUXLQYP2SVTQSMGOCEAMH7RDKXNMWGA2 \ / AMOS7 \ YOURUM ::
#\[7]2SU4OD6QKYPKU232CGVAZGFCY33RD3PRQ6L3WOHUXHPKSIEW76DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
