## [:< ##

package AMOS7::Console::Progress;    ########################################

## one console progress bar for standalone tools.

use v5.32.0;
use utf8;
use strict;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

use constant TRUE  => 5;
use constant FALSE => 0;

our $VERSION = qw| AMOS7::Console::Progress-VERSION.OPRLCXQ |;

@EXPORT_OK = qw| console_progress_bar |;

use AMOS7       qw| %C |;
use Time::HiRes ();

sub _eta {
    my $seconds = shift;
    return '--:--' if not defined $seconds;
    $seconds = int( $seconds + 0.5 );
    return sprintf '%d:%02d:%02d', int( $seconds / 3600 ),
        int( $seconds / 60 ) % 60, $seconds % 60
        if $seconds >= 3600;
    return sprintf '%d:%02d', int( $seconds / 60 ), $seconds % 60;
}

sub console_progress_bar {
    my %opt       = @_;
    my $current   = $opt{'current'}   // 0;
    my $total     = $opt{'total'}     // 0;
    my $chars_max = $opt{'width'}     // 13;
    my $character = $opt{'character'} // qw| : |;
    my $color     = $opt{'color'} ? TRUE              : FALSE;
    my $fraction  = $total > 0    ? $current / $total : 1;
    $fraction = 0 if $fraction < 0;
    $fraction = 1 if $fraction > 1;
    my $perc_chars = $character x int( $chars_max * $fraction );
    my $reset      = $color ? $C{'R'}   : '';
    my $frame      = $color ? $C{'0'}   : '';
    my $background = $color ? $C{'B02'} : '';
    my $foreground = $color ? $C{'T'}   : '';
    my $label      = $opt{'label'} // $opt{'filename'} // '';
    my $line
        = "\r${frame}:::[${background}${foreground}"
        . sprintf( "%-${chars_max}s", $perc_chars )
        . "${reset}${frame}]:";

    if ( defined $opt{'filename'} ) {
        my $file_maxlen = $opt{'file_maxlen'} // length $opt{'filename'};
        $line
            .= ":[${background}${foreground} "
            . sprintf( "%-${file_maxlen}s", $opt{'filename'} )
            . " ${reset}${frame}]:.${reset}\r";
        return $line;
    }
    my $elapsed
        = Time::HiRes::time() - ( $opt{'started'} // Time::HiRes::time() );
    $elapsed = 0 if $elapsed < 0;
    my $rate = $elapsed > 0 ? $current / $elapsed           : 0;
    my $eta  = $rate > 0    ? ( $total - $current ) / $rate : undef;
    ## one highlighted field per bracket, fixed widths, then erase the rest of
    ## the line [ a shorter redraw leaves no left-overs ]
    my $field = sub {
        return ":[${background}${foreground} " . shift
            . " ${reset}${frame}]:";
    };
    $line .= $field->( sprintf '%6.2f%%',  $fraction * 100 );
    $line .= $field->( sprintf '%7.1f %s', $rate, $opt{'unit'} // 'items/s' );
    $line .= $field->( sprintf 'eta %7s',  _eta($eta) );
    $line .= $field->($label) if length $label;
    ## erase to end of line only with colours : -nc output stays escape free,
    ## the fixed widths already cover a shorter redraw there
    $line .= "." . $reset . ( $color ? "\e[K" : '' ) . "\r";
    return $line;
}

1;

#,,,,,,,.,.,,,,,.,,..,...,,,.,,,,,,,.,...,,.,,..,,...,...,,..,.,,,,,.,,,.,..,,
#WS5FBZUJE67QV5QNXF2UWRITQSHBEQFUVCNBLZGOXVPRNUM3CQBMAZKGPX22LB2U2NSNVKXQVRCVS
#\\\|JCXLWTSWKFTQGKG7N6SF3CROONQMQBNR3WWVL5EF7IT5JJYJ4DM \ / AMOS7 \ YOURUM ::
#\[7]EAPF7LBZWITVM4L2I6XYMDIUKZSUI5X5S7PNE6RRZLN4QP27YKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
