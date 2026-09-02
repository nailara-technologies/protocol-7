package CredFabTest;

# [ common helpers for credential-fabric integration test harness ]

use v5.24;
use strict;
use warnings;
use English;

use Exporter 'import';
our @EXPORT_OK = qw|
    find_project_root p7c p7c_eval zenka_running
    start_echo_server stop_echo_server
    harness_assert wait_for_log proxy_port_ready
    get_zenka_log slurp_yaml parse_echo_body
    temp_dir cleanup_temp say_summary
    |;

use File::Spec;
use Cwd qw| abs_path |;
use FindBin qw| $RealBin |;
use IO::Socket::IP;
use YAML::XS;

our $VERBOSE     = $ENV{'CREDFAB_TEST_VERBOSE'} // 0;
our $P7C         = $ENV{'CREDFAB_TEST_P7C'}     // 'p7c';
our $PROXY_ADDR  = '127.0.0.1';
our $PROXY_PORT  = 8118;
our $RESULT      = { pass => 0, fail => 0, assertions => [] };
our $TEMP_DIR    = '';
our $ECHO_PID    = 0;

sub find_project_root {
    my $start = $RealBin;
    my $root  = abs_path( File::Spec->catdir( $start, File::Spec->updir,
        File::Spec->updir, File::Spec->updir ) );
    return $root if -d File::Spec->catdir( $root, 'modules' )
        and -d File::Spec->catdir( $root, 'bin' );
    die "[ fatal ] cannot locate protocol-7 project root\n";
}

sub _run {
    my @cmd = @ARG;
    warn "[ run ] @cmd\n" if $VERBOSE;
    my $out = '';
    my $err = '';
    {
        local $OUTPUT_AUTOFLUSH = 1;
        open my $stdout, '>', \$out or die $ERRNO;
        open my $stderr, '>', \$err or die $ERRNO;
        my $pid = open my $fh, '-|', @cmd or return ( '', $ERRNO, -1 );
        local $/;
        $out = <$fh> // '';
        close $fh;
        my $exit = $CHILD_ERROR >> 8;
        return ( $out, $err, $exit );
    }
}

sub p7c {
    my ( $cmd, $args ) = @ARG;
    $args //= '';
    my @cmd = ( $P7C, $cmd );
    push @cmd, $args if length $args;
    my ( $out, $err, $exit ) = _run(@cmd);
    chomp $out;
    return wantarray ? ( $out, $err, $exit ) : $out;
}

sub p7c_eval {
    my ( $zenka, $code ) = @ARG;
    return p7c( "$zenka.eval-code", $code );
}

sub zenka_running {
    my ($name) = @ARG;
    my $out = p7c( 'v7-zenki.list', 'zenki' );
    return 0 if not defined $out;
    return $out =~ m{\b$name\b} ? 1 : 0;
}

sub proxy_port_ready {
    my $deadline = time + 10;
    while ( time < $deadline ) {
        my $sock = IO::Socket::IP->new(
            PeerHost => $PROXY_ADDR,
            PeerPort => $PROXY_PORT,
            Type     => SOCK_STREAM(),
            Timeout  => 1,
        );
        return 1 if defined $sock;
        select undef, undef, undef, 0.2;
    }
    return 0;
}

sub temp_dir {
    return $TEMP_DIR if length $TEMP_DIR;
    my $base = $ENV{'CREDFAB_TEST_DIR'} // File::Spec->tmpdir;
    my $dir  = File::Spec->catdir( $base,
        'credfab-test-' . time . '-' . $$ );
    mkdir $dir or die "[ fatal ] cannot create $dir: $ERRNO\n";
    $TEMP_DIR = $dir;
    return $dir;
}

sub cleanup_temp {
    return if not length $TEMP_DIR;
    return if $ENV{'CREDFAB_TEST_KEEP'};
    system 'rm', '-rf', $TEMP_DIR;
    $TEMP_DIR = '';
}

sub start_echo_server {
    my ( $port, $log_file ) = @ARG;
    my $pid = fork // die "[ fatal ] fork failed: $ERRNO\n";
    if ( $pid == 0 ) {
        # [ child echo server ]
        my $listen = IO::Socket::IP->new(
            LocalHost => '127.0.0.1',
            LocalPort => $port,
            Type      => SOCK_STREAM(),
            Listen    => 5,
            ReuseAddr => 1,
        ) or die "[ fatal ] echo listen on $port: $ERRNO\n";

        open my $log, '>', $log_file
            or die "[ fatal ] cannot open echo log: $ERRNO\n";
        $log->autoflush(1);

        while ( my $client = $listen->accept ) {
            my $req = '';
            my $chunk;
            while ( $client->sysread( $chunk, 4096 ) ) {
                $req .= $chunk;
                last if $req =~ m{\r?\n\r?\n};
            }
            my @lines   = split m{\r?\n}, $req;
            my $first   = shift @lines;
            my $headers = {};
            for my $line (@lines) {
                last if $line eq '';
                if ( $line =~ m{^([^:]+):\s*(.*)$} ) {
                    $headers->{ lc $1 } = $2;
                }
            }
            my ( $method, $path ) = split m{ +}, $first // '', 3;
            $path //= '/';

            my $body = eval { YAML::XS::Dump( { path => $path, headers => $headers } ) };
            $body //= "path: $path\n";

            print {$client}
                "HTTP/1.1 200 OK\r\n"
                . "Content-Type: text/yaml\r\n"
                . "Content-Length: " . length($body) . "\r\n"
                . "Connection: close\r\n\r\n"
                . $body;

            print {$log} $req . "---\n";
            close $client;
        }
        exit 0;
    }
    $ECHO_PID = $pid;
    # [ wait for listener to be ready ]
    my $deadline = time + 5;
    while ( time < $deadline ) {
        my $probe = IO::Socket::IP->new(
            PeerHost => '127.0.0.1',
            PeerPort => $port,
            Type     => SOCK_STREAM(),
            Timeout  => 1,
        );
        return $pid if defined $probe;
        select undef, undef, undef, 0.1;
    }
    die "[ fatal ] echo server did not start on port $port\n";
}

sub stop_echo_server {
    return if not $ECHO_PID;
    kill 'TERM', $ECHO_PID;
    waitpid $ECHO_PID, 0;
    $ECHO_PID = 0;
}

sub harness_assert {
    my ( $scenario, $name, $cond, $msg ) = @ARG;
    my $status = $cond ? '[ OK ]' : '[ FAIL ]';
    print "$status scenario $scenario : $name : $msg\n";
    if ($cond) {
        $RESULT->{'pass'}++;
    } else {
        $RESULT->{'fail'}++;
    }
    push @{ $RESULT->{'assertions'} },
        { scenario => $scenario, name => $name, pass => $cond ? 1 : 0, msg => $msg };
    return $cond;
}

sub wait_for_log {
    my ( $zenka, $pattern, $timeout ) = @ARG;
    $timeout //= 5;
    my $deadline = time + $timeout;
    while ( time < $deadline ) {
        my $log = get_zenka_log($zenka);
        return 1 if defined $log and $log =~ m{$pattern};
        select undef, undef, undef, 0.2;
    }
    return 0;
}

sub get_zenka_log {
    my ($zenka) = @ARG;
    my $out = p7c( "$zenka.show-buffer", 'zenka' );
    return defined $out ? $out : '';
}

sub slurp_yaml {
    my ($path) = @ARG;
    open my $fh, '<', $path or return undef;
    local $/;
    my $txt = <$fh>;
    close $fh;
    return eval { YAML::XS::Load($txt) };
}

sub parse_echo_body {
    my ($body) = @ARG;
    return eval { YAML::XS::Load($body) };
}

sub say_summary {
    my ($label) = @ARG;
    print "\n[ summary ] $label\n";
    print "  passed : $RESULT->{'pass'}\n";
    print "  failed : $RESULT->{'fail'}\n";
    return $RESULT->{'fail'} == 0;
}

1;

# [ end ]

#,,,.,...,...,.,.,,..,,..,,..,,,.,,..,...,..,,..,,...,...,.,,,,.,,.,.,,..,..,,
#EVRM7GM7HQPGBT5E4U33HWD3QAZFLUQ4KFZGV3KCO55K575OOTWJNMFLWXOYZ4OU6CEKCVAEZ2VVU
#\\\|VF2MHL7BHT45VALIP6WABGWYA4S24NMQ5DDHAF57I3E4GGW3UUY \ / AMOS7 \ YOURUM ::
#\[7]XDQHXNQIEW6LE4BTC2WGO7M34SKXNSJEDC53UVSAQC7UNW7NYMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
