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
    resolve_install
    |;

##[ load_known_deps ]#########################################################

## single canonical accessor for src/base.known_dependencies data :        ##
## reachable from both zenka and standalone-script contexts, so callers    ##
## never need the <[base.known_dependencies]> P7-module-invocation route [ ##
## zenka-context only ] for this data. $section selects the data section [ ##
## default 'perlmod' ] ; the underlying file can be re-routed or upgraded  ##
## later without hunting down every caller                                 ##

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
    my ($zenki_base) = @_;

    my %pm_deps;
    return \%pm_deps unless -d $zenki_base;

    opendir my $dh, $zenki_base or return \%pm_deps;
    while ( my $zenka = readdir $dh ) {
        next if $zenka =~ m|^\.|;

        my $pm_dep_dir = "$zenki_base/$zenka/deps/p-mod";
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

#,,,,,.,.,...,.,,,,,,,.,.,..,,,..,,..,...,..,,.,.,...,...,.,.,...,,.,,..,,,,,,
#XC66FGJXKESNSJZDZJT4CSGOII7J7ZZXASG34ETCRFT5VE3D54ZWXGM7YP6JZSNRJY2ZAFQBVA4QS
#\\\|FG26QA3WLK47O73STGAS5FDW4Z4ODTK6DUKRZJRNFENWOWJADMJ \ / AMOS7 \ YOURUM ::
#\[7]HEQVM6NGMN2VA2W5OSO2XCGAN4SJ2XJJOJZ2D3FECCMXL6DH4IBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
