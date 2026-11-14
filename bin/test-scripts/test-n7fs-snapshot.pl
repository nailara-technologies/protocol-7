#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 8 : independent staging pulls, snapshot headers and shrink freezes.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::N7FS          qw| make_dirs read_file |;
use AMOS7::N7FS::Disk    qw| disk_read_id |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Sign    qw| key_file_signer |;
use AMOS7::N7FS::Snapshot;
use AMOS7::N7FS::Tree qw| manifest_open |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};

sub cli {
    my @args = @ARG;
    my $out  = "$base/out";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    return ( $rc, read_file($out) );
}

my ( $rc, $out ) = cli( 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( 'init', '-name', 'snapshot', '-intent', 'sandbox' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( 'attach', $disk );
ok( $rc == 0, 'sandbox disk is ready' ) or say $out;

write_file( "$src/export.pl",
          "#!/usr/bin/perl\nuse strict;\nsystem qw| cp -a "
        . "-- |, '$src/cmd/.', \$ARGV[0];\nexit \$? >> 8;\n" );
chmod 0755, "$src/export.pl" or die $OS_ERROR;
write_file( "$src/fake-cp.pl",
          "#!/usr/bin/perl\nuse strict;\n\@ARGV = grep { \$_ ne "
        . "'--reflink=always' } \@ARGV;\nexec qw| cp |, \@ARGV;\n" );
chmod 0755, "$src/fake-cp.pl" or die $OS_ERROR;

foreach my $method (qw| cmd reflink copy-verify hardlink |) {
    my $source = "$src/$method";
    make_dirs("$source/sub");
    write_file( "$source/sub/file", "$method contents\n" );
    local $ENV{'N7FS_CP'} = $method eq 'reflink' ? "$src/fake-cp.pl" : 'cp';
    ( $rc, $out ) = cli(
        'snapshot',      $disk,          $source,    '-method', $method,
        '-tree',         "snap-$method", '-staging', "$base/staging-$method",
        '-keep-staging', 2,
        $method eq 'cmd'
        ? ( '-snapshot-cmd', "$src/export.pl" )
        : ()
    );
    ok( $rc == 0 && $out =~ m|1 files, \d+ bytes, 0 unstable|,
        "$method produces a complete snapshot" )
        or say $out;
    ok( $out =~ m|hardlink snapshots share|,
        'hardlink warns about in-place source writes'
    ) if $method eq 'hardlink';
}

( $rc, $out ) = cli(
    'snapshot',                  $disk,
    "$src/copy-verify",          '-method',
    'copy-verify',               '-tree',
    'snap-copy-verify',          '-staging',
    "$base/staging-copy-verify", '-keep-staging',
    2
);
ok( $rc == 0, 'a second copy-verify snapshot succeeds' ) or say $out;
my @staging = sort grep {m|\A\d{14}\z|}
    do { opendir( my $d, "$base/staging-copy-verify" ) or die; readdir $d };
ok( @staging == 2
        && read_file("$base/staging-copy-verify/$staging[0]/sub/file") eq
        "copy-verify contents\n"
        && read_file("$base/staging-copy-verify/$staging[1]/sub/file") eq
        "copy-verify contents\n",
    'a second pull never overwrites the first staging directory'
);

my $id          = disk_read_id( qw| root | => $root, qw| disk | => $disk );
my $replay      = journal_replay($id);
my ($copy_tree) = sort grep { index( $ARG, 'snap-copy-verify:' ) == 0 }
    keys $replay->{'trees'}->%*;
my ( undef, $head ) = manifest_open(
    $id,
    { qw| store_format | => 3 },
    $replay->{'trees'}{$copy_tree}
);
ok( $head->{'snapshot'}{'method'} eq 'copy-verify'
        && $head->{'snapshot'}{'begin'} =~ m|\A\d{14}\z|
        && $head->{'snapshot'}{'end'}   =~ m|\A\d{14}\z|
        && $head->{'snapshot'}{'files'} == 1
        && $head->{'snapshot'}{'bytes'} == length "copy-verify contents\n",
    'the manifest header carries method, ntime range, files and bytes'
);

## a source changed after every attempted copy remains explicitly unstable ##
{
    my $changes = 0;
    local $AMOS7::N7FS::Snapshot::COPY_HOOK = sub {
        write_file( "$src/copy-verify/sub/file", 'changed ' . ++$changes );
    };
    my $r = AMOS7::N7FS::Snapshot::snapshot_run(
        qw| root |         => $root,
        qw| host_dir |     => $hdir,
        qw| disk |         => $disk,
        qw| host |         => key_file_signer("$hdir/host.key"),
        qw| source |       => "$src/copy-verify",
        qw| method |       => 'copy-verify',
        qw| tree |         => 'unstable',
        qw| staging |      => "$base/staging-unstable",
        qw| keep_staging | => 2,
    );
    ok( $r->{'unstable'} == 1 && $changes == 3,
        'copy-verify retries three times and marks a changing source unstable'
    );
    write_file( "$src/copy-verify/sub/file", "copy-verify contents\n" );
}

sub files_fixture {
    my $name = shift;
    my $dir  = "$src/$name";
    make_dirs($dir);
    write_file( "$dir/f$ARG", '1234567890' ) for 1 .. 10;
    return $dir;
}

my $mild = files_fixture('mild');
( $rc, $out ) = cli(
    'snapshot',    $disk,   $mild,       '-method',
    'copy-verify', '-tree', 'snap-mild', '-staging',
    "$base/staging-mild"
);
unlink "$mild/f$ARG" for 9, 10;
( $rc, $out ) = cli(
    'snapshot',    $disk,   $mild,       '-method',
    'copy-verify', '-tree', 'snap-mild', '-staging',
    "$base/staging-mild"
);
ok( $rc == 0
        && $out !~ m|SHRUNK|
        && !defined AMOS7::N7FS::Snapshot::retention_frozen(
        qw| host_dir | => $hdir,
        qw| disk |     => $disk,
        qw| prefix |   => 'snap-mild:'
        ),
    'a twenty percent file shrink does not freeze retention'
) or say $out;

my $bad = files_fixture('bad');
( $rc, $out ) = cli(
    'snapshot',    $disk,   $bad,       '-method',
    'copy-verify', '-tree', 'snap-bad', '-staging',
    "$base/staging-bad"
);
unlink "$bad/f$ARG" for 7 .. 10;
( $rc, $out ) = cli(
    'snapshot',    $disk,   $bad,       '-method',
    'copy-verify', '-tree', 'snap-bad', '-staging',
    "$base/staging-bad"
);
my $frozen = AMOS7::N7FS::Snapshot::retention_frozen(
    qw| host_dir | => $hdir,
    qw| disk |     => $disk,
    qw| prefix |   => 'snap-bad:'
);
ok( $rc == 0 && $out =~ m|SHRUNK| && defined $frozen,
    'a forty percent shrink keeps the snapshot and freezes retention' )
    or say $out;
ok( $frozen->{'files'} == 6 && $frozen->{'previous-files'} == 10,
    'the hand-editable freeze records both file counts'
);
my $config = read_file("$hdir/snapshot-retention.cfg");
ok( $config =~ m|files\s+= 6| && $config !~ m|^\{|m,
    'freeze state uses aligned protocol-7 config, not json'
);
( $rc, $out ) = cli( 'snapshot-confirm', $disk, 'snap-bad' );
ok( $rc == 0 && !defined AMOS7::N7FS::Snapshot::retention_frozen(
        qw| host_dir | => $hdir,
        qw| disk |     => $disk,
        qw| prefix |   => 'snap-bad:'
    ),
    'snapshot-confirm unfreezes the prefix'
) or say $out;

my $crash = files_fixture('crash');
( $rc, $out ) = cli(
    'snapshot',    $disk,   $crash,       '-method',
    'copy-verify', '-tree', 'snap-crash', '-staging',
    "$base/staging-crash"
);
unlink "$crash/f$ARG" for 7 .. 10;
{
    local $ENV{'N7FS_TEST_FAULT'} = 'snapshot:after-rename';
    ( $rc, $out ) = cli(
        'snapshot',    $disk,
        $crash,        '-method',
        'copy-verify', '-tree',
        'snap-crash',  '-staging',
        "$base/staging-crash"
    );
}
ok( $rc != 0 && $out =~ m|injected fault snapshot:after-rename|,
    'a crash after staging rename interrupts the shrunk snapshot'
);
( $rc, $out ) = cli(
    'snapshot',    $disk,   $crash,       '-method',
    'copy-verify', '-tree', 'snap-crash', '-staging',
    "$base/staging-crash"
);
ok( $rc == 0 && defined AMOS7::N7FS::Snapshot::retention_frozen(
        qw| host_dir | => $hdir,
        qw| disk |     => $disk,
        qw| prefix |   => 'snap-crash:'
    ),
    'capturing complete staging after a crash still applies the shrink guard'
) or say $out;
( $rc, $out ) = cli( 'snapshot-confirm', $disk, 'snap-crash' );

( $rc, $out ) = cli(
    'snapshot',    $disk,
    $bad,          '-method',
    'copy-verify', '-tree',
    'snap/bad',    '-staging',
    "$base/staging-refused"
);
ok( $rc != 0 && $out =~ m|tree names refuse /|,
    'snap slash names are refused clearly'
) or say $out;

done();

#,,,,,..,,,,,,.,.,,.,,..,,,,,,...,.,,,..,,.,.,..,,...,...,,..,,,.,,.,,,,.,,..,
#QLHWCTPBJDHJST2YWNGGN5YQUTRQYAI46ZOAI3DFCMIVLNVEY7C4NLRO7PKAH3SZQ5IKTPSFHRRYA
#\\\|ISG6GOOLDSY3XSHCYSPJPH5AREAWTY4YI6A6ZHDRQVZ4SFWMB5V \ / AMOS7 \ YOURUM ::
#\[7]PK56H3F7UUNLUUMXHRKQA6QC7AQAY6XRW7VYNU3ER7PPYWABX6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
