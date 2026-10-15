package AMOS7::deps::debp;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| probe_apt probe_apt_fresh install_apt |;

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
    return ( defined $out && $out =~ m|install ok installed| ) ? 1 : 0;
}

##[ probe_apt_fresh ]#########################################################

## dpkg-query per package [ ~3 ms ] : always the current state, no apt   ##
## cache in the process                                                  ##
## [ AptPkg::Cache : ~0.4 s, ~70 MB, never updated after an install ] -- ##
## for long-lived processes [ v7-zenki ]. no shell : the name goes to    ##
## dpkg-query as an argument                                             ##

sub probe_apt_fresh {
    my ($pkg) = @_;

    return 0 unless defined $pkg && $pkg =~ m|^[a-z0-9][a-z0-9.+\-~]*$|;

    my $pid = open( my $fh, '-|' );
    return 0 unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>', '/dev/null' );
        exec {'dpkg-query'} 'dpkg-query', '-W', '-f=${Status}', $pkg;
        exit 1;
    }
    my $out = do { local $/; <$fh> }
        // '';
    close($fh);

    return $out =~ m|install ok installed| ? 1 : 0;
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
        while ( length(qx(lslocks | grep ^dpkg 2>/dev/null)) and $wait = 11
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

    ## invalidate memoized apt package state cache ##
    $_apt_cache = undef;

    return { ok => \@installed, failed => \@failed };
}

1;

#,,,,,,..,,,.,,,,,.,,,..,,.,,,...,,..,...,..,,..,,...,...,...,...,...,,,,,,,.,
#KNDTWDVGFS7T5ZQURQ7BD7B47QB2IPGXZGRCNJZNC4LOOTDI7LJTGXPFIB4TOSWM5FRS5ZKY46UYW
#\\\|3NQAU244DU5HMAQPHQVARFXTRXOON4WS6LMCCH5OXDG25VBLTJX \ / AMOS7 \ YOURUM ::
#\[7]SJ2CJBBTKET3YZLCRD2TVWZS6F3KWLGYITO6AEMTIIALETAJM6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
