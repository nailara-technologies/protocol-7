#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

##                                                         ##
##  AMOS7::deps::hw_detect : read-only hardware detection  ##
##                                                         ##

## exercises data/lib-path/pm/AMOS7/deps/hw_detect.pm against fake input    ##
## roots only [ File::Temp ] -- never the real /proc, /sys, /lib/firmware   ##
## or /etc/apt. covers : the three evidence  strengths [ kernel log         ##
## failures -> NEEDED, modinfo firmware absent under /lib/firmware ->       ##
## POSSIBLE, pci gpu \ cpu microcode \ arm device-tree -> HARDWARE ], intel ##
## \ nvidia \ amd gpus, the raspberry pi model, .zst \ .xz compressed       ##
## firmware variants, missing non-free-firmware in both one-line .list and  ##
## deb822 .sources apt formats, apt-file and isenkram-lookup mapping with   ##
## unmapped files never guessed a package, an unreadable kernel log, and    ##
## write_hw_profile : profile added, replaced, every other byte unchanged,  ##
## bad names refused. the command itself runs once against a copied tree    ##
## for --write                                                              ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
}

use AMOS7::deps::hw_detect qw| detect_hardware write_hw_profile |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return TRUE;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

my $sandbox = tempdir( CLEANUP => 1 );

## a fake root : hash of relative path -> content ##
sub make_root {
    my (%files) = @_;
    my $root
        = File::Spec->catdir( $sandbox, 'root-' . $PID . '-' . int rand 1e9 );
    for my $rel ( sort keys %files ) {
        my $path = File::Spec->catfile( $root, split m|/|, $rel );
        make_path( ( File::Spec->splitpath($path) )[1] );
        write_file( $path, $files{$rel} );
    }
    return $root;
}

## a fake command-runner : program name -> [ exit, output ] or coderef ##
sub make_runner {
    my (%response) = @_;
    return sub {
        my (@cmd) = @_;
        my $entry = $response{ $cmd[0] } or return ( 127, '' );
        return ref $entry eq 'CODE' ? $entry->(@cmd) : @$entry;
    };
}

sub suggestions_for {
    my ( $result, $pkg ) = @_;
    return grep { ( $_->{pkg} // '' ) eq $pkg } @{ $result->{suggestions} };
}

sub has_pkg {
    my ( $result, $pkg ) = @_;
    return scalar suggestions_for( $result, $pkg );
}

##[ the intel laptop scenario ]###############################################

my $intel_root = make_root(
    'proc/modules' => <<'EOF',
iwlwifi 458752 0 - Live 0xffffffffc0a00000
snd_hda_intel 53248 1 - Live 0xffffffffc0900000
fake_mod 16384 0 - Live 0xffffffffc0800000
EOF
    'proc/cpuinfo' => <<'EOF',
processor	: 0
vendor_id	: GenuineIntel
model name	: Intel(R) Core(TM) i7-2640M
processor	: 1
vendor_id	: GenuineIntel
EOF
    'sys/bus/pci/devices/0000:00:02.0/class'  => "0x030000\n",
    'sys/bus/pci/devices/0000:00:02.0/vendor' => "0x8086\n",
    'sys/bus/pci/devices/0000:00:02.0/device' => "0x0126\n",
    'lib/firmware/keepme.bin'                 => '',
    'lib/firmware/keepme2.bin.zst'            => '',
    'etc/apt/sources.list'                    => <<'EOF',
deb http://deb.debian.org/debian bookworm main non-free-firmware
EOF
);

my $journal_canned = <<'EOF';
Oct 15 16:43:15 testhost kernel: Linux version 6.1.0
Oct 15 16:43:16 testhost kernel: iwlwifi 0000:03:00.0: Direct firmware load for iwlwifi-6000-4.ucode failed with error -2
Oct 15 16:43:16 testhost kernel: iwlwifi 0000:03:00.0: no firmware found
EOF

my %intel_cmd = (
    journalctl => [ 0, $journal_canned ],
    dmesg      => [ 0, "this dmesg output must never be read\n" ],
    modinfo    => sub {
        my (@cmd) = @_;
        my $mod   = $cmd[-1];
        my %fw    = (
            iwlwifi       => "iwlwifi-6000-4.ucode\nkeepme.bin\n",
            fake_mod      => "fake-fw.bin\nkeepme2.bin\n",
            snd_hda_intel => "",
        );
        return ( exists $fw{$mod} ? 0 : 1, $fw{$mod} // '' );
    },
    'apt-file' => sub {
        my (@cmd) = @_;
        my %map = (
            'iwlwifi-6000-4.ucode' => "firmware-iwlwifi: "
                . "lib/firmware/iwlwifi-6000-4.ucod" . "e\n",
            'fake-fw.bin' => "firmware-fake: " . "lib/firmware/fake-fw.bin\n",
        );
        my $file = $cmd[-1];
        return ( 0, $map{$file} // '' );
    },
);

my $result = detect_hardware(
    root => $intel_root,
    run  => make_runner(%intel_cmd),
);

check 'intel scenario : the kernel log came from journalctl, readable',
    (       $result->{kernel_log}{readable}
        and $result->{kernel_log}{source} eq 'journalctl' );
check 'intel scenario : firmware-iwlwifi suggested as NEEDED',
    ( has_pkg( $result, 'firmware-iwlwifi' )
        and ( suggestions_for( $result, 'firmware-iwlwifi' ) )[0]{strength}
        eq 'NEEDED' );
check 'intel scenario : the NEEDED evidence is the kernel log line',
    ( suggestions_for( $result, 'firmware-iwlwifi' ) )[0]{evidence}[0]
    =~ m|journalctl : .*Direct firmware load for iwlwifi-6000-4\.ucode failed|;
check 'intel scenario : fake-fw.bin suggested as POSSIBLE',
    ( has_pkg( $result, 'firmware-fake' )
        and ( suggestions_for( $result, 'firmware-fake' ) )[0]{strength} eq
        'POSSIBLE' );
check 'intel scenario : the POSSIBLE evidence names module and absence',
    ( suggestions_for( $result, 'firmware-fake' ) )[0]{evidence}[0]
    =~ m|module fake_mod firmware fake-fw\.bin absent under /lib/firmware|;
check 'intel scenario : firmware present on disk is never suggested',
    not grep { ( $_->{file} // '' ) =~ m|\Akeepme| }
    @{ $result->{suggestions} };
check 'intel scenario : .zst compressed firmware counts as present',
    not scalar @{ $result->{unmapped} };
check 'intel scenario : intel-gpu-tools from the pci display class',
    ( has_pkg( $result, 'intel-gpu-tools' )
        and ( suggestions_for( $result, 'intel-gpu-tools' ) )[0]{evidence}[0]
        =~ m|pci 0000:00:02\.0 class 0x030000 vendor 0x8086| );
check 'intel scenario : intel-microcode from cpuinfo vendor_id',
    ( has_pkg( $result, 'intel-microcode' )
        and ( suggestions_for( $result, 'intel-microcode' ) )[0]{evidence}[0]
        =~ m|cpu vendor_id GenuineIntel| );
check 'intel scenario : no nvidia or amd entries',
    not( has_pkg( $result, 'firmware-amd-graphics' )
    or has_pkg( $result, 'amd64-microcode' )
    or @{ $result->{notes} } );
check 'intel scenario : non-free-firmware component found in .list format',
    $result->{non_free_firmware} == 1;

##[ nvidia gpu \ amd cpu \ unreadable kernel log ]############################

my $nvidia_root = make_root(
    'proc/modules' => "nvidia 16384 0 - Live 0xffffffffc0800000\n",
    'proc/cpuinfo' => "processor\t: 0\nvendor_id\t: AuthenticAMD\n",
    'sys/bus/pci/devices/0000:01:00.0/class'  => "0x030200\n",
    'sys/bus/pci/devices/0000:01:00.0/vendor' => "0x10de\n",
    'sys/bus/pci/devices/0000:01:00.0/device' => "0x1c82\n",
    'etc/apt/sources.list' => "deb http://deb.debian.org/debian "
        . "bookworm main\n",
);

my $nvidia_result = detect_hardware(
    root => $nvidia_root,
    run  => make_runner(
        journalctl => [ 1, '' ],    ## needs privileges ##
        dmesg      => [ 1, '' ],    ## restricted too   ##
        modinfo    => [ 0, '' ],
        'apt-file' => [ 0, '' ],
    ),
);

check 'nvidia scenario : an unreadable log is reported, not fatal',
    $nvidia_result->{kernel_log}{readable} == 0;
check 'nvidia scenario : the proprietary driver is a note, not a package',
    (       @{ $nvidia_result->{notes} } == 1
        and $nvidia_result->{notes}[0]{topic}    =~ m|nvidia gpu driver|
        and $nvidia_result->{notes}[0]{evidence} =~ m|vendor 0x10de| );
check 'nvidia scenario : no nvidia package is ever suggested',
    not has_pkg( $nvidia_result, 'nvidia-driver' );
check 'nvidia scenario : amd cpu microcode from cpuinfo',
    has_pkg( $nvidia_result, 'amd64-microcode' );
check 'nvidia scenario : no intel microcode on an amd cpu',
    not has_pkg( $nvidia_result, 'intel-microcode' );
check 'nvidia scenario : non-free-firmware missing from plain main source',
    $nvidia_result->{non_free_firmware} == 0;

##[ amd gpu ]#################################################################

my $amd_root = make_root(
    'proc/modules' => "",
    'proc/cpuinfo' => "processor\t: 0\nvendor_id\t: GenuineIntel\n",
    'sys/bus/pci/devices/0000:04:00.0/class'  => "0x038000\n",
    'sys/bus/pci/devices/0000:04:00.0/vendor' => "0x1002\n",
    'sys/bus/pci/devices/0000:04:00.0/device' => "0x67df\n",
    'sys/bus/pci/devices/0000:05:00.0/class'  => "0x020000\n",
    'sys/bus/pci/devices/0000:05:00.0/vendor' => "0x8086\n",
    'sys/bus/pci/devices/0000:05:00.0/device' => "0x1533\n",
    'etc/apt/sources.list.d/amd.sources'      => <<'EOF',
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm
Components: main non-free-firmware
EOF
);

my $amd_result = detect_hardware(
    root        => $amd_root,
    run         => make_runner( journalctl => [ 0, "nothing here\n" ] ),
    have_binary => sub {0},    ## neither apt-file nor isenkram-lookup ##
);

check 'amd scenario : firmware-amd-graphics from the pci display class',
    ( has_pkg( $amd_result, 'firmware-amd-graphics' )
        and ( suggestions_for( $amd_result, 'firmware-amd-graphics' ) )
        [0]{evidence}[0] =~ m|class 0x038000 vendor 0x1002| );
check 'amd scenario : a non-display intel pci device suggests no gpu tools',
    not has_pkg( $amd_result, 'intel-gpu-tools' );
check 'amd scenario : non-free-firmware found in deb822 .sources format',
    $amd_result->{non_free_firmware} == 1;

my $amd_root_no_nff = make_root(
    'etc/apt/sources.list.d/upstream.sources' => <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm
Components: main
EOF
);
check 'deb822 .sources without the component reads as missing',
    detect_hardware(
    root        => $amd_root_no_nff,
    run         => make_runner(),
    have_binary => sub {0},
    )->{non_free_firmware} == 0;

##[ raspberry pi arm board ]##################################################

my $rpi_root = make_root(
    'proc/modules'           => "",
    'proc/cpuinfo'           => "processor\t: 0\nmodel name\t: ARMv8\n",
    'proc/device-tree/model' => "Raspberry Pi 4 Model B\n",
    'etc/apt/sources.list'   => "deb http://deb.debian.org/debian "
        . "bookworm main\n",
);

my $rpi_result = detect_hardware(
    root        => $rpi_root,
    run         => make_runner( journalctl => [ 0, "clean boot\n" ] ),
    have_binary => sub {0},
);

check 'rpi scenario : raspi-firmware from the device-tree model',
    ( has_pkg( $rpi_result, 'raspi-firmware' )
        and ( suggestions_for( $rpi_result, 'raspi-firmware' ) )[0]{strength}
        eq 'HARDWARE'
        and
        ( suggestions_for( $rpi_result, 'raspi-firmware' ) )[0]{evidence}[0]
        =~ m|device tree model : Raspberry Pi 4 Model B| );
check 'rpi scenario : firmware-brcm80211 as POSSIBLE',
    ( has_pkg( $rpi_result, 'firmware-brcm80211' )
        and
        ( suggestions_for( $rpi_result, 'firmware-brcm80211' ) )[0]{strength}
        eq 'POSSIBLE' );
check 'rpi scenario : no x86 microcode on an arm board',
    not( has_pkg( $rpi_result, 'intel-microcode' )
    or has_pkg( $rpi_result, 'amd64-microcode' ) );

##[ unmapped files are never guessed a package ]##############################

my $unmapped_root = make_root(
    'proc/modules' => "mystery_mod 1024 0 - Live 0xffffffffc0800000\n",
    'etc/apt/sources.list' => "deb http://deb.debian.org/debian "
        . "bookworm main\n",
);

my $unmapped_result = detect_hardware(
    root => $unmapped_root,
    run  => make_runner(
        journalctl => [
            0, "kernel: Direct firmware load " . "for weird-fw.bin failed\n"
        ],
        modinfo    => sub { ( 0, "mystery-fw.bin\n" ) },
        'apt-file' => [ 0, '' ],    ## the local index has no match ##
    ),
    have_binary => sub {1},
);

check 'unmapped scenario : files no mapper '
    . 'knows stay unmapped, with evidence',
    ( @{ $unmapped_result->{unmapped} } == 2
        and grep { $_->{file} eq 'weird-fw.bin' }
        @{ $unmapped_result->{unmapped} }
        and grep { $_->{file} eq 'mystery-fw.bin' }
        @{ $unmapped_result->{unmapped} } );
check 'unmapped scenario : no package was guessed for an unknown file',
    @{ $unmapped_result->{suggestions} } == 0;

my $isenkram_result = detect_hardware(
    root => $unmapped_root,
    run  => make_runner(
        journalctl => [
            0,
            "kernel: Direct firmware load for solo-fw.bin failed\nkernel: "
                . "Direct firmware load for dual-fw.bin failed\n"
        ],
        'isenkram-lookup' => sub {
            my (@cmd) = @_;
            my $file  = $cmd[-1];
            my %map   = (
                'solo-fw.bin' => "firmware-solo\n",
                'dual-fw.bin' => "pkg-a\npkg-b\n",    ## ambiguous */
            );
            return ( 0, $map{$file} // '' );
        },
    ),
    have_binary => sub { my ($name) = @_; $name eq 'apt-file' ? 0 : 1 },
);
check 'isenkram scenario : a single unambiguous candidate maps the file',
    has_pkg( $isenkram_result, 'firmware-solo' );
check 'isenkram scenario : an ambiguous answer stays unmapped',
    ( not has_pkg( $isenkram_result, 'pkg-a' )
        and grep { $_->{file} eq 'dual-fw.bin' }
        @{ $isenkram_result->{unmapped} } );

##[ write_hw_profile ]########################################################

my $profiles_fixture = <<'EOF';
profiles:
  minimal:
    description: "minimal protocol-7 runtime [core dependencies only]"
    apt:
      - git
      - perl
      - make
    cpan:
      - Event

  hw-thinkpad-sandybridge:
    description: "hardware : sandy bridge thinkpads"
    apt:
      - firmware-iwlwifi        # intel centrino 6205 \ 6300 wifi
      - intel-microcode         # cpu microcode updates

  tools:
    description: "utility tools and scripts"
    apt:
      - libdbi-perl
EOF

my $profiles_path = File::Spec->catfile( $sandbox, 'profiles-write.yaml' );
write_file( $profiles_path, $profiles_fixture );

my @write_suggestions = (
    {   strength => 'NEEDED',
        pkg      => 'firmware-iwlwifi',
        evidence => [
                  'journalctl : Direct firmware load '
                . 'for iwlwifi-6000-4.ucode failed'
        ],
    },
    {   strength => 'HARDWARE',
        pkg      => 'intel-microcode',
        evidence => ['cpu vendor_id GenuineIntel'],
    },
    {   strength => 'POSSIBLE',
        pkg      => 'firmware-iwlwifi',    ## a dup : written once ##
        evidence => ['second file maps to the same package'],
    },
);

my ( $ok, $block )
    = write_hw_profile( $profiles_path, 'testhost', \@write_suggestions );
my $written = slurp($profiles_path);

check 'write : the profile was added',
    ( $ok and $written =~ m|^  hw-testhost:$|m );
check 'write : every package listed, each commented with its evidence',
    ( $written =~ m|firmware-iwlwifi\s+# NEEDED : journalctl : .*iwlwifi|m
        and $written
        =~ m|intel-microcode\s+# HARDWARE : cpu vendor_id GenuineIntel|m );
check 'write : a package suggested twice is written once',
    scalar( () = $block =~ m|firmware-iwlwifi|g ) == 1;
check 'write : every other profile byte-identical [ block subtracts ]',
    ( $written =~ s|\Q$block\E||r ) eq $profiles_fixture;

## a second write replaces the block in place, the rest untouched ##
( $ok, $block ) = write_hw_profile(
    $profiles_path,
    'testhost',
    [
        {   strength => 'HARDWARE',
            pkg      => 'amd64-microcode',
            evidence => ['cpu vendor_id AuthenticAMD']
        }
    ]
);
$written = slurp($profiles_path);
check 'write : replacing keeps a single hw-testhost block',
    (       $written =~ m|^  hw-testhost:$|m
        and $written !~ m|^  hw-testhost:$.*^  hw-testhost:$|ms );
check 'write : the replacement drops the old packages',
    (       index( $block, 'firmware-iwlwifi' ) < 0
        and index( $block, 'amd64-microcode' ) >= 0 );
check 'write : the replaced block still subtracts to the fixture',
    ( $written =~ s|\Q$block\E||r ) eq $profiles_fixture;

## names outside \A[a-z0-9-]+\z are refused, the file untouched ##
for my $bad_name ( 'Bad Name', 'UPPER', 'a_b', '.dot', "trail\n", '..' ) {
    my ( $refused, $error )
        = write_hw_profile( $profiles_path, $bad_name, [] );
    check "write : name [ $bad_name ] refused before the file is read",
        (       not $refused
            and defined $error
            and $error =~ m|invalid profile name| );
}
check 'write : a refused name leaves the file byte-identical',
    slurp($profiles_path) eq $written;

##[ the command against a copied tree ]#######################################

my $tree = File::Spec->catdir( $sandbox, 'tree' );
make_path( map { File::Spec->catdir( $tree, @$_ ) } [qw| bin |],
    [qw| .deps |], [qw| data lib-path |] );
copy( "$RealBin/../p7-deps", "$tree/bin/p7-deps" )
    or die "copy : $OS_ERROR";
symlink( abs_path("$RealBin/../../data/lib-path/pm"),
    "$tree/data/lib-path/pm" )
    or die "symlink : $OS_ERROR";
write_file( "$tree/.deps/profiles.yaml", $profiles_fixture );

sub p7_deps {
    my (@args) = @_;
    open my $err_fh, '>', File::Spec->catfile( $sandbox, 'stderr' )
        or die $OS_ERROR;
    my $pid = open( my $out_fh, '-|' );
    die "fork : $OS_ERROR" if not defined $pid;
    if ( $pid == 0 ) {
        open( STDIN,  '<',  File::Spec->devnull );
        open( STDERR, '>&', $err_fh );
        exec( $EXECUTABLE_NAME, "$tree/bin/p7-deps", @args ) or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $out = <$out_fh> // '';
    close $out_fh;    ## reaps the child, $? is its exit ##
    return ( $CHILD_ERROR >> 8, $out, slurp("$sandbox/stderr") // '' );
}

my ( $exit, $out, $err ) = p7_deps(qw| detect-hw --write bad_name |);
check 'command : a bad --write name exits 0110', $exit == 0110;
check 'command : the refusal names the name on STDERR',
    $err =~ m|:: < p7-deps > : invalid profile name \[ bad_name \]|;
check 'command : a refused --write never touched the profiles file',
    slurp("$tree/.deps/profiles.yaml") eq $profiles_fixture;

( $exit, $out ) = p7_deps(qw| detect-hw --write sandboxtest |);
check 'command : detect-hw --write exits 0 on this host', $exit == 0;
check 'command : the profile landed in the copied tree',
    slurp("$tree/.deps/profiles.yaml") =~ m|^  hw-sandboxtest:$|m;
check 'command : every pre-existing profile is still intact',
    index( slurp("$tree/.deps/profiles.yaml"), 'hw-thinkpad-sandybridge' )
    >= 0;
if ( $out =~ m|(\d+) packages suggested| and $1 > 0 ) {
    check 'command : the written packages carry their evidence comments',
        slurp("$tree/.deps/profiles.yaml")
        =~ m{^      - \S+ +# (?:NEEDED|POSSIBLE|HARDWARE) : }m;
} else {
    check 'command : this host suggested nothing -- nothing to write', 1;
}

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,.,,,,,.,,,.,,..,...,..,,,..,...,,..,..,,..,,...,...,...,,..,...,,..,,,.,
#4COJW74NNH2E4USD6RIXFEXSFBAWPH2C4QW2EJCBZHI34OK6LXEHBNNHKDGYRT62IWWAVIYFTESUS
#\\\|PT54RJAGXQGRFRQUYA64ARUIKIHR27R66CGJYMOWICCGDZJBQ2N \ / AMOS7 \ YOURUM ::
#\[7]7T4N3UBGBN334IY7C4WSVVS4TE736EAFFVTUL5ELKQFWHK43F2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
