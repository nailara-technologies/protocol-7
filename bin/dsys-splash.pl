#!/usr/bin/perl

# temporary dibosys splash screen script ( will be replaced by nailara agent.. )

my $scale_factor = 0.5;    # <- of screen width ...

use Gtk3;
use File::Spec;
use Time::HiRes qw(sleep time);

exit(1) if not defined $ENV{'DISPLAY'};

( my $root_path = $0 ) =~ s|/[^/]+/[^/]+$||;
my $logo_path = $root_path . '/data/gfx/logos/dibosys/dibosys_logo.trans.png';

exit(2) if !-f $logo_path;

Gtk3->init;

my $window = Gtk3::Window->new('popup');
$window->signal_connect( delete_event => sub { Gtk3->main_quit } );
my $use_transparency = $window->is_composited ? 1 : 0;
$window->set_opacity(1) if $use_transparency;
$window->set_position('center');
$window->set_border_width(0);
$window->set_decorated(0);
$window->set_keep_above(1);
$window->set_app_paintable(1);
my $screen = $window->get_screen();

if ($use_transparency) {
    my $rgba = $screen->get_rgba_visual();
    $window->set_visual($rgba);
} else {
    my $css_prov = Gtk3::CssProvider->new();
    my $screen   = Gtk3::Gdk::Screen::get_default();
    $css_prov->load_from_data('*{background-color:#ffffff}');
    Gtk3::StyleContext::add_provider_for_screen( $screen, $css_prov, -1 );
}

my $pbuf  = Gtk3::Gdk::Pixbuf->new_from_file($logo_path);
my $img_w = $pbuf->get_width();
my $img_h = $pbuf->get_height();
my $scr_w = $screen->get_width();
my $scr_h = $screen->get_height();
my $image = Gtk3::Image->new_from_pixbuf(
    $pbuf->scale_simple(
        sprintf( "%.0f", $scr_w * $scale_factor ),
        sprintf( "%.0f", $img_h * ( ( $scr_w / $img_w ) * $scale_factor ) ),
        'hyper'
    )
);

$window->add($image);
$window->show_all;

my $fade_delay = 4223;

if ( -e '/tmp/.dibosys.display_was_off' ) {
    unlink('/tmp/.dibosys.display_was_off');
    $fade_delay += 7777;    # ...compensate screen bootup delay... [slow ones]
}

my $fade_start;
Glib::Timeout->add(
    $fade_delay,
    sub {
        $fade_start = sprintf( "%.4f", time );
        $window->signal_connect( draw => \&fade_out );
        $window->queue_draw;
    }
);

Gtk3->main;

sub fade_out {
    my $window      = shift;
    my $old_opavity = $window->get_opacity;
    my $new_opacity = sprintf(
        "%.8f",
        1 - (
            ( time - $fade_start ) * 0.42 - ( 0.365 * ( time - $fade_start ) )
        )
    );
    if ( $new_opacity > 0 ) {
        if ( $new_opacity != $old_opavity ) {
            $window->set_opacity($new_opacity);
            $window->queue_draw;
        } else {
            sleep 0.001;
        }
    } else {
        Gtk3->main_quit;
        exit(0);
    }
}
