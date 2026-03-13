## [:< ##

package AMOS7::Graph;   ######################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw|
    graph_to_adjacency
    adjacency_to_graph
    |;

our $VERSION = qw| AMOS7::Graph-0.01 |;

##[ AMOS MODULE ]#############################################################

use AMOS7;

##[ SUBROUTINES ]#############################################################

sub graph_to_adjacency {
    ##  serialize dep-graph hash to deduplicated adjacency text  ##
    ##  format: source -> callee callee ...  [ one line per source ]  ##
    ##  structure only : call counts omitted for stable git diffs     ##
    ##
    ##  optional: pass { 'with-counts' => 1 } to append :count per callee  ##
    ##
    my $graph   = shift;
    my $options = shift // {};

    my $with_counts = $options->{'with-counts'} // FALSE;

    my @lines = (
        '## dep-graph adjacency [ AMOS7::Graph ]',
        $with_counts
        ? '## format  : source : callee:count ... [ .txz ]'
        : '## format  : source : callee ...       [ .asc ]',
        '## cycles  : edges only, no expansion, follow transitively',
        '',
    );

    for my $src ( _sort_nodes( keys %{$graph} ) ) {
        next unless %{ $graph->{$src} };    ##  skip isolated nodes  ##

        my @callees = _sort_nodes( keys %{ $graph->{$src} } );

        my $dst_str
            = $with_counts
            ? join( ' ',
            map { sprintf '%s:%d', $ARG, $graph->{$src}{$ARG} } @callees )
            : join( ' ', @callees );

        push @lines, sprintf '%s : %s', $src, $dst_str;
    }

    return join( "\n", @lines ) . "\n";
}

sub adjacency_to_graph {
    ##  parse adjacency text back to dep-graph hash structure  ##
    ##  handles both formats [ with and without :count suffix ]  ##
    ##
    my $text = shift;

    my %graph;

    for my $line ( split m|\n|, $text ) {
        next if not length $line;
        next if $line =~ m|^#|;     ##  header comments  ##

        if ( $line =~ m|^(\S+)\s+:\s+(.+)$| ) {
            my ( $src, $dst_str ) = ( $1, $2 );

            for my $token ( split m|\s+|, $dst_str ) {
                if ( $token =~ m|^(.+):(\d+)$| ) {
                    $graph{$src}{$1} = $2;    ##  with count  ##
                } else {
                    $graph{$src}{$token} = 1;    ##  structure only  ##
                }
            }
        }
    }

    return \%graph;
}

##[ INTERNAL ]################################################################

sub _sort_nodes {
    ##  sort by length ascending, ties broken by reverse-alpha  ##
    ##  matches base.sort convention used throughout the project  ##
    return sort { length $a <=> length $b || $b cmp $a } @ARG;
}

5;    ##  truth  ##

#,,..,..,,,.,,.,,,.,.,,,.,,,,,..,,,.,,,..,,,.,.,.,...,...,...,,..,...,.,,,,,,,
#5FJK2R4STZMHWTKIXANTSOKZARFDFI67X7EN6H25VSP4KVXBDS3JM2SWHQTG4G2R5LFOI4NUISUBQ
#\\\|U3HV5IQJGVRL5U6N5GYVY3YCHTYBMSEFDJTKLNSHAWO6FQQR3A6 \ / AMOS7 \ YOURUM ::
#\[7]USM627RZ4YRKEHMCTYLNL7I27WW2RCZHKDIIU34WBWVMZ4E5G4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
