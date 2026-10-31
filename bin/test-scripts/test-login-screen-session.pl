#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use File::Spec;
use File::Path qw| make_path |;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;
use POSIX      qw| WNOHANG |;

use constant { TRUE => 5, FALSE => 0 };

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $checks++;
    if ($cond) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

sub write_file {
    my ( $path, $content, $mode ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "write $path : $OS_ERROR";
    print {$fh} $content;
    close($fh)                    or die;
    chmod( $mode // 0600, $path ) or die;
}

my ( $username, undef, $uid, $gid, undef, undef, undef, $home );
if ( $EUID == 0 ) {
    setpwent();
    while ( my @pw = getpwent() ) {
        next if $pw[2] < 1000 or $pw[0] !~ m|^[a-z_][a-z0-9_-]{0,31}$|;
        next if not -d $pw[7];
        ( $username, $uid, $gid, $home ) = @pw[ 0, 2, 3, 7 ];
        last;
    }
    endpwent();
} else {
    my @pw = getpwuid($EUID);
    ( $username, $uid, $gid, $home ) = @pw[ 0, 2, 3, 7 ];
}
ok( defined $username && $uid >= 1000,
    'fixture identity with uid >= 1000 is available' );
if ( not defined $username ) {
    say ":: cannot run supervisor fixtures without a user account";
    exit 1;
}

my $root = abs_path(
    File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir ) );
my $tmp           = tempdir( CLEANUP => 1 );
my $config_home   = File::Spec->catdir( $tmp,         'config-home' );
my $autostart_dir = File::Spec->catdir( $config_home, 'protocol-7' );
make_path($autostart_dir);
my $log             = File::Spec->catfile( $tmp, 'session.log' );
my $compton_started = File::Spec->catfile( $tmp, 'compton.started' );
my $openbox         = File::Spec->catfile( $tmp, 'openbox-stub' );
my $compton         = File::Spec->catfile( $tmp, 'compton-stub' );
my $autostart       = File::Spec->catdir( $autostart_dir, 'autostart' );
my $openbox_config  = File::Spec->catfile( $tmp, "openbox.$username.xml" );
my $xauth           = File::Spec->catfile( $tmp, "$username.Xauthority" );

write_file( $openbox, <<'EOT', 0755 );
#!/bin/sh
printf 'openbox:%s\n' "$*" >> "$LOGIN_TEST_LOG"
while [ ! -f "$LOGIN_TEST_COMPOSITOR" ]; do sleep 0.05; done
exit 0
EOT
write_file( $compton, <<'EOT', 0755 );
#!/bin/sh
printf 'compton:%s\n' "$*" >> "$LOGIN_TEST_LOG"
: > "$LOGIN_TEST_COMPOSITOR"
while :; do sleep 1; done
EOT
write_file( $autostart, <<'EOT', 0755 );
#!/bin/sh
printf 'autostart\n' >> "$LOGIN_TEST_LOG"
exit 0
EOT
write_file( $openbox_config, "<openbox_config/>\n" );
write_file( $xauth,          "fixture\n" );

my $session_config = File::Spec->catfile( $tmp, 'session.cfg' );
write_file( $session_config,
          "root_path = $tmp\nopenbox.bin = $openbox\ncompton.bin = "
        . "$compton\nopenbox.config_file = "
        . "$openbox_config\nxauthority.dir = $tmp\n" );

if ( $EUID == 0 ) {
    chown(
        $uid,            $gid,     $tmp,     $config_home,
        $autostart_dir,  $openbox, $compton, $autostart,
        $openbox_config, $xauth,   $session_config
    ) or die "fixture chown : $OS_ERROR";
}

sub run_session {
    my ($config_path) = @ARG;
    my $pid = fork() // die;
    if ( $pid == 0 ) {
        if ( $EUID == 0 ) {
            POSIX::setgid($gid) or POSIX::_exit(120);
            POSIX::setuid($uid) or POSIX::_exit(121);
        }
        $ENV{'USER'}                        = $username;
        $ENV{'HOME'}                        = $home;
        $ENV{'DISPLAY'}                     = ':13';
        $ENV{'XDG_CONFIG_HOME'}             = $config_home;
        $ENV{'LOGIN_SCREEN_SESSION_CONFIG'} = $config_path;
        $ENV{'LOGIN_TEST_LOG'}              = $log;
        $ENV{'LOGIN_TEST_COMPOSITOR'}       = $compton_started;
        exec {"$root/bin/login-screen-session"}
            "$root/bin/login-screen-session"
            or POSIX::_exit(127);
    }
    my $deadline = time + 10;
    while ( time < $deadline ) {
        my $done = waitpid( $pid, WNOHANG );
        return ( $done, $CHILD_ERROR ) if $done == $pid;
        select( undef, undef, undef, 0.05 );
    }
    kill 'KILL', $pid;
    waitpid( $pid, 0 );
    return ( $pid, -1 );
}

my ( $done, $status ) = run_session($session_config);
ok( $done > 0 && $status == 0,
    'supervisor exits cleanly after openbox logout' );
open( my $log_fh, '<:raw', $log ) or die "missing session log";
my @lines = grep {length} map {s|\n$||r} <$log_fh>;
close($log_fh);
my $sequence_ok
    = @lines == 3
    && $lines[0] =~ m|^openbox:|
    && $lines[1] =~ m|^compton:|
    && $lines[2] eq 'autostart';
ok( $sequence_ok, 'openbox, compton, then user autostart sequence' );
say 'actual sequence : ' . join( ' | ', @lines ) if not $sequence_ok;
ok( $lines[0] eq "openbox:--sm-disable --config-file $openbox_config",
    'openbox receives the exact per-user config by list exec'
);
ok( $lines[1] eq 'compton:-d :13', 'compton receives the selected display' );

unlink($log);
write_file( $session_config,
          "root_path = $tmp\nopenbox.bin = $openbox\ncompton.bin = "
        . "$compton\nopenbox.config_file = "
        . "$tmp/missing-user.xml\nxauthority.dir = $tmp\n" );
chown( $uid, $gid, $session_config ) if $EUID == 0;
( $done, $status ) = run_session($session_config);
ok( $done > 0 && $status != 0 && !-e $log,
    'missing per-user config fails before any desktop child starts' );

write_file( $session_config,
          "root_path = $tmp\nopenbox.bin = $openbox\ncompton.bin = "
        . "$compton\nopenbox.config_file = "
        . "$openbox_config\nxauthority.dir = $tmp\n" );
chmod( 0644, $xauth ) or die;
chown( $uid, $gid, $session_config, $xauth ) if $EUID == 0;
( $done, $status ) = run_session($session_config);
ok( $done > 0 && $status != 0 && !-e $log,
    'unsafe xauthority mode fails before any desktop child starts' );

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,.,,,..,,,,,..,,.,.,.,.,,,.,.,.,..,,,,.,.,,,..,,...,..,,..,,...,.,,,..,,...,
#E5QRG6VPBEDTBRCKUN5ULB4KJ3MIJD4QXWJC54ICVDBJ5JRCFHYWJ6DFZMFR4N2T4YGYAVPTVD6DI
#\\\|GSMWMCFDVIA6KQGNPWXCN3TZNA535UIF55V6FTSUDB5CIE6LECY \ / AMOS7 \ YOURUM ::
#\[7]VTW2QFAZCTONADSBRSGU5NZUC4V7DESU2UVPTTCIIFEWEXAQISAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
