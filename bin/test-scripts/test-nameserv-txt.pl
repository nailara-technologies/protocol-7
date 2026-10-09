#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv txt challenge records : longest-suffix zone match, value
## coexistence, remove-by-value, nxdomain \ nodata answers and a real local
## udp query against the handler. no network beyond 127.0.0.1, no port 53 -- a
## high port on the loopback interface only.

use bytes;

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use IO::Socket::INET;

use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::RR;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;
our $call;

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG) for qw| nameserv.cmd.add-txt nameserv.cmd.remove-txt
    nameserv.zone.lookup nameserv.handler.query |;

## --- stubs ------------------------------------------------------------- ##

my @logs;
$code{'base.logs'} = sub {
    push @logs, sprintf( $_[1] // '', @_[ 2 .. $#ARG ] );
    return TRUE;
};

my @saved_zones;
$code{'nameserv.zone.save'} = sub {
    push @saved_zones, $_[0];
    return TRUE;
};

## --- shared zone state -------------------------------------------------- ##

sub reset_zones {

    # example.com :  a plain record + a challenge name holding two values
    # sub.example.com :  its own zone [ longer-suffix match must win ]
    $data{'nameserv'} = {
        'cfg'   => { 'challenge_ttl' => 60 },
        'zones' => {
            'example.com' => {
                'serial'  => 100,
                'ttl'     => 3600,
                'records' => [
                    {   'name'  => 'www.example.com',
                        'type'  => 'A',
                        'value' => '203.0.113.7'
                    }
                ],
            },
            'sub.example.com' => {
                'serial'  => 200,
                'ttl'     => 3600,
                'records' => [],
            },
        },
        'stats' => { 'queries' => 0, 'errors' => 0 },
    };
    @saved_zones = ();
    return;
}

sub zone_records {
    my ($zone_name) = @ARG;
    return @{ $data{'nameserv'}{'zones'}{$zone_name}{'records'} };
}

sub txt_values {
    my ($fqdn) = @ARG;
    return map { $ARG->{'value'} }
        grep { lc( $ARG->{'name'} ) eq $fqdn and $ARG->{'type'} eq 'TXT' }
        zone_records('example.com');
}

sub run_cmd {
    my ( $module, $args ) = @ARG;
    local $call = { 'args' => $args };
    return $code{$module}->();
}

######################################################################
say ': add-txt [ longest-suffix zone match ]';
{
    reset_zones();
    my $r = run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.sub.example.com token-sub' );

    ok( ( $r->{'mode'} // '' ) eq qw| true |,
        'add under the deeper zone : mode true'
    );
    ok( join( ' ', @saved_zones ) eq 'sub.example.com',
        '  :.. the deeper zone was saved' );
    ok( ( scalar txt_values('_acme-challenge.sub.example.com') ) == 0
            && ( scalar zone_records('sub.example.com') ) == 1,
        '  :.. the record landed in sub.example.com, not example.com'
    );
    ok( ( zone_records('sub.example.com') )[0]->{'ttl'} == 60,
        '  :.. challenge ttl applied [ 60 ]' );

    ## now a name that only matches the parent zone
    $r = run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-one' );
    ok( ( $r->{'mode'} // '' ) eq qw| true |
            && join( ' ', @saved_zones ) eq 'sub.example.com example.com',
        'add under the parent zone : the parent zone was saved'
    );

    ## a suffix without a label boundary must not match
    $r = run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.notexample.com token-x' );
    ok( ( $r->{'mode'} // '' ) eq qw| false |
            && ( $r->{'data'} // '' ) =~ m|no matching zone|,
        'label-boundary : notexample.com is refused'
    );
}

######################################################################
say ': add-txt [ two values coexist, duplicate is a no-op ]';
{
    reset_zones();
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-one' );
    my $r = run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-two' );

    ok( ( $r->{'mode'} // '' ) eq qw| true |,
        'second value added : mode true'
    );
    my @values = sort +txt_values('_acme-challenge.example.com');
    ok( join( ' ', @values ) eq 'token-one token-two',
        '  :.. both txt values coexist' );
    ok( ( scalar @saved_zones ) == 2, '  :.. zone saved for each addition' );

    ## duplicate value : no-op, still true, no third record, no save
    $r = run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-one' );
    ok( ( $r->{'mode'} // '' ) eq qw| true |
            && ( $r->{'data'} // '' ) =~ m|already present|,
        'duplicate value : mode true with a note'
    );
    ok( ( scalar txt_values('_acme-challenge.example.com') ) == 2
            && ( scalar @saved_zones ) == 2,
        '  :.. nothing added, nothing saved'
    );
}

######################################################################
say ': remove-txt [ by value only, idempotent ]';
{
    reset_zones();
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-one' );
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-two' );

    my $r = run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.example.com token-one' );

    ok( ( $r->{'mode'} // '' ) eq qw| true |,
        'remove one value : mode true' );
    ok( join( ' ', txt_values('_acme-challenge.example.com') ) eq 'token-two',
        '  :.. the other value is kept'
    );

    ## missing value : mode true with a note [ idempotent cleanup ]
    $r = run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.example.com token-nine' );
    ok( ( $r->{'mode'} // '' ) eq qw| true |
            && ( $r->{'data'} // '' ) =~ m|not present|,
        'missing value : mode true with a note'
    );
    ok( join( ' ', txt_values('_acme-challenge.example.com') ) eq 'token-two',
        '  :.. nothing changed'
    );

    ## empty value arg : refused [ never remove all ]
    $r = run_cmd( 'nameserv.cmd.remove-txt', '_acme-challenge.example.com' );
    ok( ( $r->{'mode'} // '' ) eq qw| false |
            && ( $r->{'data'} // '' ) =~ m|usage|,
        'empty value arg : mode false [ never remove all ]'
    );

    $r = run_cmd( 'nameserv.cmd.add-txt', '_acme-challenge.example.com' );
    ok( ( $r->{'mode'} // '' ) eq qw| false |,
        'add-txt with a single arg : mode false'
    );

    ## remove the last value : mode true, the name is gone
    $r = run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.example.com token-two' );
    ok( ( $r->{'mode'} // '' ) eq qw| true |
            && ( scalar txt_values('_acme-challenge.example.com') ) == 0,
        'remove last value : mode true, no txt left'
    );
    ok( ( scalar zone_records('example.com') ) == 1
            && ( zone_records('example.com') )[0]->{'type'} eq 'A',
        '  :.. the www A record is untouched'
    );

    ## no-zone refusal
    $r = run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.other.org token-one' );
    ok( ( $r->{'mode'} // '' ) eq qw| false |
            && ( $r->{'data'} // '' ) =~ m|no matching zone|,
        'remove with no matching zone : mode false'
    );
}

######################################################################
say ': handler answers [ real udp query on 127.0.0.1, high port ]';
{

    ## listener socket stands in for the zenka's udp socket
    my $sock = IO::Socket::INET->new(
        'LocalAddr' => '127.0.0.1',
        'LocalPort' => 0,
        'Proto'     => 'udp',
    ) or die "cannot bind udp socket : $OS_ERROR";
    my $port = $sock->sockport;

    my $client = IO::Socket::INET->new(
        'PeerAddr' => "127.0.0.1:$port",
        'Proto'    => 'udp',
    ) or die "cannot open client socket : $OS_ERROR";

    my $ask = sub {
        my ($qname) = @ARG;
        my $query = Net::DNS::Packet->new( $qname, 'TXT' );
        $client->send( $query->data );
        $data{'nameserv'}{'socket'} = $sock;
        $code{'nameserv.handler.query'}->();
        my $buf = '';
        $client->recv( $buf, 512, 0 );
        return Net::DNS::Packet->new( \$buf );
    };

    reset_zones();
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-one' );
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.example.com token-two' );

    my $reply  = $ask->('_acme-challenge.example.com');
    my @rrs    = $reply->answer;
    my @values = sort map { $ARG->txtdata } @rrs;

    ok( $reply->header->rcode eq 'NOERROR' && ( scalar @rrs ) == 2,
        'two txt values : both returned in one answer'
    );
    ok( join( ' ', @values ) eq 'token-one token-two',
        '  :.. both values present' );
    ok( ( scalar grep { $ARG->ttl == 60 } @rrs ) == 2,
        '  :.. challenge ttl answered [ 60 ]'
    );

    run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.example.com token-one' );
    $reply = $ask->('_acme-challenge.example.com');
    @rrs   = $reply->answer;
    ok( $reply->header->rcode eq 'NOERROR'
            && ( scalar @rrs ) == 1
            && $rrs[0]->txtdata eq 'token-two',
        'one value removed : the other is still answered'
    );

    run_cmd( 'nameserv.cmd.remove-txt',
        '_acme-challenge.example.com token-two' );
    $reply = $ask->('_acme-challenge.example.com');
    ok( $reply->header->rcode eq 'NXDOMAIN' && ( scalar $reply->answer ) == 0,
        'last value removed : the name answers NXDOMAIN'
    );

    ## name exists with another type only : NODATA, not NXDOMAIN
    $reply = $ask->('www.example.com');
    ok( $reply->header->rcode eq 'NOERROR' && ( scalar $reply->answer ) == 0,
        'name exists as A only : txt query answers NODATA'
    );

    ## name outside every zone : REFUSED
    $reply = $ask->('elsewhere.org');
    ok( $reply->header->rcode eq 'REFUSED', 'no zone match : REFUSED' );

    ## longer zone served first : the deeper zone answers its own name
    run_cmd( 'nameserv.cmd.add-txt',
        '_acme-challenge.sub.example.com token-sub' );
    $reply = $ask->('_acme-challenge.sub.example.com');
    @rrs   = $reply->answer;
    ok( $reply->header->rcode eq 'NOERROR'
            && ( scalar @rrs ) == 1
            && $rrs[0]->txtdata eq 'token-sub',
        'deeper zone : its challenge name is answered authoritatively'
    );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,.,.,..,,,..,.,.,,..,.,,,.,,,,,.,...,.,,,..,,...,..,,,,.,.,,,,.,,..,,,,.,
#DQI5OYP3IHKHRSLIBB7TAK3HVGLXSE5GGUVR5KRIKJYQSR6WUHXXGAXR3YJYK4SXENDLWZU6MK3UI
#\\\|IEOPV5J3BYEBYFFF5CWHTWW3VLY6AXZKN6FJQLDWX7OYGIINJKT \ / AMOS7 \ YOURUM ::
#\[7]2Z3FHO7LXN3Q7TT67FCJXWJVVH4LBHPGHBAQPV7QV4LSNLZD6SCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
