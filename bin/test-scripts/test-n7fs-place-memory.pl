#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## bounded place : small and 2 MiB nodes, peak rss, growth and resume

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use AMOS7::N7FS        qw| make_dirs read_file write_new_file |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Placement;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

my @scales
    = defined $ENV{'N7FS_TEST_PLACE_NODES'}
    ? ( $ENV{'N7FS_TEST_PLACE_NODES'} )
    : ( 10_000, 50_000 );
my @large_scales
    = ( $ENV{'N7FS_TEST_PLACE_LARGE'} // 1 ) eq '0' ? ()
    : defined $ENV{'N7FS_TEST_PLACE_LARGE_NODES'}   ? split m|,|,
    $ENV{'N7FS_TEST_PLACE_LARGE_NODES'}
    : ( 256, 768 );
my $large_bytes        = 2 * 1024**2;
my $limit              = 640 * 1024;
my $growth_limit       = 2;
my $large_growth_limit = 12;

if ( @ARGV and $ARGV[0] eq qw| place-child | ) {
    my ( $base, $disk, $check ) = @ARGV[ 1, 2, 3 ];
    open( my $pass, '<:raw', "$base/pass" ) or die $OS_ERROR;
    my $root = root_open(
        qw| path |    => "$base/root.key",
        qw| pass_fd | => fileno($pass),
    );
    my $trace_next = 0;
    my $r          = AMOS7::N7FS::Placement::place_missing(
        qw| root |       => $root,
        qw| disk |       => $disk,
        qw| disk_root |  => "$base/root",
        qw| host_dir |   => "$base/host",
        qw| no_check |   => !$check,
        qw| dry_run |    => 0,
        qw| samples |    => 1,
        qw| commit_age | => '99Y0',
        qw| progress |   => sub {
            my ( $visited, $total, $finished ) = @ARG;
            return if not $ENV{'N7FS_TEST_PLACE_TRACE'};
            my $step = $ENV{'N7FS_TEST_PLACE_TRACE_STEP'} // 64;
            return if not $finished and $visited < $trace_next;
            $trace_next = int( $visited / $step + 1 ) * $step;
            my $status = read_file('/proc/self/status')
                // die 'no proc status';
            my ($rss) = $status =~ m|^VmRSS:\s+(\d+) kB|m;
            say "chunk visited=$visited total=$total finished=$finished "
                . 'rss_kib='
                . ( $rss // 'unknown' );
        },
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

sub run_scale {
    my ( $nodes, $blob_bytes, $chunk, $check ) = @ARG;
    $blob_bytes //= 0;
    $chunk      //= 2048;
    $check      //= 1;
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
    my $filler
        = $blob_bytes
        ? 'protocol-7-large-node' x int( $blob_bytes / 21 + 1 )
        : '';

    for my $index ( 0 .. $nodes - 1 ) {
        write_new_file( "$tree/node-$index", "node $index\n" ), next
            if not $blob_bytes;
        my $body = pack( 'Q>', $index ) . $filler;
        write_new_file( "$tree/node-$index",
            substr( $body, 0, $blob_bytes ) );
    }
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
    local $ENV{'N7FS_TEST_PLACE_CHUNK'} = $chunk;
    local $ENV{'N7FS_TEST_PLACE_TRACE'} = $blob_bytes ? 1 : 0;
    local $ENV{'N7FS_TEST_PACK_LIMIT'}  = 0 if $blob_bytes;

    my $place = sub {
        my $out = "$base/place.out";
        my $pid = fork // die "fork : $OS_ERROR";
        if ( $pid == 0 ) {
            open( STDOUT, '>:raw', $out )     or exit 98;
            open( STDERR, '>&',    \*STDOUT ) or exit 98;
            exec( $EXECUTABLE_NAME, $PROGRAM_NAME, 'place-child', $base,
                $disk, $check )
                or exit 99;
        }
        waitpid $pid, 0;
        my $text = read_file($out) // '';
        return ( $CHILD_ERROR >> 8, $text );
    };

    my ( $rc, $out ) = $place->();
    say $out;
    my ($peak) = $out =~ m|peak_kib=(\d+)|;
    my @rss = $out =~ m|^chunk .*rss_kib=(\d+)|mg;
    ok( $rc == 0 && $out =~ m|plan=$nodes sealed=$nodes unplaced=0|,
        "first run places every one of $nodes synthetic nodes"
    ) or say $out;
    ok( defined $peak && $peak < $limit,
        "peak rss stays below $limit KiB [ measured "
            . ( $peak // 'unknown' )
            . ' KiB ]'
    );
    ( $rc, $out ) = $place->();
    say $out;
    my ($resume_peak) = $out =~ m|peak_kib=(\d+)|;
    my @resume_rss = $out =~ m|^chunk .*rss_kib=(\d+)|mg;
    ok( $rc == 0 && $out =~ m|plan=0 sealed=0 unplaced=0|,
        'second run resumes with nothing to do'
    ) or say $out;
    ok( defined $resume_peak && $resume_peak < $limit,
        "resume peak rss stays below $limit KiB [ measured "
            . ( $resume_peak // 'unknown' )
            . ' KiB ]'
    );
    return {
        qw| first |      => $peak        // 0,
        qw| resume |     => $resume_peak // 0,
        qw| first_rss |  => @rss        ? $rss[-1]        : undef,
        qw| resume_rss | => @resume_rss ? $resume_rss[-1] : undef,
    };
}

my %peaks;
$peaks{$ARG} = run_scale($ARG) for @scales;
if ( @scales == 2 ) {
    my $delta = $scales[1] - $scales[0];
    my $first = sprintf '%.3f',
        ( $peaks{ $scales[1] }{'first'} - $peaks{ $scales[0] }{'first'} )
        / $delta;
    my $resume = sprintf '%.3f',
        ( $peaks{ $scales[1] }{'resume'} - $peaks{ $scales[0] }{'resume'} )
        / $delta;
    say "growth first_kib_per_node=$first "
        . "resume_kib_per_node=$resume bound_kib_per_node=$growth_limit";
    ## 2 KiB allows 80 MiB for 40,000 more nodes, with packed addresses,
    ## bounded shard caches and only compact replay records retained
    ok( $first <= $growth_limit,
        "initial rss growth stays below $growth_limit KiB per node" );
    ok( $resume <= $growth_limit,
        "resume rss growth stays below $growth_limit KiB per node" );
}

my %large_peaks;
$large_peaks{$ARG} = run_scale( $ARG, $large_bytes, 2048, 0 )
    for @large_scales;
if ( @large_scales == 2 ) {
    my $delta = $large_scales[1] - $large_scales[0];
    my $first = sprintf '%.3f',
        ( ( $large_peaks{ $large_scales[1] }{'first_rss'} // 0 )
        - ( $large_peaks{ $large_scales[0] }{'first_rss'} // 0 ) )
        / $delta;
    my $resume = sprintf '%.3f',
        ( ( $large_peaks{ $large_scales[1] }{'resume_rss'} // 0 )
        - ( $large_peaks{ $large_scales[0] }{'resume_rss'} // 0 ) )
        / $delta;
    say "large steady growth first_kib_per_node=$first "
        . "resume_kib_per_node=$resume "
        . "bound_kib_per_node=$large_growth_limit";
    ## 12 KiB bounds retained map state at 160k nodes without hiding a run ##
    ## whose live map or upload buffers grow with every sealed node        ##
    ok( defined $large_peaks{ $large_scales[0] }{'first_rss'}
            && defined $large_peaks{ $large_scales[1] }{'first_rss'}
            && $first <= $large_growth_limit,
        "large-node initial rss growth stays "
            . "below $large_growth_limit KiB per node"
    );
    ok( defined $large_peaks{ $large_scales[0] }{'resume_rss'}
            && defined $large_peaks{ $large_scales[1] }{'resume_rss'}
            && $resume <= $large_growth_limit,
        "large-node resume rss growth stays "
            . "below $large_growth_limit KiB per node"
    );
}

done();

#,,,.,,.,,,,.,...,..,,,,,,.,,,...,,,.,,,.,.,.,..,,...,...,,,.,,..,..,,...,,.,,
#LU4ZIKDOR233QNUGZYBPFYFRLOKCFOQ52S4SDTE33VRVEDIENXK7OMETB5IM322PGMSJMBT3IQLJW
#\\\|4X3YEGCVTEXQDSBTPDUIPPTHCW2B4MN76TTH26IVY5K4WJOF75C \ / AMOS7 \ YOURUM ::
#\[7]37LHUB2LTLELSMZKM7HKXFNDAWLXCICETTOJPG7HUM5FR6EX7QCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
