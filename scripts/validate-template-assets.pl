#!/usr/bin/env perl

## [:< ##
# name = validate-template-assets.pl
# descr = Parse templates, extract asset references, auto-copy missing assets from data/

use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Path qw(make_path);
use File::Basename;

## Configuration ##
my $project_root = $ENV{PROJECT_ROOT} || "/data/projects/protocol-7";
my $template_dir = "$project_root/var/httpd/skins";
my $static_dir   = "$project_root/var/httpd/static";
my $data_dir     = "$project_root/data";

## Asset source mapping ##
my %asset_sources = (
    '/static/gfx/logos/' => "$data_dir/gfx/logos/",
    '/static/css/'       => "$data_dir/web/css/",
    '/static/js/'        => "$data_dir/web/js/",
    '/static/fonts/'     => "$data_dir/fonts/",
);

## Statistics ##
my $templates_scanned = 0;
my $assets_found      = 0;
my $assets_missing    = 0;
my $assets_copied     = 0;
my %asset_references;

print ".:[ Protocol-7 Template Asset Validator ]:.\n\n";
print "Project root: $project_root\n";
print "Template dir: $template_dir\n";
print "Static dir:   $static_dir\n";
print "\n";

## Find all .tmpl files ##
my @template_files;
find(
    sub {
        push @template_files, $File::Find::name if /\.tmpl$/;
    },
    $template_dir
);

print "[*] Found " . scalar(@template_files) . " template file(s)\n\n";

## Process each template ##
foreach my $template_file (@template_files) {
    print "[ ] Scanning: " . basename($template_file) . "\n";
    process_template($template_file);
    $templates_scanned++;
}

## Summary ##
print "\n";
print "=" x 70 . "\n";
print "Summary:\n";
print "  Templates scanned:    $templates_scanned\n";
print "  Asset references:     $assets_found\n";
print "  Assets missing:       $assets_missing\n";
print "  Assets auto-copied:   $assets_copied\n";
print "=" x 70 . "\n";

if ( $assets_copied > 0 ) {
    print "\n[✓] Successfully resolved $assets_copied missing asset(s)\n";
} elsif ( $assets_missing > 0 ) {
    print "\n[!] Warning: $assets_missing asset(s) could not be resolved\n";
    exit 1;
} else {
    print "\n[✓] All assets validated successfully\n";
}

exit 0;

## Process a template file ##
sub process_template {
    my ($file) = @_;

    open( my $fh, '<', $file ) or do {
        print "    [!] Cannot read: $!\n";
        return;
    };

    my $content = do { local $/; <$fh> };
    close($fh);

    ## Extract asset references ##
    ## Pattern matches: src="/path" href="/path" url('/path') url("/path")
    my @patterns = (
        qr{src=["']([^"']+)["']},       # <img src="..." />
        qr{href=["']([^"']+)["']},      # <link href="..." />
        qr{url\(['"]([^'"]+)['"]\)},    # url('...') in CSS
    );

    my %seen;
    foreach my $pattern (@patterns) {
        while ( $content =~ /$pattern/g ) {
            my $asset_path = $1;

            ## Only process /static/* paths ##
            next unless $asset_path =~ m{^/static/};
            next if $seen{$asset_path}++;

            $assets_found++;
            $asset_references{$asset_path}++;

            validate_asset($asset_path);
        }
    }
}

## Validate and resolve an asset ##
sub validate_asset {
    my ($web_path) = @_;

    ## Convert web path to filesystem path ##
    my $fs_path = "$project_root/var/httpd$web_path";

    if ( -f $fs_path ) {
        print "    [✓] $web_path (exists)\n";
        return;
    }

    ## Asset missing - try to resolve from data/ ##
    print "    [!] $web_path (missing)\n";
    $assets_missing++;

    my $source_path = resolve_source_path($web_path);

    if ( !$source_path ) {
        print "        └─ Cannot resolve source path\n";
        return;
    }

    if ( !-f $source_path ) {
        print "        └─ Source not found: $source_path\n";
        return;
    }

    ## Copy asset ##
    print "        └─ Copying from: $source_path\n";

    my $target_dir = dirname($fs_path);
    make_path($target_dir) unless -d $target_dir;

    if ( copy( $source_path, $fs_path ) ) {
        chmod( 0644, $fs_path );
        print "        └─ [✓] Copied successfully\n";
        $assets_copied++;
        $assets_missing--;
    } else {
        print "        └─ [!] Copy failed: $!\n";
    }
}

## Resolve asset web path to data/ source path ##
sub resolve_source_path {
    my ($web_path) = @_;

    ## Try each mapping ##
    foreach my $prefix ( keys %asset_sources ) {
        if ( $web_path =~ m{^\Q$prefix\E(.+)$} ) {
            my $filename    = $1;
            my $source_dir  = $asset_sources{$prefix};
            my $source_path = "$source_dir$filename";

            return $source_path if -f $source_path;

            ## Try common variations ##
            ## e.g., nailara_logo.trans-dark.png might be in data/gfx/logos/
            my $basename = basename($filename);
            my $alt_path = "$source_dir$basename";
            return $alt_path if -f $alt_path;
        }
    }

    return undef;
}

#,,,,,.,.,,,,,.,,,,,.,,,,,.,.,.,,,.,.,.,...,,,.,.,,,...,.,,,.,...,...,...,,,..,
#PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_1
#\\\\|PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_2
#\\[7]PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_3
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
