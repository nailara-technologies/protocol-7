#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## a place run limited to some categories and some holders :  -only-category
## <a,b> and -only-holder <a,b> on place and placement

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

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
        exec( $EXECUTABLE_NAME, "$FindBin::RealBin/../n7fs", '-root', $root,
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

my %h = map { $ARG => "$base/$ARG" } qw| ha hb hc |;
make_dirs($ARG) for values %h;
foreach my $n (qw| a b c |) {
    ( $rc, $out )
        = cli( ['vp'], 'holder', 'add', $n, $h{"h$n"}, '-domain', "d$n" );
    ok( $rc == 0, "holder $n added" ) or say $out;
}

sub tree_list {
    my $dir = shift;
    my @out;
    my @todo = ($dir);
    while ( my $d = shift @todo ) {
        opendir( my $dh, $d ) or next;
        foreach my $e ( sort grep { !m|\A\.\.?\z| } readdir $dh ) {
            push @out,  "$d/$e";
            push @todo, "$d/$e" if -d "$d/$e";
        }
    }
    return join "\n", map { $ARG . ' ' . ( -s $ARG // 0 ) } sort @out;
}

my @key = ( '-root-key', 'vault:main' );

## unknown names refuse the run, listing the known ones
( $rc, $out ) = cli( ['vp'], 'place', $disk, @key, '-only-category', 'nope' );
ok( $rc != 0 && $out =~ m|unknown category nope ; known : .*bulk.*vital|,
    'an unknown category is refused with the known ones' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'place', $disk, @key, '-only-holder', 'a,zz' );
ok( $rc != 0 && $out =~ m|unknown holder zz ; known : a, b, c|,
    'an unknown holder is refused with the known ones'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'placement', $disk, @key, '-only-category', 'nope' );
ok( $rc != 0 && $out =~ m|unknown category nope|,
    'placement refuses an unknown category too'
) or say $out;
ok( tree_list( $h{'ha'} ) eq '' && tree_list( $h{'hc'} ) eq '',
    'a refused run writes nothing' )
    or say tree_list( $h{'ha'} );

## dry run : the filter and what each holder would get
( $rc, $out ) = cli(
    ['vp'],     'place',          $disk,   @key,
    '-dry-run', '-only-category', 'vital', '-only-holder',
    'a,b'
);
ok( $rc == 0 && $out =~ m|filter : only category vital ; only holder a,b|,
    'dry run shows the filter' )
    or say $out;
ok( $out        =~ m|would place 5 nodes on a|
        && $out =~ m|would place 5 nodes on b|
        && $out !~ m|nodes on c|,
    'dry run : the vital tree on a and b, nothing on c'
) or say $out;

## placement reports only what the run would cover
( $rc, $out )
    = cli( ['vp'], 'placement', $disk, @key,
    '-only-category', 'vital', '-only-holder', 'a,b' );
ok( $rc == 0 && $out =~ m|^: filter : only category vital ; only holder a,b|m,
    'placement shows the filter'
) or say $out;
ok( $out =~ m|^: category vital target 3 : 5 nodes at 0|m
        && $out !~ m|^: category bulk|m,
    'placement : only the vital category'
) or say $out;
ok( $out        =~ m|^: holder a |m
        && $out =~ m|^: holder b |m
        && $out !~ m|^: holder c |m,
    'placement : only the holders of the run'
) or say $out;

## the real run : the category filter and the holder filter together
my $c_before = tree_list( $h{'hc'} );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, @key,
    '-only-category', 'vital', '-only-holder', 'a,b' );
ok( $rc == 0, 'a filtered place runs' ) or say $out;
ok( $out =~ m|placed 5 nodes on a| && $out =~ m|placed 5 nodes on b|,
    'the vital tree lands on a and b' )
    or say $out;
ok( $out =~ m|checked a : | && $out =~ m|checked b : | && $out !~ m| on c|,
    'the ending holder-check covers the holders written' )
    or say $out;
ok( $out =~ m|still under-replicated : 5 nodes|,
    'vital stays one copy short : c is left out, nothing goes elsewhere' )
    or say $out;
ok( tree_list( $h{'hc'} ) eq $c_before,
    'a filtered-out holder is never written'
) or say tree_list( $h{'hc'} );

## copies count on every holder : a report limited to c still sees a and b
( $rc, $out ) = cli( ['vp'], 'placement', $disk, @key, '-only-holder', 'c' );
ok( $out =~ m|^: category vital target 3 : 5 nodes at 2|m
        && $out =~ m|^: category bulk target 2 : 5 nodes at 0|m,
    'a holder limit still counts copies on the other holders'
) or say $out;

## holder filter alone : a holds vital already, so only bulk goes there ; c
## gets vital [ its third copy ] and bulk
( $rc, $out )
    = cli( ['vp'], 'place', $disk, @key, '-dry-run', '-only-holder', 'a,c' );
ok( $out        =~ m|would place 5 nodes on a|
        && $out =~ m|would place 10 nodes on c|
        && $out !~ m|nodes on b|,
    'holder filter : copies on b count, a gets only what it lacks'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],     'place',          $disk,   @key,
    '-dry-run', '-only-category', 'vital', '-only-holder',
    'a,b'
);
ok( $out =~ m|would place 0 nodes on a\n|
        && $out =~ m|would place 0 nodes on b\n|,
    'dry run : a named holder with nothing to take still shows'
) or say $out;

## category filter alone : bulk to two holders of any domain
( $rc, $out ) = cli( ['vp'], 'place', $disk, @key, '-only-category', 'bulk' );
ok( $rc == 0 && $out =~ m|filter : only category bulk \[|,
    'category filter runs' )
    or say $out;
my $n = 0;
$n += $ARG for $out =~ m|placed (\d+) nodes on|g;
ok( $n == 10 && $out !~ m|under-replicated|,
    'category filter : bulk reaches two copies, vital untouched' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, @key );
ok( $out        =~ m|^: category vital target 3 : 5 nodes at 2|m
        && $out =~ m|^: category bulk target 2 : 5 nodes at 2|m
        && $out !~ m|^: filter|m,
    'an unfiltered report : vital still at 2, bulk at 2, no filter line'
) or say $out;

done();

#,,,.,..,,...,,,.,,.,,..,,..,,,,.,,,,,,.,,..,,..,,...,...,..,,...,,,.,,.,,,.,,
#VW24DO25INDJMW6N5TQRNJUNKZWHMLFNJJV4MSXXYD7INJ2TOQVCSXIFXDTSHUTGU6TYS72GF5A3E
#\\\|L7F2ZVNFZYYTAO5ZVVH2PCQS7YT35FEMVAZHWGABWSK3RV7LMCM \ / AMOS7 \ YOURUM ::
#\[7]MZ2SEMPH7DQJWSODRIEJWMSCOLTSXW2AAJK2FZK6X5XJNYS2IECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
