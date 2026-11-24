#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

##          the walk of usage.token-leak-check, run as a                    ##
##          stream_child of the usage zenka. secrets arrive on              ##
##          stdin only [ never argv or environment ] and no line            ##
##          written here carries one : no file content is printed,          ##
##          and paths are redacted                                          ##
##                                                                          ##
##          stdin  : 'secret <kind-hex> <value-hex>', 'root                 ##
##          <path-hex>', 'own <path-hex>' [ credential file ],              ##
##          'prune <path-hex>', 'end' stdout : tab separated :              ##
##          'hit <path> <kind> <count> ..', 'unreadable <path>'             ##
##          [ the first few ], 'done <unreadable> <s>'                      ##

use Cwd         qw| abs_path |;
use Fcntl       qw| O_RDONLY O_NONBLOCK O_NOFOLLOW |;
use Time::HiRes ();

my $chunk_size = ( $ARGV[0] // '' ) =~ m|\A([1-9]\d*)\z| ? $1 : 1 << 20;
my $show_max   = 5;

my ( @secrets, @roots, @own, @prune, $complete );
while ( my $line = <STDIN> ) {
    chomp $line;
    my ( $key, @hex ) = split m| |, $line;
    $key //= '';
    my @val = map { pack 'H*', $ARG } @hex;
    if    ( $key eq 'secret' and @val == 2 ) { push @secrets, [@val] }
    elsif ( $key eq 'root' and @val == 1 )   { push @roots,   $val[0] }
    elsif ( $key eq 'own' and @val == 1 )    { push @own,     $val[0] }
    elsif ( $key eq 'prune' and @val == 1 )  { push @prune,   $val[0] }
    elsif ( $key eq 'end' )                  { $complete = 1; last }
}
die "incomplete request\n" if not $complete or not @secrets;

$OUTPUT_AUTOFLUSH = 1;
my $started = Time::HiRes::time();

my $keep = 0;    ## carried between chunks : longest secret - 1 ##
foreach my $s (@secrets) {
    $keep = length( $s->[1] ) - 1 if length( $s->[1] ) > $keep + 1;
}

sub safe_path {
    my $path = shift;
    foreach my $s ( sort { length $b->[1] <=> length $a->[1] } @secrets ) {
        my $at;
        substr( $path, $at, length $s->[1], '[redacted]' )
            while ( $at = index $path, $s->[1] ) >= 0;
    }
    $path =~ s{([\x00-\x1f\x7f])}{sprintf '\\x%02x', ord $1}ge;
    return $path;
}

my $unreadable = 0;

sub unreadable {
    my $path = shift;
    return if $OS_ERROR{'ENOENT'};    ## gone since it was listed ##
    say join "\t", 'unreadable', safe_path($path)
        if ++$unreadable <= $show_max;
    return;
}

## seen by device + inode : overlapping roots and hard links count once ##
my %seen;
foreach my $path (@own) {
    my @st = stat $path;
    $seen{"$st[0]:$st[1]"} = 1 if @st;
}
my ( %pruned, @pruned_real );
foreach my $path (@prune) {
    my @st = stat $path;
    next if not @st;
    $pruned{"$st[0]:$st[1]"} = 1;
    push @pruned_real, abs_path($path) // ();
}

sub scan_file {
    my ( $path, $size ) = @ARG;
    sysopen( my $fh, $path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW )
        or return unreadable($path);
    return close $fh if not -f $fh;
    my ( %count, $failed );
    my $tail  = '';
    my $limit = $size + ( 64 << 20 );    ## a file that keeps growing ##
    my $total = 0;
    while ( $total <= $limit ) {
        my $got = sysread( $fh, my $chunk, $chunk_size );
        if ( not defined $got ) { unreadable($path); $failed = 1; last }
        last if not $got;
        $total += $got;
        my $old    = length $tail;
        my $buffer = $tail . $chunk;
        foreach my $s (@secrets) {
            my $len = length $s->[1];
            ## only matches reaching into the new bytes : the others were ##
            ## counted with the chunk before                              ##
            my $from = $old - $len + 1;
            $from = 0 if $from < 0;
            while ( ( my $at = index $buffer, $s->[1], $from ) >= 0 ) {
                $count{ $s->[0] }++;
                $from = $at + $len;
            }
        }
        $tail
            = length $buffer > $keep
            ? substr( $buffer, length($buffer) - $keep )
            : $buffer;
    }
    close $fh;
    say join "\t", 'hit', safe_path($path),
        map { ( $ARG, $count{$ARG} ) } sort keys %count
        if %count;
    return;
}

ROOT: foreach my $root (@roots) {
    my $real = abs_path($root);
    if ( not defined $real or not -e $real ) {
        unreadable($root) if not $OS_ERROR{'ENOENT'};
        next;
    }
    foreach my $out (@pruned_real) {
        next ROOT if index( "$real/", "$out/" ) == 0;
    }
    my @stack = ($real);
    while (@stack) {
        my $path = pop @stack;
        my @st   = lstat $path;
        if ( not @st ) { unreadable($path); next }
        next if -l _;    ## symlinks are not followed ##
        my $id = "$st[0]:$st[1]";
        if ( -d _ ) {
            next if $pruned{$id} or $seen{$id}++;
            my $dh;
            if ( not opendir $dh, $path ) { unreadable($path); next }
            ( my $base = $path ) =~ s{/\z}{};
            push @stack, map {"$base/$ARG"}
                reverse sort grep { $ARG ne '.' and $ARG ne '..' }
                readdir $dh;
            closedir $dh;
        } elsif ( -f _ ) {    ## no sockets, pipes or devices ##
            next if $seen{$id}++;
            scan_file( $path, $st[7] );
        }
    }
}

printf "done\t%d\t%.1f\n", $unreadable, Time::HiRes::time() - $started;

#,,.,,...,...,.,,,.,.,,,,,,,,,.,,,,,.,,..,,..,.,.,...,...,,,.,,,,,,.,,.,.,,,.,
#SYDBAG3NJVDPX36BLBBKSLAN4G2FOWBMPYUJG2JE2VC3KYTQS3PDW3ZG3I434T66ACAPPEUATOGQC
#\\\|OIOC6PJ5O3V65LHGOJXFQLDA7L5RWB4YCHJYZK365KJIRD3J6L6 \ / AMOS7 \ YOURUM ::
#\[7]TBGBXMLJOPAGWNZYFTNSRW64OFRPHPT5K45TURQC6VL5HDKU36BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
