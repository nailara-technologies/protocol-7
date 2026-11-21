#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use Time::HiRes ();
use AMOS7::N7FS
    qw| read_file make_dirs ntime_now ntime14 signed_record_pack |;
use AMOS7::N7FS::Sign qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id disk_lock
    disk_require_attached state_read store_key_signer witness_note_format |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes meta_entries |;
use AMOS7::N7FS::Reference qw| reference_scan |;
use AMOS7::N7FS::Journal   qw| journal_replay journal_write |;
use AMOS7::N7FS::Category  qw| category_set category_definitions
    category_assignments category_set_reference |;
use AMOS7::N7FS::Sum qw| epoch_b32 |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";
use constant TRUE => 5;

my $count = $ENV{'N7FS_TREE_CATEGORY_SCALE'} // 96;
die "N7FS_TREE_CATEGORY_SCALE must be a positive integer\n"
    if $count !~ m|\A[1-9]\d*\z|;

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'category-performance',
    intent => 'selector equivalence and batch timing'
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);
my $id    = disk_read_id( %base, disk => $disk );
my $store = key_file_signer("$hdir/stores/$disk.store.key");
category_set( %run, name => 'work' );

my $tree_src = "$src/tree";
make_dirs($tree_src);
write_file( "$tree_src/$_", "content $_\n" ) for qw| a b c |;
my $outside = write_file( "$src/outside", "outside content\n" );
assimilate( %run, paths => [$tree_src], tree => 'scale' );
assimilate( %run, paths => [$outside] );

my $replay = journal_replay($id);
my $tree   = $replay->{'trees'}{'scale'};
require AMOS7::N7FS::Seal;
my @tree_nodes = sort { $a cmp $b }
    AMOS7::N7FS::Seal::_manifest_files( $id, $tree->{'manifest'} );
my ($outside_ref)
    = grep { $ARG->{'holder'} eq $outside }
    values $replay->{'references'}->%*;
my $outside_node   = $outside_ref->{'node'};
my @node_addresses = ( @tree_nodes, $outside_node );
my %base_meta;

for my $meta ( meta_entries(%run) ) {
    $base_meta{ $meta->{'address'} } //= $meta;
}

sub empty_set {
    return {
        nodes       => [],
        meta        => [],
        references  => [],
        releases    => [],
        trees       => [],
        categories  => [],
        assignments => [],
        batches     => [],
    };
}

my @prefix = map {"$src/group-$_"} qw| a b other |;
my $add    = empty_set();
for my $n ( 0 .. $count - 1 ) {
    my $group   = $n % 4;
    my $address = $group < 3 ? $tree_nodes[$group] : $outside_node;
    my ( $epoch_name, $amos, $bmw ) = split m|/|, $address;
    my $ntime  = ntime14( ntime_now() );
    my $holder = sprintf '%s/file-%05d', $prefix[ $group < 3 ? $group : 2 ],
        $n;
    my $name      = "file-$n";
    my $node_path = "$root/$disk/$address";
    my $meta_name = "$ntime."
        . AMOS7::N7FS::b32( AMOS7::N7FS::random_bytes(5) ) . '.meta';
    my $meta = {
        %{ $base_meta{$address} },
        name         => $name,
        source       => $holder,
        import_ntime => $ntime,
        epoch        => $epoch_name,
    };
    make_dirs("$node_path/meta");
    write_file( "$node_path/meta/$meta_name",
        signed_record_pack( 'meta', $meta, $store, 3 ) );
    push $add->{'meta'}->@*, { node => $address, name => $meta_name };

    my $ref_path = "$ntime/$amos/$bmw/addr";
    my $ref_dir  = "$node_path/references/$ntime/$amos/$bmw";
    make_dirs($ref_dir);
    write_file(
        "$ref_dir/addr",
        signed_record_pack(
            'reference',
            {   disk   => $disk,
                addr   => $address,
                holder => $holder,
                name   => $name,
                ntime  => $ntime,
            },
            $store, 3
        )
    );
    push $add->{'references'}->@*,
        {
        node   => $address,
        path   => $ref_path,
        holder => $holder,
        name   => $name
        };
}
journal_write( $id, $store, $add, empty_set(), {} );

$replay = journal_replay($id);
my $old_entry   = $replay->{'entries'}[-1];
my $old_payload = {
    %{ $old_entry->{'payload'} },
    add => { %{ $old_entry->{'payload'}{'add'} } },
};
delete $old_payload->{'add'}{'batches'};
write_file(
    "$root/$disk/.n7fs/journal/$old_entry->{'name'}",
    signed_record_pack( 'journal', $old_payload, $store, 3 )
);
$replay = journal_replay($id);
ok( !exists $old_payload->{'add'}{'batches'}
        && keys( $replay->{'references'}->%* ) == $count + 4,
    'a journal without the batch list still replays every reference'
);

my $old_root = "$box->{'base'}/old-root";
my $old_hdir = "$box->{'base'}/old-host";
copy_tree( $root, $old_root );
copy_tree( $hdir, $old_hdir );
my %old_run = ( %run, root => $old_root, host_dir => $old_hdir );
my $old_id  = disk_read_id( %old_run, disk => $disk );

sub legacy_category_set_reference {
    my %opt      = @ARG;
    my $category = $opt{'category'};
    my $target   = $opt{'target'} // '';
    my $lock     = disk_lock( disk_read_id(%opt) );
    my $id       = disk_require_attached(%opt);
    my $store    = store_key_signer( %opt, id => $id );
    my $state    = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $replay   = journal_replay($id);
    die "unknown category\n"
        if not exists category_definitions( $id, $replay )->{$category};
    my @refs;
    my %tree_files;

    if ( $target =~ m|\Atree-name:(.*)\z|s ) {
        my $tree_name = $1;
        my $tree      = $replay->{'trees'}{$tree_name};
        die "unknown tree\n" if not defined $tree;
        $tree_files{$ARG} = TRUE
            for AMOS7::N7FS::Seal::_manifest_files( $id,
            $tree->{'manifest'} );
    }

    foreach my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
    {
        foreach my $ref ( grep { not $ARG->{'dropped'} }
            reference_scan( $node, $id ) ) {
            my $match
                = $target =~ m|\Atree-name:| ? $tree_files{ $ref->{'node'} }
                : $target =~ m|\A(?:tree\|path):(.*)\z|s
                ? index( $ref->{'holder'}, $1 ) == 0
                : $ref->{'node'} eq $target;
            push @refs, $ref if $match;
        }
    }
    die "no live reference matches\n" if not @refs;
    my $assignments = category_assignments( $id, $store, \@refs,
        sub { return $category } );
    my $add = empty_set();
    $add->{'assignments'} = $assignments;
    my $journal = journal_write( $id, $store, $add, empty_set(), {} );
    witness_note_format(
        %opt,
        id          => $id,
        state       => $state,
        journal_seq => $journal->{'seq'}
    );
    return { assignments => $assignments, seq => $journal->{'seq'} };
}

sub assignment_categories {
    my $replay = shift;
    return join "\n",
        map { $_ . "\t" . $replay->{'assignments'}{$_}{'category'} }
        sort keys $replay->{'assignments'}->%*;
}

my @cases = (
    { target => 'tree-name:scale', expected => \@tree_nodes },
    { target => "tree:$prefix[0]", expected => [ $tree_nodes[0] ] },
    { target => "path:$prefix[1]", expected => [ $tree_nodes[1] ] },
);
my ( $before, $after ) = ( 0, 0 );
my $new_assignment_history
    = keys journal_replay($id)->{'assignment_history'}->%*;

for my $case (@cases) {
    my $target = $case->{'target'};
    my $start  = Time::HiRes::time();
    my $old    = legacy_category_set_reference(
        %old_run,
        target   => $target,
        category => 'work'
    );
    my $old_time = Time::HiRes::time() - $start;
    $before += $old_time;

    my $reader = \&AMOS7::N7FS::Category::reference_each;
    my %scanned;
    my $new;
    $start = Time::HiRes::time();
    {
        no warnings qw| redefine |;
        local *AMOS7::N7FS::Category::reference_each = sub {
            my $node    = shift;
            my $address = join '/', epoch_b32( $node->{'epoch'} ),
                $node->{'amos'}, $node->{'bmw'};
            $scanned{$address} = TRUE;
            return $reader->( $node, @ARG );
        };
        $new = category_set_reference(
            %run,
            target   => $target,
            category => 'work'
        );
    }
    my $new_time = Time::HiRes::time() - $start;
    $after += $new_time;

    my $old_replay = journal_replay($old_id);
    my $new_replay = journal_replay($id);
    ok( $old->{'assignments'}->@* == $new->{'assignments'}->@*
            && $new->{'assignments'}->@* > 0
            && assignment_categories($old_replay) eq
            assignment_categories($new_replay),
        "$target returns the old assignments "
            . "and replays to the same categories"
    );
    ok( join( "\n", sort keys %scanned ) eq
            join( "\n", sort { $a cmp $b } $case->{'expected'}->@* ),
        "$target authenticates only the selected nodes"
    );
    ok( $new_replay->{'seq'} == $old_replay->{'seq'},
        "$target writes one journal entry in both implementations" );
    say sprintf 'CATEGORY %-24s before %.3f s, after %.3f s',
        $target, $old_time, $new_time;
}

my $old_replay = journal_replay($old_id);
my $new_replay = journal_replay($id);
ok( keys( $old_replay->{'assignment_history'}->%* ) > 0
        && keys( $old_replay->{'batch_history'}->%* ) == 0
        && assignment_categories($old_replay) eq
        assignment_categories($new_replay),
    'the old per-reference journal and new batch journal replay identically'
);
ok( keys( $new_replay->{'batch_history'}->%* ) == scalar @cases
        && keys( $new_replay->{'assignment_history'}->%* )
        == $new_assignment_history,
    'each new call adds one batch and no per-reference assignment records'
);
ok( store_verify( %old_run, disk => $disk )
        && store_verify( %run, disk => $disk ),
    'both legacy and batch stores pass full verification'
);
say sprintf 'CATEGORY SCALE %d references : before %.3f s, after %.3f s',
    $count, $before, $after;

done();

#,,.,,,.,,..,,,,,,,..,,,.,,,.,..,,.,,,.,,,...,..,,...,...,,,,,,.,,..,,...,,,,,
#AINOUKE5GNIQP74VRLCOR6CR55XQP3G7LFFOABJBP4LPYVDY5RHIASTJ5WHJ7K3SEVVVXRIA4WAHK
#\\\|BSQHM64BL3HSHEWSL6WBPLWUS4AF2MDOXYUV2TCCQ3TRJEHRSVB \ / AMOS7 \ YOURUM ::
#\[7]QMF7IC677CCDDPP3LQ5IBPUXYWILFAGDRKVMAQ2HLU7RKQOOD4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
