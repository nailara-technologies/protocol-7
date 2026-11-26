#!/usr/bin/env perl
use v5.32.0;
use strict;
use warnings;
use English;

use Test::More;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

use constant { TRUE => 5, FALSE => 0 };

our %data;
our %code;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $now        = 100;
my $free       = 900;
my $files_free = 900;
my $files      = 1000;
my $read_only  = FALSE;
my $fs_type    = 'ext4';
my @events;
my @log_levels;
$data{'disk'}{'warn_free'}                  = 13;
$data{'disk'}{'critical_free'}              = 5;
$data{'disk'}{'warn_min_free_gb'}           = 13;
$data{'disk'}{'critical_min_free_gb'}       = 5;
$data{'disk'}{'absolute_floor_min_size_gb'} = 64;
$data{'disk'}{'history_samples'}            = 13;
$code{'base.time'}                          = sub { return $now };
$code{'system.disk.mounts'}                 = sub {
    return [
        {   device    => '/dev/fake',
            path      => '/fake',
            type      => $fs_type,
            read_only => $read_only,
        }
    ];
};
$code{'system.disk.statvfs'} = sub {
    return {
        block_size  => 1,
        blocks      => 1000,
        blocks_free => $free,
        files       => $files,
        files_free  => $files_free,
    };
};
$code{'base.logs'} = sub { push @log_levels, $ARG[0]; return TRUE };
$code{'protocol-7.route-send'} = sub { push @events, shift; return TRUE };

load_src('system.disk.poll');
load_src('system.disk.post_init');
load_src('system.disk.cmd.disk-status');
load_src('system.disk.cmd.disk-register');
load_src('system.disk.cmd.disk-update');
load_src('system.disk.cmd.disk-done');
load_src('base.interval.rhythm.disk');

my $poll_calls = 0;
$code{'system.disk.handler.poll'} = sub { $poll_calls++; return TRUE };
$code{'system.disk.post_init'}->();
is $poll_calls, 0, 'startup does not poll before the cube session exists';
is_deeply $data{'system'}{'callbacks'}{'initialized'},
    ['system.disk.handler.poll'],
    'startup defers the first poll to the initialized callback';
$data{'system'}{'zenka'}{'initialized'} = TRUE;
$code{'system.disk.post_init'}->();
is $poll_calls, 1, 'an initialized zenka polls immediately';

$free = 40;
$code{'system.disk.poll'}->();
is scalar @events, 1, 'first poll reports an already-critical mount';
like $events[0]{'call_args'}{'args'}, qr|critical|,
    'startup byte pressure is critical';

@events = ();
delete $data{'system'}{'disk'}{'mounts'};
$free       = 900;
$files_free = 40;
$code{'system.disk.poll'}->();
is scalar @events, 1, 'first poll reports inode-only critical pressure';
like $events[0]{'call_args'}{'args'}, qr|critical|,
    'startup inode pressure is critical';

@events = ();
delete $data{'system'}{'disk'}{'mounts'};
$files      = 0;
$files_free = 0;
$code{'system.disk.poll'}->();
is scalar @events, 0, 'healthy first poll emits no recovery';
ok !$data{'system'}{'disk'}{'mounts'}{'/fake'}{'inodes_counted'},
    'zero total inodes means inode data is unavailable';
ok !defined $data{'system'}{'disk'}{'mounts'}{'/fake'}{'inodes_free_percent'},
    'inode-less filesystem has no inode percentage';

delete $data{'system'}{'disk'}{'mounts'};
$files      = 1000;
$files_free = 40;
$free       = 40;
$read_only  = TRUE;
$code{'system.disk.poll'}->();
is scalar @events, 0, 'read-only mount never warns at startup';
is $data{'system'}{'disk'}{'interval_state'}{'pressure'}, 0,
    'read-only mount does not accelerate polling';
my $read_only_status = $code{'system.disk.cmd.disk-status'}->();
like $read_only_status->{'data'}, qr|/fake\s+ro\s+|,
    'read-only mount is marked in disk-status';

@events = ();
delete $data{'system'}{'disk'}{'mounts'};
$read_only  = FALSE;
$free       = 900;
$files_free = 900;
$code{'system.disk.poll'}->();
is scalar @events, 0, 'healthy writable first poll stays silent';
@events = ();
$now    = 200;
$free   = 700;
$code{'system.disk.poll'}->();
is scalar @events, 0, 'healthy polls emit no events';
my $mount = $data{'system'}{'disk'}{'mounts'}{'/fake'};
cmp_ok abs( $mount->{'rate'} - -2 ), '<', 0.00001,
    'trend derives byte loss per second';
is $mount->{'eta'}, 350, 'eta uses current free bytes and trend';

$free = 120;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events,        1, 'warning emits once while below threshold';
is $events[0]{'command'}, 'notify.warn', 'warning uses notify path';

$free = 40;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events, 2, 'critical emits once while below threshold';

$free = 900;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events,        3,             'recovery emits once';
is $events[2]{'command'}, 'notify.info', 'recovery uses notify path';
like $events[2]{'call_args'}{'args'}, qr|recovered|, 'recovery is named';

$files_free = 40;
$code{'system.disk.poll'}->();
is scalar @events, 4, 'inode critical threshold is watched';
$files_free = 900;
$code{'system.disk.poll'}->();
is scalar @events, 5, 'inode recovery emits once';

$data{'disk'}{'mount'}{'/fake'}{warn_free}     = 1;
$data{'disk'}{'mount'}{'/fake'}{critical_free} = 0.5;
$code{'system.disk.poll'}->();
is scalar @events, 5, 'per-mount thresholds override defaults';
delete $data{'disk'}{'mount'};

my $status = $code{'system.disk.cmd.disk-status'}->();
is $status->{'mode'}, 'size', 'multiline status uses size reply mode';
unlike $status->{'data'}, qr|\\n|, 'status contains no literal backslash-n';
my @status_lines = split m|\n|, $status->{'data'}, -1;
is $status_lines[-1],    '', 'status rows end with real newlines';
is scalar @status_lines, 3,  'header and mount are on separate lines';
is length( $status_lines[0] ), length( $status_lines[1] ),
    'status columns align with the header';
like $status->{'data'}, qr|/fake\s+rw\s+\d+ B\s+\d+ B\s+900 B|,
    'disk-status reports aligned mount and byte columns';
like $status->{'data'}, qr|\d+/\d+\s+\d+\s+.*B/s|,
    'disk-status reports inode counts and trend';
is_deeply \@log_levels, [ (0) x @log_levels ],
    'every crossing is logged into the system buffer';

$data{'system'}{'disk'}{'jobs'} = {};
my $registered = $code{'system.disk.cmd.disk-register'}
    ->( 'import-one', '/fake/store', 100 );
is $registered->{'mode'}, 'true', 'writer registration accepts a fitting job';
like $registered->{'data'},
    qr|\Afits mount=/fake expected=100 free=900 reserved=0 free_after=800|,
    'fit answer reports expected and remaining free bytes';
is $data{'system'}{'disk'}{'jobs'}{'import-one'}{'started'}, $now,
    'registered writer keeps its start time';
my $updated = $code{'system.disk.cmd.disk-update'}->( 'import-one', 20 );
like $updated->{'data'}, qr|expected=100 written=20 left=80|,
    'writer update reports expected, written and left';
my $tight = $code{'system.disk.cmd.disk-register'}
    ->( 'import-two', '/fake/other', 740 );
is $tight->{'mode'}, 'true', 'tight writer registration is allowed';
like $tight->{'data'}, qr|\Atight .*reserved=80 free_after=80|,
    'fit calculation includes other registered writers';
my $refused = $code{'system.disk.cmd.disk-register'}
    ->( 'import-three', '/fake/full', 800 );
is $refused->{'mode'}, 'false', 'writer below critical space is refused';
like $refused->{'data'}, qr|\Adoes-not-fit .*free_after=-720|,
    'refusal includes the projected free bytes';
ok !exists $data{'system'}{'disk'}{'jobs'}{'import-three'},
    'refused writer is not registered';
my $jobs_status = $code{'system.disk.cmd.disk-status'}->();
like $jobs_status->{'data'},
    qr|jobs on /fake : free after jobs 80 B|,
    'disk-status subtracts all remaining writer demand';
like $jobs_status->{'data'},
    qr|import-one : expected 100 B, written 20 B, left 80 B|,
    'disk-status lists expected, written and left per writer';
@events = ();
$free   = 120;
$code{'system.disk.poll'}->();
like $events[0]{'call_args'}{'args'},
    qr|registered jobs : import-one, import-two|,
    'warning names registered writers on the mount';
my $done = $code{'system.disk.cmd.disk-done'}->('import-two');
like $done->{'data'}, qr|\Adone import-two mount=/fake|,
    'completed writer is acknowledged';
ok !exists $data{'system'}{'disk'}{'jobs'}{'import-two'},
    'completed writer leaves the registry';
$code{'system.disk.cmd.disk-done'}->('import-one');
$free = 900;

my $fake_mounts = $code{'system.disk.mounts'};
my $tmp         = tempdir( CLEANUP => 1 );
my $mounts_file = "$tmp/mounts";
my @pseudo      = qw|
    proc sysfs devpts devtmpfs tmpfs securityfs cgroup cgroup2 pstore debugfs
    tracefs configfs fusectl hugetlbfs mqueue binfmt_misc autofs overlay
    efivarfs bpf rootfs rpc_pipefs nfs nfs4 cifs smbfs ceph fuse.sshfs
    |;
open my $mounts_fh, '>', $mounts_file or die $OS_ERROR;
print {$mounts_fh} "fake /fake/$ARG $ARG rw 0 0\n" for @pseudo;
print {$mounts_fh} "efivarfs /sys/firmware/efi/efivars efivarfs rw 0 0\n";
print {$mounts_fh} "/dev/fake /data ext4 ro,nosuid 0 0\n";
print {$mounts_fh} "/dev/fake /space\\040dir xfs rw 0 0\n";
close $mounts_fh;
$code{'base.cfg_bool'} = sub { return FALSE };
load_src('system.disk.mounts');
my $local_mounts = $code{'system.disk.mounts'}->($mounts_file);
is_deeply [ map { $ARG->{'path'} } @{$local_mounts} ],
    [ '/data', '/space dir' ],
    'pseudo and network mounts are skipped by type';
is_deeply [ map { $ARG->{'read_only'} ? qw| ro | : qw| rw | }
        @{$local_mounts} ],
    [qw| ro rw |], 'read-only flag comes from mount options';
$code{'system.disk.mounts'} = $fake_mounts;

my $rhythm = $code{'base.interval.rhythm.disk'};
my @delays = map {
    $rhythm->(
        {   state     => { pressure => $ARG },
            cfg       => { start    => 377, cap => 13 },
            harmonize => sub { return shift },
        }
    )
} 0, 0.5, 1;
ok $delays[0] > $delays[1] && $delays[1] > $delays[2],
    'disk rhythm accelerates as free space falls';
is $delays[2], 13, 'critical pressure reaches configured floor';

## invented inode numbers [ drvfs \ 9p report windows made-up counts ] ##
foreach my $case (
    [ 'drvfs',       1000, 40,     'drvfs' ],
    [ '9p',          999,  999999, '9p, free above total' ],
    [ '9p',          1000, 40,     '9p' ],
    [ 'fuse',        1000, 40,     'fuse' ],
    [ 'fuse.rclone', 1000, 40,     'fuse.<name>' ],
    [ 'fuseblk',     1000, 40,     'fuseblk' ],
    [ 'ext4',        999,  999999, 'any type with free above total' ],
    [ 'ext4',        0,    0,      'total zero' ],
) {
    my ( $type, $total, $left, $label ) = @{$case};
    @events = ();
    delete $data{'system'}{'disk'}{'mounts'};
    ( $fs_type, $files, $files_free ) = ( $type, $total, $left );
    $free      = 900;
    $read_only = FALSE;
    $code{'system.disk.poll'}->();
    my $m = $data{'system'}{'disk'}{'mounts'}{'/fake'};
    ok !$m->{'inodes_counted'} && !@events && !$m->{'level'},
        "$label : inodes not checked, no warning";
    @events = ();
    $free   = 40;
    $code{'system.disk.poll'}->();
    like $events[0]{'call_args'}{'args'} // '',
        qr|critical \[ 4\.0 % bytes, inodes n\\a \]|,
        "$label : the byte check stays, says inodes n\\a";
    like $code{'system.disk.cmd.disk-status'}->()->{'data'},
        qr|n\\a\s+n\\a|, "$label : disk-status shows n\\a";
}
( $fs_type, $files, $files_free, $free ) = ( 'ext4', 1000, 40, 900 );
@events = ();
delete $data{'system'}{'disk'}{'mounts'};
$code{'system.disk.poll'}->();
like $events[0]{'call_args'}{'args'}, qr|4\.0 % inodes free|,
    'a real inode count is still reported';

done_testing();

#,,..,..,,,.,,,,,,..,,,..,,,.,.,,,...,.,.,.,,,..,,...,...,..,,,.,,...,,,,,,.,,
#WL7DPKI3D3FI7QMBKJHQ67O3P2F35LJTEEPPMFCR4ONKMNYGRNPUV5ZEDV46XZHUFUSUBKL74PETM
#\\\|RQUSEIHUUDEYSKPR47BRMCAN55BVOUWSGLPD5P4WYHJW6P3SL65 \ / AMOS7 \ YOURUM ::
#\[7]I4KY2OJAGBFDZP4MJZIOR5V5VE7JQG7LFOLXNOYUI3GBMQCKIQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
