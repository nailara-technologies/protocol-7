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

sub load_known_deps {
    my ($p7_root) = @_;

    my $known_file = "$p7_root/modules/base.known_dependencies";

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

    return $known->{perlmod} // {};
}

##[ scan_zenki_pm_deps ]######################################################

sub scan_zenki_pm_deps {
    my ($zenki_base) = @_;

    my %pm_deps;
    return \%pm_deps unless -d $zenki_base;

    opendir my $dh, $zenki_base or return \%pm_deps;
    while ( my $zenka = readdir $dh ) {
        next if $zenka =~ /^\./;

        my $pm_dep_dir = "$zenki_base/$zenka/pm-dep";
        next unless -d $pm_dep_dir;

        opendir my $pdh, $pm_dep_dir or next;
        while ( my $file = readdir $pdh ) {
            next if $file =~ /^\./;

            my $module = $file;
            $module =~ s/__/::/g;
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
            @debs = grep { !/^cpan:/ } @{ $known->{debian} };
        }
        if (@debs) {
            return { method => 'debian', pkg => $debs[0] };
        }
    }

    my $cpan = $known->{cpan_fallback}
        // $known->{cpan}
        // $module_name;

    return { method => 'cpan', pkg => $cpan };
}

1;

#,,,,,.,,,,.,,,,,,,,,,..,,...,,..,,,,,,..,,.,,..,,...,...,,.,,.,,,..,,,..,...,
#5PGRYJA26WQT55KW34P6QW7PWAJVWZJGEGIOJNY47TV2Z4UHIA5CVN6QB6GJZNFNP55FYS33BJFTA
#\\\|OPS2YYOS67EIAS3YBDVFU22PT2SE4IKMJQJWA4URJOLK2CGKDWU \ / AMOS7 \ YOURUM ::
#\[7]SY2JISZ37WCZNJZGUA7LNZQLJVIUDGTMOWJPXY7MOHBFPUZ6X6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
