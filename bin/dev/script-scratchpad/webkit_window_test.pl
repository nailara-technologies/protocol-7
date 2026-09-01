#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

## test: gtk window map signal, get_mapped, get_xid  diagnoses web-browser
## zenka wait_for_window crash

use Gtk3 -init;
use Glib::Object::Introspection;
Glib::Object::Introspection->setup(
    basename => 'WebKit2',
    version  => '4.1',
    package  => 'Gtk3::WebKit2'
);

say ': creating window';
my $window = Gtk3::Window->new('toplevel');
$window->set_title('web-browser test');
$window->set_default_size( 800, 600 );

say ': get_mapped '
    . 'before show_all: '
    . ( $window->get_mapped ? "TRUE" : "FALSE" );

## test map signal
$window->signal_connect(
    'map' => sub {
        say ': MAP SIGNAL FIRED';
        say ': get_mapped '
            . 'in map signal: '
            . ( $window->get_mapped ? "TRUE" : "FALSE" );

        my $gdk_win = $window->get_window;
        if ( defined $gdk_win ) {
            my $xid = eval { $gdk_win->get_xid };
            if ($@) {
                say ": get_xid threw: $@";
            } else {
                say ": X11 window id: $xid";
            }
        } else {
            say ': gdk_win is undef';
        }

        ## quit after 2 seconds
        Glib::Timeout->add( 2000, sub { Gtk3->main_quit; return 0 } );
        return 0;
    }
);

## test realize signal
$window->signal_connect(
    'realize' => sub {
        say ': REALIZE SIGNAL FIRED';
        say ': get_mapped '
            . 'in realize: '
            . ( $window->get_mapped ? "TRUE" : "FALSE" );
        return 0;
    }
);

say ': calling show_all';
$window->show_all;

say ': get_mapped '
    . 'after show_all: '
    . ( $window->get_mapped ? "TRUE" : "FALSE" );

say ': entering main loop';
Gtk3->main;

say ': done';

#,,,,,,,,,,,.,.,,,.,,,.,,,,.,,,,.,.,.,,,,,,,.,..,,...,...,...,..,,.,.,.,,,.,.,
#H4HKFZBVQERQEDJYIFHVMEJ7U56RCECJJTOO5EK3IJPFFKEKT3PM4HF3I2OGSTOTXJCFP4URFNAKS
#\\\|I5ZZOWSNTPP35QUL3GHD3D5FOR2GILGLFGISEQ72DZDGBIXHIWT \ / AMOS7 \ YOURUM ::
#\[7]FXYLJUSD4CV6JO46RQ7U3AKDT23WXYQWIRYB3FIYSBQTNBL6QWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
