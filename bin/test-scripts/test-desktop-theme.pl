#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;

use Test::More;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;

use lib "$RealBin/../../data/lib-path/pm";
use AMOS7::Desktop::Theme qw| read gtk_css web_css cairo_rgb |;

my $root  = abs_path("$RealBin/../..");
my $theme = read( { 'root' => $root } );

is scalar keys %{$theme},   26, 'all theme tokens read from cfg/desktop';
is $theme->{'font.family'}, 'White Rabbit', 'canonical font family';
is $theme->{'font.size'},   13,             'base font size';

my $tmp = tempdir( CLEANUP => 1 );
make_path "$tmp/cfg", "$tmp/etc/host-config";
open my $disk_fh, '>', "$tmp/cfg/desktop" or die $OS_ERROR;
print {$disk_fh} "desktop.theme.color.accent = 000001\n";
close $disk_fh;
open my $host_fh, '>', "$tmp/etc/host-config/theme-test.cfg" or die $OS_ERROR;
print {$host_fh} "desktop.theme.color.accent = 000002\n";
close $host_fh;
my $host_theme = read(
    {   'root'    => $tmp,
        'zenka'   => 'theme-test',
        'etc_dir' => "$tmp/etc",
    }
);
is $host_theme->{'color.accent'}, '000002', 'host theme layer wins';
like web_css($host_theme), qr|--p7-color-accent: #000002;|,
    'host override reaches web css';

my %exact_old_value = (
    'background'        => '000013',
    'background_mid'    => '000042',
    'background_dark'   => '000208',
    'background_focus'  => '00084A',
    'background_held'   => '05082A',
    'foreground'        => '0055CC',
    'foreground_bright' => '0088FF',
    'foreground_dim'    => '003A8C',
    'accent'            => '4427AC',
    'warning'           => 'C58D07',
    'error'             => 'C05050',
    'ok'                => '09AA5E',
    'selection'         => '1A0946',
    'button'            => '001A88',
    'button_top'        => '000EA0',
);
my $web = web_css($theme);

foreach my $name ( sort keys %exact_old_value ) {
    ( my $property = $name ) =~ s|_|-|g;
    like $web, qr|--p7-color-\Q$property\E: #\Q$exact_old_value{$name}\E;|,
        "exact old colour preserved for $name";
}

like $web, qr|--p7-font-family: 'White Rabbit';|, 'web font custom property';
like $web, qr|--p7-font-size: 13px;|, 'web font size custom property';
like $web, qr|--p7-spacing-m: 8px;|,  'web spacing custom property';
like $web, qr|--p7-translucency-panel: 0.92;|, 'web translucency property';
foreach my $alias (
    qw| bg bg-mid bg-dark fg fg-bright fg-dim btn btn-top accent gold
    outline held text-soft text-mid text-dim |
) {
    like $web, qr|--p7-\Q$alias\E: var\(--p7-|,
        "legacy alias $alias retained";
}

my $gtk = gtk_css($theme);
like $gtk, qr|font-family: "White Rabbit"; font-size: 13px;|,
    'gtk uses token font';
like $gtk, qr|window, dialog, grid, box \{\s+background-color: #000013;|s,
    'gtk background stays exact';
like $gtk, qr|entry:focus \{ background-color: #00084A; \}|,
    'gtk focus stays exact';
like $gtk, qr|background-color: #1A0946; color: #0088FF;|,
    'gtk selection and hover stay exact';
like $gtk, qr|[.]muted \{ color: #003A8C; \}|, 'gtk muted colour stays exact';
like $gtk, qr|entry \{\s+background-color: #000042;|s,
    'gtk panel colour stays exact';

my @accent_rgb = cairo_rgb( $theme, 'color.accent' );
is_deeply \@accent_rgb, [ 68 / 255, 39 / 255, 172 / 255 ],
    'cairo helper returns float triple';

my $static_path = "$root/data/web-root/vhosts/jobsite.vhost/theme.css";
open my $static_fh, '<', $static_path or die $OS_ERROR;
local $INPUT_RECORD_SEPARATOR = undef;
my $static = <$static_fh>;
close $static_fh;
is $static, $web, 'static jobsite stylesheet matches generated tokens';

open my $html_fh, '<', "$root/data/web-root/vhosts/jobsite.vhost/index.html"
    or die $OS_ERROR;
my $html = <$html_fh>;
close $html_fh;
like $html, qr|<link rel="stylesheet" href="theme[.]css">|,
    'jobsite page links the static stylesheet';
$INPUT_RECORD_SEPARATOR = "\n";

our %data;
our %code;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|[.]|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$root/src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

{

    package Gtk3::CssProvider;
    sub new            { return bless {}, shift }
    sub load_from_data { $_[0]->{'css'} = $_[1] }

    package Gtk3::StyleContext;
    sub add_provider_for_screen { return 1 }
}

$code{'base.perlmod.autoload'}        = sub { return 1 };
$data{'system'}{'root_path'}          = $root;
$data{'system'}{'zenka'}{'name'}      = 'theme-test';
$data{'system'}{'path'}{'zenka-dirs'} = { 'etc_P7' => "$tmp/etc" };
load_src('base.gtk.style');
my $provider = $code{'base.gtk.style'}->('screen');
like $provider->{'css'}, qr|background-color: #000013;|,
    'gtk adapter reads real token file';
$provider = $code{'base.gtk.style'}->(
    'screen',
    {   'color'       => { 'text' => '#010203' },
        'font_size'   => 17,
        'font_family' => 'Token Override',
        'css'         => "extra { padding: 2px; }\n",
    }
);
like $provider->{'css'}, qr|color: #010203;|,
    'gtk adapter keeps per-call colour overrides';
like $provider->{'css'}, qr|font-family: "Token Override"; font-size: 17px;|,
    'gtk adapter keeps per-call font overrides';
like $provider->{'css'}, qr|extra \{ padding: 2px; \}|,
    'gtk adapter appends surface css';

done_testing;

#,,.,,,..,,,,,,,.,,,,,,,,,...,,.,,,,,,.,,,...,..,,...,...,..,,.,.,,.,,,..,...,
#HFB7SYBNI4E4P2WMCDY3AJ3IYSVUM5F6W3RACVM3HH4AKRWMMGCLHCQIQCULDK3SKYALNXYB2NDFM
#\\\|BAIBUCJ3OORFSWPTCL76BX4EER5CAY4BKOPCL6I4UQWUJI2LMG5 \ / AMOS7 \ YOURUM ::
#\[7]K77K4X3RTU442DRLON7OXT7HLWDCPXGQCW75JQ5EUNPDFBHI5EBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
