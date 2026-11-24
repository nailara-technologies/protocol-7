#!/usr/bin/env perl
use v5.32;
use strict;
use English;

## a fake line-framed child for test-stream-child.pl : one command per   ##
## stdin line, answers on stdout [ stderr for `err` ]                    ##
##   echo   : `got <bytes>` per line          err <text> : a stderr line ##
##   part   : `par` + pause + `tial`          crash <n>  : exit n        ##
##   grand  : a grandchild in the group, `grand <pid>` [ grand deaf :    ##
##            it ignores TERM ]  env <name> \ cwd : `env <value>` ..     ##
##   deaf   : TERM ignored, stdin eof ignored                            ##
## argv : slow <s> -- no stdin read for s seconds [ a full pipe ]        ##

$OUTPUT_AUTOFLUSH = 1;
binmode $_, ':raw' for *STDIN, *STDOUT, *STDERR;
select( undef, undef, undef, $ARGV[1] ) if ( $ARGV[0] // '' ) eq 'slow';
say 'ready';

my $deaf = 0;
while ( my $line = <STDIN> ) {
    chomp $line;
    if ( $line =~ m{\Aerr (.*)\z} ) {
        print STDERR "$1\n";
    } elsif ( $line eq 'part' ) {
        print 'par';
        select( undef, undef, undef, 0.3 );
        print "tial\n";
    } elsif ( $line =~ m{\Acrash (\d+)\z} ) {
        exit $1;
    } elsif ( $line =~ m{\Agrand( deaf)?\z} ) {
        my $hard = $1;
        my $pid  = fork;
        if ( defined $pid and not $pid ) {
            $SIG{q|TERM|} = q|IGNORE| if $hard;
            close STDOUT;
            close STDERR;
            sleep 60;
            exit 0;
        }
        say "grand $pid";
    } elsif ( $line eq 'deaf' ) {
        $SIG{'TERM'} = 'IGNORE';
        $deaf = 1;
        say 'deaf';
    } elsif ( $line =~ m{\Aenv (\w+)\z} ) {
        say "env " . ( $ENV{$1} // q|-| );
    } elsif ( $line eq q|cwd| ) {
        require Cwd;
        say q|cwd | . Cwd::getcwd();
    } elsif ( $line eq 'nonl' ) {
        print 'no newline at the end';
        exit 0;
    } else {
        say 'got ' . length $line;
    }
}
sleep 60 if $deaf;
exit 0;

#,,..,,,.,,,,,...,.,,,...,.,.,...,,,.,,,,,.,.,..,,...,...,...,,..,...,.,,,...,
#QGVYSKLDVLTN3Q3ZEZTNXKZOGT7B4WLUYLAW6MSL3PQXCQEVERMMD6QVYDGSRYCCF7B5PI5R56CB6
#\\\|7AHSHW7IVUKHSW5Q6AWEZDQ2U6BVLMJJRTGSKKKI7SGASO46Z25 \ / AMOS7 \ YOURUM ::
#\[7]54S5IOV2IOTNINPYP4MPVOKKH2ZRMI52DKTHDETQ57FL5RSAMCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
