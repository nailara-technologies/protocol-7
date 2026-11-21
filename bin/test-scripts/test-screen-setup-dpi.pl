#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;

use Test::More;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use FindBin    qw| $RealBin |;

use lib "$RealBin/../../data/lib-path/pm";
use AMOS7::Desktop::DPI qw|
    parse_value suggest_dpi parse_xrandr tint2rc openbox_rc
    |;
use AMOS7::Config::Reader;

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

is scalar parse_value( 120,  96 ),  120, 'absolute dpi';
is scalar parse_value( '+6', 120 ), 126, 'positive relative dpi';
is scalar parse_value( '-6', 120 ), 114, 'negative relative dpi';
is scalar parse_value( 72,   96 ),  72,  'lower bound accepted';
is scalar parse_value( 288,  96 ),  288, 'upper bound accepted';
is scalar parse_value( 71,   96 ), 'dpi must be between 72 and 288',
    'below bound rejected';
is scalar parse_value( '+200', 120 ), 'dpi must be between 72 and 288',
    'relative overflow rejected';
is scalar parse_value( '-29', 96 ), 'dpi must be between 72 and 288',
    'relative underflow rejected';
is scalar parse_value( '1.5', 96 ), 'expected an absolute dpi or +n / -n',
    'fraction rejected';

is suggest_dpi( 1920, 1080, 510, 290 ), 96,    'suggestion rounds to six dpi';
is suggest_dpi( 3840, 2160, 510, 290 ), 192,   'high resolution suggestion';
is suggest_dpi( 1920, 1080, 0,   290 ), undef, 'zero physical size rejected';

my $xrandr = <<'XRANDR';
Screen 0: minimum 8 x 8, current 1920 x 1080
OUTPUT connected primary 1920x1080+0+0 (0x45) normal 510mm x 290mm
OTHER disconnected
XRANDR
my $monitors = parse_xrandr($xrandr);
is scalar @$monitors,     1,  'one connected physical monitor parsed';
is $monitors->[0]{'dpi'}, 96, 'xrandr dimensions produce suggestion';

my $timer_cb;
my $delay;
my $reverts = 0;
my $timer   = AMOS7::Desktop::DPI::RevertTimer->new(
    'next_delay' => sub { return 13 },
    'schedule'   => sub {
        ( $delay, $timer_cb ) = @ARG;
        return sub { $timer_cb = undef };
    },
    'on_revert' => sub { $reverts++ },
);
is $timer->arm, 13, 'revert timer uses supplied interval delay';
ok $timer->pending, 'revert timer armed';
$timer_cb->();
is $reverts, 1, 'stubbed timer reverts once';
ok( !$timer->pending, 'timer no longer pending after revert' );
$timer->arm;
$timer->cancel;
$timer_cb->() if defined $timer_cb;
is $reverts, 1, 'cancel prevents stale timer revert';

my $tmp = tempdir( CLEANUP => 1 );
make_path "$tmp/cfg", "$tmp/etc/host-config";
open my $shared_fh, '>', "$tmp/cfg/desktop" or die $OS_ERROR;
print {$shared_fh} "desktop.dpi = 96\n";
close $shared_fh;
open my $host_fh, '>', "$tmp/etc/host-conf" . "ig/screen-setup.cfg"
    or die $OS_ERROR;
print {$host_fh} "desktop.dpi = 144\n";
close $host_fh;
my $layered = AMOS7::Config::Reader->read( 'desktop',
    { 'root' => $tmp, 'zenka' => 'screen-setup', 'etc_dir' => "$tmp/etc" } );
is $layered->get('desktop.dpi'), 144, 'host settings layer wins';

our %data;
our %code;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
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

$code{'file.which'}            = sub { return '/stubbed-consumer' };
$code{'screen.setup.dpi.exec'} = sub {
    die 'external consumer executed during dry-run';
};
$code{'base.get_homedir'} = sub { return $tmp };
$code{'file.make_path'}   = sub { make_path(shift); return TRUE };
$code{'file.slurp'}       = sub {
    my $path = shift;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    close $fh;
    return \$text;
};
$code{'file.put'} = sub {
    my ( $path, $text ) = @ARG;
    open my $fh, '>', $path or return undef;
    print {$fh} $text;
    close $fh;
    return TRUE;
};
$code{'base.logs'} = sub { return TRUE };

make_path "$tmp/.config/tint2", "$tmp/.config/gtk-3.0";
my $tint_path     = "$tmp/.config/tint2/tint2rc";
my $tint_original = <<'TINT2';
task_font = White Rabbit 15
time1_font = White Rabbit 13
time2_font = White Rabbit 12
custom_font = sans 99
systray_icon_size = 30
launcher_icon_size = 24
TINT2
open my $tint_fh, '>', $tint_path or die $OS_ERROR;
print {$tint_fh} $tint_original;
close $tint_fh;
chmod 0640, $tint_path or die $OS_ERROR;
my $openbox_path     = "$tmp/openbox.xml";
my $openbox_original = <<'OPENBOX';
<theme><font place="ActiveWindow"><size>10</size></font>
<font place="MenuItem"><size>14</size></font></theme>
OPENBOX
open my $openbox_fh, '>', $openbox_path or die $OS_ERROR;
print {$openbox_fh} $openbox_original;
close $openbox_fh;
my $gtk_path = "$tmp/.config/gtk-3.0/settings.ini";
my $gtk_original
    = "[Settings]\ngtk-xft-dpi = 98304\ngtk-theme-name = tuned\n";
open my $gtk_fh, '>', $gtk_path or die $OS_ERROR;
print {$gtk_fh} $gtk_original;
close $gtk_fh;

$data{'x11'}{'display'}      = ':stub';
$data{'system'}{'conf_path'} = "$tmp/cfg";
load_src('screen.setup.dpi.apply');
load_src('screen.setup.dpi.report');
my $consumer_settings = {
    'tint2rc'      => $tint_path,
    'openbox_rc'   => $openbox_path,
    'gtk_settings' => $gtk_path,
};
my $dry = $code{'screen.setup.dpi.apply'}->(
    { 'value' => 120, 'dry_run' => TRUE, 'settings' => $consumer_settings } );
is_deeply $dry->{'results'},
    { map { $ARG => 'changed' } qw| xrdb gtk tint2 openbox | },
    'dry-run reports every consumer changed';
my $report = $code{'screen.setup.dpi.report'}->($dry);
like $report, qr|desktop\.dpi = 120 \[dry-run\]|, 'dry-run report value';
like $report, qr|tint2 : changed|, 'dry-run report consumer status';
is ${ $code{'file.slurp'}->($tint_path) }, $tint_original,
    'dry-run leaves tint2rc unchanged';
is ${ $code{'file.slurp'}->($openbox_path) }, $openbox_original,
    'dry-run leaves openbox rc unchanged';
ok( !-e "$tint_path.p7-dpi-original",    'dry-run writes no tint2 backup' );
ok( !-e "$openbox_path.p7-dpi-original", 'dry-run writes no openbox backup' );
ok( !-e "$gtk_path.p7-dpi-original",     'dry-run writes no gtk backup' );

$code{'file.which'} = sub { return undef };
my $missing = $code{'screen.setup.dpi.apply'}->(
    { 'value' => 120, 'dry_run' => TRUE, 'settings' => $consumer_settings } );
is_deeply $missing->{'results'},
    {
    'xrdb'    => 'not-installed',
    'gtk'     => 'changed',
    'tint2'   => 'not-installed',
    'openbox' => 'not-installed',
    },
    'dry-run reports missing consumers without running them';

my ($tint_new) = tint2rc( $tint_original, $tint_original, 120, 96 );
like $tint_new, qr|task_font = White Rabbit 19|,
    'tint2 uses original font size';
my ($tint_reference) = tint2rc( $tint_original, $tint_original, 144, 120 );
like $tint_reference, qr|task_font = White Rabbit 18|,
    'configured dpi reference controls scaling';
like $tint_new, qr|systray_icon_size = 38|, 'tint2 uses original icon size';
like $tint_new, qr|custom_font = sans 99|,
    'unlisted tint2 keys stay untouched';
my $tint_with_extra = $tint_original . "tooltip_font = sans 77\n";
my ($tint_missing) = tint2rc( $tint_with_extra, $tint_original, 120, 96 );
like $tint_missing, qr|tooltip_font = sans 77|,
    'key missing from tint2 original stays untouched';
my $openbox_partial = $openbox_original;
$openbox_partial =~ s|<font place="MenuItem".*?</font>||s;
my ($openbox_new)
    = openbox_rc( $openbox_original, $openbox_partial, 120, 96 );
like $openbox_new, qr|ActiveWindow"><size>13|,
    'openbox uses original title size';
like $openbox_new, qr|MenuItem"><size>14|,
    'font entry missing from openbox original stays untouched';

$code{'file.which'}            = sub { return '/stubbed-consumer' };
$code{'screen.setup.dpi.exec'} = sub {
    my $args = shift;
    $args->{'cb'}->( TRUE, '' );
    return TRUE;
};
$code{'screen.setup.dpi.apply'}
    ->( { 'value' => 120, 'settings' => $consumer_settings } );
for my $path ( $tint_path, $openbox_path, $gtk_path ) {
    ok -f "$path.p7-dpi-original", 'first change creates original copy';
}
is ${ $code{'file.slurp'}->("$tint_path.p7-dpi-original") }, $tint_original,
    'tint2 original bytes saved';
is ${ $code{'file.slurp'}->("$openbox_path.p7-dpi-original") },
    $openbox_original,
    'openbox original bytes saved';
is ${ $code{'file.slurp'}->("$gtk_path.p7-dpi-original") }, $gtk_original,
    'gtk original bytes saved';
is ${ $code{'file.slurp'}->($tint_path) }, $tint_new,
    'first tint2 change uses original values';
like ${ $code{'file.slurp'}->($openbox_path) }, qr|MenuItem"><size>18|,
    'openbox entry scales from its original value';
like ${ $code{'file.slurp'}->($gtk_path) }, qr|gtk-xft-dpi = 122880|,
    'gtk value scales from original';
like ${ $code{'file.slurp'}->($gtk_path) }, qr|gtk-theme-name = tuned|,
    'other gtk settings stay untouched';
is( ( stat $tint_path )[2] & 07777, 0640, 'atomic write keeps file mode' );

$code{'screen.setup.dpi.apply'}
    ->( { 'value' => 144, 'settings' => $consumer_settings } );
like ${ $code{'file.slurp'}->($tint_path) }, qr|task_font = White Rabbit 23|,
    'second change scales from original rather than prior result';
is ${ $code{'file.slurp'}->("$tint_path.p7-dpi-original") }, $tint_original,
    'second change does not overwrite tint2 original';
is ${ $code{'file.slurp'}->("$openbox_path.p7-dpi-original") },
    $openbox_original,
    'second change does not overwrite openbox original';
is ${ $code{'file.slurp'}->("$gtk_path.p7-dpi-original") }, $gtk_original,
    'second change does not overwrite gtk original';

my $cleared;
$code{'screen.setup.dpi.persist'} = sub {
    my $value = shift;
    $cleared = not defined $value;
    return TRUE;
};
load_src('screen.setup.dpi.restore-original');
$code{'screen.setup.dpi.restore-original'}
    ->( { 'settings' => $consumer_settings } );
is ${ $code{'file.slurp'}->($tint_path) }, $tint_original,
    'restore returns exact tint2 bytes';
is ${ $code{'file.slurp'}->($openbox_path) }, $openbox_original,
    'restore returns exact openbox bytes';
is ${ $code{'file.slurp'}->($gtk_path) }, $gtk_original,
    'restore returns exact gtk bytes';
ok $cleared,                        'restore clears host dpi override';
ok -f "$tint_path.p7-dpi-original", 'restore keeps original copy';

done_testing;

#,,,,,...,...,,..,..,,,,.,.,.,,..,...,,.,,,..,..,,...,...,...,,,.,..,,,.,,,..,
#EWPJWCOHTOHTQYUUNDW7ZDCJO2MWWLMOJBXLJFTFBKKTGUKQ5VBWNSLMLJTD4XBGD4GSJ3SZASSXC
#\\\|OCP47DZC5FXIJ4GB7W3VEMPJLL2QVDTPI7LGDKLAOXUI7SSRPNR \ / AMOS7 \ YOURUM ::
#\[7]PP37K32GB3GFE73GKWY3EREA56AUE4XBBCOFA5BXXHLQU73X66CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
