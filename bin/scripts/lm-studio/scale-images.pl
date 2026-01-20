#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Temp qw(tempfile);
use File::Copy;
use Image::Magick;

die "Usage: $0 <directory> [max_width] [max_height]\n\nExample:\n"
    . "  $0 /path/to/images\n  $0 /path/to/images 800 800\n  $0 . 512 512\n"
    unless @ARGV;

my $dir        = $ARGV[0];
my $max_width  = $ARGV[1] || 1024;
my $max_height = $ARGV[2] || 1024;

die "Directory not found: $dir\n" unless -d $dir;

print "Scaling images in: $dir\n";
print "Max dimensions: ${max_width}x${max_height}\n\n";

my $total_saved     = 0;
my $files_processed = 0;
my $files_skipped   = 0;

File::Find::find(
    sub {
        return unless /\.(png|jpg|jpeg|webp|gif)$/i;
        return if -l $_;    # Skip symlinks

        my $file = $_;
        my $path = $File::Find::name;

        # Get original file size
        my $original_size = -s $path;

        # Create Magick object
        my $image = Image::Magick->new;
        my $err   = $image->Read($path);

        if ($err) {
            warn "Failed to read $path: $err\n";
            return;
        }

        # Get current dimensions
        my @geometry = $image->Get( 'width', 'height' );
        my ( $width, $height ) = @geometry;

        # Check if scaling is needed
        if ( $width <= $max_width && $height <= $max_height ) {
            print "SKIP: $path ($width x $height - already optimal)\n";
            $files_skipped++;
            undef $image;
            return;
        }

        # Scale the image
        my $scale_geometry = "${max_width}x${max_height}";
        $err = $image->Resize(
            geometry => $scale_geometry,
            filter   => 'Lanczos'
        );

        if ($err) {
            warn "Failed to resize $path: $err\n";
            undef $image;
            return;
        }

        # Get new dimensions
        @geometry = $image->Get( 'width', 'height' );
        my ( $new_width, $new_height ) = @geometry;

        # Write to temp file in same directory to avoid cross-device issues
        my $temp_path = "$path.tmp.$$";

        $err = $image->Write($temp_path);
        if ($err) {
            warn "Failed to write temp file: $err\n";
            unlink $temp_path;
            undef $image;
            return;
        }

        my $new_size = -s $temp_path;

        # Only replace if smaller (safety check)
        if ( $new_size < $original_size ) {
            move( $temp_path, $path ) or do {
                warn "Failed to replace $path: $!\n";
                unlink $temp_path;
                undef $image;
                return;
            };

            my $saved     = $original_size - $new_size;
            my $reduction = int( 100 * $saved / $original_size );

            printf
                ": SCALED : %-60s | %4dx%-4d -> %4dx%-4d "
                . "| %8d -> %8d bytes [-$reduction%%]\n",
                $path,
                $width,         $height,
                $new_width,     $new_height,
                $original_size, $new_size;

            $total_saved += $saved;
            $files_processed++;
        } else {
            print ":SKIP: $path [ scaled version not smaller, reverted ]\n";
            unlink $temp_path;
            $files_skipped++;
        }

        undef $image;
    },
    $dir
);

print "\n=== Summary ===\n";
printf "Files scaled: %d\n",      $files_processed;
printf "Files skipped: %d\n",     $files_skipped;
printf "Total bytes saved: %d\n", $total_saved;

if ( $total_saved > 0 ) {
    my $mb_saved = $total_saved / ( 1024 * 1024 );
    printf "Total MB saved: %.2f\n", $mb_saved;
}

print "Done!\n";

#,,.,,,.,,.,.,.,,,,.,,,.,,...,,.,,,..,...,.,.,..,,...,...,.,.,,,.,,,,,,,,,,,,,
#NRG5CLSTLOJJHXRV3KFNTOLHDQKOJF5D2AHDN75QPEWEMURIOPJIMHHAIT7XZPTNHTNKEFRYRRZTQ
#\\\|VSESY4FXPBEBTKW3LNLGETBA63WX4T6LDRPELZSUV6XDTCNVWE4 \ / AMOS7 \ YOURUM ::
#\[7]ED65QTDPEMJESGFTBSHJABB2ILP6JG3L7T2XFVHSCL4VWT2UPUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
