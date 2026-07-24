package AMOS7::deps::dist_upgr;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| run |;

##[ run ]#####################################################################

sub run {
    my ($action) = @_;
    $action //= 'dist-upgrade';

    my $log = '';
    my $ok  = 1;

    ## Non-interactive environment ##
    local $ENV{'DEBIAN_FRONTEND'}          = 'noninteractive';
    local $ENV{'APT_LISTCHANGES_FRONTEND'} = 'none';
    local $ENV{'UCF_FORCE_CONFMISS'}       = 'true';
    local $ENV{'UCF_FORCE_CONFOLD'}        = 'true';
    local $ENV{'PAGER'}                    = '/bin/true';

    my $sudo = ( $EUID == 0 ) ? '' : 'sudo ';

    my @steps = (
        [   "dpkg recovery",
            "${sudo}dpkg --force-confold --force-confdef "
                . "--force-confmiss --force-overwrite --configure -a"
        ],
        [ "apt-fix install", "${sudo}apt-get -fy install" ],
        [   "$action (pass 1)",
            "${sudo}apt-get -y -o Dpkg::Options::=--force-confold -o "
                . "Dpkg::Options::=--force-confdef -o "
                . "Dpkg::Options::=--force-confmiss $action"
        ],
        [ "pam-auth-update",       "${sudo}pam-auth-update --force" ],
        [ "cleanup mediainfo tmp", "rm -rf /var/cache/apt/mediainfo_tmp*" ],
        [ "apt update",            "${sudo}apt-get update" ],
        [   "$action (pass 2)",
            "${sudo}apt-get -fy -o Dpkg::Options::=--force-confold -o "
                . "Dpkg::Options::=--force-confdef -o "
                . "Dpkg::Options::=--force-confmiss -o "
                . "Dpkg::Options::=--force-overwrite $action"
        ],
        [   "clean and autoremove",
            "${sudo}apt-get clean && ${sudo}apt-get -y --purge autoremove"
        ],
    );

    for my $step (@steps) {
        my ( $name, $cmd ) = @$step;
        $log .= ":. $name ..,\n";

        my $output = `$cmd 2>&1`;
        my $exit   = $?;

        $log .= $output if defined $output;
        $log .= "\n";

        if ( $exit != 0 ) {
            ## Some steps are best-effort ##
            if ( $name =~ /pam-auth-update|cleanup mediainfo/ ) {
                $log .= ":. $name failed (non-critical)\n";
            } else {
                $ok = 0;
                $log .= ":. ERROR during $name\n";
                last;
            }
        }
    }

    ## Final cleanup ##
    system("rm -rf /var/cache/apt/mediainfo_tmp* /root/.cpanm");

    return { ok => $ok, log => $log };
}

1;

#,,.,,..,,,,,,,,,,.,,,,,,,,,,,,,.,.,,,,..,.,,,..,,...,...,...,,..,...,,,,,...,
#2F4XF4VH2OM442QYC2XDIZKGZUJSYCCVKN3JDP2RGYYU7ZS2TG7JT5MYRPJ7VWEF25S7S5YIT6VLO
#\\\|EYD77LEQYIYJNMJK2BV5HBX5AMBFSR7J2VNKYHISYR7V24UJM72 \ / AMOS7 \ YOURUM ::
#\[7]QZE6DNBGFIWYYPIP5DF3ECKOS77MXAZSEPXQZ4FBJ5JTCI57OECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
