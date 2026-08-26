#!/usr/bin/env perl

=head1 NAME

test-strm-size-client.pl - Test client for Protocol-7 STRM-SIZE fragmentation

=head1 SYNOPSIS

  test-strm-size-client.pl [options] [command]

  Options:
    --socket PATH            unix socket path [ default: /var/run/.7/UNIX/NIW7OAQ ]
    --user NAME              auth username                  [ default: root ]
    --declare-strm-size      send declare-strm-size-support true before cmd
    --strm-mode locked|normal  select cube strm-mode for session
    --count N                expected payload byte count    [ default: auto ]
    --output FILE            write received payload bytes   [ default: discard ]
    --timeout SECS           socket read timeout            [ default: 30 ]
    --verbose, -v            verbose diagnostic output
    --hex-peek N             dump first N bytes of payload as hex after receive
    --help                   this help

  Command (positional, default: web.test-strm-size 500):
    any p7 command that returns SIZE / STRM-SIZE reply

=head1 DESCRIPTION

Purpose-built streaming client to verify STRM-SIZE fragmentation end-to-end.
No reassembly buffer — state-machine parser handles:

    SIZE <N>\n<N bytes>                       # plain SIZE reply
    STRM-SIZE open <N>\n                      # fragmented reply header
    STRM-SIZE <K>\n<K bytes>  [ repeating ]   # chunk
    STRM-SIZE close\n                         # fragmented reply trailer

Also: TRUE / FALSE / WAIT status lines, optional ( cmd_id ) prefixes.

Exits 0 on success, nonzero on framing error or byte-count mismatch.

=cut

use strict;
use warnings;
use v5.10.0;

use IO::Socket::UNIX;
use IO::Select;
use Getopt::Long qw| :config no_ignore_case bundling |;
use Fcntl        qw| :DEFAULT |;

my $socket_path       = '/var/run/.7/UNIX/NIW7OAQ';
my $username          = 'root';
my $declare_strm_size = 0;
my $strm_mode         = '';
my $expected_count    = 0;
my $output_file       = '';
my $timeout           = 30;
my $verbose           = 0;
my $hex_peek          = 0;
my $show_help         = 0;

GetOptions(
    'socket=s'           => \$socket_path,
    'user=s'             => \$username,
    'declare-strm-size!' => \$declare_strm_size,
    'strm-mode=s'        => \$strm_mode,
    'count=i'            => \$expected_count,
    'output=s'           => \$output_file,
    'timeout=i'          => \$timeout,
    'verbose|v!'         => \$verbose,
    'hex-peek=i'         => \$hex_peek,
    'help|h!'            => \$show_help,
) or die "invalid options ; try --help\n";

if ($show_help) {
    exec 'perldoc', $0;
}

my $test_cmd = join ' ', @ARGV;
$test_cmd = 'web.test-strm-size 500' if not length $test_cmd;

## auto expected count for the default test-strm-size command ##
if ( not $expected_count and $test_cmd =~ m|^ \S*test-strm-size \s+ (\d+) |x )
{
    $expected_count = $1 * 1024;
}

my $log = sub { print STDERR '[client] ', @_, "\n" if $verbose };

$log->("socket: $socket_path");
$log->("user:   $username");
$log->("cmd:    $test_cmd");
$log->("expect: $expected_count bytes") if $expected_count;
$log->("mode:   locked=$strm_mode declare-strm-size=$declare_strm_size");

##[ CONNECT ]#################################################################

my $sock = IO::Socket::UNIX->new(
    Type => SOCK_STREAM,
    Peer => $socket_path,
) or die "cannot connect to $socket_path: $!\n";

$sock->blocking(1);
binmode $sock;

my $sel = IO::Select->new($sock);

##[ PUSH-BACK READ BUFFER ]###################################################
## every byte the socket yields flows through $rxbuf ; line reads scan for ##
## \n , byte reads consume up to N bytes ; never call sysread directly     ##

my $rxbuf = '';

my $pump = sub {
    my ($min_bytes) = @_;
    $min_bytes //= 1;
    while ( length($rxbuf) < $min_bytes ) {
        my @ready = $sel->can_read($timeout);
        die "timeout after ${timeout}s waiting for bytes\n" if not @ready;
        my $chunk = '';
        my $got   = sysread $sock, $chunk, 65536;
        if ( not defined $got ) { die "sysread error: $!\n" }
        if ( $got == 0 )        { die "eof from server\n" }
        $rxbuf .= $chunk;
    }
};

my $read_line = sub {
    while ( index( $rxbuf, "\n" ) < 0 ) { $pump->() }
    my $nl   = index( $rxbuf, "\n" );
    my $line = substr $rxbuf, 0, $nl, '';
    substr $rxbuf, 0, 1, '';    ## drop \n ##
    return $line;
};

my $read_bytes = sub {
    my ($n) = @_;
    $pump->($n) if length($rxbuf) < $n;
    my $bytes = substr $rxbuf, 0, $n, '';
    return $bytes;
};

##[ AUTH ]####################################################################

my $greet = $read_line->();
$log->("greet: $greet");

print $sock "select unix\n";
my $select_ack = $read_line->();
$log->("select: $select_ack");
die "select failed: $select_ack\n" if $select_ack !~ /^TRUE\b/;

print $sock "auth unix-$username\n";
my $auth_ack = $read_line->();
$log->("auth:   $auth_ack");
die "auth failed: $auth_ack\n" if $auth_ack !~ /AUTH_TRUE/;

##[ CAPABILITY NEGOTIATION ]##################################################

my $send_cmd = sub {
    my ($cmd) = @_;
    $log->("-> $cmd");
    print $sock "$cmd\n";
};

my $expect_ok_line = sub {
    my ($ctx) = @_;
    my $line = $read_line->();
    $log->("<- $line");
    if ( $line =~ /^(?:\(\d+\)\s+)?FALSE\b/ ) {
        die "$ctx failed: $line\n";
    }
    return $line;
};

if ($declare_strm_size) {
    $send_cmd->('set-capability declare-strm-size-support true');
    $expect_ok_line->('declare-strm-size-support');
}

if ( length $strm_mode ) {
    die "--strm-mode must be locked or normal\n"
        if $strm_mode ne 'locked' and $strm_mode ne 'normal';
    $send_cmd->("set-capability select-strm-mode $strm_mode");
    $expect_ok_line->('select-strm-mode');
}

##[ ISSUE TEST COMMAND ]######################################################

$send_cmd->($test_cmd);

##[ REPLY STATE MACHINE ]#####################################################

my $out_fh;
if ( length $output_file ) {
    open $out_fh, '>:raw', $output_file
        or die "cannot open $output_file: $!\n";
}

my $peek_bytes = '';

my $sink = sub {
    my ($bytes_ref) = @_;
    print {$out_fh} $$bytes_ref if defined $out_fh;
    if ( $hex_peek and length($peek_bytes) < $hex_peek ) {
        my $need = $hex_peek - length($peek_bytes);
        $peek_bytes .= substr $$bytes_ref, 0, $need;
    }
};

my $total_payload  = 0;
my $announced      = 0;
my $saw_size       = 0;
my $saw_strm_open  = 0;
my $saw_strm_close = 0;
my $chunks         = 0;

my $strip_cmd_id = sub {
    my ($line) = @_;
    $line =~ s|^\(\d+\)\s+||;
    return $line;
};

my $start_t = time();

PARSE: while (1) {

    my $line     = $read_line->();
    my $stripped = $strip_cmd_id->($line);
    $log->("<- $stripped");

    if ( $stripped =~ m|^SIZE\s+(\d+)$| ) {

        $saw_size  = 1;
        $announced = 0 + $1;
        $log->("SIZE frame : $announced bytes");

        my $remaining = $announced;
        while ( $remaining > 0 ) {
            my $want = $remaining > 65536 ? 65536 : $remaining;
            my $got  = $read_bytes->($want);
            $sink->( \$got );
            $total_payload += length($got);
            $remaining     -= length($got);
        }
        last PARSE;

    } elsif ( $stripped =~ m|^STRM-SIZE\s+open\s+(\d+)$| ) {

        $saw_strm_open = 1;
        $announced     = 0 + $1;
        $log->("STRM-SIZE open : $announced bytes");

    } elsif ( $stripped =~ m|^STRM-SIZE\s+close(?:-timeout)?$| ) {

        $saw_strm_close = 1;
        $log->("STRM-SIZE close [ $line ]");
        last PARSE;

    } elsif ( $stripped =~ m|^STRM-SIZE\s+(\d+)$| ) {

        my $chunk = 0 + $1;
        $chunks++;
        my $got = $read_bytes->($chunk);
        $sink->( \$got );
        $total_payload += length($got);
        $log->(
            sprintf "STRM-SIZE chunk %d : %d bytes [ total %d / %d ]",
            $chunks, length($got), $total_payload, $announced
        );

    } elsif ( $stripped =~ m|^TRUE\b| ) {

        $log->("TRUE status [ $line ] — no payload ; exiting");
        last PARSE;

    } elsif ( $stripped =~ m|^FALSE\b| ) {

        die "command failed: $line\n";

    } elsif ( $stripped =~ m|^WAIT\b| ) {

        $log->("WAIT — continuing");
        next PARSE;

    } elsif ( $stripped =~ m|^\s*$| ) {

        next PARSE;

    } else {

        $log->("unrecognized frame line: $line");
    }
}

my $elapsed = time() - $start_t;

close $out_fh if defined $out_fh;
close $sock;

##[ VERIFY ]##################################################################

print "\n=== result ===\n";
printf "  cmd            : %s\n", $test_cmd;
printf "  reply framing  : %s\n", $saw_size
    ? 'SIZE'
    : $saw_strm_open ? (
    $saw_strm_close ? 'STRM-SIZE [ complete ]' : 'STRM-SIZE [ incomplete ]' )
    : 'none/status';
printf "  announced      : %d bytes\n", $announced;
printf "  received       : %d bytes\n", $total_payload;
printf "  chunks         : %d\n",       $chunks if $saw_strm_open;
printf "  elapsed        : %ds\n",      $elapsed;

if ( $hex_peek and length $peek_bytes ) {
    my $hex = unpack 'H*', $peek_bytes;
    $hex =~ s|(..)|$1 |g;
    my $asc = $peek_bytes;
    $asc =~ s|[^\x20-\x7e]|.|g;
    print "  hex peek       : $hex\n";
    print "  asc peek       : $asc\n";
}

my $exit = 0;

if ( $saw_strm_open and not $saw_strm_close ) {
    print "  STATUS         : FAIL [ STRM-SIZE open without close ]\n";
    $exit = 2;
} elsif ( $announced and $total_payload != $announced ) {
    printf "  STATUS         : FAIL [ received %d != announced %d ]\n",
        $total_payload, $announced;
    $exit = 3;
} elsif ( $expected_count and $total_payload != $expected_count ) {
    printf "  STATUS         : FAIL [ received %d != expected %d ]\n",
        $total_payload, $expected_count;
    $exit = 4;
} else {
    print "  STATUS         : OK\n";
}

exit $exit;

__END__

=head1 AUTHOR

Protocol-7 Development Team

=head1 LICENSE

See LICENSE file

=cut

#,,..,.,,,,.,,,..,.,.,,,.,.,,,..,,,..,,..,...,..,,...,...,,,,,...,,,.,.,,,.,,,
#PHKWQCPMVXV3SAOT6S2C6DT3ZLEA2K2ZNKXIZYEOUBK6UZPWMWTQKCRL6NB76IFNC7Q4CWEWMQTCC
#\\\|BXILJ2PKD5KTZDORPG4OOGEBYLFVNBLNZDRQ7GNQHQODQKZ3RRJ \ / AMOS7 \ YOURUM ::
#\[7]TCLJF3BHXPBDBAWQ4G5VJKAF2DKTADHR44V2YWTFQRCXEGJ2JODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
