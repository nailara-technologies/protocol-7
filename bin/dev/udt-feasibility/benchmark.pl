#!/usr/bin/perl

use v5.32.0;
use strict;
use warnings;
use FindBin;
use Getopt::Long qw| GetOptions |;
use IO::Socket::INET;
use POSIX       qw| WNOHANG |;
use Time::HiRes qw| sleep time |;
use lib "$FindBin::RealBin/lib";
use UDT::Simple;

my $bytes     = 64 * 1024 * 1024;
my $runs      = 3;
my $delay_ms  = 40;
my $burst     = 1;
my $timeout   = 45;
my $transport = 'all';
my $loss_arg  = '';
my $output    = "$FindBin::RealBin/results.tsv";
GetOptions(
    'bytes=i'     => \$bytes,
    'runs=i'      => \$runs,
    'delay-ms=f'  => \$delay_ms,
    'burst=i'     => \$burst,
    'timeout=f'   => \$timeout,
    'transport=s' => \$transport,
    'loss=s'      => \$loss_arg,
    'output=s'    => \$output,
) or die "invalid options\n";

my @transports = $transport eq 'all' ? qw| tcp udt |    : ($transport);
my @losses = length $loss_arg ? split( ',', $loss_arg ) : ( 0, 1, 5, 10, 20 );
my $payload = 'protocol-7-udt-feasibility' x 2731;
substr( $payload, 65536, length($payload) - 65536, '' );
open my $result_fh, '>', $output or die "cannot write results : $!\n";
print {$result_fh} join(
    "\t",
    qw| transport loss_pct run bytes seconds goodput_mbps rtt_ms
        send_rate_mbps send_loss_total recv_loss_total retransmits_total status |
) . "\n";

sub free_port {
    my $proto  = shift;
    my $socket = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto     => $proto,
        $proto eq 'tcp' ? ( Listen => 1 ) : (),
    ) or die "cannot reserve $proto port : $!\n";
    my $port = $socket->sockport;
    $socket->close;
    return $port;
}

sub udt_error {
    return sprintf '%s [%d]', UDT::Simple::last_error(),
        UDT::Simple::last_error_code();
}

sub start_server {
    my ( $kind, $port ) = @_;
    pipe my $reader, my $writer or die "server pipe failed : $!\n";
    my $pid = fork // die "server fork failed : $!\n";
    if ( $pid == 0 ) {
        close $reader;
        $writer->autoflush(1);
        eval {
            if ( $kind eq 'udt' ) {
                UDT::Simple::startup() == 0 or die udt_error();
                my $listener = UDT::Simple::socket();
                $listener >= 0                             or die udt_error();
                UDT::Simple::bind( $listener, $port ) == 0 or die udt_error();
                UDT::Simple::listen( $listener, 1 ) == 0   or die udt_error();
                print {$writer} "ready\n";
                my $peer = UDT::Simple::accept($listener);
                $peer >= 0 or die udt_error();
                my $received = 0;

                while ( $received < $bytes ) {
                    my $wanted = $bytes - $received;
                    $wanted = 65536 if $wanted > 65536;
                    my $count
                        = UDT::Simple::recv( $peer, my $chunk, $wanted );
                    $count >= 0 or die udt_error();
                    $count > 0  or die "early eof\n";
                    $received += $count;
                }
                UDT::Simple::send( $peer, 'K' ) == 1 or die udt_error();
                UDT::Simple::close($peer);
                UDT::Simple::close($listener);
                UDT::Simple::cleanup();
            } else {
                my $listener = IO::Socket::INET->new(
                    LocalAddr => '127.0.0.1',
                    LocalPort => $port,
                    Proto     => 'tcp',
                    Listen    => 1,
                    ReuseAddr => 1,
                ) or die "tcp listen failed : $!\n";
                print {$writer} "ready\n";
                my $peer = $listener->accept
                    or die "tcp accept failed : $!\n";
                my $received = 0;
                while ( $received < $bytes ) {
                    my $read = sysread( $peer, my $chunk, 65536 );
                    defined $read or die "tcp recv failed : $!\n";
                    $read > 0     or die "early eof\n";
                    $received += $read;
                }
                syswrite( $peer, 'K' ) == 1 or die "tcp ack failed : $!\n";
                $peer->close;
                $listener->close;
            }
        };
        print {$writer} "error : $@" if length $@;
        exit( length $@ ? 1 : 0 );
    }
    close $writer;
    my $ready = <$reader> // '';
    close $reader;
    die "server did not start : $ready\n" if $ready ne "ready\n";
    return $pid;
}

sub start_relay {
    my ( $kind, $listen_port, $target_port, $loss ) = @_;
    my $script = $kind eq 'udt' ? 'udp-loss-relay.pl' : 'tcp-stall-relay.pl';
    my $pid    = fork // die "relay fork failed : $!\n";
    if ( $pid == 0 ) {
        exec $^X, "$FindBin::RealBin/$script",
            '--listen-port', $listen_port,
            '--target-port', $target_port,
            '--loss',        $loss,
            '--delay-ms',    $delay_ms,
            $kind eq 'udt' ? ( '--burst', $burst ) : ();
        die "relay exec failed : $!\n";
    }
    sleep 0.08;
    return $pid;
}

sub run_client {
    my ( $kind, $port ) = @_;
    my $counters = {};
    if ( $kind eq 'udt' ) {
        UDT::Simple::startup() == 0 or die udt_error();
        my $socket = UDT::Simple::socket();
        $socket >= 0                                or die udt_error();
        UDT::Simple::connect( $socket, $port ) == 0 or die udt_error();
        my $sent = 0;
        while ( $sent < $bytes ) {
            my $offset = $sent % 65536;
            my $length = $bytes - $sent;
            $length = 65536 - $offset if $length > 65536 - $offset;
            my $count = UDT::Simple::send( $socket,
                substr( $payload, $offset, $length ) );
            $count >= 0 or die udt_error();
            $sent += $count;
        }
        UDT::Simple::recv( $socket, my $ack, 1 ) == 1   or die udt_error();
        UDT::Simple::perfmon( $socket, $counters ) == 0 or die udt_error();
        UDT::Simple::close($socket);
        UDT::Simple::cleanup();
    } else {
        my $socket = IO::Socket::INET->new(
            PeerAddr => '127.0.0.1',
            PeerPort => $port,
            Proto    => 'tcp',
        ) or die "tcp connect failed : $!\n";
        my $sent = 0;
        while ( $sent < $bytes ) {
            my $offset = $sent % 65536;
            my $length = $bytes - $sent;
            $length = 65536 - $offset if $length > 65536 - $offset;
            my $written = syswrite( $socket, $payload, $length, $offset );
            defined $written or die "tcp send failed : $!\n";
            $sent += $written;
        }
        sysread( $socket, my $ack, 1 ) == 1 or die "tcp ack failed : $!\n";
        $socket->close;
    }
    return $counters;
}

sub stop_child {
    my $pid = shift;
    return if not defined $pid or waitpid( $pid, WNOHANG ) > 0;
    kill 'TERM', $pid;
    for ( 1 .. 20 ) {
        return if waitpid( $pid, WNOHANG ) > 0;
        sleep 0.01;
    }
    kill 'KILL', $pid;
    waitpid( $pid, 0 );
}

for my $kind (@transports) {
    for my $loss (@losses) {
        for my $run ( 1 .. $runs ) {
            my ( $server_pid, $relay_pid );
            my $started = time;
            my ( $counters, $error );
            eval {
                local $SIG{'ALRM'} = sub { die "run timeout\n" };
                alarm $timeout;
                my $proto       = $kind eq 'udt' ? 'udp' : 'tcp';
                my $server_port = free_port($proto);
                my $relay_port  = free_port($proto);
                $server_pid = start_server( $kind, $server_port );
                $relay_pid
                    = start_relay( $kind, $relay_port, $server_port, $loss );
                $counters = run_client( $kind, $relay_port );
                alarm 0;
            };
            $error = $@;
            alarm 0;
            my $elapsed = time - $started;
            stop_child($_) for $relay_pid, $server_pid;
            my $status
                = length $error
                ? $error =~ m|run timeout|
                    ? 'timeout'
                    : 'error'
                : 'complete';
            warn "$kind loss $loss run $run : $error"
                if length $error and $status ne 'timeout';
            $counters //= {};
            my $goodput
                = $status eq 'complete'
                ? $bytes * 8 / $elapsed / 1_000_000
                : 0;
            printf {$result_fh}
                "%s\t%s\t%d\t%d\t%.6f\t%.3f\t%s\t%s\t%s\t%s\t%s\t%s\n",
                $kind, $loss, $run, $bytes, $elapsed, $goodput, (
                map { $counters->{$_} // '' }
                    qw| rtt_ms send_rate_mbps send_loss_total recv_loss_total
                    retransmits_total |
                ),
                $status;
            $result_fh->flush;
            printf "%s loss %s run %d : %.3f s, %.3f mbps, %s\n",
                $kind, $loss, $run, $elapsed, $goodput, $status;
        }
    }
}

#,,,,,.,,,.,.,,,.,,.,,..,,,,,,,..,.,.,.,,,..,,..,,...,...,,..,,,.,,,,,...,,,.,
#DW732HIMIF6C6LPPMZD5TPCQWUSBSCHCPUNF22M3THZHUUSDPX4TMEZCQWBCTUCGCWXED2UPG2ERS
#\\\|26QQGWO3VRRV2VAFIPLRLYWNHY3GQ547VS4ENBVDLD3R6V2MOXQ \ / AMOS7 \ YOURUM ::
#\[7]VOTSKS4LASMVTOCR3W4XX5RDDQOCZWKA5TGN5JZZVNQ6RVLJE2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
