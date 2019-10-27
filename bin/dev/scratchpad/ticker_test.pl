#!/usr/bin/perl

#
#   copyright /c\ 2015,2019 \/ Alexander (Taeki) Taute <src@dev.nailara.net>
#
#   Permission to use, copy, modify, and/or distribute this software for any
#   purpose with or without fee is hereby granted, provided that the above
#   copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
#  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
#  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

use strict;
use warnings;

use SDL;
use SDL::TTF;
use SDL::Rect;
use SDL::Event;
use SDL::Events;
use SDL::Video;
use SDL::Color;
use SDL::Surface;
use SDL::VideoInfo;

SDL::init(SDL_INIT_VIDEO);
SDL::TTF::init();

my @font_names = qw(
    FreeSans
    FreeMono
    FreeMonoBold
    FreeSansBold
);

## configuration ##

my $ticker_position = 'bottom';    # [top|center|bottom]

my $font_used = $font_names[3];
my $font_size = 84;
my $delay     = 5;

#my $font_used = $font_names[1];
#my $font_size = 222;
#my $delay     = 0;

my $bold          = 0;
my $shadow        = 1;
my $shadow_offset = 2;
my $border_offset = 0;

my $steps = 1;

# prepare colors to use for the ticker
my $fg_col = SDL::Color->new( 0x00, 0x02, 0x69 );    # foreground
my $bg_col = SDL::Color->new( 0x00, 0x00, 0x13 );    # background
my $sh_col = SDL::Color->new( 0x00, 0x01, 0x17 );    # text shadow

# the test text ...
my $test_text = << '__EOT__'
     . 0 000 4511 932 230769 - 040 \ 707 .,
    ^
        . parasites do not compute ., .:[ HOLES IN SPACE ]:.
        . parasites do not compute ., .:[ HOLES IN SPACE ]:.

      . The's'at katra k'tei i'k'therie -
        In' k'tmneri a'nailara laikani'he.
        The's'at katra - a'ri'nailara .,
    ^
      . Our Katra is a clear surface -
        It reflects the universe in harmony.
        Our Katra - the universe are one .,
    ^
      . 0000 00000 0110 0010 .,
__EOT__
    ;

# adjust / add paths as needed.. (and install droid fonts or configure another)
my $font_path;
$font_path = '/usr/share/fonts/truetype/freefont';        # debian
$font_path = '/usr/share/fonts/TTF' if !-d $font_path;    # arch linux

# skip frames in event polling
my $event_skip_frames = 5;

## initialization ##

# determine font path (droid fonts need to be installed)
die "font path not found" if !-d $font_path;
$font_path .= "/$font_used.ttf";

# load the configured font
my $font_obj = SDL::TTF::open_font( $font_path, $font_size );
die "Failed to open font " . SDL::get_error if !$font_obj;
my $font_height    = SDL::TTF::font_height($font_obj);
my $font_line_skip = SDL::TTF::font_line_skip($font_obj);
my $border_height  = int( abs( SDL::TTF::font_descent($font_obj) ) / 2 );

# determine screen size
my $video_info = SDL::Video::get_video_info()
    or die "Failed to get video info: " . SDL::get_error;
my @modes = @{ SDL::Video::list_modes( $video_info->vfmt, SDL_FULLSCREEN ) };
my $max_mode = shift(@modes);
my ( $screen_width, $screen_height )
    = ( $max_mode->w, $font_line_skip + ( $border_height * 2 ) );

# set up position on the screen
if ( $ticker_position eq 'center' ) {
    SDL::putenv("SDL_VIDEO_CENTERED=center");
} else {
    my $y_pos = $ticker_position eq 'top' ? 0 : $max_mode->h - $screen_height;
    SDL::putenv("SDL_VIDEO_WINDOW_POS=0,$y_pos");
}

# prepare event handling
my $event = SDL::Event->new();

# initialize SDL window
my $display
    = SDL::Video::set_video_mode( $screen_width, $screen_height, 32,
    SDL_DOUBLEBUF | SDL_HWSURFACE | SDL_HWACCEL | SDL_NOFRAME | SDL_PREALLOC )
    or die SDL::get_error();

my $m_bg_col    # prepare a mapped color for screen background
    = SDL::Video::map_RGB( $display->format(), $bg_col->r, $bg_col->g,
    $bg_col->b );

# clear screen area
SDL::Video::fill_rect( $display,
    SDL::Rect->new( 0, 0, $screen_width, $screen_height ), $m_bg_col );

# cleanup whitespaces..
my $scroll_text = $test_text;
$scroll_text =~ s|\n| |g;
$scroll_text =~ s| +| |g;
$scroll_text =~ s/^\s+|\s+$//g;
$scroll_text =~ s/\s*\^\s*/^/g;

## preparing the text snipplet images in memory beforehand ##

my @content;
while ( $scroll_text =~ s/^((\S{1,23}\s*){1,5})// and my $string = $1 ) {

    # $string will contain pieces of 1-5 words ( $string max. length: 92 bytes )

    my ( $width, $height );

    # use '^' chars to allow text to scroll out of screen before continueing ...
    if ( $string =~ s|^(.+)(\^.*)|$1| ) {
        $scroll_text = "$2$scroll_text";
    } elsif ( $string =~ s|^\^|| ) {
        $scroll_text = "$string$scroll_text";
        ( $width, $height ) = ( $screen_width, $font_height );
        $string = '';
    }

    # calculate text snipplet size
    ( $width, $height ) = @{ SDL::TTF::size_text( $font_obj, $string ) }
        if length($string);

    # adjust surface size for shadow dimensions
    if ($shadow) {
        $width  += $shadow_offset;
        $height += $shadow_offset;
    }

    my $surface    # initialize text snipplet surface
        = SDL::Surface->new( SDL_HWSURFACE, $width, $height, 32, 0, 0, 0, 0 );

    # fill snipplet surface with background color
    SDL::Video::fill_rect( $surface,
        SDL::Rect->new( 0, 0, $width, $height ), $m_bg_col );

    if ( length($string) ) {
        if ($shadow) {

            # render text shadow (if configured)
            my $text_shadow_surface
                = SDL::TTF::render_utf8_blended( $font_obj, $string, $sh_col );

            # copy shadow to text snipplet surface
            SDL::Video::blit_surface(
                $text_shadow_surface,
                SDL::Rect->new( 0, 0, $width, $height ),
                $surface,
                SDL::Rect->new(
                    $shadow_offset, $shadow_offset, $width, $height
                ),
            );
        }

        # render foreground text
        my $text_surface
            = SDL::TTF::render_utf8_blended( $font_obj, $string, $fg_col );

        # copy foreground text to text snipplet surface
        SDL::Video::blit_surface(
            $text_surface, SDL::Rect->new( 0, 0, $width, $height ),
            $surface,      SDL::Rect->new( 0, 0, $width, $height ),
        );
    }

    # store text snipplet data
    my $element = {
        'surface' => $surface,
        'height'  => $height,
        'width'   => $width,
        'text'    => $string,
    };
    push( @content, $element );
}

### ticker scroll animation ###

my $frame       = 0;
my $flip_failed = 0;
while (1) {    # main loop ( exits on QUIT, mouse and key events)
    my @content_copy = @content;    # create a working copy

    # initialize offsets / positions
    map { $_->{'text_offset'} = 0; $_->{'screen_offset'} = $screen_width; }
        @content_copy;

    while (@content_copy) {

        # copy visible elements to screen
        my $last_offset;
        for my $index ( 0 .. scalar @content_copy - 1 ) {
            $frame++;
            my $element = $content_copy[$index];
            next if not defined $element->{'width'};

            # calculate text slice width and position
            $element->{'text_offset'} += $steps
                if $element->{'screen_offset'} < 0;
            $element->{'screen_offset'} -= $steps if !$element->{'text_offset'};

            # copy current text slice to screen
            SDL::Video::blit_surface(
                $element->{'surface'},
                SDL::Rect->new(
                    $element->{'text_offset'},
                    0, $screen_width - $element->{'screen_offset'},
                    $element->{'height'}
                ),
                $display,
                SDL::Rect->new(
                    $element->{'screen_offset'},
                    $border_height + $border_offset,
                    $screen_width - $element->{'screen_offset'},
                    $element->{'height'}
                )
            );

            last    # skip elements beyond the right screen border
                if $element->{'screen_offset'}
                + ( $element->{'width'} - $element->{'text_offset'} )
                >= $screen_width;

        }

        # remove no longer visible elements
        shift @content_copy
            if $content_copy[0]->{'text_offset'} >= $content_copy[0]->{'width'};

        # update screen ( try hardware blitting first )
        if ( !$flip_failed ) {
            unless ( SDL::Video::flip($display) == 0 ) {
                my $err_str = SDL::get_error() || $!;
                my $err_str_brackets = length($err_str) ? " [ $err_str ]" : '';
                warn "failed to swap buffers! (switching to software mode)"
                    . $err_str_brackets . "\n";
                $flip_failed = 1;
            }
        }

        # if hardware blitting failed, try the software method
        SDL::Video::update_rect( $display, 0, 0, $screen_width, $screen_height )
            if $flip_failed;

        # check events to see if we need to exit
        if ( $frame >= $event_skip_frames ) {
            SDL::Events::pump_events();
            if ( SDL::Events::poll_event($event) ) {
                if (   $event->type == SDL_MOUSEBUTTONDOWN
                    or $event->type == SDL_KEYDOWN
                    or $event->type == SDL_QUIT ) {
                    exit;
                }
            }
            $frame = 0;
        }

        # pause to slow down
        SDL::delay($delay) if $delay;
    }
}
