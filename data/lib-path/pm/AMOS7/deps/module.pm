package AMOS7::deps::module;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw|
    load_known_deps
    scan_zenki_pm_deps
    probe_module
    probe_module_file
    resolve_install
    |;

##[ load_known_deps ]#########################################################

## single canonical accessor for src/base.known_dependencies data :         ##
## reachable from both zenka and standalone-script contexts, so callers     ##
## never need the <[base.known_dependencies]> P7-module-invocation route    ##
## [ zenka-context only ] for this data. $section selects the data section  ##
## [ default 'perlmod' ] ; the underlying file can be re-routed or upgraded ##
## later without hunting down every caller                                  ##

sub load_known_deps {
    my ( $p7_root, $section ) = @_;

    $section //= 'perlmod';

    return {} unless defined $p7_root and length $p7_root;

    my $known_file = "$p7_root/src/base.known_dependencies";

    return {} unless -f $known_file;

    open my $fh, '<', $known_file or return {};
    my @lines = <$fh>;
    close $fh;

    ## Strip P7 header and signature footer ##
    my $in_data = 0;
    my @data_lines;

    for my $line (@lines) {
        if ( $line =~ m|^## \[:< ##| ) {
            $in_data = 1;
            next;
        }
        next unless $in_data;
        last if $line =~ m|^#,,|;
        push @data_lines, $line;
    }

    my $code = join '', @data_lines;
    $code =~ s|^\s*# name = .*\n||m;

    my $known = eval $code;
    if ($EVAL_ERROR) {
        warn "Error parsing known dependencies: $EVAL_ERROR";
        return {};
    }

    return $known->{$section} // {};
}

##[ scan_zenki_pm_deps ]######################################################

sub scan_zenki_pm_deps {
    my ($p7_root) = @_;

    my %pm_deps;
    return \%pm_deps unless defined $p7_root and length $p7_root;

    my @scan_sources = (
        ##  runtime-owned registration location [ authoritative ]  ##
        { base => "$p7_root/var/zenki-deps/p-mod", legacy => 0 },

        ##  legacy tracked-tree location [ transition merge ]  ##
        { base => "$p7_root/cfg/zenki", legacy => 1 },
    );

    for my $source (@scan_sources) {
        my $zenki_base = $source->{'base'};
        my $is_legacy  = $source->{'legacy'};

        next unless -d $zenki_base;

        opendir my $dh, $zenki_base or next;
        while ( my $zenka = readdir $dh ) {
            next if $zenka =~ m|^\.|;

            my $pm_dep_dir
                = $is_legacy
                ? "$zenki_base/$zenka/deps/p-mod"
                : "$zenki_base/$zenka";

            next unless -d $pm_dep_dir;

            opendir my $pdh, $pm_dep_dir or next;
            while ( my $file = readdir $pdh ) {
                next if $file =~ m|^\.|;

                my $module = $file;
                $module =~ s|__|::|g;
                push @{ $pm_deps{$module} }, $zenka;
            }
            closedir $pdh;
        }
        closedir $dh;
    }

    return \%pm_deps;
}

##[ probe_module ]############################################################

sub probe_module {
    my ($module_name) = @_;

    return 0 unless defined $module_name && length $module_name;

    my $file = $module_name;
    $file =~ s|::|/|g;
    $file .= '.pm';

    eval {
        local $SIG{__DIE__}  = sub { };
        local $SIG{__WARN__} = sub { };
        require $file;
    };

    return $EVAL_ERROR ? 0 : 1;
}

##[ probe_module_file ]#######################################################

## installed = its .pm file is found in @INC -- NOT loaded. for long-lived ##
## processes [ v7-zenki ] : require would load every zenka's modules into  ##
## it [ memory, Inline compiles, signal handlers set at load time ]        ##

sub probe_module_file {
    my ($module_name) = @_;

    return 0 unless defined $module_name && length $module_name;
    return 0 unless $module_name =~ m|^[A-Za-z_]\w*(?:::\w+)*$|;

    ( my $file = $module_name ) =~ s|::|/|g;
    $file .= '.pm';

    return 1 if exists $INC{$file};    ## already loaded ##
    for my $dir (@INC) {
        next     if ref $dir;          ## code ref hooks ##
        return 1 if -f "$dir/$file";
    }
    return 0;
}

##[ resolve_install ]#########################################################

sub resolve_install {
    my ( $module_name, $known_deps ) = @_;

    $known_deps //= {};

    my $known = $known_deps->{$module_name};

    if ( $known && $known->{debian} ) {
        my @debs;
        if ( ref( $known->{debian} ) eq 'ARRAY' ) {
            @debs = grep { !m|^cpan:| } @{ $known->{debian} };
        }
        if (@debs) {
            return { method => 'debian', pkg => $debs[0] };
        }
    }

    my $cpan = $known->{cpan_fallback} // $known->{cpan} // $module_name;

    return { method => 'cpan', pkg => $cpan };
}

1;

#,,..,.,.,,,.,.,.,,..,,..,.,,,,,.,,,.,,..,...,.,.,...,...,.,.,...,..,,,..,,.,,
#SRG3MUXFMJNONZXI74JXAWP7VT5FZKRY3HOBWCG4KXZNCGILEHD26R3BFW5JSUOELKEARPPWDGHPG
#\\\|SYQGPSJEBDRN3RECXWVHCIBS4J36X4M53W2SBEF2SOOUCBNVFT4 \ / AMOS7 \ YOURUM ::
#\[7]3TOXKL4TD6LLCOCE7SLOHJNC3YISZRCR5FPT5ZAPIFZLPD3UX6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
