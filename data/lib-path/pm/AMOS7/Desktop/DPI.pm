package AMOS7::Desktop::DPI;
our $VERSION = qw| AMOS7::Desktop::DPI-VERSION.I46RTLQ |;

use v5.32;
use strict;
use warnings;
use English;
use Fcntl qw| O_WRONLY O_CREAT O_EXCL |;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw|
    parse_value suggest_dpi parse_xrandr tint2rc openbox_rc gtk_settings_ini
    update_p7_config atomic_write consumer_write restore_consumer
    |;

my $TEMP_SEQUENCE = 0;

sub read_bytes {
    my $path = shift;
    open my $fh, '<:raw', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    close $fh or return undef;
    return \$text;
}

sub atomic_write {
    my ( $path, $text, $mode ) = @ARG;
    $mode //= 0644;
    my $temp;
    my $fh;
    do {
        $temp = sprintf '%s.p7-dpi-tmp-%d-%d', $path, $PID, $TEMP_SEQUENCE++;
    } until sysopen( $fh, $temp, O_WRONLY | O_CREAT | O_EXCL, 0600 );

    my $ok = chmod( $mode, $fh );
    $ok &&= print {$fh} $text;
    $ok &&= close $fh;
    if ( not $ok or not rename $temp, $path ) {
        close $fh if defined fileno $fh;
        unlink $temp;
        return 0;
    }
    return 1;
}

sub consumer_write {
    my ( $path, $text ) = @ARG;
    my $original_path = "$path.p7-dpi-original";
    my @target_stat   = CORE::stat $path;
    my $target_mode   = @target_stat ? $target_stat[2] & 07777 : 0644;

    if ( not -e $original_path ) {
        my $original = @target_stat ? read_bytes($path) : \'';
        return 0 if @target_stat and not defined $original;
        return 0
            if not atomic_write( $original_path, $$original, $target_mode );
    }
    return atomic_write( $path, $text, $target_mode );
}

sub restore_consumer {
    my $path          = shift;
    my $original_path = "$path.p7-dpi-original";
    return 'ok' if not -f $original_path;
    my $original = read_bytes($original_path);
    return 'failed' if not defined $original;
    my @stat = CORE::stat $original_path;
    my $mode = @stat ? $stat[2] & 07777 : 0644;
    return atomic_write( $path, $$original, $mode ) ? 'changed' : 'failed';
}

sub parse_value {
    my ( $input, $current ) = @ARG;
    $current //= 96;
    return ( undef, 'current dpi is not valid' )
        if $current !~ m|^\d+$|
        or $current < 72
        or $current > 288;

    $input //= '';
    $input =~ s|^\s+||;
    $input =~ s|\s+$||;
    return ( undef, 'expected an absolute dpi or +n / -n' )
        if $input !~ m|^([+-]?)(\d+)$|;

    my $value
        = $1 eq '+' ? $current + $2
        : $1 eq '-' ? $current - $2
        :             $2 + 0;
    return ( undef, 'dpi must be between 72 and 288' )
        if $value < 72 or $value > 288;
    return $value;
}

sub suggest_dpi {
    my ( $width, $height, $width_mm, $height_mm ) = @ARG;
    return undef
        if grep { not defined or !m|^\d+(?:\.\d+)?$| or $_ <= 0 }
        ( $width, $height, $width_mm, $height_mm );

    my $pixels = sqrt( $width * $width + $height * $height );
    my $inches
        = sqrt( $width_mm * $width_mm + $height_mm * $height_mm ) / 25.4;
    my $dpi = int( $pixels / $inches / 6 + 0.5 ) * 6;
    $dpi = 72  if $dpi < 72;
    $dpi = 288 if $dpi > 288;
    return $dpi;
}

sub parse_xrandr {
    my $text = shift // '';
    my @monitors;
    foreach my $line ( split m|\n|, $text ) {
        next
            if $line
            !~ m|^(\S+)\s+connected(?:\s+primary)?\s+(\d+)x(\d+)\+\d+\+\d+.*?(\d+(?:\.\d+)?)mm\s+x\s+(\d+(?:\.\d+)?)mm|;
        push @monitors,
            {
            'name'      => $1,
            'width'     => $2 + 0,
            'height'    => $3 + 0,
            'width_mm'  => $4 + 0,
            'height_mm' => $5 + 0,
            'dpi'       => suggest_dpi( $2, $3, $4, $5 ),
            };
    }
    return \@monitors;
}

my %TINT2_BASE = map { $ARG => 1 } qw|
    taskbar_name_font task_font time1_font time2_font
    bat1_font bat2_font tooltip_font
    |;

sub tint2rc {
    my ( $text, $original, $dpi, $reference ) = @ARG;
    $reference //= 96;
    my $changed = 0;

    foreach my $key ( keys %TINT2_BASE ) {
        next if $original !~ m|^\Q$key\E\s*=\s*.*?\D(\d+(?:\.\d+)?)\s*$|m;
        my $base = $1;
        my $size = int( $base * $dpi / $reference + 0.5 );
        $text =~ s{^(\Q$key\E\s*=\s*.*?\D)(\d+(?:\.\d+)?)\s*$}{
            $changed++ if $2 != $size;
            "$1$size";
        }gme;
    }
    foreach my $key (qw| systray_icon_size launcher_icon_size |) {
        next if $original !~ m|^\Q$key\E\s*=\s*(\d+)\s*$|m;
        my $base = $1;
        my $size = int( $base * $dpi / $reference + 0.5 );
        $text =~ s{^(\Q$key\E\s*=\s*)(\d+)\s*$}{
            $changed++ if $2 != $size;
            "$1$size";
        }gme;
    }
    return ( $text, $changed );
}

sub openbox_rc {
    my ( $text, $original, $dpi, $reference ) = @ARG;
    $reference //= 96;
    my $changed = 0;
    while ( $original
        =~ m|<font\s+place="([^"]+)"[^>]*>.*?<size>(\d+(?:\.\d+)?)</size>|gs )
    {
        my ( $place, $base ) = ( $1, $2 );
        my $size = int( $base * $dpi / $reference + 0.5 );
        $text
            =~ s{(<font\s+place="\Q$place\E"[^>]*>.*?<size>)(\d+(?:\.\d+)?)(</size>)}{
            $changed++ if $2 != $size;
            "$1$size$3";
        }gse;
    }
    return ( $text, $changed );
}

sub gtk_settings_ini {
    my ( $text, $original, $dpi, $reference ) = @ARG;
    $reference //= 96;
    my $changed = 0;
    return ( $text, $changed )
        if $original !~ m|^gtk-xft-dpi\s*=\s*(\d+)\s*$|m;
    my $value = int( $1 * $dpi / $reference + 0.5 );
    $text =~ s{^(gtk-xft-dpi\s*=.*)$}{
        $changed++ if $1 ne "gtk-xft-dpi = $value";
        "gtk-xft-dpi = $value";
    }gme;
    return ( $text, $changed );
}

sub update_p7_config {
    my ( $text, $key, $value ) = @ARG;
    $text //= '';
    my $found = $text =~ m|^\Q$key\E\s*=|m;
    if ( defined $value ) {
        $text =~ s{^\Q$key\E\s*=.*$}{$key = $value}gm if $found;
        $text .= "$key = $value\n"                    if not $found;
    } elsif ($found) {
        $text =~ s{^\Q$key\E\s*=.*\n?}{}gm;
    }
    return $text;
}

package AMOS7::Desktop::DPI::RevertTimer;

use v5.32;
use strict;
use warnings;
use English;

sub new {
    my ( $class, %args ) = @ARG;
    return bless {
        'next_delay' => $args{'next_delay'},
        'schedule'   => $args{'schedule'},
        'on_revert'  => $args{'on_revert'},
        'state'      => {},
        'pending'    => 0,
    }, $class;
}

sub arm {
    my $self = shift;
    $self->cancel;
    $self->{'pending'} = 1;
    $self->{'delay'}   = $self->{'next_delay'}->( $self->{'state'} );
    $self->{'timer'}   = $self->{'schedule'}->(
        $self->{'delay'},
        sub {
            return if not $self->{'pending'};
            $self->{'pending'} = 0;
            $self->{'on_revert'}->();
        },
    );
    return $self->{'delay'};
}

sub cancel {
    my $self = shift;
    $self->{'pending'} = 0;
    return if not defined $self->{'timer'};
    if ( ref $self->{'timer'} eq 'CODE' ) {
        $self->{'timer'}->();
    } elsif ( ref $self->{'timer'} and $self->{'timer'}->can('cancel') ) {
        $self->{'timer'}->cancel;
    }
    delete $self->{'timer'};
}

sub pending { return $_[0]->{'pending'} }

1;

#,,,,,,..,.,.,,..,,..,.,,,,,.,..,,..,,.,,,..,,..,,...,...,..,,.,,,,,,,.,,,,.,,
#JUT2KZXHPNAV6ZR7XA7PM5TGEVZCP7WMMH5ABWA7FLPZLR63YHJSHPWUTXAXLEC7W5VUIRZAYTTVW
#\\\|U6T4IYRQQ6DLZN4MMDOLLH6C2VEB5Z65X3PJ633NARY7RFYNSGE \ / AMOS7 \ YOURUM ::
#\[7]V64WBXAAU2ESKKVK5E2QTPXMXSNTNHEODDSG3RYMUCMAQ2YWB6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
