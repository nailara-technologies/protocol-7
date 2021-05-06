
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

@EXPORT = qw| error_exit caller_str format_error TERM_SIZE %C $VERSION |;

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

sub format_error {
    my $err_msg = shift // qw| :undef: |;
    my $c_lvl   = shift // 1;
    my ( $caller_str, $file, $line );
    $err_msg =~ s|\n$||;
    ( $file, $line ) = @{^CAPTURE}
        if $err_msg =~ s| at (\S+) line (\d+).*$||gs;
    $err_msg =~ s|\((did[^\)]+)\?\)|[ $LAST_PAREN_MATCH ? ]|;
    $err_msg =~ s|"\s|' |g;
    $err_msg =~ s|\s"| '|g;
    $err_msg =~ s|\s+BEGIN failed.+$||sg;
    $err_msg =~ s|(\S+):|$LAST_PAREN_MATCH :|;

    $err_msg = lcfirst($err_msg) if $err_msg =~ m|^[A-Z][^A-Z]|;

    if ( defined $file ) {
        clean_up_caller( \$file );    ## shorten ##
        $caller_str = join( qw| : |, $file, $line );
        $err_msg .= " [$caller_str]" if $c_lvl >= 0;
    }
    $err_msg =~ s,(can't|unable to),cannot,g;
    $err_msg =~ s|^warning : something's wrong$|:undef:|g;
    $err_msg =~ s|^use of uninitialized value in warn$|:undef:|g;
    ++$c_lvl if $c_lvl < 0;
    $caller_str = caller( abs($c_lvl) );
    return ( $err_msg, $caller_str ) if wantarray;
    return $err_msg;
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
    $$filename_sref =~ s{^/usr/(local/)?bin/}{};
    $$filename_sref =~ s{^/usr/share/perl5/}{,../};
    $$filename_sref =~ s{^.+/perl\-base/}{,./perl-base/};
    $$filename_sref =~ s{^.+/protocol-7/data/lib-path/pm/}{};
    return $$filename_sref if not $was_ref;
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
#LQDIHLGXNSWNYII6ZLLDEAHQOYGCILPQPPRX7S7BSGZ2XMWYGPE27C7ZBGRBJH3FT5N2KBVZ5BOAO
#::: 6BZUQ3MYMRZMUK6YQ7WQ3WGHDRD4W7LNP7WL2NK4BN7RBZESQQG :::: NAILARA AMOS :::
# :: NATW3MMYGAGXJLTVK3SICCDDDOMHULKTYPNRDR4VQ2BJ5HRNDSDA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
