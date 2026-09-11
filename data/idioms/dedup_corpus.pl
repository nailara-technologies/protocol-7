#!/usr/bin/env perl
## dedup_corpus.pl -- curate a mined corpus (data/idioms/mine_git_history.pl's
## output): collapse whitespace-normalized duplicate (before,after) pairs,
## then cap each category so one bulk mechanical commit (e.g. a repo-wide
## `return 0/1` -> `return FALSE/TRUE` sweep) can't dominate training -- see
## data/tasks/coding-git-history-idiom-mining.md's rating/dedup hazard.
##
## dedup key = category + whitespace-collapsed before/after -- a same-shape
## substitution at a different indent level is the same training signal, not a
## distinct example. within a category over the cap, prefer commit-diversity
## first (one example per distinct commit before taking a second from any
## commit) so the cap doesn't just keep the single largest bulk-sweep commit's
## own variations.
##
## usage: dedup_corpus.pl --in data/idioms/corpus/mined.jsonl
## --out data/idioms/corpus/mined.curated.jsonl
## --cap 80

use strict;
use warnings;
use Getopt::Long;
use JSON::PP qw| decode_json encode_json |;

my $in_path  = 'data/idioms/corpus/mined.jsonl';
my $out_path = 'data/idioms/corpus/mined.curated.jsonl';
my $cap      = 80;

GetOptions(
    'in=s'  => \$in_path,
    'out=s' => \$out_path,
    'cap=i' => \$cap,
) or die "usage error\n";

sub normalize_ws {
    my ($text) = @_;
    $text =~ s|^\s+||gm;
    $text =~ s|\s+$||gm;
    $text =~ s|\s+| |g;
    return $text;
}

open my $ifh, '<', $in_path or die "cannot read $in_path: $!\n";
my @rows;
while ( my $line = <$ifh> ) {
    chomp $line;
    next unless length $line;
    push @rows, decode_json($line);
}
close $ifh;

printf STDERR "loaded %d rows\n", scalar @rows;

## pass 1: whitespace-normalized exact-dup collapse, per category ##
my %seen;
my @deduped;
for my $r (@rows) {
    my $key = join( "\x00",
        $r->{'category'},
        normalize_ws( $r->{'before'} ),
        normalize_ws( $r->{'after'} ) );
    next if $seen{$key}++;
    push @deduped, $r;
}
printf STDERR "after whitespace-normalized dedup: %d rows (was %d)\n",
    scalar @deduped, scalar @rows;

## pass 2: per-category cap, commit-diversity-first selection ##
my %by_category;
push @{ $by_category{ $_->{'category'} } }, $_ for @deduped;

my @final;
for my $cat ( sort keys %by_category ) {
    my @cat_rows = @{ $by_category{$cat} };
    if ( @cat_rows <= $cap ) {
        push @final, @cat_rows;
        next;
    }

    ## group by commit within this category, then round-robin across   ##
    ## commits so the cap can't be filled entirely from one bulk sweep ##
    my %by_commit;
    push @{ $by_commit{ $_->{'commit'} } }, $_ for @cat_rows;
    my @commit_queues = values %by_commit;

    my @picked;
    while ( @picked < $cap and grep {@$_} @commit_queues ) {
        for my $q (@commit_queues) {
            next unless @$q;
            push @picked, shift @$q;
            last if @picked >= $cap;
        }
    }
    printf STDERR
        "  %-12s %4d -> %4d (capped, %d distinct commits contributing)\n",
        $cat, scalar @cat_rows, scalar @picked, scalar @commit_queues;
    push @final, @picked;
}

open my $ofh, '>', $out_path or die "cannot write $out_path: $!\n";
print $ofh encode_json($_) . "\n" for @final;
close $ofh;

printf STDERR "wrote %d curated rows to %s\n", scalar @final, $out_path;

my %final_counts;
$final_counts{ $_->{'category'} }++ for @final;
printf STDERR "final category counts: %s\n",
    join( ', ', map {"$_=$final_counts{$_}"} sort keys %final_counts );

#,,,,,.,.,,.,,.,.,..,,,,.,...,,..,,,.,.,,,..,,..,,...,..,,..,,,,.,..,,.,.,.,,,
#65R6HGIZBWGQBTK3ELNGD3HF6HEEVKTYDII24ZELXMERX3DMR67TQE4KQ2QWKRSVJIQJM7MU55WEO
#\\\|ZGEUKGH4SWVTIWX5IYIJTQ674QHCR2JMVPUUWIUVJ43UDA3ITG4 \ / AMOS7 \ YOURUM ::
#\[7]ZKG2ZVNREWJLH2EEM6LGW576J34GRWD6VMI2OLWAQ56WQIFHMOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
