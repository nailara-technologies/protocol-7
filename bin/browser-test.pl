#!/usr/bin/perl

use strict;
use warnings;

use Gtk2 -init;
use Gtk2::WebKit;
use Glib qw/TRUE FALSE/;
use Time::HiRes qw(sleep);
use Data::Dumper qw(Dumper);

my $fade = 1;
$fade = 0 if @ARGV and $ARGV[0] eq '-nofade';

my $window = Gtk2::Window->new('toplevel');

$window->set_decorated(0);
$window->set_border_width(0);

$window->set_accept_focus(0);
$window->set_has_frame(0);

#$window->set_opacity(0.5);
#$window->set_resizable(0);

#$window->set_default_size( 300, 200 );
#$window->set_size_request( 900, 420 );
$window->set_title('browser');

$window->signal_connect( destroy => sub { Gtk2->main_quit() } );

my $hide_scrollbars = 1;

Gtk2::Rc->parse_string(<<__) if $hide_scrollbars;
style "hide-scrollbar-style"
{
  GtkScrollbar::slider_width = 0
  GtkScrollbar::min-slider-length = 0
  GtkScrollbar::activate_slider = 0
  GtkScrollbar::trough_border = 0
  GtkScrollbar::has-forward-stepper = 0
  GtkScrollbar::has-backward-stepper = 0
  GtkScrollbar::stepper_size = 0
  GtkScrollbar::stepper_spacing = 0
  GtkScrollbar::trough-side-details = 0
  GtkScrollbar::default_border = { 0, 0, 0, 0 }
  GtkScrollbar::default_outside_border = { 0, 0, 0, 0 }
  GtkScrolledWindow::scrollbar-spacing = 0
  GtkScrolledWindow::scrollbar-within-bevel = False
}
widget_class "*Scrollbar" style "hide-scrollbar-style"
widget_class "*ScrolledWindow" style "hide-scrollbar-style"
__

my $view = Gtk2::WebKit::WebView->new();

$view->can_focus(0);

#my $frame = $view->get_main_frame();
#$frame->signal_connect( "scrollbars-policy-changed", sub { return TRUE } );

my $scroll = Gtk2::ScrolledWindow->new();

my @event_list = qw(
    button-press-event
    button-release-event
    motion-notify-event
);

foreach my $sname (@event_list) {
    $view->signal_connect( $sname, sub { return TRUE } );
}

my $settings = $view->get_settings;

#$settings->set_property( 'auto-load-images', FALSE );
#$settings->set_property( 'enable-scripts',   FALSE );

$settings->set_property( 'enable-offline-web-application-cache', FALSE );
$settings->set_property( 'enable-default-context-menu',          FALSE );
$settings->set_property( 'enable-html5-local-storage',           FALSE );
$settings->set_property( 'enable-java-applet',                   FALSE );
$settings->set_property( 'enable-fullscreen',                    FALSE );
$settings->set_property( 'enable-page-cache',                    TRUE );
$settings->set_property( 'enable-private-browsing',              TRUE );

$view->set_settings($settings);

#$scroll->set_default_size( 300, 200 );
#$scroll->set_policy( 'GTK_POLICY_ALWAYS', 'GTK_POLICY_ALWAYS' );
$scroll->add($view);
$window->add($scroll);

#$scroll->set_policy( 'GTK_POLICY_NEVER' , 'GTK_POLICY_NEVER' );

#$view->load_uri('http://nailara.de/');
$view->load_uri('https://www.ccc.de/');
#$view->load_uri('http://www.twc.de/');
#$view->load_uri('https://www.startpage.com/');

$view->set_editable(0);

#$view->set_zoom_level(1.2);

#$SIG{'ALRM'} = sub { print "reloading...\n"; $view->reload() };
#alarm(5);

#$SIG{'ALRM'} = sub {
#    print "resizing...\n";
#    $window->set_size_request( 900, 500 );
#    $window->set_resizable(0);
#};
#alarm(4);

my ( $size_x, $size_y ) = ( 1000, 584 );

if ($fade) {
    $window->set_opacity(0);
    $window->set_size_request( $size_x, $size_y );
    $window->set_resizable(0);
} else {
    $window->set_size_request( 0, 0 );
}

my $reload     = 0;
my $first_load = 1;
my $faded_out  = $fade;

$view->signal_connect(
    'notify::load-status' => sub {
        my $status = $view->get_load_status;
        print "<$status>\n";
        return unless $view->get_uri and $status eq 'finished';
        if ( !$reload and $fade ) {
            fade_in();
            $reload = 0;
        } elsif ($first_load) {
            $window->set_size_request( $size_x, $size_y );
            $window->set_resizable(0);
            $first_load = 0;
        }

    }
);

my $scroll_pos = 0;

Glib::Timeout->add( 33, \&scroll_handler,, 0 );

#Glib::Idle->add( \&scroll_handler );

#my $vbar = $scroll->get_vscrollbar();
#$scroll->signal_connect(
#    'ScrolledWindow::signal_edge_reached' => sub { print "EDGE REACHED\n" } );

$window->set_default_size( 2, 2 );
$window->show_all();
$window->set_default_size( 0, 0 );

$window->set_keep_above(0);
$window->set_keep_below(1);

Glib::IO->add_watch(
    fileno(STDIN),
    ['in'],
    sub {
        chomp( my $cmd = <STDIN> );
        if ( $cmd eq 'reload' ) { $reload = 1; $view->reload }
        elsif ( $cmd eq 'fadein' ) {
            fade_in();
        } elsif ( $cmd eq 'fadeout' ) {
            fade_out();
        } elsif ( $cmd =~ /opacity ([01]{1}(\.\d+)?)/ ) {
            my $opacity = $1;
            print "setting opacity to $opacity ..\n";
            $window->set_opacity($opacity);
        } elsif ( $cmd =~ /move (\-?\d+) (\-?\d+)/ ) {
            my ( $x, $y ) = ( $1, $2 );
            print "moving to ${x}, ${y} ..\n";
            $window->move( $x, $y );
        } elsif ( $cmd =~ /scale (\d+(\.\d+)?)/ ) {
            my $factor = $1;
            print "scale factor ${factor} ..\n";
            $view->set_zoom_level($factor);
        } elsif ( $cmd =~ /resize (\d+) (\d+)/ ) {
            my ( $w, $h ) = ( $1, $2 );
            print "resizing to ${w}x${h} ..\n";
            $window->set_size_request( $w, $h );
        } elsif ( $cmd eq 'quit' ) {
            if ($fade) {
                fade_out('quit');
            } else {
                Gtk2->main_quit();
            }
        } else {
            print "loading url : '$cmd'\n";
            if ( defined($cmd) ) {
                $reload = 0;
                if ($fade) {
                    fade_out("load $cmd");
                } else {
                    $view->load_uri($cmd);
                }
            }
        }
        return 1;
    },
    $view
);

Gtk2->main;

sub fade_in {
    return if !$fade;
    my $opacity = 0;
    $opacity = 1 if !$faded_out;
    my $callback = sub {
        my $opcr = shift;
        $window->set_opacity( $$opcr = sprintf( "%.2f", $$opcr + 0.01 ) );
        sleep 0.01;
        return TRUE if $$opcr < 1;
        $faded_out = 0;
        return FALSE;
    };
    Glib::Idle->add( $callback, \$opacity );
}

sub fade_out {
    return if !$fade;
    my $fade_cmd = shift || '';
    my $opacity = 1;
    $opacity = 0 if $faded_out;
    my $callback = sub {
        my $opcr = shift;
        $window->set_opacity( $$opcr = sprintf( "%.2f", $$opcr - 0.01 ) );
        sleep 0.01;
        return TRUE if $$opcr > 0;
        Gtk2->main_quit() if $fade_cmd eq 'quit';
        if ( $fade_cmd =~ /^load (.+)$/ ) {
            $view->load_uri($1);
        }
        $faded_out = 1;
        return FALSE;
    };
    Glib::Idle->add( $callback, \$opacity );
}
