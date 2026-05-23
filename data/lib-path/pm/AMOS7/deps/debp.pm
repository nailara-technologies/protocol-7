package AMOS7::deps::debp;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| probe_apt install_apt |;

##[ probe_apt ]###############################################################

sub probe_apt {
    my ($pkg) = @_;

    return 0 unless defined $pkg && length $pkg;

    my $result
        = `dpkg-query -W -f='\${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" && echo "found" || echo ""`;

    return ( defined $result && $result =~ /found/ ) ? 1 : 0;
}

##[ install_apt ]#############################################################

sub install_apt {
    my (@pkgs) = @_;

    return { ok => [], failed => [] } unless @pkgs;

    ## Non-interactive environment ##
    local $ENV{'APT_LISTCHANGES_FRONTEND'} = 'none';
    local $ENV{'UCF_FORCE_CONFFOLD'}       = 'true';
    local $ENV{'UCF_FORCE_CONFMISS'}       = 'true';
    local $ENV{'DEBCONF_PRIORITY'}         = 'critical';
    local $ENV{'PAGER'}                    = '/bin/true';
    local $ENV{'LANG'}                     = 'en_US.UTF-8';

    my $sudo = ( $EUID == 0 ) ? '' : 'sudo ';
    my $max_fail = 5;
    my $ok       = 0;
    my @failed;
    my @installed;

    my $pkg_list = join( ' ', @pkgs );

    while ( !$ok and $max_fail-- ) {
        my $warned = 0;
        my $wait   = 2 + int( rand(5) );

        ## Wait for dpkg lock ##
        while ( length( qx(lslocks | grep ^dpkg 2>/dev/null) ) and $wait = 11
            or $wait-- )
        {
            if ( $wait > 10 and !$warned++ ) {
                warn "... waiting for dpkg lock to disappear ...\n";
            }
            select( undef, undef, undef, 0.33 );
        }

        open( my $apt_out, '-|', 'apt-get', '-fy', 'install', @pkgs )
            or do {
            warn "apt-get failed to execute: $!\n";
            push @failed, @pkgs;
            last;
            };

        my $output = join( '', <$apt_out> );
        close($apt_out);
        my $result = $?;

        if ( $result == 0 ) {
            push @installed, @pkgs;
            $ok = 1;
        } elsif ( $output =~ m|Unable to locate package| ) {
            warn "Package not found - cannot continue\n";
            push @failed, @pkgs;
            last;
        } else {
            warn ": retrying automatic installation ..,\n";
            if ( $max_fail == 0 ) {
                push @failed, @pkgs;
            }
        }
    }

    return { ok => \@installed, failed => \@failed };
}

1;

#,,.,,..,,.,.,,..,,..,,,.,,,.,,,.,,..,,,,,..,,..,,...,...,...,...,,,.,,..,..,,
#MYASHFMRSUCL4YDRXBT5UWUPOHZVM5IBNVHX7IL7KYKNNZM4O6OZUB66UB4AFKHNJ6DHRH2JSEZRM
#\\\|7WZLW5JHK6HCCZ5UZCGBZ2M4WDPWR4AQROOTWYLF3HQQNCAPMG7 \ / AMOS7 \ YOURUM ::
#\[7]72AKRXZRF6OBIGXAIJHBQOO3VXHFXN3W7AW7BTMK522M7K7VMWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
