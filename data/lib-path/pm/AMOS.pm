
package AMOS;  ###############################################################

## use AMOS::Version;    ## use to calculate new version ##

our $VERSION = qw| AMOS-MODULE-0.0.95 |;

use v5.24;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw| $VERSION TERM_SIZE error_exit %C |;

##[ COLORS ]##################################################################

our %C = (
    qw|  T  | => "\e[38;2;6;71;195m",
    qw|  b  | => "\e[48;2;9;5;42m",
    qw|  0  | => "\e[38;2;68;39;172m",
    qw|  g  | => "\e[38;2;71;195;6m",
    qw|  o  | => "\e[38;2;197;141;7m",
    qw|  B  | => "\e[1m",
    qw|  R  | => "\e[0m",
);

##[ ERROR HANDLER ]###########################################################

sub error_exit {
    chomp( my $emsg = shift );

    $emsg =~ s|^[A-Z](*nla:[A-Z])|\l$MATCH|;
    $emsg =~ s|(*plb:\w): (\S+)|$C{B} : $C{o}$LAST_PAREN_MATCH|;

    say "$C{R}$C{g}:$C{R}\n$C{g}: $C{o}$emsg$C{R}\n$C{g}:$C{R}";

    exit(113);
}

##[ TERMINALS ]###############################################################

sub TERM_SIZE {

    my $handle = shift // *STDIN;    ## use *STDOUT for pipe detection ##

    return undef if not -t $handle;
    state $size       = "\0" x 8;
    state $TIOCGWINSZ = 21523;

    ioctl( $handle, $TIOCGWINSZ, $size ) or return undef;
    my $size_aref = [ unpack qw| S!S!S!S! |, $size ];

    return ( $size_aref->[1], $size_aref->[0] );
}

return 1;  ###################################################################

#.............................................................................
#ZCHPLEG4ZB67EAL6OIRTQPXHDLRUVW2W3KGX6AECSARJX23BSYUKEITO4XD25MLM4NXG6U3KQSRBC
#::: NRGC7VOVIOKIP64ET7VWVOBDEP7GOMWXC3Q3WGAORAGHCEC57R6 :::: NAILARA AMOS :::
# :: 3X7WWGMQTPOUZWUXBZWCD5OQDZX2AVYHCJ4G2TU4VHIY75ETYIDI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
