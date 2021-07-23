
package AMOS7; ###############################################################

## use AMOS7::Version;    ## use to calculate new version ##

our $VERSION = qw| AMOS-MODULE-0.1.16 |;

use v5.24;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

@EXPORT = qw[

    TERM_SIZE %C error_exit warn_err caller_str format_error

];

##  determine protocol-7 install path  ##
our $protocol_7_root = p7_root_dir();

@EXPORT_OK = qw| $VERSION $protocol_7_root |;

###[ USED TEXT COLORS ]#######################################################

our %C = (
    qw|  T  | => "\e[38;2;6;71;195m",
    qw| B00 | => "\e[48;2;0;0;17m",
    qw| B01 | => "\e[48;2;9;5;24m",
    qw| B02 | => "\e[48;2;9;5;42m",
    qw|  b  | => "\e[48;2;9;5;42m",      ## <-- redundant [replace]
    qw|  0  | => "\e[38;2;68;39;172m",
    qw|  g  | => "\e[38;2;71;195;6m",
    qw|  o  | => "\e[38;2;197;141;7m",
    qw|  B  | => "\e[1m",
    qw|  R  | => "\e[0m",
);

##[ TERMINAL [ TTY ] ]########################################################

sub TERM_SIZE {
    my $handle = shift // *STDIN;        ## use *STDOUT for pipe detection ##

    return undef if not -t $handle;
    state $size       = "\0" x 8;
    state $TIOCGWINSZ = 21523;

    ioctl( $handle, $TIOCGWINSZ, $size ) or return undef;
    my $size_aref = [ unpack qw| S!S!S!S! |, $size ];

    return ( $size_aref->[1], $size_aref->[0] );
}

##[ ERROR HANDLING ]##########################################################

sub error_exit {
    my $err_str = shift // '';

    if ( $err_str !~ m| <\{N?C\d*\}>$| ) {
        if ( not defined $main::PROTOCOL_SEVEN ) {
            $err_str .= ' <{NC}>';
        } else {
            $err_str .= ' <{C1}>';
        }
    }

    ## caller level [ + 1 ] ##
    $err_str =~ s|(*plb: <\{C)(\d+)(*pla:}>$)|1+$1|e;

    if (@ARG) {
        ## sprintf template ##
        use warnings qw| FATAL |;
        $err_str = eval { sprintf $err_str, @ARG };

        if ( index( lcfirst $EVAL_ERROR, 'argument in sprintf', 0 ) >= 0 ) {
            $err_str
                = index( lcfirst($EVAL_ERROR), qw| missing |, 0 ) == 0
                ? 'missing error_exit argument <{C2}>'
                : 'redundant error_exit argument <{C2}>';

        } elsif ( length $EVAL_ERROR ) {
            $err_str =~ s| at \S+. line \d+.+$| <{C1}>|;
        }
        $err_str //= 'error_exit sprintf error <{C1}>';
        chomp($err_str);
    }

    $err_str =~ s|^[A-Z](*nla:[A-Z])|\l$MATCH|;
    $err_str =~ s|(*plb:\w): (\S+)|$C{B} : $C{o}$LAST_PAREN_MATCH|;
    $err_str =~ s|%|%%|g;    ##  reversed again in warn_err  ##

    warn_err($err_str);

    exit(qw| 0110 |) if not defined $main::PROTOCOL_SEVEN;
    return undef;            ##  protocol-7 mode  ##
}

sub warn_err {
    my $err_str = shift // ':: warn :: undefined <{C1}>';
    my $c_lvl   = shift // 1;

    say STDERR ': warn_err : caller level as second argument expected'
        if defined $c_lvl and $c_lvl !~ m|^\-?\d+$|;

    ##  warn_err \ sprintf template processing  ##
    ##
    if ( @ARG or $err_str =~ m,(*nlb:%)%[sd\d\.], ) {

        use warnings qw| FATAL |;    ##  catching sprintf warnings  ##
        $err_str = eval { sprintf $err_str, @ARG };

        if ( index( lcfirst $EVAL_ERROR, 'argument in sprintf', 0 ) >= 0 ) {
            $err_str
                = index( lcfirst($EVAL_ERROR), qw| missing |, 0 ) == 0
                ? sprintf( 'missing warn_err argument <{C%d}>',   $c_lvl )
                : sprintf( 'redundant warn_err argument <{C%d}>', $c_lvl );

        } elsif ( length $EVAL_ERROR ) {
            $err_str =~ s| at \S+. line \d+.+$| <{C1}>|;
        }
        $err_str //= 'warn_err sprintf error <{C1}>';
        chomp($err_str);
    } else {
        $err_str =~ s|%%|%|g;
    }

    $c_lvl++ if scalar( [ caller(1) ]->[3] // '' ) eq qw| AMOS7::error_exit |;

    my $no_caller = 0;
    $c_lvl     = $LAST_PAREN_MATCH if $err_str =~ s| <\{C(\d+)\}>$||;
    $no_caller = 1                 if $err_str =~ s| <\{NC\}>$||;

    if ( defined $main::PROTOCOL_SEVEN ) {    ##  zenka  ##
        if ($no_caller) {
            warn sprintf '%s <{NC}>', $err_str;
        } else {
            warn sprintf '%s <{C%d}>', $err_str, $c_lvl;
        }
    } else {
        my $caller_str = $no_caller ? '' : caller_str($c_lvl);
        print STDERR
            sprintf( "$C{R}$C{g}:$C{R}\n$C{g}: $C{o}%s%s$C{R}\n$C{g}:$C{R}\n",
            $err_str, defined $caller_str ? " $C{T}$C{B}$caller_str" : '' );
    }
    return undef;
}

sub format_error {
    my $err_str = shift // qw| :undef: |;
    my $c_lvl   = shift // 1;
    my ( $caller_str, $file, $line );
    $err_str =~ s|\n$||;
    ( $file, $line ) = @{^CAPTURE}
        if $err_str =~ s| at (.+?) line (\d+).*$||gs;
    $err_str =~ s|\((did[^\)]+)\?\)|[ $LAST_PAREN_MATCH ? ]|;
    $err_str =~ s|"\s|' |g;
    $err_str =~ s|\s"| '|g;
    $err_str =~ s|\s+BEGIN failed.+$||sg;
    $err_str =~ s|(\S+):(*pla:\s)|$LAST_PAREN_MATCH :|;

    $err_str = lcfirst($err_str) if $err_str =~ m|^[A-Z][^A-Z]|;

    if ( defined $file ) {
        clean_up_caller( \$file );    ## shorten ##
        $caller_str = join( qw| : |, $file, $line );
        $err_str .= " [$caller_str]" if $c_lvl >= 0;
    }
    $err_str =~ s,(can't|unable to),cannot,g;
    $err_str =~ s|^warning : something's wrong$|:undef:|g;
    $err_str =~ s|^use of uninitialized value in warn$|:undef:|g;
    ++$c_lvl if $c_lvl < 0;
    $caller_str = caller( abs($c_lvl) );
    return ( $err_str, $caller_str ) if wantarray;
    return $err_str;
}

sub caller_str {
    my $c_lvl = shift // 0;    ## 0 means caller parent [ from here ] ##
    $c_lvl++;                  ## <-- accounting for this subroutine ##
    my $adj = 1;

    ##  adjusting reported caller level on errors  ##
    my $caller_subroutine = [ caller(1) ]->[3] // '';
    $adj++ if $caller_subroutine eq qw| AMOS7::warn_err |;
    if ( defined caller(2) ) {
        $caller_subroutine = [ caller(2) ]->[3] // '';
        $adj++ if $caller_subroutine eq qw| AMOS7::error_exit |;
    }

    my ( $package, $filename, $line, $subroutine ) = caller($c_lvl);
    if ( not defined $filename ) {
        return sprintf( '[ caller level too high : %03d ]', $c_lvl - $adj );
    } else {
        clean_up_caller( \$filename );    ## shorten ##
        return "[$filename:$line]";
    }
}

sub clean_up_caller {
    my $filename_sref = shift;
    my $was_ref       = length( ref($filename_sref) ) ? 1 : 0;
    $filename_sref = \"$filename_sref" if not $was_ref;
    ## shorten for .pm mods ##
    $$filename_sref =~ s|//|/|g;
    $$filename_sref =~ s|^/usr/(local/)?bin/||;
    $$filename_sref =~ s|^/usr/share/perl5/|,../|;
    $$filename_sref =~ s|^.+/perl\-base/|,./perl-base/|;
    $$filename_sref =~ s|^.+/protocol-7/data/lib-path/pm/||;
    return $$filename_sref if not $was_ref;
}

##[ PROTOCOL-7 INSTALLATION PATH ]###########################################

sub p7_root_dir {

    ## module loaded by protocol-7 zenka ##
    return $main::data{'system'}{'root_path'}
        if defined *main::data{HASH}
        and defined $main::data{'system'}
        and defined $main::data{'system'}{'root_path'};

    ## module is loaded from protocol-7 pm directory ##
    return $LAST_PAREN_MATCH
        if __FILE__ =~ m|^(.+)/data/lib-path/pm/AMOS7.pm$|;

    return undef;    ##  other methods not implemented yet  ##
}

return 5;  ###################################################################

#,,..,.,,,,..,,.,,.,.,..,,,,,,,,,,.,.,.,.,,.,,..,,...,...,,,,,.,.,.,.,.,,,,,,,
#G3DKTYIZC7GISPA7E4A35X2TDALLHS4WCPUWTVDYKVWIPUTO22BVUNJTLY4SBO37DBA3EQI6RNYYG
#\\\|MFTKRDIX2EEER46UM6ROEFVZH6BSYJKQCUL2AUB2H4ZJWFX46VE \ / AMOS7 \ YOURUM ::
#\[7]UNE2AWBWWNJZHZ7FGP7LGUFDQHCLNQLJ2I7FBDGA47YZNZFL6YDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
