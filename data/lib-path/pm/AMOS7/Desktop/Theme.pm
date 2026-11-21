package AMOS7::Desktop::Theme;
our $VERSION = qw| AMOS7::Desktop::Theme-VERSION.7GCMNHQ |;

use v5.32;
use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;
use AMOS7::Config::Reader;

our @EXPORT_OK = qw| read gtk_css web_css cairo_rgb |;

my %WEB_ALIAS = (
    'bg'        => 'color.background',
    'bg-mid'    => 'color.background_mid',
    'bg-dark'   => 'color.background_dark',
    'fg'        => 'color.foreground',
    'fg-bright' => 'color.foreground_bright',
    'fg-dim'    => 'color.foreground_dim',
    'btn'       => 'color.button',
    'btn-top'   => 'color.button_top',
    'accent'    => 'color.accent',
    'gold'      => 'color.warning',
    'outline'   => 'color.background_dark',
    'held'      => 'color.background_held',
    'text-soft' => 'color.foreground_bright',
    'text-mid'  => 'color.foreground',
    'text-dim'  => 'color.foreground_dim',
);

## built-in tokens [ the values of cfg/desktop ] : every gtk zenka loads  ##
## its style through this module, so a missing file or one bad value must ##
## never stop a start -- missing \ invalid tokens fall back one by one    ##
my %DEFAULT = (
    'font.family'             => 'White Rabbit',
    'font.size'               => '13',
    'color.background'        => '000013',
    'color.background_mid'    => '000042',
    'color.background_dark'   => '000208',
    'color.background_focus'  => '00084A',
    'color.background_held'   => '05082A',
    'color.foreground'        => '0055CC',
    'color.foreground_bright' => '0088FF',
    'color.foreground_dim'    => '003A8C',
    'color.accent'            => '4427AC',
    'color.warning'           => 'C58D07',
    'color.error'             => 'C05050',
    'color.ok'                => '09AA5E',
    'color.selection'         => '1A0946',
    'color.button'            => '001A88',
    'color.button_top'        => '000EA0',
    'translucency.panel'      => '0.92',
    'translucency.overlay'    => '0.74',
    'translucency.selection'  => '0.72',
    'translucency.muted'      => '0.45',
    'spacing.xs'              => '2',
    'spacing.s'               => '4',
    'spacing.m'               => '8',
    'spacing.l'               => '12',
    'spacing.xl'              => '20',
);

sub _valid_token {
    my ( $name, $value ) = @ARG;
    return $value =~ m|^#?[0-9a-fA-F]{6}$| if $name =~ m|^color[.]|;
    return $value =~ m|^\d+$|
        if $name eq 'font.size' or $name =~ m|^spacing[.]|;
    return $value =~ m|^(?:0(?:\.\d+)?\|1(?:\.0+)?)$|
        if $name  =~ m|^translucency[.]|;
    return length $value > 0;
}

sub read {
    my $opts   = shift // {};
    my $tokens = eval {
        AMOS7::Config::Reader->read( 'desktop', $opts )
            ->section('desktop.theme');
    };
    if ( ref $tokens ne 'HASH' ) {
        warn "desktop theme : cfg/desktop not "
            . "readable, built-in tokens used\n";
        $tokens = {};
    }
    my %theme = %DEFAULT;
    foreach my $name ( keys %{$tokens} ) {
        my $value = $tokens->{$name} // '';
        $value =~ s|^\s+||;
        $value =~ s|\s+$||;
        if ( exists $DEFAULT{$name} and not _valid_token( $name, $value ) ) {
            warn "desktop theme : invalid '$name', built-in value used\n";
            next;
        }
        $theme{$name} = $value;
    }
    return wantarray ? %theme : \%theme;
}

sub _color {
    my ( $theme, $name ) = @ARG;
    my $value = $theme->{$name} // '';
    die "desktop theme colour '$name' is not six-digit hex\n"
        if $value !~ m|^#?([0-9a-fA-F]{6})$|;
    return '#' . uc ${^CAPTURE}[0];
}

sub _css_value {
    my ( $theme, $name ) = @ARG;
    return _color( $theme, $name ) if $name =~ m|^color[.]|;
    my $value = $theme->{$name} // '';
    return "'$value'"   if $name eq 'font.family';
    return "${value}px" if $name eq 'font.size' or $name =~ m|^spacing[.]|;
    return $value;
}

sub gtk_css {
    my ( $theme, $opt ) = @ARG;
    $opt //= {};
    my $family = $opt->{'font_family'} // $theme->{'font.family'};
    $family =~ s|[{};"]| |g;
    my $size = $opt->{'font_size'} // $theme->{'font.size'};
    die "desktop theme font size is not an integer\n" if $size !~ m|^\d+$|;

    my %color = map { $ARG => _color( $theme, $ARG ) } qw|
        color.background color.background_mid color.background_focus
        color.foreground color.foreground_bright color.foreground_dim
        color.selection
        |;

    return <<"EOT";
* { background-image: none; box-shadow: none; text-shadow: none;
    outline-color: $color{'color.foreground'}; }
window, dialog, grid, box {
    background-color: $color{'color.background'}; color: $color{'color.foreground'};
    font-family: "$family"; font-size: ${size}px; }
label { background-color: transparent; color: $color{'color.foreground'}; }
.muted { color: $color{'color.foreground_dim'}; }
entry {
    background-color: $color{'color.background_mid'}; color: $color{'color.foreground'};
    caret-color: $color{'color.foreground'};
    border: 1px solid $color{'color.foreground'}; border-radius: 0; }
entry:focus { background-color: $color{'color.background_focus'}; }
entry selection, entry selection:focus {
    background-color: $color{'color.selection'}; color: $color{'color.foreground_bright'}; }
button {
    background-color: $color{'color.background_mid'}; color: $color{'color.foreground'};
    border: 1px solid $color{'color.foreground'}; border-radius: 0; }
button:hover, button:focus { background-color: $color{'color.background_focus'}; color: $color{'color.foreground_bright'}; }
button label { color: inherit; }
menu { background-color: $color{'color.background'}; border-color: $color{'color.background_mid'};
       color: $color{'color.foreground'}; }
menu *:hover, menu *:focus { background-color: $color{'color.background_mid'}; color: $color{'color.foreground_bright'}; }
EOT
}

sub web_css {
    my $theme = shift;
    my $css   = ":root {\n";
    foreach my $name ( sort keys %{$theme} ) {
        ( my $property = $name ) =~ s|[._]|-|g;
        my $value = _css_value( $theme, $name );
        $css .= sprintf "    --p7-%s: %s;\n", $property, $value;
    }
    $css .= "\n    /* existing jobsite names remain aliases */\n";
    foreach my $alias ( sort keys %WEB_ALIAS ) {
        ( my $target = $WEB_ALIAS{$alias} ) =~ s|[._]|-|g;
        $css .= sprintf "    --p7-%s: var(--p7-%s);\n", $alias, $target;
    }
    return $css . "}\n";
}

sub cairo_rgb {
    my ( $theme, $name ) = @ARG;
    my $hex = _color( $theme, $name );
    return map { hex($ARG) / 255 } ( $hex =~ m|([0-9a-fA-F]{2})|g );
}

1;

#,,..,..,,,,.,..,,,,,,,.,,.,.,..,,.,.,..,,.,.,..,,...,...,.,,,,,.,,,,,,,.,,.,,
#IMCCPRC32FVNXMBIERJEYOKWMF3WA776OFEQORD44V2LFIZMDFRIFPNK2UPZ5B53GZJUDOMTE52PC
#\\\|VWBR2PKB4OTCRLL3BKZJPBJVDRIZFRNABOCUWIWQ4D6F4GMKBCJ \ / AMOS7 \ YOURUM ::
#\[7]HUNYROAAEMITZBYJ23V6SW35O3LQA5GB5XDGYI34ISS5FIOPKUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
