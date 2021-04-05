#!/usr/bin/perl -T

$ENV{'PATH'} = '/bin:/usr/bin';

use strict;
use warnings;

use Digest::SHA;
use Archive::Tar;
use LWP::UserAgent;
use File::Path qw(make_path);

my $impressive_version = '0.11.1';

print "\n :\n : installing impressive version $impressive_version ..\n";

my @download_urls = (
    'http://sourceforge.net/projects/impressive/files/'
        . "Impressive/$impressive_version/"
        . "Impressive-$impressive_version.tar.gz/download",
    "http://mirror.nailara.net/impressive/Impressive-$impressive_version.tar.gz"
);

my $paths = {
    'archive_tmp' => "/tmp/Impressive-$impressive_version.tar.gz",
    'install_dir' => '/usr/local/impressive'
};

my $file_sizes
    = { 'archive' => 195743, 'impressive.py' => 244877 };    # v_0.11.1
my $sha1_checksums = {
    'archive'       => '0f47caec3abd0398814550cabfb78ecca8b5eb85',
    'impressive.py' => 'b35f9bdc5c702cb8865bfc618fc0fd497566af88'
};

my $target_path = $paths->{'install_dir'} . '/bin/impressive';

if ( -f $target_path ) {
    if ( [ stat($target_path) ]->[7] == $file_sizes->{'impressive.py'}
        and Digest::SHA->new(1)->addfile($target_path)->hexdigest eq
        $sha1_checksums->{'impressive.py'} ) {
        print " : impressive v$impressive_version is already installed!"
            . " [checksum OK]\n :\n\n";
        if ( -f $paths->{'archive_tmp'} ) {
            unlink( $paths->{'archive_tmp'} )
                or warn " [!] failed to remove "
                . $paths->{'archive_tmp'}
                . ": $!\n\n";
        }
        exit;
    } else {
        print " : <!> removing previously installed impressive version ..\n";
        unlink($target_path)
            or
            installation_failed("failed to delete file '$target_path' [$!]");
    }
}
my $delete_archive = 0;
if ( -f $paths->{'archive_tmp'} ) {
    if (&size_OK) {
        if ( Digest::SHA->new(1)->addfile( $paths->{'archive_tmp'} )
            ->hexdigest eq $sha1_checksums->{'archive'} ) {
            print " : archive already exists ( checksum OK )\n";
        } else {
            $delete_archive = 1;
        }
    } else {
        $delete_archive = 1;
    }
}
if ($delete_archive) {
    unlink( $paths->{'archive_tmp'} )
        or die "failed to delete archive [$!]";
}
if ( !-f $paths->{'archive_tmp'} ) {
    my $download = LWP::UserAgent->new();
    $download->max_size( $file_sizes->{'archive'} );
    foreach my $url (@download_urls) {
        my ($server) = $url =~ m|://([^/]+)/|;
        my $failed   = 0;
        my $err_msg  = '';
        print " : downloading archive from $server ..\n";
        my $response = $download->get( $url,
            ':content_file' => $paths->{'archive_tmp'} );
        if ( !$response->is_success ) {
            $err_msg = $response->status_line;
            $failed  = 1;
        }
        if ( !$failed and &size_OK ) {
            if ( Digest::SHA->new(1)->addfile( $paths->{'archive_tmp'} )
                ->hexdigest eq $sha1_checksums->{'archive'} ) {
                print " : download succeeded ( archive checksum OK )\n";
            } else {
                $err_msg = 'ARCHIVE CHECKSUM MISMATCH';
                $failed  = 1;
            }
        } elsif ( !$failed ) {
            $err_msg = 'invalid archive size';
            $failed  = 1;
        }
        if ($failed) {
            if ( -f $paths->{'archive_tmp'} ) {
                unlink( $paths->{'archive_tmp'} )
                    or installation_failed("failed to delete archive [$!]");
            }
            print " : : DOWNLOAD FAILED [$err_msg]\n";
        } else {
            last;
        }
    }
}
if ( !-f $paths->{'archive_tmp'} ) {
    installation_failed('unable to download archive');
} else {
    my $tar          = Archive::Tar->new;
    my $install_dir  = $paths->{'install_dir'};
    my $extract_file = "Impressive-$impressive_version/impressive.py";
    $tar->read( $paths->{'archive_tmp'} )
        or installation_failed("failed to open archive file [$!]");
    if ( Digest::SHA->new(1)->add( $tar->get_content($extract_file) )
        ->hexdigest ne $sha1_checksums->{'impressive.py'} ) {
        installation_failed("CHECKSUM MISMATCH ['impressive.py']");
    }
    if ( !-d $install_dir ) {
        print " : creating installation directory '$install_dir'..\n";
        my $err;
        eval {
            make_path(
                $install_dir,
                {   'error' => \$err,
                    'uid'   => 0,
                    'group' => 0,
                    'mode'  => 0755
                }
            );
        };
        if ( !-d $install_dir ) {
            my ( $file, $message ) = %{ $$err[0] };
            installation_failed(
                "failed to create directory '$install_dir' [$message]");
        }
    }
    print " : extracting to '$target_path'..\n";
    make_path( "$install_dir/bin",
        { 'uid' => 0, 'group' => 0, 'mode' => 0755 } );
    $tar->extract_file( $extract_file, $target_path )
        or installation_failed("failed to extract 'impressive.py' [$!]");
    if ( [ stat($target_path) ]->[7] == $file_sizes->{'impressive.py'}
        and Digest::SHA->new(1)->addfile($target_path)->hexdigest eq
        $sha1_checksums->{'impressive.py'} ) {
        qx(touch $target_path);    # timestamp
        chown( 0, 0, $target_path )
            or installation_failed("chown failed : $!");
        unlink( $paths->{'archive_tmp'} )
            or warn " : [!] failed to delete archive [$!]\n";
        print " : installation successful =) [ checksum OK ]\n :\n\n";
        exit;
    } else {
        unlink( $paths->{'archive_tmp'} )
            or warn " : [!] failed to delete archive [$!]\n";
        unlink($target_path) or warn "unlink($target_path) : $1\n";
        installation_failed("error during file extraction");
    }
}

sub installation_failed {
    my $reason = shift;
    if ( -f $paths->{'archive_tmp'} ) {
        unlink( $paths->{'archive_tmp'} )
            or warn " : [!] failed to delete archive [$!]\n";
    }
    if ( -f $target_path ) {
        unlink($target_path)
            or warn " : [!] failed to '$target_path' [$!]\n";
    }
    qx(rmdir $paths->{install_dir}) if -d $paths->{'install_dir'};
    die " :\n : INSTALLATION FAILED ( $reason )\n :\n\n";
}

sub size_OK {
    return [ stat( $paths->{'archive_tmp'} ) ]->[7]
        == $file_sizes->{'archive'};
}
