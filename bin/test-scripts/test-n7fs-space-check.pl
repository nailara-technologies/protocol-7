#!/usr/bin/env perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
use File::Temp qw| tempdir |;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use AMOS7::N7FS::Disk  qw| disk_init disk_attach disk_require_attached |;
use AMOS7::N7FS::Store qw| assimilate |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

use constant TRUE => 5;

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = test_signer();
clock_real();

my %base = ( root => $root, host_dir => $hdir );
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'space-check-test',
    intent => 'n7fs space check test [ test data ]',
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);
my $disk_id = disk_require_attached(%run);

my $body = "test data : space check\n" x 13;
write_file( "$src/one", $body );
write_file( "$src/two", $body );

my $p7c_dir = tempdir( CLEANUP => 1 );
my $p7c_log = "$p7c_dir/calls";
write_file(
    "$p7c_dir/p7c",
    <<'P7C_STUB'
#!/usr/bin/env perl
use strict;
use warnings;
exit 127 if $ENV{'P7C_TEST_FAIL'};
open my $log, '>>', $ENV{'P7C_TEST_LOG'} or die $!;
print {$log} join( "\t", @ARGV ), "\n";
close $log;
my $fit = $ENV{'P7C_TEST_FIT'} // 'fits';
print "$fit mount=/fake expected=13 free=130 reserved=0 free_after=117 "
    . "warn_free=13 critical_free=5\n";
exit( $fit eq 'does-not-fit' ? 1 : 0 );
P7C_STUB
);
chmod 0755, "$p7c_dir/p7c" or die $OS_ERROR;
local $ENV{'PATH'}         = "$p7c_dir:$ENV{'PATH'}";
local $ENV{'P7C_TEST_LOG'} = $p7c_log;

local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, length($body) - 1, 1, 1, 1 ] };
my $before = snapshot($root);
refused(
    sub { assimilate( %run, paths => [ "$src/one", "$src/two" ] ) },
    qr|expected store growth \d+ bytes exceeds free space \d+ bytes|,
    'too small store file system is refused with both numbers'
);
ok( snap_equal( $before, snapshot($root) ),
    'refusal writes no store content'
);

## the estimate is the stat sizes : the duplicate source counts again
local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, 2 * length($body), 1, 1, 1 ] };
my $report = assimilate( %run, paths => [ "$src/one", "$src/two" ] );
ok( $report->{'failed'} == 0, 'exactly enough room passes' );
ok( scalar( grep { $ARG->{'status'} eq 'stored' } $report->{'entries'}->@* )
        == 1,
    'duplicate batch content is counted and stored once'
);

## already stored content : the estimate still counts it [ no hashing ]
local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, 0, 1, 1, 1 ] };
refused(
    sub { assimilate( %run, paths => ["$src/one"] ) },
    qr|estimate from the sizes of 1 sources : may be high|,
    'the refusal says the estimate comes from sizes and may be high'
);
local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, length($body), 1, 1, 1 ] };
my $repeat = assimilate( %run, paths => ["$src/one"] );
ok( $repeat->{'entries'}[0]{'status'} eq 'unchanged',
    'already stored content passes when its size fits [ estimate ]' );
## unreadable \ vanished \ non-regular sources add nothing to the estimate
{
    local $AMOS7::N7FS::Store::STATVFS
        = sub { return [ 1, 1, 1000, 1000, length($body), 1, 1, 1 ] };
    my @gone = ( "$src/vanished", $src );
    my $check
        = AMOS7::N7FS::Store::assimilate_space_check(
        { %run, '_disk_job_attempted' => TRUE },
        $disk_id, 1, [ map { { 'path' => $ARG } } @gone, "$src/one" ] );
    ok( $check->{'expected_bytes'} == length($body)
            && $check->{'new_nodes'} == 1,
        'vanished file and directory left out of the estimate'
    );
    my $twice
        = AMOS7::N7FS::Store::assimilate_space_check(
        { %run, '_disk_job_attempted' => TRUE },
        $disk_id, 1, [ map { { 'path' => $ARG } } "$src/one", "$src/one" ] );
    ok( $twice->{'expected_bytes'} == length($body),
        'one inode counts once' );
}
open my $calls_fh, '<', $p7c_log or die $OS_ERROR;
my @calls = <$calls_fh>;
close $calls_fh;
chomp @calls;
ok( $calls[0]
        =~ qr|\Asystem\.disk-register\tn7fs-.*\t${\( 2 * length $body )}\z|,
    'assimilate registers the estimated store growth through p7c'
);
ok( $calls[1] =~ qr|\Asystem\.disk-done\tn7fs-.*\z|,
    'assimilate completes its registered writer'
);
ok( $calls[2] =~ qr|\Asystem\.disk-register\t.*\t${\( length $body )}\z|,
    'unchanged content registers its size [ estimate ]' );
ok( $calls[3] =~ qr|\Asystem\.disk-done\t|, 'that writer is also completed' );

{
    local $ENV{'P7C_TEST_FIT'} = 'does-not-fit';
    local $AMOS7::N7FS::Store::STATVFS
        = sub { return [ 1, 1, 1000, 1000, 10000, 1, 1, 1 ] };
    write_file( "$src/three", "new content for remote refusal\n" );
    my $remote_before = snapshot($root);
    refused(
        sub { assimilate( %run, paths => ["$src/three"] ) },
        qr|system disk pre-check : does-not-fit .*free_after=117|,
        'system zenka does-not-fit answer refuses before writing'
    );
    ok( snap_equal( $remote_before, snapshot($root) ),
        'remote refusal writes no store content'
    );
}

{
    local $ENV{'P7C_TEST_FAIL'} = 1;
    local $AMOS7::N7FS::Store::STATVFS
        = sub { return [ 1, 1, 1000, 1000, 10000, 1, 1, 1 ] };
    write_file( "$src/four", "new content without system zenka\n" );
    my $without_p7c = assimilate( %run, paths => ["$src/four"] );
    ok( $without_p7c->{'failed'} == 0,
        'unavailable p7c leaves the local pre-check non-fatal' );
}

done();

#,,.,,..,,...,,,,,.,,,..,,...,...,,.,,..,,.,,,..,,...,...,.,.,,.,,.,.,..,,.,.,
#XB7UP3ICLKWZ6IMSJKX2G7K5BOXNQKU2GEG5E3Q3ZA3AHQIT2TPS4QWFWOEYEUOJX6473SVK2NEG6
#\\\|7NFKMUCSXSLIQFWNCY74UK4CCOBIZ4WKHZYMQ7GM4NNFKZZS5PY \ / AMOS7 \ YOURUM ::
#\[7]TNU7TYPTIVGGMKOHTNKIASKGQG24RQUYPEF6JCK24H6ZXAIERUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
