#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use JSON::PP;
use MIME::Base64;

die "Usage: $0 <directory>\n\nExample:\n"
    . "  $0 ~/.lmstudio/user-files\n  $0 /path/to/images\n"
    unless @ARGV;

my $dir = $ARGV[0];
die "Directory not found: $dir\n" unless -d $dir;

chdir $dir or die "Cannot chdir to $dir: $!\n";

# Find all PNG/JPG files and their metadata JSON pairs
opendir my $dh, '.' or die "Cannot open directory: $!\n";
my @image_files = grep {m,\.(png|jpg)$,i} readdir $dh;
closedir $dh;

die "No image files found\n" unless @image_files;

print "Found " . scalar(@image_files) . " image files\n";

my $total_saved   = 0;
my $files_updated = 0;

foreach my $image_file ( sort @image_files ) {
    my $metadata_file = "$image_file.metadata.json";

    next unless -f $metadata_file;

    # Determine MIME type from file extension
    my $mime_type = $image_file =~ /\.jpg$/i ? 'image/jpeg' : 'image/png';

    # Read the image file
    open my $img_fh, '<:raw', $image_file or do {
        warn "Cannot read $image_file: $!\n";
        next;
    };
    my $image_data = do { local $/; <$img_fh> };
    close $img_fh;

    my $new_b64      = encode_base64( $image_data, '' );    # No line breaks
    my $new_data_uri = "data:$mime_type;base64,$new_b64";

    # Read metadata JSON
    open my $json_fh, '<:raw', $metadata_file or do {
        warn "Cannot read $metadata_file: $!\n";
        next;
    };
    my $json_content = do { local $/; <$json_fh> };
    close $json_fh;

    my $original_json_size = length($json_content);

    # Parse JSON
    my $json = JSON::PP->new->utf8;
    my $data;
    eval { $data = $json->decode($json_content); };
    if ($@) {
        warn "Failed to parse $metadata_file: $@\n";
        next;
    }

    # Check if preview.data exists
    next unless exists $data->{preview} && exists $data->{preview}{data};

    my $old_data_uri = $data->{preview}{data};

    # Only replace if new version is smaller
    if ( length($new_data_uri) < length($old_data_uri) ) {
        $data->{preview}{data} = $new_data_uri;

        # Write updated JSON
        my $updated_json = $json->canonical->pretty->encode($data);

        open $json_fh, '>:raw', $metadata_file or do {
            warn "Cannot write $metadata_file: $!\n";
            next;
        };
        print $json_fh $updated_json;
        close $json_fh;

        my $new_json_size = length($updated_json);
        my $saved         = $original_json_size - $new_json_size;

        printf "%-50s: %d bytes -> %d bytes [ saved %d bytes ]\n",
            $metadata_file,
            length($old_data_uri),
            length($new_data_uri),
            $saved;

        $total_saved += $saved;
        $files_updated++;
    } else {
        printf "%-50s: already optimized (no change needed)\n",
            $metadata_file;
    }
}

print "\n=== Summary ===\n";
printf "Files updated: %d\n",     $files_updated;
printf "Total bytes saved: %d\n", $total_saved;
print "Done!\n";

#,,,.,.,.,.,,,..,,..,,..,,,,.,,.,,,,,,.,.,,..,..,,...,...,..,,,,.,..,,,..,.,,,
#OGTINVZDEL75DQ5MSLBNE6OIGWSXUZOYLW2GPLQIBBSDBTL7ON33UCVC6WVMX6NXVWJUTUMOKFMCA
#\\\|LVYMIWIXOM2FYMXUHX2T2NSJ7N4X5L2QDIK5MGIQVUBXHH62DUA \ / AMOS7 \ YOURUM ::
#\[7]MTYNOAVCZWGOP5OD7GMBMSIIGETJ3XMDTUTNNA6MEHEIOMBCRECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
