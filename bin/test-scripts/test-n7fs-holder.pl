#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
use File::Copy qw| copy |;
use IPC::Open3 qw| open3 |;
use Symbol     qw| gensym |;

$^F = 100;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use JSON::PP;
use AMOS7::N7FS        qw| read_file write_new_file make_dirs unb32 |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Keys;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $cli  = "$FindBin::Bin/../n7fs";
my $fake = "$FindBin::Bin/fixtures/n7fs/fake-ssh.sh";
chmod 0755, $fake or die $OS_ERROR;
my $remote = "$box->{'base'}/remote";
make_dirs( $remote, 0700 );
my $log = "$box->{'base'}/ssh.log";
write_new_file( $log, '' );
my $spec = 'ssh:fake:/holder';
$ENV{'N7FS_SSH'}         = $fake;
$ENV{'FAKE_SSH_LOG'}     = $log;
$ENV{'FAKE_HOLDER_ROOT'} = $remote;
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';
my $passfile = "$box->{'base'}/pass";
write_new_file( $passfile, "holder pass\nholder pass\n" );
my $rootfile = "$box->{'base'}/root.key";

sub cli {
    my ( $expect, $name, @args ) = @_;
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    my ( $in, $out, $err ) = ( undef, undef, gensym );
    my $pid
        = open3( $in, $out, $err, $cli, '-pass-fd', fileno($pass), @args );
    close $in;
    my $stdout = do { local $INPUT_RECORD_SEPARATOR; <$out> }
        // '';
    my $stderr = do { local $INPUT_RECORD_SEPARATOR; <$err> }
        // '';
    waitpid $pid, 0;
    my $status = $CHILD_ERROR >> 8;
    ok( $status == $expect, "$name [ status $status ]" );
    say "        $stderr" if $status != $expect;
    return ( $stdout, $stderr );
}

say ':: fixture';
cli( 0, 'root init', '-root-key', $rootfile, '-argon-m', 1024,
    qw| root init |, $rootfile );
my $host = test_signer();
my $disk = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'holder-test',
    qw| intent |   => 'fake ssh holder',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $host,
);
my $source = "$box->{'src'}/plain-name.txt";
write_new_file( $source, 'blind holder acceptance content' );
chmod 0644, $source;
utime 123456789, 123456789, $source;
symlink 'plain-name.txt', "$box->{'src'}/link" or die $OS_ERROR;
assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $host,
    qw| paths |          => [ $box->{'src'} ],
    qw| tree |           => 'holder-tree',
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);

say ':: seal and clean recovery';
cli( 0, 'seal tree over fake ssh',
    '-root-key', $rootfile,
    '-out', $spec, '-tree', 'holder-tree', 'seal', $disk );
cli( 0, 'holder check', '-root-key', $rootfile,
    '-samples', 2, 'holder-check', $spec );
ok( index( read_file($log), 'dd if=' ) < 0,
    'range reads use tail and head, not byte-wise dd'
);
my $before_read_failure = snapshot($remote);
{
    local $ENV{'FAKE_SSH_READ_FAIL'} = 1;
    cli( 1, 'read failure during seal is fatal',
        '-root-key', $rootfile,
        '-out', $spec, '-tree', 'holder-tree', 'seal', $disk );
}
ok( snap_equal( $before_read_failure, snapshot($remote) ),
    'failed read cannot replace the holder head or map'
);
my $clean_root = "$box->{'base'}/clean-root.key";
copy( $rootfile, $clean_root ) or die $OS_ERROR;
chmod 0600, $clean_root;
my $target = "$box->{'base'}/recovered";
cli( 0, 'clean named-tree recovery',
    '-root-key', $clean_root,
    '-from',     $spec, '-tree', 'holder-tree', 'seal-recover', $target );
ok( read_file("$target/plain-name.txt") eq read_file($source),
    'remote tree bytes match' );
my @a = stat $source;
my @b = stat "$target/plain-name.txt";
ok( ( $a[2] & 07777 ) == ( $b[2] & 07777 ) and $a[9] == $b[9],
    'remote tree metadata matches' );
ok( readlink("$target/link") eq 'plain-name.txt', 'remote symlink matches' );
{
    local $ENV{'FAKE_SSH_DOWNLOAD_DROP'} = 7;
    cli(1,              'truncated streaming download fails cleanly',
        '-root-key',    $clean_root,
        '-from',        $spec,
        '-tree',        'holder-tree',
        'seal-recover', "$box->{'base'}/download-target"
    );
}
cli(0,              'download resumes from the local spool size',
    '-root-key',    $clean_root,
    '-from',        $spec,
    '-tree',        'holder-tree',
    'seal-recover', "$box->{'base'}/download-target"
);
ok( read_file("$box->{'base'}/download-target/plain-name.txt") eq
        read_file($source),
    'resumed download restores identical content'
);
my $argv_log = read_file($log);
ok( index( $argv_log, 'plain-name.txt' ) < 0
        and index( $argv_log, 'holder pass' ) < 0
        and index( $argv_log, $rootfile ) < 0,
    'fake ssh argv has no plaintext name, passphrase or key path'
);
cli( 1, 'shell metacharacter alias refused',
    '-root-key', $rootfile, 'holder-check', 'ssh:bad;host:/holder' );

say ':: interrupted upload resumes';
my $resume_spec   = 'ssh:resume:/holder';
my $resume_remote = "$box->{'base'}/resume-remote";
make_dirs( $resume_remote, 0700 );
local $ENV{'FAKE_HOLDER_ROOT'} = $resume_remote;
$ENV{'FAKE_SSH_DROP'} = 37;
cli( 0, 'drop is retried and upload resumes',
    '-root-key', $rootfile,
    '-out', $resume_spec, '-tree', 'holder-tree', 'seal', $disk );
delete $ENV{'FAKE_SSH_DROP'};
my $before = read_file($log);
cli( 0, 'rerun skips confirmed blobs',
    '-root-key', $rootfile,
    '-out', $resume_spec, '-tree', 'holder-tree', 'seal', $disk );
my $after = read_file($log);
ok( ( () = $after =~ m|cat >>|g ) == ( () = $before =~ m|cat >>|g ),
    'finished blobs are not re-sent' );
my $crash_remote = "$box->{'base'}/crash-remote";
make_dirs( $crash_remote, 0700 );
{
    local $ENV{'FAKE_HOLDER_ROOT'} = $crash_remote;
    $ENV{'FAKE_SSH_DROP'}            = 41;
    $ENV{'FAKE_SSH_FAIL_AFTER_DROP'} = 1;
    cli( 1, 'process fails after a partial upload',
        '-root-key', $rootfile,
        '-out', 'ssh:crash:/holder', '-tree', 'holder-tree', 'seal', $disk );
    delete $ENV{'FAKE_SSH_DROP'};
    delete $ENV{'FAKE_SSH_FAIL_AFTER_DROP'};
    my ($pending_file) = glob "$rootfile.state/pending/*";
    my $pending_json = JSON::PP->new->decode( read_file($pending_file) );
    ok( substr( unb32( $pending_json->{'wrap'} ), 0, 5 ) eq "P7SW\x01",
        'pending node keys are wrapped at rest' );
    my @pending_spools = glob "$rootfile.state/spool/.sealing.*";
    ok( @pending_spools == 1,
        'interrupted spool uses a deterministic pending name' );
    my $partial_log = read_file($log);
    cli(0,           'rerun continues the same ciphertext temporary',
        '-root-key', $rootfile,
        '-out',      'ssh:crash:/holder',
        '-tree',     'holder-tree',
        'seal',      $disk
    );
    my ($temp_name)
        = $partial_log =~ m|crash cat >> '/holder/([A-Z2-7]+[.]upload)'|;
    my $resumed_log = read_file($log);
    ok( index( $resumed_log, "crash cat >> '/holder/$temp_name'" ) >= 0,
        'partial ciphertext name is reused after process failure'
    );
}
$ENV{'FAKE_HOLDER_ROOT'} = $remote;

say ':: failure, old data and corruption';
{
    my $wrong_remote = "$box->{'base'}/wrong-remote";
    make_dirs( $wrong_remote, 0700 );
    local $ENV{'FAKE_HOLDER_ROOT'} = $wrong_remote;
    local $ENV{'FAKE_SSH_WRONG'}   = 1;
    cli( 1, 'wrong sampled readback is refused',
        '-root-key', $rootfile,
        '-out', 'ssh:wrong:/holder', '-tree', 'holder-tree', 'seal', $disk );
}
ok( AMOS7::N7FS::Holder::_quote("/holder/a'b") eq "'/holder/a'\"'\"'b'",
    'remote paths are single quoted for posix sh' );
{
    my $failure_remote = "$box->{'base'}/failure-remote";
    make_dirs( $failure_remote, 0700 );
    local $ENV{'FAKE_HOLDER_ROOT'} = $failure_remote;
    local $ENV{'FAKE_SSH_FAIL'}    = 1;
    cli( 1, 'persistent command failure is clear',
        '-root-key', $rootfile,
        '-out', 'ssh:failure:/holder', '-tree', 'holder-tree', 'seal',
        $disk );
}
{
    local $ENV{'FAKE_SSH_READ_FAIL'} = 1;
    local $ENV{'FAKE_SSH_STDERR'}    = 1;
    cli( 1, 'large stderr cannot deadlock a failed read',
        '-root-key', $rootfile, 'holder-check', $spec );
}
my $root = do {
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    AMOS7::N7FS::Keys::root_open(
        qw| path |    => $rootfile,
        qw| pass_fd | => fileno($pass)
    );
};
my $head_name      = AMOS7::N7FS::Seal::_head_name($root);
my @ssh_lines      = split m|\n|, read_file($log);
my ($first_upload) = grep { $ssh_lines[$_] =~ m|cat >>| } 0 .. $#ssh_lines;
my ($first_head)
    = grep { $ssh_lines[$_] =~ m|mv -f -- .*$head_name| } 0 .. $#ssh_lines;
ok( defined $first_head and $first_head > $first_upload,
    'head is published only after content, map and journal uploads'
);
my $head_path = "$remote/$head_name";
write_new_file( "$head_path.upload", 'stale head bytes' );
copy( $head_path, "$box->{'base'}/old-head" ) or die $OS_ERROR;
cli(0,
    'advance remote head',
    '-root-key',
    $rootfile,
    '-out', $spec, 'shred', $disk,
    do {
        my $id = AMOS7::N7FS::Disk::disk_read_id(
            qw| root | => $box->{'root'},
            qw| disk | => $disk
        );
        my $replay = AMOS7::N7FS::Journal::journal_replay($id);
        ( sort keys $replay->{'nodes'}->%* )[0];
    }
);
copy( $head_path, "$box->{'base'}/saved-head" ) or die $OS_ERROR;
copy( "$box->{'base'}/old-head", $head_path )   or die $OS_ERROR;
cli(1,              'old remote head refused',
    '-root-key',    $rootfile,
    '-from',        $spec,
    '-tree',        'holder-tree',
    'seal-recover', "$box->{'base'}/old-target"
);
copy( "$box->{'base'}/saved-head", $head_path ) or die $OS_ERROR;
unlink $head_path                               or die $OS_ERROR;
cli( 1, 'deleted head on a pinned holder is refused',
    '-root-key', $rootfile, 'holder-check', $spec );
copy( "$box->{'base'}/saved-head", $head_path ) or die $OS_ERROR;
my ( undef, undef, $current_map )
    = AMOS7::N7FS::Seal::_context( $root, $spec, 0 );
my $victim = ( map { $ARG->{'blob'} } values $current_map->{'nodes'}->%* )[0];
ok( unlink("$remote/$victim") == 1, 'delete a currently mapped blob' );
cli( 1, 'holder-check detects deleted blob',
    '-root-key', $rootfile, 'holder-check', $spec );
write_new_file( "$remote/$victim", 'wrong bytes' );
cli( 1, 'holder-check detects corrupted blob',
    '-root-key', $rootfile, 'holder-check', $spec );
cli(1,              'wrong truncated remote data refuses recovery',
    '-root-key',    $rootfile,
    '-from',        $spec,
    '-tree',        'holder-tree',
    'seal-recover', "$box->{'base'}/corrupt-target"
);

done();

#,,,,,,,,,,.,,,,,,,,.,..,,,..,,,,,,.,,,..,,.,,..,,...,...,.,.,...,,.,,,.,,,.,,
#72HZPNL3ANCJ5V7XBSGU7SE7QKHACFKQVFOYE7VJWAQZU3C4RLBPZOO2XGJ2F3KHP3IAAO6MSVGP4
#\\\|LETA33SC24VOOQBSFMAVHEVVQLIRPW76W7BJNWGMCIBA7SNMPP3 \ / AMOS7 \ YOURUM ::
#\[7]GFNLGMM5YWU5XIJ5HMSD457MIDJB74WTIL24XPPXZRXIASWLEYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
