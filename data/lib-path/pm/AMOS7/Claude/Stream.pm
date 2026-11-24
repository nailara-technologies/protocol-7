## [:< ##

## readable event lines from claude code stream-json events ##
##
## one implementation for bin/mcp-server-p7 [ the one-shot claude runs ] and
## the claude zenka [ src/claude.stream.describe ]. the events are decoded by
## the caller -- stream-json is an external wire format, decoded at the edge
## only -- this module only formats the decoded hash :
##
##   AMOS7::Claude::Stream::describe( $event, %opt )  ->  list of lines
##
## input     => sub { $input_hash }  how a tool call's input is shown
## [ default : key=value pairs, sorted ]  user_text => 1  keep the text blocks
## of a user event [ default : off ]

package AMOS7::Claude::Stream; ###############################################
our $VERSION = qw| AMOS7::Claude::Stream-VERSION.7DD3U7I |;

BEGIN {
    use strict;
    use English;
    use warnings;
}

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

@EXPORT_OK = qw| describe short |;

## one line, cut at a length ##
sub short {
    my ( $text, $max ) = @ARG;
    $text //= '';
    $text =~ s|\s*\n\s*| / |g;
    return length $text > $max ? substr( $text, 0, $max ) . ' ..' : $text;
}

## a tool input as key=value pairs ##
sub flat {
    my $v = shift;
    return $v if not ref $v;
    return join ' ', map { "$ARG=" . ( $v->{$ARG} // '' ) } sort keys %{$v}
        if ref $v eq qw| HASH |;
    return join ' ', map { ref $ARG ? '..' : $ARG } @{$v}
        if ref $v eq qw| ARRAY |;
    return '..';
}

sub describe {
    my ( $d, %opt ) = @ARG;
    $d //= {};
    my $input = $opt{'input'} // \&flat;

    my $type = $d->{'type'} // '';
    if ( $type eq qw| system | ) {
        return sprintf 'init : session %s model %s',
            $d->{'session_id'} // '-', $d->{'model'} // '-'
            if ( $d->{'subtype'} // '' ) eq qw| init |;
        return 'system : ' . ( $d->{'subtype'} // '' );
    }
    if ( $type eq qw| result | ) {
        return sprintf 'final : %s%s : %s', $d->{'subtype'} // '',
            defined $d->{'total_cost_usd'}
            ? sprintf( ' [ %.2f usd ]', $d->{'total_cost_usd'} )
            : '',
            short( $d->{'result'}, 400 );
    }
    return 'control : ' . ( $d->{'response'}{'subtype'} // '' )
        if $type eq qw| control_response |;

    my @out;
    my $content = $d->{'message'}{'content'};
    $content = [ { 'type' => qw| text |, 'text' => $content } ]
        if defined $content and not ref $content;
    foreach my $block ( ref $content eq qw| ARRAY | ? @{$content} : () ) {
        next if ref $block ne qw| HASH |;
        my $bt = $block->{'type'} // '';
        if ( $bt eq qw| text | ) {
            push @out, 'text : ' . short( $block->{'text'}, 400 )
                if $type ne qw| user | or $opt{'user_text'};
        } elsif ( $bt eq qw| tool_use | ) {
            push @out, sprintf 'tool : %s %s', $block->{'name'} // '',
                short( $input->( $block->{'input'} // {} ), 200 );
        } elsif ( $bt eq qw| tool_result | ) {
            my $c = $block->{'content'};
            $c = join ' ',
                map { ref $ARG ? $ARG->{'text'} // '' : $ARG } @{$c}
                if ref $c eq qw| ARRAY |;
            push @out, sprintf 'result%s : %s',
                $block->{'is_error'} ? ' [ error ]' : '',
                short( $c, 200 );
        }
    }
    return @out;
}

1;

#,,..,,,.,..,,.,.,,..,.,.,.,.,,.,,,,.,.,,,,..,..,,...,..,,,.,,.,.,..,,,,,,...,
#HY5SGJ4DIZAVHBUUX4M37XRYEZETLHFTY454HAZFHMLLQLQ3YYW2NITBSIP5KVB5S3R6ZXLJX6P5M
#\\\|TQAJJ6F6GVWOSOCIPM2MHASDKLUZQOIYSX37BY26QTNZWXRPLDK \ / AMOS7 \ YOURUM ::
#\[7]D5EPOPR4FO2IRMWCMUMCA5L4ROMYVMONCC2C7H4ATUBRUGAMA6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
