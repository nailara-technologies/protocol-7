#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## bounded place : 50,000 live nodes, fresh-process peak rss and resume

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use AMOS7::N7FS        qw| make_dirs read_file write_new_file |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Placement;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

my $nodes = $ENV{'N7FS_TEST_PLACE_NODES'} // 50_000;
my $limit = 640 * 1024;

if ( @ARGV and $ARGV[0] eq qw| place-child | ) {
    my ( $base, $disk ) = @ARGV[ 1, 2 ];
    open( my $pass, '<:raw', "$base/pass" ) or die $OS_ERROR;
    my $root = root_open(
        qw| path |    => "$base/root.key",
        qw| pass_fd | => fileno($pass),
    );
    my $r = AMOS7::N7FS::Placement::place_missing(
        qw| root |       => $root,
        qw| disk |       => $disk,
        qw| disk_root |  => "$base/root",
        qw| host_dir |   => "$base/host",
        qw| no_check |   => 0,
        qw| dry_run |    => 0,
        qw| samples |    => 1,
        qw| commit_age | => '99Y0',
    );
    my $status = read_file('/proc/self/status') // die 'no proc status';
    my ($peak) = $status =~ m|^VmHWM:\s+(\d+) kB|m;
    die 'no VmHWM' if not defined $peak;
    my $plan = 0;
    $plan += $r->{'plan'}{$ARG} // 0 for keys $r->{'plan'}->%*;
    my $sealed = 0;
    $sealed += $r->{'sealed'}{$ARG} // 0 for keys $r->{'sealed'}->%*;
    say "place plan=$plan sealed=$sealed "
        . "unplaced=$r->{'unplaced'} peak_kib=$peak";
    my $failed = grep { not $_->{'ok'} } values $r->{'results'}->%*;
    exit( $failed ? 1 : 0 );
}

my $box  = sandbox();
my $base = $box->{'base'};
write_new_file( "$base/pass", "pw\npw\n" );
open( my $pass_in, '<:raw', "$base/pass" ) or die $OS_ERROR;
root_init(
    qw| path |    => "$base/root.key",
    qw| pass_fd | => fileno($pass_in),
    qw| m |       => 1024,
    qw| t |       => 1,
    qw| p |       => 1,
);
seek $pass_in, 0, 0 or die $OS_ERROR;
my $root = root_open(
    qw| path |    => "$base/root.key",
    qw| pass_fd | => fileno($pass_in),
);
my $signer = test_signer();
my $disk   = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'place-memory',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
my $tree = "$box->{'src'}/tree";
make_dirs($tree);
my @paths = map {"$tree/node-$ARG"} 0 .. $nodes - 1;
write_new_file( $paths[$ARG], "node $ARG\n" ) for 0 .. $nodes - 1;
my $import = assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $signer,
    qw| paths |          => [$tree],
    qw| tree |           => 'memory-tree',
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
ok( scalar( $import->{'entries'}->@* ) == $nodes,
    "synthetic tree contains $nodes nodes"
);
my $holder = "$base/holder";
make_dirs($holder);
AMOS7::N7FS::Placement::holders_save(
    {   qw| local | => {
            qw| spec |   => $holder,
            qw| role |   => qw| durable |,
            qw| domain | => qw| local |,
            qw| owned |  => 1,
        },
    },
    qw| root | => $root,
);
$ENV{'N7FS_TEST_PLACE_CHUNK'} = 1000;

sub place {
    my $out = "$base/place.out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, $PROGRAM_NAME, 'place-child', $base, $disk )
            or exit 99;
    }
    waitpid $pid, 0;
    my $text = read_file($out) // '';
    return ( $CHILD_ERROR >> 8, $text );
}

my ( $rc, $out ) = place();
say $out;
my ($peak) = $out =~ m|peak_kib=(\d+)|;
ok( $rc == 0 && $out =~ m|plan=$nodes sealed=$nodes unplaced=0|,
    'first run places every synthetic node' )
    or say $out;
ok( defined $peak && $peak < $limit,
    "peak rss stays below $limit KiB [ measured "
        . ( $peak // 'unknown' )
        . ' KiB ]'
);
( $rc, $out ) = place();
say $out;
ok( $rc == 0 && $out =~ m|plan=0 sealed=0 unplaced=0|,
    'second run resumes with nothing to do'
) or say $out;

done();

#,,.,,.,.,,..,,,.,...,,,,,,,,,..,,,..,,,,,.,.,..,,...,.,.,.,.,...,,.,,,.,,...,
#I7RPYNDBWRCPQENFOGTGN2ESXB3EU5ZM37QHSKEII3FK3WKHFOD3I2CVCORNOD2BMHOGPC4BWEGMM
#\\\|IZTH6COPRXBEGWL6XZCXZRAFERZ44UW55U2WBDCICHP2ALJCC2F \ / AMOS7 \ YOURUM ::
#\[7]N4K4N77JGBTP6F65EVBTFEQJZM44V56ENKIJVH2FNMQBJJ7GF2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
