package AMOS7::deps::hw_detect;
our $VERSION = qw| AMOS7::deps::hw_detect-VERSION.HLBR6LA |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

use AMOS7::deps::os_package qw| probe_binary |;

our @EXPORT_OK = qw| detect_hardware write_hw_profile |;

## read-only hardware \ firmware detection for bin/p7-deps detect-hw :
##
## three evidence strengths, strongest first -- every suggestion carries the
## lines it was derived from
##
## NEEDED   : kernel log lines 'Direct firmware load for <file> failed'
## POSSIBLE : 'modinfo -F firmware' files of loaded modules that are absent
## under /lib/firmware [ .zst \ .xz variants count ]  HARDWARE : pci display
## class 0x03xx vendor, cpu microcode vendor and arm device-tree models
##
## every input source is injectable for tests : a root-dir prefix for the proc
## \ sys \ firmware \ apt-sources reads, a command-runner coderef for
## journalctl \ dmesg \ modinfo \ apt-file \ isenkram-lookup and a binary
## availability probe. never installs, never needs root, never touches the
## network [ apt-file search reads its local index only ]

my $PROFILE_NAME_RE = qr|\A[a-z0-9-]+\z|;

## pci display class vendor -> the tool \ firmware suggestion it implies ##
my %GPU_VENDOR = (
    '0x8086' => { pkg => 'intel-gpu-tools',       label => 'intel gpu' },
    '0x1002' => { pkg => 'firmware-amd-graphics', label => 'amd gpu' },
    '0x10de' => { pkg => undef,                   label => 'nvidia gpu' },
);

## cpuinfo vendor_id -> microcode package ##
my %UCODE_VENDOR = (
    'GenuineIntel' => 'intel-microcode',
    'AuthenticAMD' => 'amd64-microcode',
);

##[ detect_hardware ]#########################################################

## detect_hardware( %opt ) -> \%result
##
##   root        : prefix for proc \ sys \ lib \ etc reads [ default '/' ]
##   run         : coderef ( @cmd ) -> ( $exit_code|undef, $stdout ) -- the
##                 command-runner ; the default forks and execs list-form
##   have_binary : coderef ( $name ) -> 0|1 -- availability probe ; the
##                 default is os_package::probe_binary
##
## the result :
##   kernel_log        => { readable => 1, source => 'journalctl'|'dmesg' }
##                      | { readable => 0, source => undef }
##   non_free_firmware => the apt sources carry 'non-free-firmware' : 1|0
##   suggestions       => [ { strength => NEEDED|POSSIBLE|HARDWARE,
##                            pkg => <name>, evidence => [ <line>, .. ] } ]
##                      [ packages deduped, strongest occurrence kept ]
##   notes             => [ { topic => .., evidence => .. } ] -- hardware
##                      findings that name no package [ the nvidia driver ]
##   unmapped          => [ { file => .., strength => ..,
##                            evidence => [ .. ] } ] -- firmware files no
##                      package mapping was found for

sub detect_hardware {
    my (%opt) = @_;

    my $ctx = {
        root        => $opt{root}        // qw| / |,
        run         => $opt{run}         // \&_run_capture,
        have_binary => $opt{have_binary} // \&probe_binary,
    };

    my $kernel = _kernel_log($ctx);

    my @suggestions;
    my @unmapped;
    my @notes;

    ## strength 1 : firmware files the kernel log names as failed loads ##
    my %needed_file;
    if ( $kernel->{readable} ) {
        for my $line ( split m|\n|, $kernel->{text} ) {
            next unless $line =~ m|Direct firmware load for (\S+) failed|;
            my $file = $1;
            $needed_file{$file} //= [];
            push @{ $needed_file{$file} }, _evidence_line($line);
        }
    }

    for my $file ( sort keys %needed_file ) {
        my $evidence = $kernel->{source} . ' : '
            . join( ' ; ', @{ $needed_file{$file} } );
        my $pkg = _map_file_to_package( $file, $ctx );
        if ( defined $pkg ) {
            push @suggestions,
                {
                strength => qw| NEEDED |,
                pkg      => $pkg,
                evidence => [$evidence],
                file     => $file,
                };
        } else {
            push @unmapped,
                {
                file     => $file,
                strength => qw| NEEDED |,
                evidence => [$evidence],
                };
        }
    }

    ## strength 2 : firmware files loaded modules may ask for, absent under ##
    ## /lib/firmware -- .zst \ .xz compressed variants count                ##
    my %possible_file;
    for my $module ( _loaded_modules($ctx) ) {
        my ( $code, $out )
            = $ctx->{run}->( qw| modinfo -F firmware |, $module );
        next unless defined $code and $code == 0 and defined $out;
        for my $file ( split m|\n|, $out ) {
            next unless length $file;
            next if _firmware_present( $ctx->{root}, $file );
            $possible_file{$file} //= [];
            push @{ $possible_file{$file} },
                "module $module firmware $file absent under /lib/firmware";
        }
    }

    for my $file ( sort keys %possible_file ) {
        next if exists $needed_file{$file};    ## NEEDED already covers it
        my $pkg        = _map_file_to_package( $file, $ctx );
        my $suggestion = {
            strength => qw| POSSIBLE |,
            evidence => $possible_file{$file},
            file     => $file,
        };
        if ( defined $pkg ) {
            $suggestion->{pkg} = $pkg;
            push @suggestions, $suggestion;
        } else {
            $suggestion->{file} = $file;
            push @unmapped, $suggestion;
        }
    }

    ## strength 3 : hardware itself -- gpu vendor, cpu microcode, boards ##
    _detect_pci_gpu( $ctx, \@suggestions, \@notes );
    _detect_microcode( $ctx, \@suggestions );
    _detect_arm_board( $ctx, \@suggestions );

    ## a package suggested twice keeps its strongest evidence ##
    my %seen_pkg;
    @suggestions = grep {
        my $pkg = $ARG->{pkg};
        ( defined $pkg and not $seen_pkg{$pkg}++ )
            ? 1
            : 0
    } @suggestions;

    return {
        kernel_log        => $kernel,
        non_free_firmware => _has_non_free_firmware($ctx),
        suggestions       => \@suggestions,
        notes             => \@notes,
        unmapped          => \@unmapped,
    };
}

##[ kernel log ]##############################################################

## journalctl first, dmesg as fallback -- both may need privileges ; an ##
## unreadable log is reported, never fatal                              ##
sub _kernel_log {
    my ($ctx) = @_;

    for my $source ( [ qw| journalctl |, qw| journalctl -k -b --no-pager | ],
        [ qw| dmesg |, qw| dmesg | ] ) {
        my ( $name, @cmd ) = @$source;
        next unless $ctx->{have_binary}->($name);
        my ( $code, $out ) = $ctx->{run}->(@cmd);
        next unless defined $code and $code == 0;
        next unless defined $out  and length $out;
        return { readable => 1, source => $name, text => $out };
    }

    return { readable => 0, source => undef, text => '' };
}

## one evidence line : the bracketed time \ source head of a kernel log ##
## line adds nothing -- keep the message itself                         ##
sub _evidence_line {
    my ($line) = @_;
    $line =~ s|\A\[[^\]]*\]\s*||;
    $line =~ s|\A\w{3} [ \d]\d \d\d:\d\d:\d\d \S+ kernel:\s*||;
    return $line;
}

##[ modules \ firmware files ]################################################

sub _loaded_modules {
    my ($ctx) = @_;

    my $path = "$ctx->{root}/proc/modules";
    open my $fh, '<', $path or return ();
    my @modules;
    while ( my $line = <$fh> ) {
        next unless $line =~ m|\A(\S+)\s|;
        push @modules, $1;
    }
    close $fh;

    return @modules;
}

## a firmware file present outright, or compressed [.zst \ .xz] ##
sub _firmware_present {
    my ( $root, $file ) = @_;

    my $base = "$root/lib/firmware/$file";
    for my $variant ( $base, "$base.zst", "$base.xz" ) {
        return 1 if -f $variant;
    }
    return 0;
}

##[ hardware : gpu \ microcode \ boards ]#####################################

sub _detect_pci_gpu {
    my ( $ctx, $suggestions, $notes ) = @_;

    my $pci_dir = "$ctx->{root}/sys/bus/pci/devices";
    opendir my $dh, $pci_dir or return;
    while ( my $slot = readdir $dh ) {
        next if $slot =~ m|\A\.|;
        my %attr;
        for my $name (qw| class vendor device |) {
            my $path = "$pci_dir/$slot/$name";
            open my $fh, '<', $path or next;
            chomp( $attr{$name} = <$fh> );
            close $fh;
        }
        next unless defined $attr{class};
        next unless $attr{class} =~ m|\A0x03|i;    ## display class ##
        my $evidence = "pci $slot class $attr{class} vendor "
            . "$attr{vendor} device $attr{device}";
        my $gpu = $GPU_VENDOR{ lc( $attr{vendor} // '' ) } // next;
        if ( defined $gpu->{pkg} ) {
            push @$suggestions,
                {
                strength => qw| HARDWARE |,
                pkg      => $gpu->{pkg},
                evidence => [$evidence],
                };
        } else {
            ## nvidia : the proprietary driver \ nvidia-smi are a separate ##
            ## decision -- reported, never suggested as a package          ##
            push @$notes,
                {
                topic    => "$gpu->{label} driver",
                evidence => $evidence,
                };
        }
    }
    closedir $dh;

    return;
}

sub _detect_microcode {
    my ( $ctx, $suggestions ) = @_;

    my $path = "$ctx->{root}/proc/cpuinfo";
    open my $fh, '<', $path or return;
    my %vendor;
    while ( my $line = <$fh> ) {
        next unless $line =~ m|\Avendor_id\s*:\s*(\S+)|;
        $vendor{$1} = 1;
    }
    close $fh;

    for my $id ( sort keys %vendor ) {
        my $pkg = $UCODE_VENDOR{$id} // next;
        push @$suggestions,
            {
            strength => qw| HARDWARE |,
            pkg      => $pkg,
            evidence => ["cpu vendor_id $id"],
            };
    }

    return;
}

sub _detect_arm_board {
    my ( $ctx, $suggestions ) = @_;

    my $path = "$ctx->{root}/proc/device-tree/model";
    open my $fh, '<', $path or return;
    my $model = <$fh> // '';
    close $fh;
    $model =~ s|\s+\z||;

    return unless $model =~ m|Raspberry Pi|i;

    push @$suggestions,
        {
        strength => qw| HARDWARE |,
        pkg      => qw| raspi-firmware |,
        evidence => ["device tree model : $model"],
        };

    ## the broadcom wireless firmware is a likely need on these boards ##
    push @$suggestions,
        {
        strength => qw| POSSIBLE |,
        pkg      => qw| firmware-brcm80211 |,
        evidence => ["device tree model : $model"],
        };

    return;
}

##[ apt sources : the non-free-firmware component ]###########################

## /etc/apt/sources.list plus sources.list.d                                ##
## [ one-line .list and deb822 .sources formats ] -- 1 when any source line ##
## \ Components entry names it                                              ##
sub _has_non_free_firmware {
    my ($ctx) = @_;

    my @files  = ("$ctx->{root}/etc/apt/sources.list");
    my $list_d = "$ctx->{root}/etc/apt/sources.list.d";
    if ( opendir my $dh, $list_d ) {
        push @files, map { m{\.(?:list|sources)\z} ? "$list_d/$_" : () }
            sort readdir $dh;
        closedir $dh;
    }

    for my $file (@files) {
        open my $fh, '<', $file or next;
        while ( my $line = <$fh> ) {
            return 1 if $line =~ m|\bnon-free-firmware\b|;
        }
        close $fh;
    }

    return 0;
}

##[ file -> package mapping ]#################################################

## apt-file first, isenkram-lookup as fallback, undef when neither maps the ##
## file [ the caller reports it unmapped -- a package is never guessed ]    ##
sub _map_file_to_package {
    my ( $file, $ctx ) = @_;

    if ( $ctx->{have_binary}->('apt-file') ) {
        my ( $code, $out )
            = $ctx->{run}->( qw| apt-file search |, $file );
        if ( defined $code and $code == 0 and defined $out ) {
            for my $line ( split m|\n|, $out ) {
                next
                    unless $line
                    =~ m|\A([a-z0-9][a-z0-9.+\-]*): \S*/\Q$file\E\s*\z|;
                return $1;
            }
        }
        return undef;    ## apt-file answered : its silence is the answer ##
    }

    if ( $ctx->{have_binary}->('isenkram-lookup') ) {
        my ( $code, $out )
            = $ctx->{run}->( qw| isenkram-lookup |, $file );
        return undef unless defined $code and $code == 0 and defined $out;
        ## conservative : a bare package name per line, exactly one ##
        ## distinct candidate wins -- anything else stays unmapped  ##
        my %candidate;
        for my $line ( split m|\n|, $out ) {
            next unless $line =~ m|\A\s*([a-z0-9][a-z0-9.+\-]+)\s*\z|;
            $candidate{$1} = 1;
        }
        my @candidates = sort keys %candidate;
        return @candidates == 1 ? $candidates[0] : undef;
    }

    return undef;
}

##[ write_hw_profile ]########################################################

## write_hw_profile( $profiles_file, $name, $suggestions ) -> ( 1, $block ) |
## ( 0, $error )
##
## adds or replaces a 'hw-<name>' profile with an apt list, each package
## commented with its evidence. names must match \A[a-z0-9-]+\z -- anything
## else is refused before the file is read. every byte outside the new \
## replaced block is kept identical ; the block text is returned so callers
## can show exactly what changed
sub write_hw_profile {
    my ( $path, $name, $suggestions ) = @_;

    return ( 0,
              "invalid profile name [ $name ] -- "
            . "only a-z 0-9 and '-' are allowed" )
        unless defined $name
        and length $name
        and $name =~ $PROFILE_NAME_RE;

    my $block = _profile_block( $name, $suggestions );

    open my $fh, '<', $path or return ( 0, "cannot read $path : $OS_ERROR" );
    my $content = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
    close $fh;

    my @lines     = split m|\n|, $content // '', -1;
    my $header_re = qr|\A  (\S+):\s*\z|;

    ## the existing hw-<name> block, if any : from its header to the next ##
    my ( $start, $end );
    for my $index ( 0 .. $#lines ) {
        next unless $lines[$index] =~ $header_re;
        my $profile_name = $1;
        if ( defined $start and not defined $end ) {
            $end = $index;
            last;
        }
        if ( not defined $start and $profile_name eq "hw-$name" ) {
            $start = $index;
        }
    }
    $end = scalar(@lines) if defined $start and not defined $end;

    my @block_lines = split m|\n|, $block, -1;
    if ( defined $start ) {
        splice( @lines, $start, $end - $start, @block_lines );
        $content = join( "\n", @lines );
    } else {
        $content //= '';
        $content .= "\n" if length $content and $content !~ m|\n\z|;
        $content .= $block;
    }

    open my $out, '>', $path
        or return ( 0, "cannot write $path : $OS_ERROR" );
    print {$out} $content;
    close $out;

    return ( 1, $block );
}

## the yaml block : description, then one apt entry per package with its ##
## evidence as a trailing comment [ load_profiles strips comments ]      ##
sub _profile_block {
    my ( $name, $suggestions ) = @_;

    my $block
        = "  hw-$name:\n"
        . qq|    description: "detected hardware [ bin/p7-deps detect-hw |
        . qq|-write $name ] -- review before install"\n|
        . "    apt:\n";

    my %seen_pkg;
    for my $suggestion (@$suggestions) {
        my $pkg = $suggestion->{pkg};
        next unless defined $pkg and length $pkg;
        next if $seen_pkg{$pkg}++;
        my $evidence = join ' ; ', @{ $suggestion->{evidence} // [] };
        $evidence =~ s|\s+| |g;
        $evidence =~ s|#|,|g;
        $evidence = substr( $evidence, 0, 62 ) . '.,.'
            if length $evidence > 66;
        $block .= sprintf "      - %-24s # %s : %s\n",
            $pkg, $suggestion->{strength}, $evidence;
    }

    return $block;
}

##[ the default command-runner ]##############################################

## fork + exec list-form, stderr silenced : ( $? >> 8, stdout ) or ( undef, ##
## '' ) when the fork failed                                                ##
sub _run_capture {
    my (@cmd) = @_;

    my $pid = open( my $fh, '-|' );
    return ( undef, '' ) unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>', '/dev/null' );
        exec { $cmd[0] } @cmd;
        exit 127;
    }

    my $out = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> }
        // '';
    close($fh);

    return ( $CHILD_ERROR >> 8, $out );
}

1;

#,,,,,..,,,..,,.,,.,.,,..,.,,,...,,,.,...,,.,,..,,...,...,,.,,,..,,,,,..,,..,,
#SELM7WXUALKZNXPJAB566PULLQ4GHNHADP2RZG4YSSIZUEGLNCPF5AZW4IVSB5GERUEQNL5O7E5UG
#\\\|TJCAUHZ5WIGRNCW7W7PH6QP6TFCVFS63QFFNFNVTLIBML6XZMBF \ / AMOS7 \ YOURUM ::
#\[7]6QHI5DN3BPL744E6C4EWLOJZSDCH7474ZOYSE2YE23MVRWYLNIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
