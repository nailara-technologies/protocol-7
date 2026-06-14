#!/usr/bin/perl

# [ helper: small lwp client through the test proxy ]

use v5.24;
use strict;
use warnings;
use English;

use LWP::UserAgent;
use HTTP::Request;

my $url = $ARGV[0] // '';
die "usage: $0 <url>\n" if not length $url;

my $ua = LWP::UserAgent->new(
    timeout => 15,
    proxy   => [ http => 'http://127.0.0.1:8118' ],
);

my $req  = HTTP::Request->new( GET => $url );
my $resp = $ua->request($req);

my $status = $resp->code;
my $body   = $resp->decoded_content // '';
my $error  = $resp->is_success ? '' : ( $resp->message // 'request failed' );

print "status=$status\n";
print "error=$error\n" if length $error;
print "body=\n$body\n";

exit( $resp->is_success ? 0 : 1 );

# [ end ]

#,,,,,.,,,,,.,,.,,...,,,.,,..,,,,,..,,,,,,,,,,..,,...,...,...,,..,,,,,,,.,,,,,
#SWM65LTI2BCMHZTO5DNOSIBOTQWZKNZOX2F33OF7ZQDFKABTJRRV3UKD5MGPP6S5IRM7FIZCZQUU2
#\\\|X7TZ3D6ELOQFUL73MLMMI3GWOFEA4ALAMRYWQNG5MM7VE66USIM \ / AMOS7 \ YOURUM ::
#\[7]UNTXPYXXVRTYXCK5ZKGOXRVK7WKKRYBPXD7UTIASF4NRJRTQH6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
