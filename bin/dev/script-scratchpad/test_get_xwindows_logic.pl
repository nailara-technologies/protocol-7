#!/usr/bin/perl -w
use strict;
use warnings;
use feature 'say';

## standalone test of the get-xwindows recursive title logic ##

use English;
use X11::Protocol;

my $X = eval { X11::Protocol->new( $ENV{'DISPLAY'} // ':0' ) };
die "cannot connect to X server: $@" if $EVAL_ERROR or not $X;

my $root        = $X->root;
my $wm_name     = $X->atom('WM_NAME');
my $net_wm_name = $X->atom('_NET_WM_NAME');
my $utf8_string = $X->atom('UTF8_STRING');
my $string      = $X->atom('STRING');

my $fetch_title = sub {
    my ( $wid, $atom, $req_type ) = @_;
    return undef unless defined $wid and defined $atom;
    my ($val)
        = eval { $X->GetProperty( $wid, $atom, $req_type, 0, 256, 0 ); };
    return undef if $EVAL_ERROR or not defined $val or not length $val;
    return $val;
};

my $try_title = sub {
    my ( $wid, $atom, $type ) = @_;
    return undef unless defined $atom;
    my $val = $fetch_title->( $wid, $atom, $type );
    return $val if defined $val;
    return $fetch_title->( $wid, $atom, 'AnyPropertyType' );
};

my $find_title;
$find_title = sub {
    my ($wid) = @_;
    return undef unless defined $wid and $wid ne 'None';

    my $title;
    $title = $try_title->( $wid, $net_wm_name, $utf8_string );
    return $title if defined $title;
    $title = $try_title->( $wid, $wm_name, $string );
    return $title if defined $title;

    my ( undef, undef, @children ) = eval { $X->QueryTree($wid) };
    return undef if $EVAL_ERROR;
    foreach my $child (@children) {
        next unless defined $child and $child ne 'None';
        $title = $find_title->($child);
        return $title if defined $title;
    }
    return undef;
};

my @entries;
eval {
    my ( undef, undef, @root_children ) = $X->QueryTree($root);
    foreach my $wid (@root_children) {
        next unless defined $wid and $wid ne 'None' and $wid =~ m|^\d+$|;
        my %wa = eval { $X->GetWindowAttributes($wid) };
        next if $EVAL_ERROR or not %wa;
        next if ( $wa{'map_state'} // '' ) eq 'Unmapped';

        my $title = $find_title->($wid);
        next unless defined $title and length $title;

        push @entries, sprintf '%d  %s', $wid, $title;
    }
};

die "QueryTree failed: $@" if $EVAL_ERROR;

say join "\n", sort @entries;
say '[ no mapped windows found ]' if not @entries;

exit;

#,,.,,,,,,.,.,,,.,,,,,.,.,.,.,,,,,..,,,.,,,.,,..,,...,..,,..,,,,.,..,,.,.,,.,,
#75MR5ADQUOFUITC6ESYMCVME74QAEJICTWP2HHVBQ2YO4GRJDJT34BQHZ5MTNM3WGYJ65LLFQQDME
#\\\|CJ4UD3OLQLTIKQEMFRWHQASQKAV6GQBYI3TCP3OVITY5JKD7LDP \ / AMOS7 \ YOURUM ::
#\[7]AI4U3KOEKXVOV3MTKTCNRKBRJZOZQDI5ECWPDJ2RUQ2FC3FBLUDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
