package AMOS7::deps::hostpower;
our $VERSION = qw| AMOS7::deps::hostpower-VERSION.LX9PMKJ |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

use File::Spec;
use File::Path qw| make_path |;

our @EXPORT_OK = qw| parse_wakeup select_wakeup_devices unit_content run |;

##[ host power management ]###################################################
##
## the azurum lessons, machine-readable
## [ runbook :  read-me/md/docs/backlog/host-power-management.md ] :
##
## 1. mask the systemd sleep targets -- the hard backstop ; no request from
## any DE or logind config can suspend the host afterwards
## 2. a guard-based oneshot service disables every ACPI wakeup device except
## the RTC [ platform:ACPI000E / AWAC ] -- /proc/acpi/wakeup writes TOGGLE, so
## the unit only writes a device that reads *enabled
## 3. GNOME idle suspend [ gsd-power -> logind ] set to 'nothing' per
## logged-in session user -- the only user-session-dependent part ; a warn,
## not a failure, when no session bus is reachable
##
## systemctl is always called list-form. P7_DEPS_SERVICE_ROOT prefixes the
## unit paths [ test roots ] and skips the systemctl steps

my @SLEEP_TARGETS = qw|
    sleep.target
    suspend.target
    hibernate.target
    hybrid-sleep.target
    |;

##[ pure helpers -- the tested part ]#########################################

## /proc/acpi/wakeup text in, device list out :
## [ { name, state, enabled, sysfs }, .. ]
sub parse_wakeup {
    my ($text) = @_;
    return [] unless defined $text and length $text;

    my @devices;
    foreach my $line ( split m{\n}, $text ) {
        next unless $line =~ m{\S};
        my ( $name, $state, $status, $sysfs ) = split m{\s+}, $line, 4;
        next unless defined $name and defined $status;
        next unless $status =~ m{\A\*?(enabled|disabled)\z};
        push @devices,
            {
            'name'    => $name,
            'state'   => $state,
            'enabled' => $1 eq qw| enabled | ? 1 : 0,
            'sysfs'   => $sysfs // '',
            };
    }
    return \@devices;
}

## the devices a wakeup-disable run should switch off : everything enabled
## except the RTC -- ACPI000E covers AWAC and similar clock devices
sub select_wakeup_devices {
    my ($devices) = @_;
    $devices = [] unless ref $devices eq qw| ARRAY |;

    return [
        map { $ARG->{'name'} }
        grep {
                    $ARG->{'enabled'}
                and $ARG->{'sysfs'} !~ m{platform:ACPI000E}
                and $ARG->{'name'} ne qw| AWAC |
        } @{$devices}
    ];
}

## the oneshot unit content for a device list [ '; true' keeps the unit    ##
## from reporting failure when its last device was already disabled -- the ##
## grep -q then exits 1 and a bare loop would inherit that ]               ##
sub unit_content {
    my ($devices) = @_;
    $devices = [] unless ref $devices eq qw| ARRAY |;

    my $list = join ' ', @{$devices};
    return <<"EOL";
[Unit]
Description=Protocol-7 host power : disable ACPI wakeup devices
Documentation=file:///usr/local/protocol-7/read-me/md/docs/backlog/host-power-management.md
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for d in $list; do grep -q "^\$d.*enabled" /proc/acpi/wakeup && echo \$d > /proc/acpi/wakeup; done; true'

[Install]
WantedBy=multi-user.target
EOL
}

##[ run ]#####################################################################

## returns { rows => [ [ part, status, detail, level ], .. ], ok => 1|0 } --
## rows feed the same report printer the service commands use
sub run {
    my $opts = shift // {};
    $opts = {} if ref $opts ne qw| HASH |;

    my $prefix   = $opts->{'prefix'} // $ENV{'P7_DEPS_SERVICE_ROOT'} // '';
    my $wakeup_f = $opts->{'wakeup_file'} // qw| /proc/acpi/wakeup |;

    my @rows;
    my $ok = 1;

    ##[ 1 : sleep targets ]##

    my $test_root = length $prefix;
    if ($test_root) {
        push @rows,
            [
            'sleep targets',                     'skipped',
            "test root $prefix -- no systemctl", 'warn'
            ];
    } else {
        my $masked
            = _read_field( qw| systemctl is-enabled |, @SLEEP_TARGETS );
        my @to_mask = grep { not _is_masked( $ARG, $masked ) } @SLEEP_TARGETS;
        if (@to_mask) {
            my ( $exit, undef ) = _run( qw| systemctl mask |, @to_mask );
            if ( $exit == 0 ) {
                push @rows, [ 'sleep targets', 'masked', join ' ', @to_mask ];
            } else {
                push @rows,
                    [
                    'sleep targets',
                    'failed',
                    "systemctl " . "mask exit $exit"
                    ];
                $ok = 0;
            }
        } else {
            push @rows,
                [ 'sleep targets', 'masked', 'already in place', 'ok' ];
        }
    }

    ##[ 2 : wakeup service ]##

    my $devices    = parse_wakeup( _slurp($wakeup_f) );
    my $to_disable = select_wakeup_devices($devices);
    my $unit_name  = qw| p7-wakeup-disable.service |;
    my $unit_dir  = File::Spec->catdir( $prefix, 'etc', 'systemd', 'system' );
    my $unit_path = File::Spec->catfile( $unit_dir, $unit_name );
    make_path($unit_dir) if not -d $unit_dir;
    my $wants_dir = File::Spec->catdir( $prefix, 'etc', 'systemd', 'system',
        'multi-user.target.wants' );
    my $wants_link = File::Spec->catfile( $wants_dir, $unit_name );
    my $content    = unit_content($to_disable);

    my $report = _write_if_differing( $unit_path, $content );
    push @rows, [ 'wakeup unit', $report->{'status'}, $unit_name ];
    if ( $report->{'status'} eq qw| failed | ) {
        $ok = 0;
    } else {
        make_path($wants_dir) if not -d $wants_dir;
        my $link_report = _symlink_if_absent( $wants_link,
            File::Spec->rel2abs($unit_path) );
        push @rows,
            [
            'wakeup enable', $link_report->{'status'},
            $link_report->{'detail'}
            ];
    }

    if ($test_root) {
        push @rows,
            [
            'wakeup devices',
            @{$to_disable} ? 'would disable' : 'none enabled',
            join( ' ', @{$to_disable} ), 'ok'
            ];
    } else {
        _run(qw| systemctl daemon-reload |)
            if $report->{'status'} eq qw| changed |;
        ## apply the toggles now, then read back what is left enabled ##
        _run( qw| systemctl start |, $unit_name );
        my $left = select_wakeup_devices( parse_wakeup( _slurp($wakeup_f) ) );
        push @rows,
            @{$left}
            ? [
            'wakeup devices',
            'still enabled',
            join( ' ', @{$left} ),
            'warn'
            ]
            : [
            'wakeup devices',            'disabled',
            join( ' ', @{$to_disable} ), 'ok'
            ];
    }

    ##[ 3 : GNOME idle suspend -- per logged-in session user ]##

    push @rows, _gnome_rows();

    return { 'rows' => \@rows, 'ok' => $ok };
}

##[ internals ]###############################################################

## systemctl is-enabled prints one state line per unit
sub _is_masked {
    my ( $unit, $state_by_unit ) = @_;
    my $state = $state_by_unit->{$unit} // '';
    return $state eq qw| masked | ? 1 : 0;
}

sub _read_field {
    my (@cmd) = @_;
    my ( $exit, $out ) = _run(@cmd);
    my %state;
    my @units = @cmd[ 2 .. $#cmd ];
    my @lines = split m{\n}, $out // '';
    foreach my $i ( 0 .. $#units ) {
        $state{ $units[$i] } = $lines[$i] // '';
    }
    return \%state;
}

## list-form ; ( exit code, stdout chomped ), stderr discarded
sub _run {
    my (@cmd) = @_;
    my $pid = open( my $pipe, '-|' ) // return ( 127, undef );
    if ( $pid == 0 ) {
        open( STDERR, '>', File::Spec->devnull );
        exec { $cmd[0] } @cmd or exit 127;
    }
    my $out = do { local $INPUT_RECORD_SEPARATOR = undef; <$pipe> }
        // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $out );
}

sub _slurp {
    my ($path) = @_;
    open( my $fh, '<', $path ) or return '';
    my $text = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> }
        // '';
    close($fh);
    return $text;
}

## write content when missing or differing ; report status ok | changed |
## failed. a differing REGULAR file at the path is left alone and reported
sub _write_if_differing {
    my ( $path, $content ) = @_;

    if ( -e $path ) {
        my $existing = _slurp($path);
        return { 'status' => qw| ok | } if $existing eq $content;
        return { 'status' => qw| failed |, 'detail' => 'exists, differs' }
            if not -l $path and -f _;    ##  leave a regular file alone  ##
    }
    if ( open( my $fh, '>', $path ) ) {
        print {$fh} $content;
        close($fh);
        return { 'status' => qw| changed | };
    }
    return { 'status' => qw| failed |, 'detail' => "$OS_ERROR" };
}

sub _symlink_if_absent {
    my ( $link, $target ) = @_;
    return { 'status' => qw| ok |, 'detail' => 'already linked' }
        if -l $link and readlink($link) eq $target;
    if ( symlink $target, $link ) {
        return { 'status' => qw| set |, 'detail' => 'multi-user target' };
    }
    return { 'status' => qw| failed |, 'detail' => "$OS_ERROR" };
}

## one row per session user : idle suspend set to nothing, or already ok ; a
## single warn row when no user session bus exists to talk to
sub _gnome_rows {
    my $schema = 'org.gnome.settings-daemon.plugins.power';
    my @rows;

    my ( $exit, undef ) = _run(qw| which gsettings |);
    if ( $exit != 0 ) {
        return [
            'gnome idle suspend',
            'skipped',
            'gsettings not installed -- no GNOME'
        ];
    }

    my @buses = grep {m{\A/run/user/\d+/bus\z}} glob qw| /run/user/*/bus |;
    return [
        'gnome idle suspend',
        'no session bus',
        "run as the desktop user : gsettings set "
            . "$schema sleep-inactive-ac-type 'nothing'",
        'warn'
        ]
        unless @buses;

    foreach my $bus (@buses) {
        my ($uid) = $bus =~ m{\A/run/user/(\d+)/bus\z};
        next if $uid < 1000;
        my $user       = getpwuid($uid) // next;
        my @env_prefix = (
            'env',
            "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus",
            "XDG_RUNTIME_DIR=/run/user/$uid"
        );
        my ( $g_exit, $current )
            = _run( 'runuser', '-u', $user, '--', @env_prefix,
            'gsettings', 'get', $schema, 'sleep-inactive-ac-type' );
        if ( $g_exit != 0 ) {
            push @rows,
                [ "user $user", 'unreachable', 'gsettings failed', 'warn' ];
            next;
        }
        if ( $current =~ m{'nothing'} ) {
            push @rows,
                [ "user $user", 'ok', 'sleep-inactive already nothing' ];
            next;
        }
        my $set_exit = 0;
        foreach
            my $key (qw| sleep-inactive-ac-type sleep-inactive-battery-type |)
        {
            my ( $s_exit, undef ) = _run(
                'runuser',   '-u',        $user, '--',
                @env_prefix, 'gsettings', 'set', $schema,
                $key,        'nothing'
            );
            $set_exit ||= $s_exit;
        }
        push @rows,
            $set_exit == 0
            ? [ "user $user", 'set', 'idle suspend -> nothing' ]
            : [ "user $user", 'failed', 'gsettings set failed', 'warn' ];
    }
    @rows = [
        'gnome idle suspend',
        'no desktop session',
        'set it when a user logs in',
        'warn'
        ]
        unless @rows;
    return @rows;
}

1;

#,,,.,.,.,..,,,..,.,.,..,,...,,.,,...,,,.,.,,,.,.,...,...,,..,,.,,,,.,,,,,..,,
#4CF7DTSIM4ZNA3FWSGLJZVEVQE7M7WE2Z5PJWJLLNH73KYKRCCDBKEAKO2SLSRZU7CPWW5RAWP6EW
#\\\|UG2F3QNWQJ2Z47BKDXYPPDFPR342TXARKFIJO24GXPM24FU4ZNX \ / AMOS7 \ YOURUM ::
#\[7]GL2RVS33MYXGCDTN4CB4IF43URM2JVBXIOGHH3EE7NIP2445FODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
