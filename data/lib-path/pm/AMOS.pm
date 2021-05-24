
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

@EXPORT = qw|
    TERM_SIZE %C $VERSION
    error_exit warn_err caller_str format_error
    |;

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

##[ ERROR HANDLING ]##########################################################

sub error_exit {
    my $err_str = shift // '';

    chomp( $err_str = sprintf $err_str, @ARG ) if @ARG; ## sprintf template ##

    $err_str =~ s|^[A-Z](*nla:[A-Z])|\l$MATCH|;
    $err_str =~ s|(*plb:\w): (\S+)|$C{B} : $C{o}$LAST_PAREN_MATCH|;

    warn_err($err_str);

    exit(113) if not defined $main::PROTOCOL_SEVEN;
}

sub warn_err {
    my $err_str = shift // ':: warn :: undefined <{C1}>';
    my $c_lvl   = shift // 1;

    say STDERR ': warn_err : caller level as second argument expected'
        if defined $c_lvl and $c_lvl !~ m|^\-?\d+$|;

    chomp( $err_str = sprintf $err_str, @ARG ) if @ARG; ## sprintf template ##

    my $no_caller = 0;
    $c_lvl     = $LAST_PAREN_MATCH if $err_str =~ s| <\{C(\d+)\}>$||;
    $no_caller = 1                 if $err_str =~ s| <\{NC\}>$||;

    if ( defined $main::PROTOCOL_SEVEN ) {              ##  zenka  ##
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
    my ( $package, $filename, $line, $subroutine ) = caller($c_lvl);
    if ( not defined $filename ) {
        return sprintf( "[ caller level too high : %03d ]", $c_lvl );
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

return 1;  ###################################################################

#.............................................................................
#KNRS4E4EXIT6EWIRR2II7VYBW7W5PX63UYGUAMP3AL7UTCETCVLRNZXIPZPLWGORYRAZ6ILHDKDMC
#::: VIBTXO7Y2E6VU7MKY2VJWT3TWQQLDWTQYQHUMBM6PJFIZQ2JOH5 :::: NAILARA AMOS :::
# :: AW6LND2DNYNOKD45NLQDGD6HJOSTY3TKQP44Y5LS7T6S4HDKJ4CA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
