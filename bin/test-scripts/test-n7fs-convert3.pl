#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS conversion 1 -> 2 -> 3 : content, source names and find rows survive;
## the first format-3 entry is a converted baseline. temp roots only.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS       qw| read_file plain_record_pack |;
use AMOS7::N7FS::Sum  qw| epoch_b32 epoch_int |;
use AMOS7::N7FS::Sign qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id disk_status
    state_read state_write witness_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes meta_entries
    reference_entries store_repair |;
use AMOS7::N7FS::Convert qw| upgrade confirm |;
use AMOS7::N7FS::Journal qw| journal_replay |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

use constant TRUE  => 5;
use constant FALSE => 0;

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = key_file_write("$hdir/host.key");
my $E    = epoch_int( clock_real() );
clock_epoch($E);

my %base = ( root => $root, host_dir => $hdir );
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'convert3-test',
    intent => 'n7fs chained conversion test [ test data ]'
);
my %run   = ( %base, disk => $disk, host => $host );
my $dpath = "$root/$disk";

sub cli_n7fs {
    my @args = @ARG;
    my $out  = "$box->{'base'}/cli.stdout";
    my $err  = "$box->{'base'}/cli.stderr";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

sub normalize_find {
    my $text = shift;
    $text =~ s|^V7[A-Z2-7]{5}/|EPOCH/|gm;
    $text =~ s|\s*\[ [^\n]* \]||gm;
    return $text;
}

## a deliberate format-1 origin, then the production chain ##
{
    my ($state_file) = glob "$dpath/.n7fs/state/*.state";
    my $p = state_read($dpath);
    delete $p->{'_name'};
    $p->{'store_format'} = 1;
    unlink $state_file or die "unlink state : $OS_ERROR";
    write_file( $state_file, plain_record_pack( 'state', $p ) );
}
disk_attach(%run);
my %body = (
    'one.txt'  => "test data : convert 3 one\n",
    'two.bin'  => "test data : convert 3 two\x00\xff\n" x 20,
    'copy.txt' => "test data : convert 3 one\n",
);
write_file( "$src/$ARG", $body{$ARG} ) for keys %body;
assimilate( %run, paths => [$src] );
clock_epoch( $E + 1 );
my $u2 = upgrade( %run, target => 2 );
ok( $u2->{'from'} == 1 && $u2->{'to'} == 2 && $u2->{'nodes'} == 2,
    'first step converts format 1 to 2' );
my $c2 = confirm(%run);
ok( $c2->{'format'} == 2 && $c2->{'nodes'} == 2,
    'format 2 is confirmed before the next step'
);
my @v2meta = meta_entries( %base, disk => $disk );
my ( $cli_rc, $find_v2, $cli_err ) = cli_n7fs( 'find', $disk );
ok( $cli_rc == 0 && $cli_err eq '', 'format 2 find output captured' );
my %v2content
    = map { ( $ARG->{'source'} => read_file("$ARG->{'node_path'}/content") ) }
    @v2meta;

clock_epoch( $E + 2 );
my $u3 = upgrade( %run, target => 3 );
ok( $u3->{'from'} == 2
        && $u3->{'to'} == 3
        && $u3->{'nodes'} == 2
        && $u3->{'journal_seq'} == 1,
    'second step converts format 2 to 3 and writes baseline sequence 1'
);
my $st = state_read($dpath);
ok( $st->{'store_format'} == 3
        && !$st->{'confirmed'}
        && $st->{'previous'}{'store_format'} == 2,
    'format 3 awaits confirmation with format 2 as previous'
);
my $replay = journal_replay( disk_read_id( %base, disk => $disk ) );
ok( $replay->{'baseline'} && $replay->{'seq'} == 1,
    'the first journal entry is marked baseline:true'
);
ok( 2 == keys $replay->{'nodes'}->%*
        && 3 == keys $replay->{'metas'}->%*
        && 3 == keys $replay->{'references'}->%*,
    'baseline lists every converted node, meta name and source reference'
);
ok( $replay->{'entries'}[0]{'payload'}{'add'}{'nodes'}->@* == 2
        && $replay->{'entries'}[0]{'payload'}{'add'}{'meta'}->@* == 3
        && $replay->{'entries'}[0]{'payload'}{'add'}{'references'}->@* == 3,
    'baseline payload contains the complete found set'
);

my @v3meta = meta_entries( %base, disk => $disk );
my %v2by
    = map { join( "\0", $ARG->{'source'}, $ARG->{'import_ntime'} ) => $ARG }
    @v2meta;
my $meta_ok = @v3meta == @v2meta;
foreach my $m (@v3meta) {
    my $old = $v2by{ join "\0", $m->{'source'}, $m->{'import_ntime'} };
    $meta_ok = 0 if not defined $old;
    next if not defined $old;
    foreach my $field ( keys %{$old} ) {
        next         if $field =~ m{\A(?:epoch|address|node_path)\z};
        $meta_ok = 0 if ( $old->{$field} // '' ) ne ( $m->{$field} // '' );
    }
}
ok( $meta_ok, 'all names, source fields and import history survive 2 -> 3' );
foreach my $m (@v3meta) {
    ok( $v2content{ $m->{'source'} } eq
            read_file("$m->{'node_path'}/content"),
        "content preserved : $m->{'source'}"
    );
}
my @refs = reference_entries( %base, disk => $disk );
ok( @refs == 3
        && 3 == grep( { $ARG->{'converted'} && !$ARG->{'dropped'} } @refs ),
    'every existing source has a live converted:true reference'
);
( $cli_rc, my $find_v3, $cli_err ) = cli_n7fs( 'find', $disk );
my $norm_v2 = normalize_find($find_v2);
my $norm_v3 = normalize_find($find_v3);
ok( $cli_rc == 0 && $norm_v3 eq $norm_v2,
    'default find preserves every row apart from the epoch directory' );
say "v2 :\n$norm_v2\nv3 :\n$norm_v3" if $norm_v2 ne $norm_v3;
( $cli_rc, my $all_v3, $cli_err ) = cli_n7fs( 'find', $disk, '-all' );
ok( $cli_rc == 0 && 3 == grep( {m|converted|} split m|\n|, $all_v3 ),
    'find -all exposes the converted reference provenance'
);

foreach my $name ( sort keys %body ) {
    ( $cli_rc, my $got, $cli_err ) = cli_n7fs( 'get', $disk, $name );
    ok( $cli_rc == 0 && $got eq $body{$name},
        "get by converted name preserves $name"
    );
}
ok( store_verify( %run, disk => $disk )->{'nodes'} == 2,
    'unconfirmed format 3 passes complete journal and disk verification' );
my $status = disk_status(%run);
ok( $status->{'journal_seq'} == 1 && $status->{'journal_baseline'},
    'status reports baseline presence and journal sequence'
);
ok( witness_read(%run)->{'journal_seq'} == 1
        && witness_read(%run)->{'store_format'} == 3,
    'the witness is raised only after state and baseline exist'
);

my $c3 = confirm(%run);
ok( $c3->{'format'} == 3 && $c3->{'nodes'} == 2,
    'confirm re-verifies the complete format 3 store'
);
ok( state_read($dpath)->{'confirmed'}, 'format 3 state is confirmed' );
my $later = write_file( "$src/later.txt", "test data : after format 3\n" );
my $ar    = assimilate( %run, paths => [$later] );
ok( $ar->{'journal_seq'} == 2,
    'new import after conversion appends sequence 2' );
my ($new_ref)
    = grep { $ARG->{'holder'} eq $later }
    reference_entries( %base, disk => $disk );
ok( $new_ref && !$new_ref->{'converted'},
    'new references are not marked as converted'
);
ok( store_verify( %run, disk => $disk )->{'nodes'} == 3,
    'converted and new data verify together'
);

say ':: crash after the state switch but before the baseline';
my $crash_disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'convert3-crash-test',
    intent => 'n7fs conversion crash test [ test data ]'
);
my %crash_run = ( %base, disk => $crash_disk, host => $host );
{
    my $p = state_read("$root/$crash_disk");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$crash_disk", $p,
        key_file_signer("$hdir/stores/$crash_disk.store.key") );
}
disk_attach(%crash_run);
assimilate( %crash_run, paths => ["$src/one.txt"] );
{
    local $AMOS7::N7FS::FAULT
        = sub { die "baseline crash\n" if $ARG[0] eq 'journal:before-write' };
    refused(
        sub { upgrade( %crash_run, target => 3 ) },
        qr|baseline crash|,
        'the conversion crash is injected after publish and state switch'
    );
}
refused(
    sub { store_verify( %base, disk => $crash_disk ) },
    qr|unlisted node|,
    'the converted node is unjournaled until explicit repair'
);
my $crash_repair = store_repair(%crash_run);
ok( 3 == $crash_repair->{'adopted'}->@*,
    'conversion repair reports the node, meta and converted reference' );
my $crash_replay
    = journal_replay( disk_read_id( %base, disk => $crash_disk ) );
ok( $crash_replay->{'baseline'}
        && $crash_replay->{'entries'}[0]{'payload'}{'repaired'},
    'conversion repair preserves baseline:true and adds repaired:true'
);
ok( store_verify( %crash_run, disk => $crash_disk )->{'nodes'} == 1
        && disk_status(%crash_run)->{'journal_baseline'},
    'the repaired conversion verifies and status reports its baseline'
);

done();

#,,,,,,.,,,..,,.,,...,.,.,,.,,,.,,.,,,.,,,...,.,.,...,...,..,,,.,,,..,,,,,,,,,
#DEMW4ZZ7KE6FKK4KXDVYEWJV765QSCPYRNGOP43GNOC55WSSELEBGNDOQF3XXEJOQ55XAA7MLLZTA
#\\\|3B775MFVZAMIJOTER7I5IQB4NXQQUOCP2PGW6E5X5R7UFIM3JJR \ / AMOS7 \ YOURUM ::
#\[7]URKI5ISC6K34J7KETDCO7ECEJXYVYU7FXURSY6BBF7HELIYIAIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
