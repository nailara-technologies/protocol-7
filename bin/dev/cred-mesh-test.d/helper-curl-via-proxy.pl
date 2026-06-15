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
    timeout => 8,
    proxy   => [ http => 'http://127.0.0.1:8118' ],
);

my $req  = HTTP::Request->new( GET => $url );
my $resp = $ua->request($req);

my $status = $resp->code;
my $body   = eval { $resp->content } // '';
my $error  = $resp->is_success ? '' : ( $resp->message // 'request failed' );

print "status=$status\n";
print "error=$error\n" if length $error;
print "body=\n$body\n";

exit( $resp->is_success ? 0 : 1 );

# [ end ]

#,,,.,.,,,.,,,.,.,,.,,,..,,..,..,,,..,.,.,,.,,..,,...,...,.,.,...,...,,,.,,..,
#GBRTRIRLE3OTTEZCVJTOG4XJP3ZEWT3EKCW3LZCD2EW6O6HADCZ3L5GBPBDTLF6C4UOQWRTRPY2VS
#\\\|ZEHMSZWXVJGUSCWLZEOLJPDBOFKVDX25EYXCDMA2ECSAVVBXF6F \ / AMOS7 \ YOURUM ::
#\[7]OZQPSC7NPYNMYSVA4TCBO2TROBEMU3DT5HMTAMKVMWZWTHK62ADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
