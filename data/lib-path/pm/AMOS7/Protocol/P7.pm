
package AMOS7::Protocol::P7;   ###############################################

use v5.24;
use strict;
use English;
use warnings;

our $VERSION = qw| AMOS-Protocol-P7-XLC5PEQ |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

@EXPORT = qw[ ];

@EXPORT_OK = qw| $VERSION $port_ranges calc_port calc_unix_path |;

##[ AMOS MODULE ]#############################################################

use AMOS7 qw| warn_err $protocol_7_root |;   ##  error handling, root path  ##
use AMOS7::CHKSUM;                           ## amos_chksum ##

##[ SET-UP \ INIT ]###########################################################

##  you can adjust this to your own set-up  ##
##
our $base_installation_path = qw| /usr/local/protocol-7 |;

our $port_ranges = {    ##  deal with overlap collisions  ##   [LLL]
    qw| external | => { 'start' => 13, 'end' => 477 },
    qw| internal | => { 'start' => 42, 'end' => 577 }
};

## if installation path differs from base path       ##
## and base path exists, ports will be recalculated  ##

our $allow_port_recalculation = 1;
our $installation_path        = $protocol_7_root;

###                                                                      ###
#   calculated port : /usr/local/protocol-7 : ext = 13, internal = 42      #
#                 /data/projects/protocol-7 : ext = 44, internal = 171     #
###                                                                      ###

##[ PROTOCOL-7 PORT CALCULATION ]#############################################

sub calc_port { ## exclusion ports taken from /etc/services [getservbyport] ##
    my $n_port;
    my $port_end;
    my $port_start;
    my $port_range = shift;

    my $path_checksum_path    ##  is this a concurrent installation ?  ##
        = ( -d $base_installation_path and $allow_port_recalculation )
        ? $base_installation_path    ##  /usr/local/protocol-7  ##
        : $installation_path;        ##  other [ development ? ] path  ##

    my $install_path_chksum = unpack qw| V |,
        amos_chksum($path_checksum_path);

    my $path_offset = $install_path_chksum ^
        unpack( qw| V |, amos_chksum($installation_path) );

    my $iterations_remaining = 47;

    if ( not length ref $port_range and defined $port_ranges->{$port_range} )
    {    ##  keyword mode  [ external | internal ]  ##

        $port_end   = $port_ranges->{$port_range}->{'end'};
        $port_start = $port_ranges->{$port_range}->{'start'};

    } elsif ( ref $port_range eq qw| HASH | ) {    ## href params mode ##
        $port_start = $port_range->{'start'};
        $port_end   = $port_range->{'end'};
        if ( not defined $port_start or not defined $port_end ) {
            warn_err("expected port 'start' and 'end' in parameter hashref");
            return undef;
        }
    } elsif (
        $port_range =~ m|^\d+$|    ## list parameter mode ##
        and @ARG == 1 and defined $ARG[0] and $ARG[0] =~ m|^\d+$|
    ) {
        $port_start = $port_range;
        $port_end   = shift @ARG;
    }
    if ( $port_start == 0 or $port_end == 0 ) {
        warn_err('port range limit cannot be 0');
        return undef;
    } elsif ( $port_start == $port_end ) {
        warn_err('port start cannot be port end parameter');
        return undef;
    }

    my $port_delta = $port_end - $port_start;
    my $factor     = 7.420707;                  ## adjusting target range ##

    my %exclusion_cache;
    while (
        not defined $n_port
        or $n_port != $port_start and (
            not AMOS7::Assert::Truth::is_true( $n_port, 1, 1 )
            or ($n_port != $port_start   ## ignore /etc/services if p7 port ##
                and ( defined $exclusion_cache{$n_port}
                    and $exclusion_cache{$n_port}
                )                        ##  /etc/services entry  ##
                or $exclusion_cache{$n_port} = exclusion_port($n_port)
            )
        )
        and $iterations_remaining--
    ) {
        $n_port = int( $port_start + $factor * $path_offset % $port_delta );
        $factor += 0.7;

        while ( $n_port > $port_end ) { $n_port -= $port_start }
    }

    warn_err('iteration limit exceeded') if not $iterations_remaining;

    return $n_port;
}

sub exclusion_port {    ##  excluding matches on TCP _and_ UDP  ##
    my $port_num = shift;
    warn_err('expected port number parameter')
        if not defined $port_num
        or $port_num !~ m|^\d+$|;

    foreach my $type (qw| tcp udp |) {

        my $service_name = scalar getservbyport( $port_num, $type );

        ##  returning true for existing entry  ##
        return 5 if defined $service_name and $service_name !~ m|protocol-?7|;
    }

    return 0;    ##  no match or protocol-7 entry  ##
}

sub calc_unix_path {    ## calc unix socket path for ip address port pair ##

    my $ip_addr  = shift;
    my $ip_port  = shift;
    my $ip_proto = lc( shift // qw| tcp | );

    if ( not defined $ip_addr ) {
        warn_err('expected ip address parameter');
        return undef;
    } elsif ( not defined $ip_port or $ip_port !~ m|^\d+$| ) {
        warn_err('expected port number parameter');
        return undef;
    }

    my $chksum_template = qw| ip\\\\%s[%s:%d] |;
    my $truth_template  = qw| /var/run/.7/UNIX/%s |;

    my $calc_input_string
        = sprintf( $chksum_template, $ip_proto, $ip_addr, $ip_port );

    return amos_template_chksum( $truth_template, \$calc_input_string );
}

return 5;  ###################################################################

#,,,.,,..,.,.,,..,,.,,,..,.,,,.,.,,..,...,,..,..,,...,...,...,,..,...,,,,,,.,,
#X3FMTHUGO3FUEWAY4X7BYQDELGXNPGMO2VLJ6DSH5LNIEQBYEEBJ25G4ULXGQ375MPGBT6EK23D5A
#\\\|L2DQ2T74AC7NIGL3UQYVSH7SSEZ4ASD4XSJ76S3JCJNM4ALQVKY \ / AMOS7 \ YOURUM ::
#\[7]I3UOEKNSKRSSXMLAEJTVZXBUMKUF5DQE6AIVOXFPLTXPZNYULWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
