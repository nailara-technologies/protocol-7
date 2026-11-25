## [:< ##

## timed on \ off switches : the one helper of the chat relay switch and   ##
## notify do-not-disturb -- span parsing, the p7 config state file and the ##
## until check. what an ended time switches to is the caller's             ##

package AMOS7::Switch; #######################################################
our $VERSION = qw| AMOS7::Switch-VERSION.ROQYC6Y |;

use v5.32;
use strict;
use English;
use warnings;

my %span_unit
    = ( 's' => 1, 'm' => 60, 'h' => 3600, 'd' => 86400, 'w' => 604800 );

## a span like 90s 13m 1h30m 2d [ a bare number : seconds ] ; undef when it ##
## is not a span or under one second                                        ##
sub parse_span {
    my $span    = shift // '';
    my $seconds = 0;
    my $pos     = 0;
    while ( $span =~ m{\G(\d+)([smhdw])?}gc ) {
        $seconds += $1 * $span_unit{ $2 // 's' };
        $pos = pos $span;
    }
    return undef if $pos != length $span or $seconds < 1;
    return $seconds;
}

## a timed switch is over : until 0 \ undef means no time limit ##
sub expired {
    my ( $until, $now ) = @ARG;
    return ( $until and $until <= ( $now // time ) ) ? 1 : 0;
}

## values stay on one line ##
sub escape_value {
    my $value = shift // '';
    $value =~ s{\\}{\\\\}g;
    $value =~ s{\n}{\\n}g;
    $value =~ s{\r}{\\r}g;
    $value =~ s{\t}{\\t}g;
    return $value;
}

sub unescape_value {
    my $value = shift // '';
    $value =~ s{\\(.)}{
        $1 eq 'n' ? "\n" : $1 eq 'r' ? "\r" : $1 eq 't' ? "\t" : $1
    }ge;
    return $value;
}

## `key = value` \ `key : value` lines, `#` comments, no continuation ##
## [ an escaped value may end in a backslash ]. return : list of      ##
## [ key, value ] in file order, both trimmed, values still escaped   ##
sub parse_state {
    my $text = shift // '';
    my @pairs;
    foreach my $line ( split m{\n}, $text ) {
        next if $line =~ m{^\s*(?:#|$)} or $line !~ m{[=:]};
        my ( $key, $value ) = split m{[=:]}, $line, 2;
        s{^\s+|\s+$}{}g for $key, $value //= '';
        push @pairs, [ $key, $value ];
    }
    return @pairs;
}

## header line [ without `# ` ] and [ key, value ] pairs as written ##
sub format_state {
    my ( $header, @pairs ) = @ARG;
    return join '', "# $header\n", map {"$ARG->[0] = $ARG->[1]\n"} @pairs;
}

## plain files [ scripts ; a zenka goes through its own zenka dir ] no file ##
## : an empty list                                                          ##
sub read_file {
    my $path = shift;
    return () if not -f $path;
    open my $fh, '<:encoding(UTF-8)', $path or return ();
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    close $fh;
    return parse_state($text);
}

## FALSE with $OS_ERROR set when it cannot be written ##
sub write_file {
    my ( $path, $header, @pairs ) = @ARG;
    open my $fh, '>:encoding(UTF-8)', $path or return 0;
    print {$fh} format_state( $header, @pairs ) or return 0;
    return close($fh) ? 1 : 0;
}

1;

#,,,,,,.,,,..,,,,,,..,...,.,.,,..,...,,..,,..,..,,...,...,.,.,,,.,.,,,.,,,,,.,
#LJMMA3WZYZVW4OOWEBW4YA3KHHOSCRXIQ6ZCY37DDHBNBOZSU5JJAJHPVYOXT5YONNXAZLJBPG2T6
#\\\|5H3R6G3S3AFDLLUFRHJJ7PJXEBJA46GL765BFOQMP4GFSWAYWEG \ / AMOS7 \ YOURUM ::
#\[7]KWOJIR6CHS5XUHA635PJAM6E5H7VQO274TCFLUYYRHMROP5JQQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
