package AMOS7::deps::dist_upgr;
our $VERSION = qw| AMOS7::deps::dist_upgr-VERSION.2XHT55I |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

use AMOS7::deps::aptlog qw| condense |;

our @EXPORT_OK = qw| run |;

##[ run ]#####################################################################

## action : apt-get action [ default dist-upgrade ]  opts   : emit -> code ref
## receiving one condensed line per call [ default : print to STDOUT ]  sudo
## -> command prefix [ default '' for root, 'sudo ' else ] path -> child PATH
## [ default : the retired shell script's list ]
##
## streaming : every step's raw apt \ dpkg output passes through the
## AMOS7::deps::aptlog condenser line by line and is emitted as produced --
## nothing waits for a step to finish. errors and prompts pass through
## verbatim. returns { ok, failed_step } : failed_step names the step that
## ended the run [ undef on success ]

sub run {
    my $action = shift // qw| dist-upgrade |;
    my $opts   = shift // {};
    $opts = {} if ref $opts ne qw| HASH |;

    my $emit = $opts->{'emit'} // sub { say $_[0] };

    my $ok          = 1;
    my $failed_step = undef;

    ## Non-interactive environment ##
    local $ENV{'DEBIAN_FRONTEND'}          = 'noninteractive';
    local $ENV{'APT_LISTCHANGES_FRONTEND'} = 'none';
    local $ENV{'UCF_FORCE_CONFMISS'}       = 'true';
    local $ENV{'UCF_FORCE_CONFOLD'}        = 'true';
    local $ENV{'PAGER'}                    = '/bin/true';
    local $ENV{'PATH'}                     = $opts->{'path'}
        // qw| /usr/sbin:/usr/bin:/sbin:/bin |;

    ## the non-interactive env travels INSIDE the command line : sudo's ##
    ## env_reset strips caller-set %ENV, and a wiped parent env         ##
    ## [ v7's exec-external ] never reaches this process to begin with  ##
    my $env_prefix
        = 'DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none '
        . 'UCF_FORCE_CONFMISS=true UCF_FORCE_CONFOLD=true '
        . 'PAGER=/bin/true';

    my $sudo = $opts->{'sudo'};
    $sudo = ( $EUID == 0 ) ? '' : 'sudo ' unless defined $sudo;

    my @steps = (
        [   "dpkg recovery",
            "${sudo}$env_prefix dpkg --force-confold --force-confdef "
                . "--force-confmiss --force-overwrite --configure -a"
        ],
        [ "apt-fix install", "${sudo}$env_prefix apt-get -fy install" ],
        [   "$action (pass 1)",
            "${sudo}$env_prefix apt-get -y -o "
                . "Dpkg::Options::=--force-confold -o "
                . "Dpkg::Options::=--force-confdef -o "
                . "Dpkg::Options::=--force-confmiss $action"
        ],
        [ "pam-auth-update", "${sudo}$env_prefix pam-auth-update --force" ],
        [ "cleanup mediainfo tmp", "rm -rf /var/cache/apt/mediainfo_tmp*" ],
        [ "apt update",            "${sudo}$env_prefix apt-get update" ],
        [   "$action (pass 2)",
            "${sudo}$env_prefix apt-get -fy -o "
                . "Dpkg::Options::=--force-confold -o "
                . "Dpkg::Options::=--force-confdef -o "
                . "Dpkg::Options::=--force-confmiss -o "
                . "Dpkg::Options::=--force-overwrite $action"
        ],
        [   "clean and autoremove",
            "${sudo}$env_prefix apt-get clean && "
                . "${sudo}$env_prefix apt-get -y --purge autoremove"
        ],
    );

    for my $step (@steps) {
        my ( $name, $cmd ) = @$step;
        $emit->( sprintf ':. %s ..,', $name );

        my $exit = _run_step( "$cmd 2>&1", $emit );

        if ( not defined $exit ) {
            $ok          = 0;
            $failed_step = $name;
            $emit->( sprintf ':. ERROR : %s could not execute', $name );
            last;
        } elsif ( $exit != 0 ) {
            ## Some steps are best-effort ##
            if ( $name =~ m{pam-auth-update|cleanup mediainfo} ) {
                $emit->( sprintf ':. %s failed (non-critical)', $name );
            } else {
                $ok          = 0;
                $failed_step = $name;
                $emit->( sprintf ':. ERROR during %s', $name );
                last;
            }
        }
    }

    ## Final cleanup ##
    system("rm -rf /var/cache/apt/mediainfo_tmp* /root/.cpanm");

    return { 'ok' => $ok, 'failed_step' => $failed_step };
}

## one step : shell line in, exit status out -- its output streams through ##
## the condenser, condensed lines emitted as they are produced             ##
sub _run_step {
    my ( $cmd, $emit ) = @_;

    my $pid = open( my $fh, '-|', $cmd );
    return undef unless defined $pid;

    ## the child may talk in tty progress protocol : status updates        ##
    ## terminated by '\r' [ overwrite-in-place ] -- split on \r as well as ##
    ## \n, skip the blank padding fragments                                ##
    my %state;
    while ( my $chunk = <$fh> ) {
        foreach my $line ( split m{[\r\n]+}, $chunk ) {
            next unless length $line;
            my $result
                = condense( { 'lines' => [$line], 'state' => \%state } );
            $emit->($ARG) for @{ $result->{'data'}->{'lines'} };
        }
    }
    close($fh);
    my $exit = $?;

    ## the dropped-routine-lines summary belongs to this step ##
    my $result
        = condense( { 'lines' => [], 'state' => \%state, 'final' => 1 } );
    $emit->($ARG) for @{ $result->{'data'}->{'lines'} };

    return $exit;
}

1;

#,,.,,,,.,,.,,..,,,.,,.,.,.,.,.,.,..,,..,,..,,.,.,...,...,...,.,.,..,,,..,,.,,
#ECT5E4MVZWAYNNE4HPEJC2PXOHUXQK5GGLXESA24LOVF5HSMXQ5DVAESTNR2FCRRMK7DXPSGTXPPO
#\\\|DDFIVSYTPWSYTJ3EOPI5BHDQ75K2VI5ZH2DU5HLSL6MGULBOS4Y \ / AMOS7 \ YOURUM ::
#\[7]EBZQI5VTRWM4N42ZBQOSTM42FBB7TNQMQIDXYCIFL5GDDBEL2QBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
