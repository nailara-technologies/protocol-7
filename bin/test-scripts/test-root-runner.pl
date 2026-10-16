#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                   ###
##  AMOS7::deps::root_runner : the debian zenka's generic root runner  ##
###                                                                   ###

## starts the REAL runner child through the same spawn_argv \ bootstrap the ##
## zenka uses [ src/debian.start.apt_child ], as a NON-ROOT user            ##
## [ 'nobody' when this test runs as root, else the current user ], on a    ##
## temp lib tree : copies of root_runner.pm, os_package.pm, debp.pm plus    ##
## TEST-ONLY backends. the family comes from P7_ROOT_RUNNER_TEST_FAMILY,    ##
## which the runner honours only when neither uid is root. covers :         ##
## - start-up line, install reply framing [ '> ' .. '= ..' '< N' ], ok \    ##
## failed \ manual parsed back with parse_result, sink + warn lines         ##
## - invalid package name refused, the backend never called                 ##
## - invalid family, family without backend, needs_root = 0 : clear         ##
## refusal, the runner stays up, 'cpan' still answers                       ##
## - unsafe ownership : group writable backend, a group writable file the   ##
## backend loads INDIRECTLY [ debp.pm via os_package ], a symlinked         ##
## backend, a tree owned by the zenka uid, [ as root : ] a file owned by a  ##
## third uid -- each refuses to start                                       ##
## - [ as root only : ] a root runner IGNORES the test family variable      ##
## [ reads the start-up line, sends 'exit' -- never 'install' ]             ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;
use POSIX      qw| setuid setgid |;

my $local_lib_path;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
}

use AMOS7::deps::os_package;

my $fail_count = 0;

## ($$) : the condition in scalar context -- a failed match must not shift ##
## the label into its place                                                ##
sub ok ($$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

sub finish {
    say '';
    if ($fail_count) {
        say "FAILED : $fail_count check[s]";
        exit 1;
    }
    say 'all checks passed';
    exit 0;
}

##[ the runner module ]#######################################################

say ': runner module';

my $have_runner = eval { require AMOS7::deps::root_runner; 1 };
ok( $have_runner, 'AMOS7::deps::root_runner loads' )
    or say "         [ $EVAL_ERROR ]";
finish() if not $have_runner;

##[ test user + temp lib tree ]###############################################

my $as_root = ( $EUID == 0 or $UID == 0 ) ? 1 : 0;
my ( $run_uid, $run_gid )
    = $as_root
    ? ( getpwnam('nobody') )[ 2, 3 ]
    : ( $UID, ( split m| |, $GID )[0] );
die "no 'nobody' user to run as\n" if not defined $run_uid;

my $other_uid = 3999999;    ## the zenka uid, unless a check wants ours ##
$other_uid-- while $other_uid == $run_uid;

my $tmp = tempdir( qw| p7-root-runner-XXXXXX |, DIR => '/tmp', CLEANUP => 1 );
chmod 0755, $tmp;
my $lib  = "$tmp/pm";
my $deps = "$lib/AMOS7/deps";
make_path("$deps/backend");

foreach my $pm (qw| root_runner.pm os_package.pm debp.pm |) {
    copy( "$local_lib_path/AMOS7/deps/$pm", "$deps/$pm" )
        or die "copy $pm : $OS_ERROR\n";
}

sub write_file {
    my ( $path, $text ) = @ARG;
    open( my $fh, '>', $path ) or die "write $path : $OS_ERROR\n";
    print {$fh} $text;
    close($fh);
}

## test-only backends : the runner may only find them through the test ##
## family variable, never by detect_os                                 ##
write_file( "$deps/backend/fakefam.pm", <<~'EOT');
    package AMOS7::deps::backend::fakefam;
    use strict;
    use warnings;
    sub name       { return 'fakefam' }
    sub needs_root { return 1 }
    sub install {
        my $sink = ( @_ and ref $_[0] eq 'CODE' ) ? shift : undef;
        my %r = ( ok => [], failed => [], manual => [] );
        foreach my $pkg (@_) {
            $sink->("fake installing $pkg") if $sink;
            my $key = $pkg =~ m|^bad| ? 'failed'
                : $pkg =~ m|^man|     ? 'manual'
                :                       'ok';
            push @{ $r{$key} }, $pkg;
        }
        warn "fake backend warning\n";
        return \%r;
    }
    1;
    EOT

write_file( "$deps/backend/norootfam.pm", <<~'EOT');
    package AMOS7::deps::backend::norootfam;
    use strict;
    use warnings;
    sub name       { return 'norootfam' }
    sub needs_root { return 0 }
    sub install {
        my $sink = ( @_ and ref $_[0] eq 'CODE' ) ? shift : undef;
        $sink->('NOROOT BACKEND CALLED') if $sink;
        return { ok => [@_], failed => [] };
    }
    1;
    EOT

sub tree_perms {    ## dirs 0755, files 0644, owned by the test user ##
    my @todo = ($tmp);
    while ( my $path = shift @todo ) {
        if ( -l $path ) {
            next;
        } elsif ( -d $path ) {
            chmod 0755, $path;
            opendir( my $dh, $path ) or die;
            push @todo, map {"$path/$ARG"} grep { !m|^\.\.?$| } readdir $dh;
            closedir $dh;
        } else {
            chmod 0644, $path;
        }
        chown $run_uid, $run_gid, $path if $as_root;
    }
}
tree_perms();

##[ child helpers ]###########################################################

## the zenka's own exec list, the child dropped to the test user ##
sub spawn_runner {
    my (%opt) = @ARG;

    pipe( my $child_in,   my $to_child )  or die "pipe : $OS_ERROR\n";
    pipe( my $from_child, my $child_out ) or die "pipe : $OS_ERROR\n";

    my @argv
        = AMOS7::deps::root_runner::spawn_argv( $EXECUTABLE_NAME, $lib,
        $opt{'deny_uid'} // $other_uid,
        qw| test | );

    my $pid = fork() // die "fork : $OS_ERROR\n";
    if ( $pid == 0 ) {
        close($to_child);
        close($from_child);
        open( STDIN,  '<&', $child_in )   or exit 126;
        open( STDOUT, '>&', $child_out )  or exit 126;
        open( STDERR, '>',  '/dev/null' ) or exit 126;
        delete @ENV{ AMOS7::deps::root_runner::perl_env_names() };
        if ( defined $opt{'family'} ) {
            $ENV{'P7_ROOT_RUNNER_TEST_FAMILY'} = $opt{'family'};
        } else {
            delete $ENV{'P7_ROOT_RUNNER_TEST_FAMILY'};
        }
        if ( $as_root and not $opt{'stay_root'} ) {
            $EGID = "$run_gid $run_gid";
            setgid($run_gid)             or exit 125;
            setuid($run_uid)             or exit 125;
            exit 125 if $UID != $run_uid or $EUID != $run_uid;
        }
        exec { $argv[0] } @argv;
        exit 127;
    }

    close($child_in);
    close($child_out);
    $to_child->autoflush(1);

    my $status = AMOS7::deps::root_runner::read_status( $from_child, 15 );

    return {
        'pid'    => $pid,
        'w'      => $to_child,
        'r'      => $from_child,
        'status' => $status // ''
    };
}

## one command : every reply line up to and including '< N' ##
sub converse {
    my ( $child, $command ) = @ARG;

    print { $child->{'w'} } "$command\n";
    my @lines;
    while (
        defined(
            my $line
                = AMOS7::deps::root_runner::read_status( $child->{'r'}, 15 )
        )
    ) {
        push @lines, $line;
        last if $line =~ m|^< \d+$|;
    }
    return \@lines;
}

sub stop_runner {    ## 'exit', then the child's exit code ##
    my ($child) = @ARG;
    print { $child->{'w'} } "exit\n";
    close( $child->{'w'} );
    waitpid( $child->{'pid'}, 0 );
    return $CHILD_ERROR >> 8;
}

sub reaped_exit {    ## a refused child exits by itself ##
    my ($child) = @ARG;
    close( $child->{'w'} );
    waitpid( $child->{'pid'}, 0 );
    return $CHILD_ERROR >> 8;
}

sub result_of {
    my ($lines) = @ARG;
    my ($line)  = grep {m|^= |} @$lines;
    return AMOS7::deps::root_runner::parse_result($line);
}

sub same_list {
    return join( ',', @{ $ARG[0] // [] } ) eq join( ',', @ARG[ 1 .. $#ARG ] );
}

say sprintf ': runner child as uid %d%s', $run_uid,
    $as_root ? ' [ nobody, this test runs as root ]' : '';

##[ 1 : a working backend ]###################################################

say ': install through the family backend';

my $child = spawn_runner( 'family' => qw| fakefam | );
ok( $child->{'status'} eq '+ ready family=fakefam install=yes',
    "start-up line '+ ready family=fakefam install=yes'"
) or say "         [ got '$child->{'status'}' ]";

my $lines  = converse( $child, 'install okpkg1 badpkg2 manpkg3' );
my $result = result_of($lines);
ok( @$lines >= 2 && $lines->[-1] eq '< 1', "mixed result : ends with '< 1'" );
ok( scalar( grep {m|^> fake installing okpkg1$|} @$lines ),
    "backend output streamed as '> ' lines [ the sink ]"
);
ok( scalar( grep {m|^> fake backend warning$|} @$lines ),
    "backend warnings become '> ' lines" );
ok( ( grep {m|^= |} @$lines ) == 1 && $lines->[-2] =~ m|^= |,
    'exactly one result line, right before the exit line'
);
ok( defined $result
        && same_list( $result->{'ok'},     qw| okpkg1 | )
        && same_list( $result->{'failed'}, qw| badpkg2 | )
        && same_list( $result->{'manual'}, qw| manpkg3 | ),
    'parse_result : ok \ failed \ manual as the backend returned them'
);

$lines  = converse( $child, 'install okpkg1 okpkg-2.0+x' );
$result = result_of($lines);
ok( $lines->[-1] eq '< 0'
        && defined $result
        && same_list( $result->{'ok'}, qw| okpkg1 okpkg-2.0+x | )
        && !@{ $result->{'failed'} }
        && !@{ $result->{'manual'} },
    "all ok : '= ok=okpkg1,okpkg-2.0+x failed= manual=' and '< 0'"
);

##[ 2 : invalid package names ]###############################################

say ': invalid package names';

foreach my $bad ( 'ok;rm', '-oDpkg::Pre-Invoke=x', 'UPPER', '../x' ) {
    $lines = converse( $child, "install okpkg1 $bad" );
    ok( ( grep {m|^> refused : invalid package name$|} @$lines )
            && $lines->[-1] eq '< 1'
            && !( grep {m|fake installing|} @$lines ),
        "'$bad' : refused, the backend never called"
    );
}

$lines = converse( $child, 'cpan Bad;Name' );
ok( ( grep {m|^> refused : invalid module name$|} @$lines )
        && $lines->[-1] eq '< 1',
    "'cpan' : invalid module name refused [ still served ]"
);

$lines = converse( $child, 'rm -rf /' );
ok( @$lines == 1 && $lines->[0] eq '< 1', "unknown command : '< 1'" );

ok( stop_runner($child) == 0, "'exit' : the runner ends with 0" );

##[ 3 : no usable backend ]###################################################

say ': families without a usable backend';

foreach my $case (
    [ 'Bad/../x',  'invalid family name',                    'failed' ],
    [ 'nofam',     "no backend for family 'nofam'",          'manual' ],
    [ 'norootfam', "backend 'norootfam' does not need root", 'failed' ]
) {
    my ( $family, $reason, $list ) = @$case;
    $child = spawn_runner( 'family' => $family );
    ok( scalar(
            $child->{'status'}
                =~ m|^\+ ready family=\S+ install=no : \Q$reason\E$|
        ),
        "'$family' : start-up line says install=no : $reason"
    ) or say "         [ got '$child->{'status'}' ]";
    $lines  = converse( $child, 'install okpkg1' );
    $result = result_of($lines);
    ok( ( grep {m|^> refused : \Q$reason\E$|} @$lines )
            && $lines->[-1] eq '< 1'
            && defined $result
            && same_list( $result->{$list}, qw| okpkg1 | )
            && !( grep {m|NOROOT BACKEND CALLED|} @$lines ),
        "'$family' : install refused, package listed as '$list', no crash"
    );
    $lines = converse( $child, 'cpan Bad;Name' );
    ok( $lines->[-1] eq '< 1',    "'$family' : the runner still answers" );
    ok( stop_runner($child) == 0, "'$family' : clean exit" );
}

##[ 4 : unsafe ownership refuses to start ]###################################

say ': unsafe lib tree';

sub expect_refused {
    my ( $label, $pattern, %opt ) = @ARG;
    my $child = spawn_runner( 'family' => qw| fakefam |, %opt );
    ok( scalar( $child->{'status'} =~ m|^- refused : .*$pattern| ),
        "$label : '- refused' at start" )
        or say "         [ got '$child->{'status'}' ]";
    ok( reaped_exit($child) == 1, "$label : the runner exits 1" );
}

chmod 0664, "$deps/backend/fakefam.pm";
expect_refused( 'group writable backend file',
    qr|fakefam\.pm' is group\\world writable| );
chmod 0644, "$deps/backend/fakefam.pm";

chmod 0775, "$deps/backend";
expect_refused( 'group writable backend dir',
    qr|backend' is group\\world writable| );
chmod 0755, "$deps/backend";

chmod 0646, "$deps/debp.pm";    ## loaded only through os_package ##
expect_refused(
    'world writable debp.pm [ an indirect load ]',
    qr|debp\.pm' is group\\world writable|
);
chmod 0644, "$deps/debp.pm";

rename "$deps/backend/fakefam.pm", "$tmp/fakefam.pm" or die;
symlink "$tmp/fakefam.pm", "$deps/backend/fakefam.pm" or die;
expect_refused( 'symlinked backend file', qr|fakefam\.pm' is a symlink| );
unlink "$deps/backend/fakefam.pm";
rename "$tmp/fakefam.pm", "$deps/backend/fakefam.pm" or die;

expect_refused(
    'tree owned by the zenka uid',
    qr|is owned by the zenka user|,
    'deny_uid' => $run_uid
);

if ($as_root) {
    chown $other_uid - 1, $run_gid, "$deps/backend/fakefam.pm";
    expect_refused(
        'backend owned by a third uid',
        qr|fakefam\.pm' is owned by uid \d+ \[ expected root or the tree owner|
    );
    chown $run_uid, $run_gid, "$deps/backend/fakefam.pm";
}

$child = spawn_runner( 'family' => qw| fakefam | );
ok( $child->{'status'} eq '+ ready family=fakefam install=yes',
    'tree restored : the runner starts again' );
stop_runner($child);

##[ 5 : as root, the test family variable is ignored ]########################

if ($as_root) {
    say ': root ignores the test family variable';
    my $real = AMOS7::deps::os_package::detect_os();
    $child = spawn_runner( 'family' => qw| fakefam |, 'stay_root' => 1 );
    ok( scalar(
            $child->{'status'} =~ m|^\+ ready family=\Q$real\E install=|
        ),
        "root runner : family '$real' from detect_os, not 'fakefam'"
    ) or say "         [ got '$child->{'status'}' ]";
    ok( stop_runner($child) == 0,
        'root runner : clean ' . 'exit [ no install sent ]' );
} else {
    say ': [ not root : the root-ignores-test-family check is skipped ]';
}

finish();
