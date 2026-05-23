package AMOS7::deps::debp;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| probe_apt install_apt |;

my $_apt_cache;

sub _apt_cache {
    unless ( defined $_apt_cache ) {
        eval { require AptPkg::Cache; $_apt_cache = AptPkg::Cache->new };
        $_apt_cache = undef if $@;
    }
    return $_apt_cache;
}

##[ probe_apt ]###############################################################

sub probe_apt {
    my ($pkg) = @_;

    return 0 unless defined $pkg && length $pkg;

    my $cache = _apt_cache();
    if ( defined $cache ) {
        my $p = $cache->{$pkg};
        return ( defined $p && $p->{CurrentState} eq 'Installed' ) ? 1 : 0;
    }

    ## fallback: dpkg-query if AptPkg unavailable ##
    my $out = `dpkg-query -W -f='\${Status}' "$pkg" 2>/dev/null`;
    return ( defined $out && $out =~ /install ok installed/ ) ? 1 : 0;
}

##[ install_apt ]#############################################################

sub install_apt {
    my (@pkgs) = @_;

    return { ok => [], failed => [] } unless @pkgs;

    return { ok => [], failed => [@pkgs] } if $EUID != 0;

    local $ENV{'APT_LISTCHANGES_FRONTEND'} = 'none';
    local $ENV{'UCF_FORCE_CONFFOLD'}       = 'true';
    local $ENV{'UCF_FORCE_CONFMISS'}       = 'true';
    local $ENV{'DEBCONF_PRIORITY'}         = 'critical';
    local $ENV{'DEBIAN_FRONTEND'}          = 'noninteractive';
    local $ENV{'PAGER'}                    = '/bin/true';
    local $ENV{'LANG'}                     = 'en_US.UTF-8';

    my $max_fail = 5;
    my $ok       = 0;
    my @failed;
    my @installed;

    while ( !$ok and $max_fail-- ) {
        my $warned = 0;
        my $wait   = 2 + int( rand(5) );

        ## wait for dpkg lock ##
        while ( length( qx(lslocks | grep ^dpkg 2>/dev/null) ) and $wait = 11
            or $wait-- ) {
            if ( $wait > 10 and !$warned++ ) {
                warn "auto_install: waiting for dpkg lock ...\n";
            }
            select( undef, undef, undef, 0.33 );
        }

        my $cmd = 'apt-get -fy install ' . join( ' ', @pkgs ) . ' 2>&1';
        open( my $apt_out, '-|', $cmd ) or do {
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
            warn "package not found — cannot continue\n";
            push @failed, @pkgs;
            last;
        } else {
            warn ": retrying automatic installation ..,\n";
            push @failed, @pkgs if $max_fail == 0;
        }
    }

    return { ok => \@installed, failed => \@failed };
}

1;

#,,..,..,,...,.,,,,,,,...,..,,.,.,..,,,,,,,..,..,,...,...,.,,,,,,,,.,,,,,,,..,
#FKEHZ77KYE3D466JA3Q35XQLJ45F4WK42VDL4ZF34G4VSYBNN4LVH6NYFJCATAG5RETPKRYJHTVVG
#\\\|L3XDCZTLZUWMXL67LPPH3P6TPXEWIDW6S2HFLYNGAPF2NWQSMWI \ / AMOS7 \ YOURUM ::
#\[7]5UBRIHGXK32ANAOC6UIJAEL3FMKD6KY44QJIEIZ47EO5EJDUWOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
