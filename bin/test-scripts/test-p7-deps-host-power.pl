#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
##  p7-deps host-power : standalone harness                          ##
###                                                                 ###

## exercises the pure parts of AMOS7::deps::hostpower against fixtures, no
## root and no systemctl required :
## - parse_wakeup : the /proc/acpi/wakeup table shape, *enabled status
## - select_wakeup_devices : everything enabled except the RTC class
## [ platform:ACPI000E sysfs, AWAC name ] is selected
## - unit_content : guard-based loop, literal $d survives for sh -c, '; true'
## keeps the oneshot from inheriting grep's exit status
## - run : against a test root + fake wakeup file -- unit written, wants
## symlink created, systemctl steps skipped, ok => 1

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, 'data', 'lib-path', 'pm' );
}

use AMOS7::deps::hostpower qw|
    parse_wakeup select_wakeup_devices unit_content run
    |;

my $checks = 0;
my $failed = 0;

sub check {
    my ( $label, $condition ) = @_;
    $checks++;
    if ($condition) {
        printf "  ok   : %s\n", $label;
    } else {
        $failed++;
        printf "  FAIL : %s\n", $label;
    }
    return;
}

##[ fixtures ]################################################################

my $wakeup_sample = <<'EOL';
Device  S-state   Status   Sysfs node
RP09      S4    *enabled   pci:0000:00:1d.0
RP07      S4    *enabled   pci:0000:00:1c.0
XHCI      S3    *enabled   pci:0000:00:14.0
AWAC      S4    *enabled   platform:ACPI000E:00
AR00      S4   *disabled   pci:0000:00:16.0
EOL

##[ parse_wakeup ]############################################################

my $devices = parse_wakeup($wakeup_sample);

check 'parse : 5 devices parsed', scalar @{$devices} == 5;
check 'parse : RP09 enabled',     $devices->[0]{'enabled'} == 1;
check 'parse : AR00 disabled',    $devices->[4]{'enabled'} == 0;
check 'parse : AWAC sysfs kept',  $devices->[3]{'sysfs'} =~ m{ACPI000E};
check 'parse : undef text -> []', scalar @{ parse_wakeup(undef) } == 0;
check 'parse : garbage ' . '-> []',
    scalar @{ parse_wakeup("nothing here") } == 0;

##[ select_wakeup_devices ]###################################################

my $selected = select_wakeup_devices($devices);
my %picked   = map { $ARG => 1 } @{$selected};

check 'select : RP09 picked',   $picked{'RP09'} // 0;
check 'select : RP07 picked',   $picked{'RP07'} // 0;
check 'select : XHCI picked',   $picked{'XHCI'} // 0;
check 'select : AWAC left out', !exists $picked{'AWAC'};
check 'select : AR00 left out', !exists $picked{'AR00'};
check 'select : 3 selected',    scalar @{$selected} == 3;
check 'select : [] in -> [] out',
    scalar @{ select_wakeup_devices( [] ) } == 0;

##[ unit_content ]############################################################

my $content = unit_content($selected);

check 'unit : every device named',
    index( $content, 'for d in RP09 RP07 XHCI' ) >= 0;
check 'unit : literal $d for sh -c, not expanded',
    index( $content, '^$d.*enabled' ) >= 0
    && index( $content, 'echo $d >' ) >= 0;
check 'unit : guard does not match disabled lines',
    index( $content, 'disabled' ) == -1;
check 'unit : oneshot with true tail', $content =~ m{Type=oneshot}
    and $content =~ m{done; true'};
check 'unit : multi-user install target',
    $content =~ m{WantedBy=multi-user\.target};
check 'unit : no device list -> empty loop body still valid',
    unit_content( [] ) =~ m{for d in ; do};

##[ run : test root + fake wakeup file ]######################################

my $tmp       = tempdir( CLEANUP => 1 );
my $fake_proc = File::Spec->catfile( $tmp, 'wakeup' );
{
    open my $fh, '>', $fake_proc or die $OS_ERROR;
    print {$fh} $wakeup_sample;
    close $fh;
}

my $result = run(
    {   'prefix'      => $tmp,
        'wakeup_file' => $fake_proc
    }
);

check 'run : ok under test root', $result->{'ok'} == 1;
check 'run : sleep targets skipped',
    grep( { $ARG->[0] eq 'sleep targets' } @{ $result->{'rows'} } );
check 'run : unit written',
    -f File::Spec->catfile( $tmp, 'etc', 'systemd', 'system',
    'p7-wakeup-disable.service' );
check 'run : wants symlink created',
    -l File::Spec->catfile( $tmp, 'etc', 'systemd', 'system',
    'multi-user.target.wants', 'p7-wakeup-disable.service' );
check 'run : would-disable row lists all three',
    grep(
    { $ARG->[0] eq 'wakeup devices'
            and index( $ARG->[2], 'RP09 RP07 XHCI' ) >= 0 }
    @{ $result->{'rows'} } );
check 'run : unit guards the disabled AR00 too [ boot-time list ]',
    grep(
    { $ARG->[0] eq 'wakeup devices' and index( $ARG->[2], 'AR00' ) >= 0 }
    @{ $result->{'rows'} } );
check 'run : unit content carries the full guard list', do {
    open my $fh, '<',
        File::Spec->catfile( $tmp, 'etc', 'systemd', 'system',
        'p7-wakeup-disable.service' );
    my $text = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
    close($fh);
    index( $text, 'for d in RP09 RP07 XHCI AR00' ) >= 0;
};

## second run against the same root : unit unchanged, symlink ok ##

my $again = run(
    {   'prefix'      => $tmp,
        'wakeup_file' => $fake_proc
    }
);
check 'run : second pass unit ok [ not changed ]',
    grep( { $ARG->[0] eq 'wakeup unit' and $ARG->[1] eq 'ok' }
    @{ $again->{'rows'} } );
check 'run : second pass still ok', $again->{'ok'} == 1;

## upgrade path : an older own unit [ marker, shorter list ] is rewritten ##

my $unit_path = File::Spec->catfile( $tmp, 'etc', 'systemd', 'system',
    'p7-wakeup-disable.service' );
{
    open my $fh, '>', $unit_path or die $OS_ERROR;
    print {$fh} "# Protocol-7 host power : stale unit\nfor d in RP09\n";
    close($fh);
}
my $upgrade = run(
    {   'prefix'      => $tmp,
        'wakeup_file' => $fake_proc
    }
);
check 'run : stale own unit rewritten',
    grep( { $ARG->[0] eq 'wakeup unit' and $ARG->[1] eq 'changed' }
    @{ $upgrade->{'rows'} } );
check 'run : upgrade pass ok', $upgrade->{'ok'} == 1;

## foreign file at the unit path is left alone ##

{
    open my $fh, '>', $unit_path or die $OS_ERROR;
    print {$fh} "# somebody else's handcrafted unit\nExecStart=/bin/true\n";
    close($fh);
}
my $foreign = run(
    {   'prefix'      => $tmp,
        'wakeup_file' => $fake_proc
    }
);
check 'run : foreign unit refused',
    grep( { $ARG->[0] eq 'wakeup unit' and $ARG->[1] eq 'failed' }
    @{ $foreign->{'rows'} } );
check 'run : foreign unit keeps failing the run', $foreign->{'ok'} == 0;

##[ summary ]#################################################################

printf "\n: %d checks passed, %d failed\n", $checks - $failed, $failed;
exit( $failed ? 1 : 0 );

#,,,,,,.,,,.,,..,,...,,.,,..,,..,,,.,,...,.,,,..,,...,..,,...,,.,,,,.,.,.,..,,
#MGGDQBLCW7F22YHJ4EFCJBQ6FGV2ALWRX5XXWL4YFTTGPHTWNNCPKU7D2P3GQMWBZ5R67MCKZXNRY
#\\\|QZEN4YKSNEPHJMHU3VQ5KS3CK7TRRWRHTKE5YKJTLXXAOWKUIUP \ / AMOS7 \ YOURUM ::
#\[7]5JMWM3OYIH6EE4I3UNMSH42SHUWU5UZPPF5FD3MXZ5CYLZXAC2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
