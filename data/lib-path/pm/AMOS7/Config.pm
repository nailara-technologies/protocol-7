package AMOS7::Config;
our $VERSION = qw| AMOS7::Config-VERSION.H6AMSWY |;

use v5.32;
use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| normalize_lines |;

##[ zenka config : line rules ]###############################################
#
# the raw-line rules of the protocol-7 config grammar, shared by the zenka
# parser [ src/base.parser.config, compiles lines to perl ] and the
# standalone readers, so the two never drift. plain perl : no zenka globals,
# no logging, nothing exported by default
#
# what is here  : description capture, comment stripping, whitespace \ cr \
#                 tab trimming, skipping of ':'-prefixed inline code lines,
#                 backslash continuation joining, `key = value` space
#                 normalisation
# what is not   : everything that turns a line into perl code [ `$` escaping,
#                 <<net>> rewriting, [call:..] handling, key \ value code
#                 generation ] stays in the zenka parser

##[ normalize_lines ]#########################################################
#
# normalize_lines( \@raw_lines [, \%opts ] ) -> arrayref of records
#
# raw lines may carry their line ending or not. one record per raw line that
# yields something, in input order :
#
#   line  => number of the raw line the record ends on [ 1 based ]
#   first => number of the raw line a joined [ continued ] line starts on
#   text  => the normalised line [ only when the line yields text ]
#   descr => text of a `.:[ .. ]:.` description found on that raw line
#            [ only when present ; scanned on EVERY raw line, also on
#            comment lines and skipped lines -- the zenka parser decides
#            whether to accept it, its rules depend on parser state ]
#
# a record with `descr` but no `text` is a raw line that only carried the
# description [ or whose text was dropped ] -- records stay in input order,
# so a consumer applies `descr` first, then handles `text`
#
# a continuation still open after the last raw line is dropped, as the zenka
# parser always did
#
# opts :  descr => 0   skip the description scan
#
# the rules, in this order, per raw line :
#
#  1. description : `.:[ word .. ]:.` -> descr
#  2. comments : a line with `key =` in front keeps `.:` [ may be a literal
#     value ] and loses only a trailing `#..` comment ; any other line also
#     loses a `.:..` tail. leading spaces, \r \n \t are removed in both
#  3. an empty line is skipped
#  4. a line starting with ':' is inline code [ skipped ] unless a
#     continuation is open
#  5. a trailing backslash opens or continues a continuation : the line is
#     appended to the open one [ nothing is emitted yet ]
#  6. the line closing a continuation is joined to it, its leading blanks
#     dropped
#  7. `key =   value` -> `key =value` [ blanks right after the first `=` ]

sub normalize_lines {
    my $raw_aref = shift // [];
    my $opts     = shift // {};

    my $want_descr = $opts->{'descr'} // 1;
    my @records    = ();

    my $last_line  = '';    ## open continuation text ##
    my $first_line = 0;     ## raw line number it started on ##
    my $line_nr    = 0;

    foreach my $raw_line ( $raw_aref->@* ) {
        $line_nr++;
        my $conf_line = $raw_line // '';    #  <-- leaving original intact.,
        my %record    = ( 'line' => $line_nr );

        $record{'descr'} = ${^CAPTURE}[0]
            if $want_descr and $conf_line =~ m|\.:\[ +([^:]+) +\]:\.|;

        ## for key=value lines, preserve .: patterns [ may be literal values ]
        if ( $conf_line =~ m|^[^=]+=| ) {
            $conf_line =~ s{^ +| *(#.*)$|[\r\n\t]+}{}g;
        } else {
            $conf_line =~ s{^ +| *(#.*|\.:.*)$|[\r\n\t]+}{}g;
        }

        if ( not length $conf_line ) {
            push @records, {%record} if exists $record{'descr'};
            next;
        }

        ##  skipping inline subroutine code  ##
        if ( not length($last_line) and index( $conf_line, ':', 0 ) == 0 ) {
            push @records, {%record} if exists $record{'descr'};
            next;
        }

        if ( $conf_line =~ s|\\ *$|| ) {
            $first_line = $line_nr if not length $last_line;
            $last_line .= $conf_line;
            push @records, {%record} if exists $record{'descr'};
            next;
        } elsif ( length($last_line) ) {
            $conf_line =~ s|^[ \t]+||;
            $conf_line       = "$last_line$conf_line";
            $last_line       = '';
            $record{'first'} = $first_line;
        }
        $conf_line =~ s|(^[^=]+=)[ \t]+|$1|;

        $record{'first'} //= $line_nr;
        $record{'text'} = $conf_line;
        push @records, {%record};
    }

    return \@records;
}

1;    ##  AMOS7::Config  ##

#,,,.,..,,..,,...,,,,,.,,,...,,,.,,,,,,.,,,.,,..,,...,.,,,...,,.,,,..,.,.,,..,
#P4CBEFI2KKYBG3L6ULBLVENY6DSBT7UQ2NT7E3RPNGGXYAE3UYMCX3EHVQIUXKTTFTZKGOC2R3AVC
#\\\|JMY72QGQDVZYMJKDQ5YLHL765XD4IULO2NQDJK25RJQOYWCICAO \ / AMOS7 \ YOURUM ::
#\[7]IJM5677BSP4G56EXCXRQMA2JXPNYOIGAMAXEAL3K53JLBRDTQYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
