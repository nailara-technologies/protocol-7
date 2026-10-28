package AMOS7::deps::module;
our $VERSION = qw| AMOS7::deps::module-VERSION.LX3IXKQ |;

use strict;
use warnings;
use English;

use File::Spec;
use POSIX      ();
use File::Temp qw| tempdir |;
use File::Find qw| find |;
use File::Copy qw| copy |;
use File::Path qw| make_path remove_tree |;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw|
    load_known_deps
    scan_zenki_pm_deps
    probe_module
    probe_module_file
    resolve_install
    install_pm_src
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

    ## local pm-src sources come first : reproducible, and some hosts      ##
    ## cannot reach cpan at all [ upstream copies that no longer compile ] ##
    if (    $known
        and ref( $known->{pm_src} ) eq 'ARRAY'
        and scalar @{ $known->{pm_src} } ) {
        return { method => 'pm_src', dirs => [ @{ $known->{pm_src} } ] };
    }

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

##[ install_pm_src ]##########################################################

## builds modules from their local sources under data/lib-path/pm-src, in   ##
## the given order : each source dir is copied into a temporary directory   ##
## and built there with cpanm, so no build files ever land in the tree.     ##
## returns TRUE when every dir built [ caller falls back to cpan on FALSE ] ##

sub install_pm_src {
    my ( $p7_root, @dirs ) = @_;

    return 0 unless defined $p7_root and length $p7_root;
    return 0 unless scalar @dirs;

    local $ENV{'PERL_CANARY_STABILITY_NOPROMPT'} = 1;    ## no tty prompt ##

    my $pm_src_base
        = File::Spec->catdir( $p7_root, qw| data lib-path pm-src | );

    foreach my $src_dir (@dirs) {
        my $src_path = File::Spec->catdir( $pm_src_base, $src_dir );
        return 0 unless -d $src_path;

        my $tmp_dir    = _build_dir() // return 0;
        my $build_path = File::Spec->catdir( $tmp_dir, $src_dir );

        ## recursive copy into the tempdir [ no files land in the tree ] ##
        my $copied = _copy_tree( $src_path, $build_path );
        my $exit   = $copied ? _run_cpanm($build_path) : -1;
        remove_tree($tmp_dir);
        return 0 if $exit != 0;
    }

    return 1;
}

## cpanm with stdout + stderr merged : lines go to $output_handler when a ##
## caller set one [ a zenka log ], plain to STDOUT otherwise [ p7-deps ]  ##

our $output_handler;

sub _run_cpanm {
    my ($build_path) = @_;

    if ( ref $output_handler ne 'CODE' ) {
        return system( qw| cpanm --notest --quiet |, $build_path );
    }

    my $pid = open( my $cpanm_fh, '-|' );
    return -1 unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        { exec( qw| cpanm --notest --quiet |, $build_path ) };
        POSIX::_exit(127);    ## exec failed ##
    }

    while ( my $line = <$cpanm_fh> ) {
        chomp $line;
        $output_handler->($line) if length $line;
    }
    close $cpanm_fh;

    return $?;
}

## build dirs live under /var/protocol-7, never in /tmp. a zenka passes its ##
## base.file.temp path [ /var/protocol-7/<zenka>/.. ] as $build_dir ;       ##
## standalone tools get /var/protocol-7/p7-deps/pm-src.<rnd>                ##
## [ tempdir only when that is not writable ]. removed right after each     ##
## build : a zenka drops privileges before exit and could not remove it any ##
## more                                                                     ##

our $build_dir;

sub _build_dir {
    if ( defined $build_dir and length $build_dir ) {
        return undef if -e $build_dir;
        make_path( $build_dir, { 'mode' => 0700 } ) or return undef;
        return $build_dir;
    }

    my $var_base = qw| /var/protocol-7/p7-deps |;
    if ( -d $var_base and -w $var_base
        or eval { make_path( $var_base, { 'mode' => 0750 } ) } ) {
        return tempdir( 'pm-src.' . 'X' x 13, 'DIR' => $var_base );
    }

    return tempdir();
}

sub _copy_tree {
    my ( $src, $dst ) = @_;

    make_path($dst) unless -d $dst;

    my $ok = 1;
    find(
        sub {
            return unless $ok;
            my $rel  = File::Spec->abs2rel( $File::Find::name, $src );
            my $dest = File::Spec->catfile( $dst, $rel );
            if ( -d $File::Find::name ) {
                make_path($dest) unless -d $dest;
            } else {
                $ok = copy( $File::Find::name, $dest );
            }
        },
        $src
    );

    return $ok;
}

1;

#,,.,,..,,,..,...,.,,,...,..,,.,.,.,,,,,.,.,,,.,.,...,...,,.,,.,.,..,,,..,,.,,
#7AA6DA2XLDA37BUNJNJFDZZFN3MANBLTCSISYTVRE7E7E4MXIOSQAZZDWA3VBMGLHMA75YYFFU32U
#\\\|MR7PZ2C5WJEBPVHTEYO33RCKG3GFM7XMGDWSFYXNH3WQZMDYG4Z \ / AMOS7 \ YOURUM ::
#\[7]5KT7EQT5FKTPLIZ6Y55KY27VFO2TQTXW7XVZEIE76QD3W6JKFKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
