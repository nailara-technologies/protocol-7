## [:< ##

package AMOS7::N7FS::Console;    ############################################

## terminal colour and animated progress for the standalone n7fs command.

use v5.32.0;
use utf8;
use strict;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Console-VERSION.76O5X6I |;

@EXPORT_OK = qw| console_configure console_say console_error console_progress
    console_close_progress console_is_tty |;

use AMOS7                    qw| %C |;
use AMOS7::Console::Progress qw| console_progress_bar |;
use Time::HiRes              ();

my ( $COLOR, $OUT_TTY, $ERR_TTY, $PROGRESS_OPEN ) = ( 0, 0, 0, 0 );

sub console_configure {
    my %opt = @_;
    $COLOR   = $opt{'color'}   ? 1 : 0;
    $OUT_TTY = $opt{'out_tty'} ? 1 : 0;
    $ERR_TTY = $opt{'err_tty'} ? 1 : 0;
    return;
}

sub console_is_tty { return $ERR_TTY }

sub console_close_progress {
    return if not $PROGRESS_OPEN;
    ## the bar line ends in \r : step past it and leave a frame line, so a
    ## shell prompt cannot overwrite the last state
    print STDERR "\n:\n";
    $PROGRESS_OPEN = 0;
    return;
}

## a run that ends without a final update still closes its bar
END { console_close_progress() }

sub _paint {
    my ( $text, $token, $enabled ) = @_;
    return $text if not $enabled;
    return $C{$token} . $text . $C{'R'};
}

sub console_say {
    console_close_progress();
    my $line = join '', @_;
    if ( $COLOR and $OUT_TTY ) {
        $line
            =~ s{\A(\s*)(restored|assigned|placed|checked|verified|created|attached|sealed|recovered|confirmed|tagged)\b}{$1 . _paint( $2, 'g', 1 )}e;
        $line
            =~ s{\b(warning|refused|failed|FAILED|unreachable|under-replicated)\b}{_paint( $1, 'o', 1 )}eg;
        $line
            =~ s{\b(tree|disk|holder)(\s+)([^\s\[\]:]+)}{$1 . $2 . _paint( $3, 'T', 1 )}eg;
    }
    print STDOUT ': ', $line, "\n";
    return;
}

sub console_error {
    my $text = join '', @_;
    console_close_progress();
    $text = _paint( $text, 'o', $COLOR && $ERR_TTY );
    print STDERR $text;
    return;
}

sub console_progress {
    my ( $label, $unit ) = @_;
    return undef if not $ERR_TTY;
    my $started = Time::HiRes::time();
    my $last    = 0;
    return sub {
        my ( $current, $total, $final ) = @_;
        my $now = Time::HiRes::time();
        return if not $final and $now - $last < 0.2;
        $last = $now;
        print STDERR ":\n" if not $PROGRESS_OPEN;
        print STDERR console_progress_bar(
            label   => $label,
            current => $current,
            total   => $total,
            started => $started,
            unit    => $unit,
            color   => $COLOR,
        );
        $PROGRESS_OPEN = 1;
        console_close_progress() if $final;
        return;
    };
}

1;

#,,,,,,.,,,.,,,..,,,.,,,,.,,,,..,,,..,,.,,,,..,,.,,,,,,..,,..,,,.,,,.,,

#,,..,.,,,,,.,,..,.,,,.,.,,.,,.,.,.,,,,.,,,.,,..,,...,..,,.,.,,.,,,.,,,..,,..,
#GHXHPYY4QE6BOY5VPQ3Y3GKSDPUUVXX7STSEKKS6LUZ5LAX4ISC72FJLBW5UQ2QKGND37PRL2QARW
#\\\|2URX4X55EWZ2MWZH74VV7XR2CR3QUECBYQUOW6S665BM3I57XGK \ / AMOS7 \ YOURUM ::
#\[7]LJH7QB3TVSOP2WSSYZJIAGX6DDKGCDFE4Z2JDKKUXFXRZJIF2UCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
