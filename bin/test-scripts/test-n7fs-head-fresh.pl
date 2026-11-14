#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
$^F = 100;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use IPC::Open3         qw| open3 |;
use Symbol             qw| gensym |;
use AMOS7::N7FS        qw| read_file write_new_file |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Placement qw| receipt_digest |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
my $box  = sandbox();
my $base = $box->{'base'};
my $pass = "$base/pass";
write_new_file( $pass, "pw\npw\n" );
open( my $pass_in, '<:raw', $pass ) or die $OS_ERROR;
root_init(
    qw| path |    => "$base/root.key",
    qw| pass_fd | => fileno($pass_in),
    qw| m |       => 1024,
    qw| t |       => 1,
    qw| p |       => 1,
);
close $pass_in;

sub open_root {
    my $path = shift;
    open( my $fh, '<:raw', $pass ) or die $OS_ERROR;
    return root_open( qw| path | => $path, qw| pass_fd | => fileno($fh) );
}

my $now = 1_000_000;
local $AMOS7::N7FS::CLOCK = sub { return $now };
my $root   = open_root("$base/root.key");
my $signer = test_signer();
my $disk   = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'head-fresh',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
my @paths = map {"$box->{'src'}/node-$ARG"} 0 .. 1;
write_new_file( $paths[$ARG], "node $ARG\n" ) for 0 .. $#paths;
my $import = assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $signer,
    qw| paths |          => \@paths,
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
my @addresses = map { $ARG->{'addr'} } $import->{'entries'}->@*;
my $holder_a  = "$base/holder-a";
my $holder_b  = "$base/holder-b";

sub seal_to {
    my ( $open, $holder, @nodes ) = @_;
    return AMOS7::N7FS::Seal::seal_nodes(
        qw| root |      => $open,
        qw| holder |    => $holder,
        qw| disk |      => $disk,
        qw| disk_root | => $box->{'root'},
        qw| host_dir |  => $box->{'host'},
        qw| addresses | => \@nodes,
        qw| trees |     => [],
    );
}

sub current_head {
    my ( $open, $holder ) = @_;
    my $sub = holder_sub($holder) // die 'missing per-root holder';
    return ( AMOS7::N7FS::Seal::_head_open( $open, $sub, 1 ), $sub );
}

seal_to( $root, $holder_a, $addresses[0] );
my ( $head_a1, $sub_a ) = current_head( $root, $holder_a );
my $old_head = read_file( "$sub_a/" . AMOS7::N7FS::Seal::_head_name($root) );
seal_to( $root, $holder_b, $addresses[0] );
seal_to( $root, $holder_a, $addresses[1] );
AMOS7::N7FS::Seal::head_refresh( $root, $holder_b );
my ( $head_b, $sub_b ) = current_head( $root, $holder_b );
my ( $head_a, undef ) = current_head( $root, $holder_a );
my $current_a = read_file( "$sub_a/" . AMOS7::N7FS::Seal::_head_name($root) );
ok( $head_b->{'peers'}{ $head_a->{'holder'} }{'v'} == $head_a->{'version'}
        and $head_b->{'peers'}{ $head_a->{'holder'} }{'t'}
        == $head_a->{'time'},
    'a signed head records every other holder version and time'
);
ok( !exists $head_b->{'peers'}{ $head_b->{'holder'} },
    'the peers vector excludes its own holder'
);

my $checked_a = AMOS7::N7FS::Seal::holder_check(
    qw| root |     => $root,
    qw| holder |   => $holder_a,
    qw| coverage | => qw| full |,
);
AMOS7::N7FS::Placement::receipt_write(
    qw| host_dir |          => $box->{'host'},
    qw| root |              => $root,
    qw| spec |              => $holder_a,
    qw| version |           => $checked_a->{'version'},
    qw| nodes |             => $checked_a->{'nodes'},
    qw| samples |           => $checked_a->{'samples'},
    qw| coverage |          => $checked_a->{'coverage'},
    qw| covered |           => $checked_a->{'covered'},
    qw| covered_nodes |     => $checked_a->{'covered_nodes'},
    qw| covered_addresses | => $checked_a->{'covered_list'},
);
AMOS7::N7FS::Seal::head_refresh( $root, $holder_b );
( $head_b, $sub_b ) = current_head( $root, $holder_b );
my $summary = $head_b->{'peers'}{ $head_a->{'holder'} }{'r'};
ok( ref $summary eq 'HASH'
        and $summary->{'v'} == $checked_a->{'version'}
        and $summary->{'t'} > 0
        and $summary->{'c'} eq 'full'
        and $summary->{'n'} == $checked_a->{'covered_nodes'},
    'a signed head carries the other holder receipt summary'
);

my $survey = AMOS7::N7FS::Seal::head_survey( $root,
    { qw| a | => $holder_a, qw| b | => $holder_b } );
ok( !$survey->{'a'}{'stale'} && !$survey->{'b'}{'stale'},
    'current heads survive a survey' );
write_file( "$sub_a/" . AMOS7::N7FS::Seal::_head_name($root), $old_head );
copy_tree( "$base/root.key.state", "$base/state-save" );

my $clean = "$base/clean.key";
write_file( $clean, read_file("$base/root.key") );
chmod 0600, $clean;
my $clean_root   = open_root($clean);
my $clean_survey = AMOS7::N7FS::Seal::head_survey( $clean_root,
    { qw| a | => $holder_a, qw| b | => $holder_b } );
ok( $clean_survey->{'a'}{'stale'}
        and $clean_survey->{'a'}{'floor'} == $head_a->{'version'}
        and $clean_survey->{'a'}{'witness'} eq 'b',
    'another holder proves an older valid head stale without home state'
);
my $clean_recovery = AMOS7::N7FS::Seal::seal_recover(
    qw| root |   => $clean_root,
    qw| holder | => $holder_b,
    qw| target | => "$base/clean-recovery",
);
ok( $clean_recovery->{'receipts'}->@* == 1
        and $clean_recovery->{'receipts'}[0]{'holder'} eq $head_a->{'holder'}
        and $clean_recovery->{'receipts'}[0]{'version'}
        == $checked_a->{'version'}
        and $clean_recovery->{'receipts'}[0]{'coverage'} eq 'full'
        and $clean_recovery->{'receipts'}[0]{'nodes'}
        == $checked_a->{'covered_nodes'},
    'clean recovery with root and one holder sees the other receipt summary'
);

my %registry = (
    qw| a | => {
        qw| spec |   => $holder_a,
        qw| domain | => 'a',
        qw| role |   => 'durable'
    },
    qw| b | => {
        qw| spec |   => $holder_b,
        qw| domain | => 'b',
        qw| role |   => 'durable'
    },
);
{
    local *AMOS7::N7FS::Placement::holders_load  = sub { return \%registry };
    local *AMOS7::N7FS::Placement::receipt_fresh = sub { return undef };
    refused(
        sub {
            AMOS7::N7FS::Placement::_copies(
                qw| root |     => $clean_root,
                qw| host_dir | => $box->{'host'},
                qw| host_pub | => $signer->public,
            );
        },
        qr|serves a rolled back head|,
        'placement refuses a holder proven stale by another holder'
    );
    my ( undef, undef, $status ) = AMOS7::N7FS::Placement::_copies(
        qw| root |        => $clean_root,
        qw| host_dir |    => $box->{'host'},
        qw| host_pub |    => $signer->public,
        qw| allow_stale | => 1,
    );
    ok( $status->{'a'}{'state'} eq 'rolled back',
        'placement -allow-stale warns and counts no copies from the old head'
    );
}

refused(
    sub {
        AMOS7::N7FS::Seal::seal_recover(
            qw| root |   => $clean_root,
            qw| holder | => $holder_a,
            qw| target | => "$base/refused",
            qw| peers |  => { qw| a | => $holder_a, qw| b | => $holder_b },
        );
    },
    qr|refusing a rolled back head|,
    'recovery refuses a holder proven stale by another holder'
);
my $allowed = AMOS7::N7FS::Seal::seal_recover(
    qw| root |        => $clean_root,
    qw| holder |      => $holder_a,
    qw| target |      => "$base/allowed",
    qw| allow_stale | => 1,
    qw| peers |       => { qw| a | => $holder_a, qw| b | => $holder_b },
);
ok( $allowed->{'version'} == $head_a1->{'version'} && -d "$base/allowed",
    '-allow-stale proceeds with the old valid head' );
refused(
    sub {
        AMOS7::N7FS::Seal::seal_recover(
            qw| root |        => $clean_root,
            qw| holder |      => $holder_a,
            qw| target |      => "$base/min-version",
            qw| allow_stale | => 1,
            qw| min_version | => $head_a1->{'version'} + 1,
        );
    },
    qr|below -min-version|,
    '-min-version refuses an older head'
);
my $single_warning = '';
{
    local $SIG{'__WARN__'} = sub { $single_warning .= join '', @ARG };
    AMOS7::N7FS::Seal::seal_recover(
        qw| root |        => $clean_root,
        qw| holder |      => $holder_a,
        qw| target |      => "$base/single",
        qw| allow_stale | => 1,
    );
}
ok( $single_warning =~ m|no second holder|,
    'a single holder proceeds and prints the freshness limit' );

write_file( "$base/refresh.key", read_file("$base/root.key") );
chmod 0600, "$base/refresh.key";
copy_tree( "$base/state-save", "$base/refresh.key.state" );
my $refresh_root = open_root("$base/refresh.key");
my ( undef, $before, $map_before, undef )
    = AMOS7::N7FS::Seal::_context( $refresh_root, $holder_b, 1 );
my $map_bytes = read_file("$sub_b/$before->{'map'}{'blob'}");
my $digest    = receipt_digest( $map_before, $before->{'version'} );
$now += 100;
my $refreshed = AMOS7::N7FS::Seal::head_refresh( $refresh_root, $holder_b );
my ( undef, $after, $map_after, undef )
    = AMOS7::N7FS::Seal::_context( $refresh_root, $holder_b, 1 );
ok( $after->{'version'} == $before->{'version'} + 1
        and $after->{'time'} > $before->{'time'}
        and $after->{'map'}{'blob'} eq $before->{'map'}{'blob'}
        and $after->{'journal'} eq $before->{'journal'}
        and read_file("$sub_b/$after->{'map'}{'blob'}") eq $map_bytes,
    'head-refresh changes time and version but neither map nor journal'
);
ok( receipt_digest( $map_after, $before->{'version'} ) eq $digest,
    'head-refresh leaves the covered receipt digest valid'
);

my $cli_root = "$base/refresh.key";

sub cli {
    my @args = @ARG;
    open( my $fh, '<:raw', $pass ) or die $OS_ERROR;
    my ( $in, $out, $err ) = ( undef, undef, gensym );
    my $pid = open3( $in, $out, $err, "$FindBin::Bin/../n7fs",
        '-pass-fd', fileno($fh), '-root-key', $cli_root, @args );
    close $in;
    my $stdout = do { local $INPUT_RECORD_SEPARATOR; <$out> }
        // '';
    my $stderr = do { local $INPUT_RECORD_SEPARATOR; <$err> }
        // '';
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, $stdout, $stderr );
}

write_file( "$sub_a/" . AMOS7::N7FS::Seal::_head_name($root), $current_a );
write_file( "$base/cli-clean.key", read_file("$base/root.key") );
chmod 0600, "$base/cli-clean.key";
$cli_root = "$base/cli-clean.key";
my ( $recover_rc, $recover_out, $recover_err )
    = cli( '-from', $holder_b, 'seal-recover', "$base/cli-peer-recovery" );
my $receipt_tag = substr( $head_a->{'holder'}, 0, 7 );
ok( $recover_rc == 0
        and $recover_out
        =~ m|receipt \Q$receipt_tag\E known from this head : v\Q$checked_a->{'version'}\E, .* full, covered \Q$checked_a->{'covered_nodes'}\E nodes|,
    'clean seal-recover prints peer receipt summaries after a home loss'
) or say "$recover_out$recover_err";
$cli_root = "$base/refresh.key";
my ( $rc, $out, $err ) = cli( 'heads', '-anchor', $holder_a, $holder_b );
ok( $rc == 0 and $out =~ m|holder .*: head v\d+, age .*floor v\d+, current|,
    'n7fs heads prints the holder table' )
    or say "$out$err";
my ($anchor) = grep {m|\A[A-Z2-7]{7} \d+ \d+\z|} split m|\n|, $out;
my ( $tag, $version, $ntime ) = split ' ', $anchor // '';
my @current = map { ( current_head( $refresh_root, $ARG ) )[0] } $holder_a,
    $holder_b;
my ($newest) = sort { $b->{'version'} <=> $a->{'version'} } @current;
ok( $tag eq substr( $root->{'root_id'}, 0, 7 )
        and $version == $newest->{'version'}
        and $ntime == $newest->{'time'},
    'the offline anchor line round trips root tag, version and ntime'
);

done();

#,,,.,,..,,.,,,.,,.,.,,..,,,,,...,.,,,.,,,,,,,..,,...,...,,,.,,,.,.,.,,,.,..,,
#MWHQ3QZM3O5GPPYX3IARV3B73E4SNO3HKLPHHWNARBESAIWNVZZRMTT5IQLLM66SX5MUE7E2UHKLA
#\\\|NAMSF43ZVEFGUSYU4JBRSXUOB3KKVSOYRTNQNZQJQF6W4L3HMNU \ / AMOS7 \ YOURUM ::
#\[7]4HXTZ3ZWOH3KSAPIUBEWUT4GMFI7IVD5F2BMDDT4FOJDJAXCPKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
