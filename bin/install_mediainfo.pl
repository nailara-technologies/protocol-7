#!/usr/bin/perl

use strict;
use warnings;

use File::Path qw(make_path);
use Digest::MD5 qw( md5_base64 );
use LWPx::ParanoidAgent;

if (    @ARGV
    and shift(@ARGV) eq '--if-missing'
    and length(qx(which mediainfo))
    and qx(mediainfo --Version) =~ /^MediaInfo / ) {
    print "\n:\n";
    my $local_version = &local_version;
    print ": mediainfo is present :) [not missing]\n:\n\n";
    exit(0);
}

my $ua = LWPx::ParanoidAgent->new;

$ENV{'PATH'} = '/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

my $rss_url  = 'https://mediaarea.net/rss/mediainfo_updates.xml';
my $base_url = 'https://mediaarea.net/download/binary/';
my $tmp_dir
    = '/var/cache/apt/archives/mediainfo_tmp.' . $$ . '-' . int( rand(55555) );

print "\n.\n";
my $local_version = &local_version;
print ": installed mediainfo version : $local_version\n";

my $online_version = &fetch_version;
print ": mediainfo version available : $online_version\n";

if ( $local_version eq 'not_found'
    or numeric($online_version) > numeric($local_version) ) {

    my $action = $local_version eq 'not_found' ? 'install' : 'upgrade to';

    print "  .\n  : going to $action mediainfo"
        . " version $online_version ...\n  :\n";

    my $arch = &host_architecture;
    print "  : target system architecture : $arch\n\n";

    my @package_urls = get_package_urls($arch);

    if ( $action ne 'install' ) {
        print "  : removing old mediainfo version...\n";
        system( 'apt-get', '-y', 'purge',   'mediainfo' );
        system( 'apt-get', '-y', '--purge', 'autoremove' );
    }

    print "  : creating tmp dir '$tmp_dir' ..\n";
    make_path( $tmp_dir, { 'mode' => 0750, 'uid' => 0, 'group' => 0 } )
        or warn "failed to create temporary directory '$tmp_dir' [$!]";

    my @downloaded_files;
    foreach my $url (@package_urls) {
        ( my $deb_name = $url ) =~ s|^.+/||;
        ( my $b64_name = md5_base64($deb_name) . '.deb' ) =~ s|/|_|g;
        print "  : downloading $deb_name ..\n"
            . "  :             > $b64_name\n";
        my $local_deb = "$tmp_dir/$b64_name";
        my $response;
        eval { $response = $ua->get( $url, ':content_file' => $local_deb ) };

        if ( not defined $response or !$response->is_success ) {
            my $err_msg = 'download failed';
            if ( defined $response ) {
                $err_msg .= ' [' . $response->status_line . ']';
            }
            die $err_msg;
        } else {
            print "  : installing ...\n";
            system( 'dpkg', '-i', $local_deb );
        }
        unlink($local_deb);
    }
    system( 'apt-get', '-fy', 'install' );

    print "  : removing tmp dir ..\n";
    rmdir($tmp_dir) or warn "rmdir($tmp_dir): $!";

    system( 'apt-get', 'clean' );
    print "  : done.\n\n";
    exit(0);

} else {
    print ":\n:: mediainfo is up to date - nothing to do ...\n\n";
    exit(0);
}

sub get_package_urls {
    my @deb_urls;
    my @html_data;
    my $arch = shift;

    foreach my $pkg_type ( 'libzen0', 'libmediainfo0', 'mediainfo' ) {
        my $parent_url = $base_url . "$pkg_type/";
        my $vers_resp  = $ua->get($parent_url);
        die "failed to access '$parent_url' [" . $vers_resp->status_line . "]"
            if not $vers_resp->is_success;
        my @v_nums;
        foreach my $html_line ( split( /\n/, $vers_resp->decoded_content ) ) {
            my $v_num = $html_line =~ /href="([\d\.]+)\// ? $1 : undef;
            push( @v_nums, $v_num ) if defined $v_num;
        }
        ( my $latest_v_num ) = sort { numeric($b) <=> numeric($a) } @v_nums;

        printf "    [ %-13s : $latest_v_num ]\n", $pkg_type;

        $parent_url .= "$latest_v_num/";
        my $pkg_html = $ua->get($parent_url);

        my @found_pkgs;
        foreach my $html_line ( split( /\n/, $pkg_html->decoded_content ) ) {
            push( @found_pkgs, $1 )
                if $html_line =~ m{href="($pkg_type.$latest_v_num[^\"]+
                                          $arch[^\"]+Debian[^\"]+\.deb)}xi;
        }
        ( my $newest_dist_pkg ) = reverse sort @found_pkgs;
        push( @deb_urls, "$base_url$pkg_type/$latest_v_num/$newest_dist_pkg" );
    }
    print "\n";
    return @deb_urls;
}

sub numeric {
    ( my $vn_str = shift // '' ) =~ s|(\d+)|sprintf("%05s",$1)|ge;
    $vn_str = sprintf( "%-23s", $vn_str );
    $vn_str =~ s|\D|0|g;
    return $vn_str;
}

sub local_version {
    chomp( my $mediainfo_path = qx(which mediainfo) );
    if (    defined $mediainfo_path
        and length($mediainfo_path)
        and -x $mediainfo_path ) {
        chomp( my $version_str = qx($mediainfo_path --version) );
        $version_str =~ s|^.+v||s;
        return $version_str
            if length($version_str) < 8 and $version_str =~ /^[\d\.]+$/;
    }
    return 'not_found';
}

sub fetch_version {
    my $rss_resp = $ua->get($rss_url);
    my $latest_version;
    die "failed to fetch rss feed '$rss_url' [" . $rss_resp->status_line . "]"
        if not $rss_resp->is_success;
    $latest_version = $1
        if $rss_resp->content =~ /<title>MediaInfo ([^u>]+)</;
    die "failed to extract latest mediainfo version from '$rss_url'"
        if length($latest_version) > 8
        or $latest_version !~ /^[\d\.]+$/;
    return $latest_version;
}

sub host_architecture {
    my $selected;
    chomp( my $arch_str = qx(/usr/bin/arch) );
    chomp( $arch_str = qx(/bin/uname -m) )
        if not defined $arch_str or !length($arch_str);
    $selected = 'i386'  if $arch_str =~ /^i\d86$/;
    $selected = 'amd64' if $arch_str eq 'x86_64';
    die "<!> failed to determine host architecture"
        if not defined $selected;
    return $selected;
}
