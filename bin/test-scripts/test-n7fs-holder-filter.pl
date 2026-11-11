#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## placement filters on a holder : -categories <list> and -min-priority <n>

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );

sub cli {
    my ( $lines, @args ) = @ARG;
    my $pf = "$base/pass";
    write_file( $pf, join '', map {"$ARG\n"} @{$lines} );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args, '-pass-fd', 0, '-vault-dir', $vdir )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
( $rc, $out )
    = cli( [], 'category', $disk, 'set', 'vital', '-copies', 3,
    '-priority', 90 );
( $rc, $out )
    = cli( [], 'category', $disk, 'set', 'bulk', '-copies', 2,
    '-priority', 10 );

foreach my $c (qw| vital bulk |) {
    make_dirs("$src/$c");
    write_file( "$src/$c/f$ARG", "$c $ARG\n" ) for 1 .. 5;
    ( $rc, $out ) = cli(
        [], 'assimilate', '-disk', $disk, '-keep', '-tree',
        $c, '-category',  $c,      "$src/$c"
    );
    ok( $rc == 0, "fixture $c imported" ) or say $out;
}
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my %h = map { $ARG => "$base/$ARG" } qw| big list prio |;
make_dirs($ARG) for values %h;
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'big', $h{'big'}, '-domain',
    'a', '-owned' );
( $rc, $out ) = cli(
    ['vp'],     'holder',  'add', 'list',
    $h{'list'}, '-domain', 'b',   '-categories',
    'vital'
);
ok( $rc == 0, 'a holder with a category list' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],     'holder',  'add', 'prio',
    $h{'prio'}, '-domain', 'c',   '-min-priority',
    50
);
ok( $rc == 0, 'a holder with a lowest priority' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],    'holder',  'add', 'bad',
    $h{'big'}, '-domain', 'd',   '-min-priority',
    'high'
);
ok( $rc != 0, 'a priority that is not a number is refused' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder', 'list' );
ok( $out =~ m|^list .*categories=vital|m
        && $out =~ m|^prio .*min-priority=50|m,
    'the list shows the filters'
) or say $out;

( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0, 'place runs' ) or say $out;
my ($on_big)  = $out =~ m|placed (\d+) nodes on big|;
my ($on_list) = $out =~ m|placed (\d+) nodes on list|;
my ($on_prio) = $out =~ m|placed (\d+) nodes on prio|;
ok( ( $on_big // 0 ) > ( $on_list // 0 ) && ( $on_list // 0 ) > 0,
    'the unfiltered holder takes everything, the filtered ones less'
) or say $out;
ok( ( $on_list // 0 ) == ( $on_prio // 0 ),
    'both filters take only the vital tree'
) or say $out;
$ARG
    and ( $rc, $out )
    = cli( ['vp'], 'holder-check', $ARG, '-root-key', 'vault:main' )
    for values %h;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|category vital target 3 : \d+ nodes at 3|
        && $out =~ m|category bulk target 2 : \d+ nodes at 1|,
    'vital reaches three copies, bulk stays where the filters allow'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $h{'list'},     '-tree',     'vital',
    "$base/rec"
);
ok( $rc == 0 && -f "$base/rec/f3", 'a filtered holder recovers its tree' )
    or say $out;

done();

#,,,.,,,,,..,,...,,,,,,,.,,..,.,.,,,.,,,.,,..,..,,...,...,.,,,,..,.,,,.,.,,,,,
#6FOXYXVMUXGYMW6LYJK7BOSSWUZR3MTCXXXKK2Z2VQN532HWFACBIBIVBMC7BTTQLRORWWA7ZHHKC
#\\\|5I5LUMM26AK3AICAISZEQ24VS3LCMXWDDOKCMGRXH7JRPKZLP73 \ / AMOS7 \ YOURUM ::
#\[7]R33QEFWEDVBHFP55RWRAFMQKSKJ5WDJHG6MSGN74EY5YOHIHX4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
