package FindProtocol7Root;

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Spec;

our $VERSION = 0.01;
our @EXPORT  = qw(find_protocol_7_root);

use base 'Exporter';

=head1 NAME

FindProtocol7Root - Robustly find Protocol-7 project root from any location

=head1 SYNOPSIS

    use FindProtocol7Root qw(find_protocol_7_root);

    my $root = find_protocol_7_root()
        or die "Could not find Protocol-7 root: $!";

    chdir $root;

=head1 DESCRIPTION

Provides a robust method to find the Protocol-7 project root directory,
regardless of where the calling script is located in the repository.

Search order:
1. PROTOCOL_7_ROOT environment variable (fastest)
2. Walk up from script location looking for project markers
3. Fallback heuristics for standard locations

=cut

sub find_protocol_7_root {
    my %opts = @_;

    # 1. Check environment variable first (fastest)
    if ( my $env_root = $ENV{PROTOCOL_7_ROOT} ) {
        if ( -d $env_root ) {
            if (   -f File::Spec->catfile( $env_root, 'bin', 'nshell' )
                || -d File::Spec->catdir( $env_root, 'modules' ) ) {
                return $env_root;
            }
        }
    }

    # 2. Find caller's script location
    my $script_path = $opts{script_path};
    unless ($script_path) {

        # Get caller's file path
        my @caller = caller(0);
        $script_path = $caller[1];
    }

    unless ( $script_path && -f $script_path ) {
        warn "Could not determine script path\n" if $opts{verbose};
        return;
    }

    my $current_dir = abs_path(
        File::Spec->dir_list( File::Spec->splitpath($script_path) ) );

    # 3. Walk up directory tree looking for markers
    my $max_depth    = $opts{max_depth} || 15;
    my $marker_count = 0;

    while ( $marker_count < $max_depth ) {

        # Check for comprehensive markers
        my $git_dir     = File::Spec->catdir( $current_dir, '.git' );
        my $modules_dir = File::Spec->catdir( $current_dir, 'modules' );
        my $bin_nshell = File::Spec->catfile( $current_dir, 'bin', 'nshell' );
        my $config_dir = File::Spec->catdir( $current_dir, 'configuration' );

        if (   ( -d $git_dir || -d $modules_dir )
            && ( -f $bin_nshell || -d $modules_dir )
            && ( -d $config_dir || -f $bin_nshell ) ) {
            return $current_dir;
        }

        # Move up one level
        my $parent  = File::Spec->updir();
        my $new_dir = File::Spec->canonpath(
            File::Spec->catdir( $current_dir, $parent ) );

        if ( $new_dir eq $current_dir ) {

            # Reached filesystem root
            last;
        }

        $current_dir = $new_dir;
        $marker_count++;
    }

    # 4. Fallback: Try one level up from script
    my $fallback_root = File::Spec->updir();
    $fallback_root = File::Spec->canonpath(
        File::Spec->catdir(
            File::Spec->dir_list( File::Spec->splitpath($script_path) ),
            $fallback_root
        )
    );

    if (   -f File::Spec->catfile( $fallback_root, 'bin', 'nshell' )
        || -d File::Spec->catdir( $fallback_root, 'modules' ) ) {
        return $fallback_root;
    }

    # 5. Fallback: Two levels up (for nested test scripts)
    $fallback_root = File::Spec->updir();
    $fallback_root = File::Spec->canonpath(
        File::Spec->catdir(
            File::Spec->dir_list( File::Spec->splitpath($script_path) ),
            $fallback_root, $fallback_root
        )
    );

    if (   -f File::Spec->catfile( $fallback_root, 'bin', 'nshell' )
        || -d File::Spec->catdir( $fallback_root, 'modules' ) ) {
        return $fallback_root;
    }

    # Failed to find root
    if ( $opts{verbose} ) {
        warn "Could not find Protocol-7 project root\n";
        warn "Searched from: "
            . File::Spec->dir_list( File::Spec->splitpath($script_path) )
            . "\n";
        warn "Set PROTOCOL_7_ROOT environment variable if needed\n";
    }

    return;
}

1;

__END__

=head1 AUTHOR

Protocol-7 Development Team

=head1 LICENSE

Same as Protocol-7

=cut

#,,,.,...,,,,,,..,.,,,,..,.,,,.,,,.,.,,..,,..,..,,...,...,...,,,,,,,,,..,,...,
#T5VSKU7LAEFLOYGOFKQOBROHAMNC2YPT3LBZFKGWG7BE7722E2QU35QPSMKICD44BH5UNAJBNLUL2
#\\\|PMHFK2QDUAPZBNNSFOUN4AHNHPRQ46GIHP42SYZHV7GEOACXZK3 \ / AMOS7 \ YOURUM ::
#\[7]US5H2H6NXUIOWLD2QYS3CJZKGH2OHVPMOIUC42CVSS2WKPUXOGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
