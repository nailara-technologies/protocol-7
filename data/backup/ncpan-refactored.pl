#!/usr/bin/perl

use v5.36;
use strict;
use warnings;
use English;
use HTTP::Tiny;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catfile catdir);
use File::Basename qw(dirname);
use File::Find;
use JSON::PP;
use Config;

my $CONFIG = {
    qw|cpan| => {
        qw|server|     => qw|www.cpan.org|,
        qw|modlist|    => qw|/modules/02packages.details.txt.gz|,
        qw|module_dir| => qw|/authors/id/|,
        qw|timeout|    => 30,
    },
    qw|paths| => {
        qw|base|    => $ENV{HOME} // qw|/var/tmp|,
        qw|work|    => qw|.ncpan|,
        qw|modules| => qw|modules|,
        qw|cache|   => qw|cache|,
    },
    qw|files| => {
        qw|modlist| => qw|02packages.details.txt|,
        qw|config|  => qw|config.json|,
    }
};

my $PATHS = setup_paths($CONFIG);

my %COMMANDS = (
    qw|list-installed| => \&cmd_list_installed,
    qw|uninstall|      => \&cmd_uninstall,
    qw|update|         => \&cmd_update,
    qw|search|         => \&cmd_search,
    qw|readme|         => \&cmd_show_readme,
    qw|install|        => \&cmd_install,
    qw|force-install|  => sub { cmd_install(@_, force => 1) },
    qw|install-file|   => \&cmd_install_file,
);

my ($cmd, @args) = @ARGV;

if (!$cmd || !exists $COMMANDS{$cmd}) {
    show_usage();
    exit 1;
}

$COMMANDS{$cmd}->(@args);
exit 0;

sub setup_paths {
    my ($cfg) = @_;
    
    my $paths = {};
    my $base = catdir($cfg->{paths}{base}, $cfg->{paths}{work});
    
    $paths->{base}    = $base;
    $paths->{modules} = catdir($base, $cfg->{paths}{modules});
    $paths->{cache}   = catdir($base, $cfg->{paths}{cache});
    $paths->{modlist} = catfile($paths->{cache}, $cfg->{files}{modlist});
    $paths->{config}  = catfile($base, $cfg->{files}{config});
    
    for my $dir ($paths->{base}, $paths->{modules}, $paths->{cache}) {
        if (-f $dir) {
            unlink $dir or die "Cannot remove file $dir: $!\n";
        }
        make_path($dir) unless -d $dir;
    }
    
    return $paths;
}

sub get_http_client {
    state $client = HTTP::Tiny->new(
        timeout => $CONFIG->{cpan}{timeout},
        verify_SSL => 1,
    );
    return $client;
}

sub download_file {
    my ($url, $output_file) = @_;
    
    my $http = get_http_client();
    my $response = $http->get($url);
    
    die "Failed to download $url: " . $response->{status} . "\n"
        unless $response->{success};
        
    open my $fh, qw|>|, $output_file
        or die "Cannot write to $output_file: $!\n";
    
    print $fh $response->{content};
    close $fh;
    
    return 1;
}

sub parse_dependencies {
    my ($makefile) = @_;
    my @deps;
    
    open my $fh, qw|<|, $makefile
        or die "Cannot read $makefile: $!\n";
    
    my $in_prereq = 0;
    while (<$fh>) {
        chomp;
        s|\s*#.*$||;  # Remove comments
        next if m|^\s*$|;
        
        if (m|^\s*'?PREREQ_PM'?\s*=>\s*\{|) {
            $in_prereq = 1;
            next;
        }
        
        if ($in_prereq) {
            if (m|^\s*\}|) {
                $in_prereq = 0;
                next;
            }
            
            if (m|^\s*'([^']+)'\s*=>\s*'?([\d\.]+)'?,?$|) {
                push @deps, [$1, $2];
            }
        }
        
        if (m|requires\s+'([^']+)'\s*=>\s*'?([\d\.]+)'?,?$|) {
            push @deps, [$1, $2];
        }
    }
    
    close $fh;
    return @deps;
}

sub extract_archive {
    my ($archive, $dest_dir) = @_;
    
    system(qw|tar xzf|, $archive, qw|-C|, $dest_dir) == 0
        or die "Failed to extract $archive: $!\n";
        
    return get_extracted_dir($dest_dir);
}

sub get_extracted_dir {
    my ($base_dir) = @_;
    
    opendir my $dh, $base_dir
        or die "Cannot read $base_dir: $!\n";
        
    my @entries = grep { !m|^\.| } readdir($dh);
    closedir $dh;
    
    return catdir($base_dir, $entries[0]) if @entries == 1;
    die "Unexpected archive content in $base_dir\n";
}

sub cmd_update {
    say "Updating module list...";
    
    my $url = "http://$CONFIG->{cpan}{server}$CONFIG->{cpan}{modlist}";
    my $gz_file = "$PATHS->{modlist}.gz";
    
    download_file($url, $gz_file);
    
    gunzip $gz_file => $PATHS->{modlist}
        or die "Gunzip failed: $GunzipError\n";
        
    unlink $gz_file;
    
    say "Module list updated successfully";
}

sub cmd_search {
    my ($pattern) = @_;
    die "Search pattern required\n" unless $pattern;
    
    open my $fh, qw|<|, $PATHS->{modlist}
        or die "Cannot read module list. Run 'update' first.\n";
    
    while (<$fh>) {
        next unless m|^(\S+)\s+(\S+)\s+(\S+)|;
        my ($name, $version, $path) = ($1, $2, $3);
        
        if ($name =~ m|$pattern|i) {
            printf "%-40s %s\n", $name, $version ne qw|undef| ? "v$version" : '';
        }
    }
    
    close $fh;
}

sub cmd_install {
    my ($module_name, %opts) = @_;
    die "Module name required\n" unless $module_name;
    
    my $mod_info = find_module($module_name)
        or die "Module '$module_name' not found\n";
    
    my $work_dir = prepare_build_dir($mod_info);
    
    if ($opts{force}) {
        build_module($work_dir, skip_tests => 1);
    } else {
        build_module($work_dir);
    }
    
    cleanup_build($work_dir);
}

sub get_readme_url {
    my ($mod_info) = @_;
    my $path = $mod_info->{path};
    $path =~ s|\.tar\.gz$|\.readme|;
    return "http://$CONFIG->{cpan}{server}$CONFIG->{cpan}{module_dir}$path";
}

sub cmd_show_readme {
    my ($module_name) = @_;
    die "Module name required\n" unless $module_name;
    
    my $mod_info = find_module($module_name)
        or die "Module '$module_name' not found\n";
        
    my $readme_url = get_readme_url($mod_info);
    my $readme = get_http_client()->get($readme_url);
    
    if ($readme->{success}) {
        my $pager = $ENV{PAGER} // qw|less|;
        open my $fh, '|-', $pager
            or die "Cannot open pager: $!\n";
        print $fh $readme->{content};
        close $fh;
    } else {
        say "No README found for $module_name";
    }
}

sub find_module {
    my ($name) = @_;
    
    open my $fh, qw|<|, $PATHS->{modlist}
        or die "Cannot read module list. Run 'update' first.\n";
        
    while (<$fh>) {
        next unless m|^(\S+)\s+(\S+)\s+(\S+)|;
        return {name => $1, version => $2, path => $3}
            if $1 eq $name;
    }
    
    close $fh;
    return;
}

sub prepare_build_dir {
    my ($mod_info) = @_;
    
    my $url = "http://$CONFIG->{cpan}{server}$CONFIG->{cpan}{module_dir}$mod_info->{path}";
    my $archive = catfile($PATHS->{modules}, $mod_info->{path});
    my $build_dir = catdir($PATHS->{modules}, qw|build|);
    
    make_path(dirname($archive));
    remove_tree($build_dir);
    make_path($build_dir);
    
    download_file($url, $archive);
    my $src_dir = extract_archive($archive, $build_dir);
    
    unlink $archive;
    return $src_dir;
}

sub build_module {
    my ($dir, %opts) = @_;
    
    chdir $dir or die "Cannot chdir to $dir: $!\n";
    
    system($^X, qw|Makefile.PL|) == 0
        or die "Failed to create Makefile\n";
        
    system(qw|make|) == 0
        or die "Build failed\n";
        
    unless ($opts{skip_tests}) {
        system(qw|make test|) == 0
            or die "Tests failed\n";
    }
    
    if ($EFFECTIVE_USER_ID == 0) {
        system(qw|make install|) == 0
            or die "Installation failed\n";
    } else {
        system(qw|sudo make install|) == 0
            or die "Installation failed\n";
    }
}

sub cmd_install_file {
    my ($archive_path) = @_;
    die "File path required\n" unless $archive_path;
    die "File not found: $archive_path\n" unless -f $archive_path;
    die "Not a .tar.gz file\n" unless $archive_path =~ m|\.tar\.gz$|;

    my $build_dir = catdir($PATHS->{modules}, qw|build|);
    remove_tree($build_dir);
    make_path($build_dir);
    
    my $src_dir = extract_archive($archive_path, $build_dir);
    build_module($src_dir);
    cleanup_build($build_dir);
}

sub cmd_list_installed {
    my ($pattern) = @_;
    my @paths = (
        @INC,
        $Config{installsitelib},
        $Config{installvendorlib},
        $Config{installprivlib},
    );
    
    my %seen;
    my %modules;
    
    for my $path (@paths) {
        next unless -d $path;
        find(
            {
                wanted => sub {
                    return unless m|\.pm$|;
                    my $mod = $File::Find::name;
                    $mod =~ s|^$path/||;
                    $mod =~ s|/|::|g;
                    $mod =~ s|\.pm$||;
                    return if $seen{$mod}++;
                    return if $pattern && $mod !~ m|$pattern|i;
                    
                    my $version = eval {
                        local @INC = ($path);
                        my $file = "$path/$mod.pm";
                        local $SIG{__WARN__} = sub {};
                        require $file;
                        my $pkg = $mod;
                        no strict qw|refs|;
                        ${$pkg . "::VERSION"} // qw|unknown|;
                    };
                    $modules{$mod} = $version // qw|n/a|;
                },
                no_chdir => 1,
            },
            $path
        );
    }
    
    printf "%-40s %s\n", qw|Module|, qw|Version|;
    say qw|=| x 50;
    
    for my $mod (sort keys %modules) {
        printf "%-40s %s\n", $mod, $modules{$mod};
    }
}

sub cmd_uninstall {
    my ($target_module) = @_;
    die "Module name required\n" unless $target_module;
    
    eval "require $target_module" or die "Module not installed: $target_module\n";
    
    my $target_path = $target_module;
    $target_path =~ s|::|/|g;
    $target_path .= qw|.pm|;
    
    my $target_file = $INC{$target_path} or die "Cannot find module path\n";
    
    if ($EFFECTIVE_USER_ID == 0) {
        if (-f qw|Makefile.PL|) {
            system(qw|make uninstall|);
        }
        unlink $target_file or warn "Failed removing $target_file: $!\n";
    } else {
        if (-f qw|Makefile.PL|) {
            system(qw|sudo make uninstall|);
        }
        system(qw|sudo rm|, $target_file) == 0 
            or warn "Failed removing $target_file\n";
    }
    
    say "Uninstalled $target_module";
}

sub cleanup_build {
    my ($dir) = @_;
    chdir $PATHS->{base} or die "Cannot chdir to $PATHS->{base}: $!\n";
    remove_tree($dir);
}

sub show_usage {
    say "Usage: ncpan <command> [args]";
    say "Commands:";
    say "  update                    Update module list";
    say "  list-installed [pattern]  List installed modules";
    say "  search <pattern>          Search for modules";
    say "  install <module>          Install a module";
    say "  force-install <mod>       Install without testing";
    say "  install-file <file>       Install from .tar.gz";
    say "  uninstall <module>        Remove installed module";
    say "  readme <module>           Show module README";
}
