package AMOS7::deps::hostpower;
our $VERSION = qw| AMOS7::deps::hostpower-VERSION.LX9PMKJ |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

use File::Spec;
use File::Path qw| make_path |;

our @EXPORT_OK = qw| parse_wakeup select_wakeup_devices unit_content
    wol_link_content run |;

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
## except the RTC -- ACPI000E covers AWAC and similar clock devices the
## devices a wakeup-disable run should switch off. default : currently enabled
## ones [ the live read-back ]. with $include_disabled : every non-RTC device
## in the table -- the boot-time unit must cover devices the firmware
## re-enables after every reboot, not only the ones enabled right now
## [ its grep guard skips the already-disabled ones ]
sub select_wakeup_devices {
    my $devices          = shift;
    my $include_disabled = shift // 0;
    $devices = [] unless ref $devices eq qw| ARRAY |;

    return [
        map { $ARG->{'name'} }
        grep {
                    ( $ARG->{'enabled'} or $include_disabled )
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

## modes :  awake ......... server duty : the host never suspends -- sleep
## targets masked [ hard backstop ], every non-RTC ACPI wake  source guarded
## off at boot  suspending .... zenka \ user suspend duty : manual suspend
## stays available [ no masking ], firmware wake defaults kept
## [ keyboard, nic port ], WakeOnLan made persistent  through systemd .link
## files -- so a host the v7-zenka  [ host poweroff \ reboot \ suspend ] puts
## down comes  back on magic packet or keyboard
##
## returns { rows => [ [ part, status, detail, level ], .. ], ok => 1|0 } --
## rows feed the same report printer the service commands use
sub run {
    my $opts = shift // {};
    $opts = {} if ref $opts ne qw| HASH |;

    my $mode = $opts->{'mode'} // qw| awake |;
    $mode = ( $mode eq qw| suspending | ) ? $mode : qw| awake |;

    my $prefix   = $opts->{'prefix'} // $ENV{'P7_DEPS_SERVICE_ROOT'} // '';
    my $wakeup_f = $opts->{'wakeup_file'} // qw| /proc/acpi/wakeup |;
    my $net_dir  = $opts->{'net_dir'}     // qw| /sys/class/net |;

    my @rows;
    my $ok = 1;

    my $test_root = length $prefix;

    if ( $mode eq qw| suspending | ) {
        ## targets stay reachable -- the zenka's suspend command must work ##
        push @rows,
            [
            'sleep targets',
            'left alone', 'manual suspend stays available', 'value'
            ];
        my $wol_failed = _wol_step( $prefix, $net_dir, $test_root, \@rows );
        $ok = 0 if $wol_failed;
        _remove_wakeup_unit( $prefix, $test_root, \@rows );
    } else {
        $ok = 0 if _mask_step( $prefix, $test_root, \@rows );
        $ok = 0
            if _wakeup_unit_step( $prefix, $wakeup_f, $test_root, \@rows );
        _remove_wol_links( $prefix, $test_root, \@rows );
    }

    ## GNOME idle suspend -- per logged-in session user : both modes want ##
    ## the desktop to never suspend on its own [ warn, not failure ]      ##

    push @rows, _gnome_rows();

    return { 'rows' => \@rows, 'ok' => $ok };
}

##[ mode steps ]##############################################################

## mask the sleep targets ; returns 1 on failure
sub _mask_step {
    my ( $prefix, $test_root, $rows ) = @_;

    if ($test_root) {
        push @{$rows},
            [
            'sleep targets',                     'skipped',
            "test root $prefix -- no systemctl", 'warn'
            ];
        return 0;
    }
    my $masked  = _read_field( qw| systemctl is-enabled |, @SLEEP_TARGETS );
    my @to_mask = grep { not _is_masked( $ARG, $masked ) } @SLEEP_TARGETS;
    return 0 unless @to_mask;

    my ( $exit, undef ) = _run( qw| systemctl mask |, @to_mask );
    if ( $exit == 0 ) {
        push @{$rows}, [ 'sleep targets', 'masked', join ' ', @to_mask ];
        return 0;
    }
    push @{$rows},
        [ 'sleep targets', 'failed', "systemctl " . "mask exit $exit" ];
    return 1;
}

## install \ refresh the guard unit ; returns 1 on failure
sub _wakeup_unit_step {
    my ( $prefix, $wakeup_f, $test_root, $rows ) = @_;

    my $devices = parse_wakeup( _slurp($wakeup_f) );
    ## the unit guards every non-RTC device : the firmware re-enables them
    ## after each reboot, so the boot-time list cannot come from the currently
    ## enabled set alone [ read-back below stays  enabled-only ]
    my $unit_list = select_wakeup_devices( $devices, 1 );
    my $unit_name = qw| p7-wakeup-disable.service |;
    my $unit_dir  = File::Spec->catdir( $prefix, 'etc', 'systemd', 'system' );
    my $unit_path = File::Spec->catfile( $unit_dir, $unit_name );
    make_path($unit_dir) if not -d $unit_dir;
    my $wants_dir = File::Spec->catdir( $prefix, 'etc', 'systemd', 'system',
        'multi-user.target.wants' );
    my $wants_link = File::Spec->catfile( $wants_dir, $unit_name );
    my $content    = unit_content($unit_list);

    my $report = _write_if_differing( $unit_path, $content );
    push @{$rows}, [ 'wakeup unit', $report->{'status'}, $unit_name ];
    if ( $report->{'status'} eq qw| failed | ) {
        return 1;
    }
    make_path($wants_dir) if not -d $wants_dir;
    my $link_report
        = _symlink_if_absent( $wants_link, File::Spec->rel2abs($unit_path) );
    push @{$rows},
        [
        'wakeup enable', $link_report->{'status'},
        $link_report->{'detail'}
        ];

    if ($test_root) {
        push @{$rows},
            [
            'wakeup devices',
            @{$unit_list} ? 'unit guards' : 'none to guard',
            join( ' ', @{$unit_list} ), 'ok'
            ];
        return 0;
    }
    _run(qw| systemctl daemon-reload |)
        if $report->{'status'} eq qw| changed |;
    ## apply the toggles now, then read back what is left enabled ##
    _run( qw| systemctl start |, $unit_name );
    my $left = select_wakeup_devices( parse_wakeup( _slurp($wakeup_f) ) );
    push @{$rows},
        @{$left}
        ? [ 'wakeup devices', 'still enabled', join( ' ', @{$left} ), 'warn' ]
        : [ 'wakeup devices', 'disabled', join( ' ', @{$unit_list} ), 'ok' ];
    return 0;
}

## suspending mode : persistent WakeOnLan=magic for every wired NIC -- .link
## files [ read by udev at device appearance ], plus an immediate best-effort
## ethtool for the running system. returns 1 on failure
sub _wol_step {
    my ( $prefix, $net_dir, $test_root, $rows ) = @_;

    my $nics = _wired_nics($net_dir);
    if ( not @{$nics} ) {
        push @{$rows}, [ 'wake on lan', 'no wired nic found', undef, 'warn' ];
        return 0;
    }
    my $link_dir = File::Spec->catdir( $prefix, 'etc', 'systemd', 'network' );
    make_path($link_dir) if not -d $link_dir;

    my $failed = 0;
    my @named;
    foreach my $nic ( @{$nics} ) {
        my $file
            = File::Spec->catfile( $link_dir, sprintf '50-p7-wol-%s.link',
            $nic->{'iface'} );
        my $report
            = _write_if_differing( $file, wol_link_content( $nic->{'mac'} ) );
        if ( $report->{'status'} eq qw| failed | ) {
            $failed = 1;
            push @{$rows},
                [
                "wol $nic->{'iface'}",
                'failed',
                $report->{'detail'} // 'write failed'
                ];
        } else {
            push @named, $nic->{'iface'};
        }
        next if $test_root;
        ## the running system gets it immediately, best effort ##
        my ( $exit, undef )
            = _run( 'ethtool', '-s', $nic->{'iface'}, 'wol', 'g' );
        push @{$rows},
            [
            "wol $nic->{'iface'}",
            'set', 'magic packet', $exit == 0 ? qw| ok | : qw| warn |
            ]
            if $exit != 0;
    }
    push @{$rows}, [ 'wake on lan', 'persistent', join( ' ', @named ), 'ok' ];
    return $failed;
}

## suspending mode : our guard unit would switch wake sources off the host
## needs [ keyboard, nic port ] -- remove it when present
sub _remove_wakeup_unit {
    my ( $prefix, $test_root, $rows ) = @_;

    my $unit_path = File::Spec->catfile( $prefix, 'etc', 'systemd', 'system',
        'p7-wakeup-disable.service' );
    my $wants_link = File::Spec->catfile( $prefix, 'etc', 'systemd',
        'system', 'multi-user.target.wants', 'p7-wakeup-disable.service' );
    if ( not -e $unit_path and not -l $wants_link ) {
        push @{$rows},
            [
            'wakeup unit',                     'not managed',
            'firmware defaults wake the host', 'ok'
            ];
        return;
    }
    unlink $wants_link if -l $wants_link;
    my $removed = unlink $unit_path;
    _run(qw| systemctl daemon-reload |) if $removed and not $test_root;
    push @{$rows},
        [
        'wakeup unit',
        $removed ? 'removed' : 'failed',
        'firmware defaults wake the host [ keyboard, nic ]',
        $removed ? qw| ok | : ()
        ];
    return;
}

## awake mode : drop .link files a previous suspending run left behind
sub _remove_wol_links {
    my ( $prefix, $test_root, $rows ) = @_;

    my $link_dir = File::Spec->catdir( $prefix, 'etc', 'systemd', 'network' );
    my @links    = glob File::Spec->catfile( $link_dir, '50-p7-wol-*.link' );
    return unless @links;
    my $removed = grep {unlink} @links;
    _run(qw| udevadm control --reload |) if $removed and not $test_root;
    push @{$rows},
        [ 'wake on lan', 'removed', "$removed p7 link file(s)", 'ok' ];
    return;
}

##[ wol helpers ]#############################################################

## the systemd .link content : match the nic by mac, wake on magic packet
sub wol_link_content {
    my ($mac) = @_;
    $mac //= '';
    return <<"EOL";
[Match]
MACAddress=$mac

[Link]
WakeOnLan=magic
EOL
}

## every wired nic under a /sys/class/net-style directory : the iface dir
## holds an address file AND a device symlink
## [ virtual ifaces -- lo, bridges, veth -- have none ] ; wireless
## [ phy80211 \ wireless ] and the zero mac are skipped
sub _wired_nics {
    my ($net_dir) = @_;

    my @nics;
    opendir( my $dh, $net_dir ) or return \@nics;
    foreach my $iface ( readdir($dh) ) {
        next if $iface =~ m{^\.};
        my $idir = File::Spec->catdir( $net_dir, $iface );
        next
            unless -l File::Spec->catfile( $idir, 'device' )
            or -e File::Spec->catfile( $idir, 'device' );
        next if -d File::Spec->catdir( $idir, 'phy80211' );
        next if -d File::Spec->catdir( $idir, 'wireless' );
        my $mac = _slurp( File::Spec->catfile( $idir, 'address' ) );
        $mac =~ s{\s+}{}g;
        next unless $mac =~ m|\A[0-9a-f]{2}(:[0-9a-f]{2}){5}\z|;
        next if $mac eq qw| 00:00:00:00:00:00 |;
        push @nics, { 'iface' => $iface, 'mac' => $mac };
    }
    closedir($dh);
    return \@nics;
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
## failed. a differing file carrying our own unit marker [ an older run ] is
## rewritten -- the upgrade path ; a FOREIGN regular file at the path is left
## alone and reported
sub _write_if_differing {
    my ( $path, $content ) = @_;

    if ( -e $path ) {
        my $existing = _slurp($path);
        return { 'status' => qw| ok | } if $existing eq $content;
        my $own = index( $existing, 'Protocol-7 host power' ) >= 0;
        return { 'status' => qw| failed |, 'detail' => 'exists, differs' }
            if not $own
            and not -l $path
            and -f _;
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

#,,,.,,.,,...,,,.,,,,,,,,,..,,,.,,,.,,...,,.,,.,.,...,...,.,.,,..,...,,.,,,.,,
#EBZN7FNJOZKVWANLJXIDUNEQBCBA4KMADDUFJIZMM4XAXHBAU5J3PV72NX3AMTLOG3R5PQCURU6LG
#\\\|K4RDAHUKFAXMBCF53EWXWOB2XHOIAMYLRKSAMKXXRCHJQ7C5O7V \ / AMOS7 \ YOURUM ::
#\[7]YCM6BHXECS2NATMYMEPOUZFBDK5SPGHH2L3OBIZ2EDRCIK4OTEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
