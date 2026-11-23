#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## dns behaviour probe per network : nameserv.dns-probe measures open \    ##
## filtering \ intercepting \ blocking-outside against fake resolvers      ##
## [ udp sockets on 127.0.0.1, random ports, answered by the test ] ; net  ##
## stores the result beside the policy                                     ##
## [ net.dns-behaviour, net.dns-policy ] and arms the slow rhythm. no real ##
## network, no zenka started.                                              ##

use bytes;

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

use IO::Socket::INET;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::RR;

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
}

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

STDOUT->autoflush(1);

## state ##

our %data;
our %code;
our %keys;
our $call;

## fake event \ watcher objects [ the zenka uses Event objects ] ##

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
    sub fd   { $_[0]->{'fd'} }
}

{

    package FakeWatcher;
    sub new       { bless { active => 1, params => $_[1] }, $_[0] }
    sub cancel    { $_[0]->{'active'} = 0 }
    sub is_active { $_[0]->{'active'} }
}

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[\$(\w+)\]>(?=\s*->)}{chr(36).qq|code{\$$1}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

for my $mod (
    qw|
    base.cfg_bool
    base.interval.next
    base.interval.rhythm.non-linear
    nameserv.upstream_address
    nameserv.cache.own_name
    nameserv.cmd.dns-probe
    nameserv.dns_probe.address
    nameserv.dns_probe.start
    nameserv.dns_probe.query
    nameserv.dns_probe.handler.answer
    nameserv.dns_probe.handler.timeout
    nameserv.dns_probe.done
    nameserv.dns_probe.finish
    network.dns_policy.get
    network.dns_policy.save
    network.dns_policy.load
    network.cmd.dns-policy
    network.cmd.dns-behaviour
    network.dns_probe.schedule
    network.dns_probe.run
    network.dns_probe.handler.timer
    |
) {
    load_module($mod);
}

## --- stubs ------------------------------------------------------------- ##

my @logs;
$code{'base.logs'}
    = sub { push @logs, sprintf $_[1] // '', @_[ 2 .. $#_ ]; return TRUE };
$code{'base.log'} = sub { push @logs, $_[1] // ''; return TRUE };

my $prng_counter = 30000;
$code{'base.prng.bytes'} = sub {
    $prng_counter = ( $prng_counter + 1 ) & 65535;
    return pack qw| n |, $prng_counter;
};

my @io_watchers;
my @timers;
$code{'event.add_io'} = sub {
    my $params = shift;
    push @io_watchers, $params;
    return FakeWatcher->new($params);
};
$code{'event.add_timer'} = sub {
    my $params = shift;
    my $w      = FakeWatcher->new($params);
    push @timers, $w;
    return $w;
};

my @handoffs;    ## network.lease.dns_handoff calls [ iface ] ##
$code{'network.lease.dns_handoff'}
    = sub { push @handoffs, shift; return TRUE };

my @sent;
my $deliver = 1;
$code{'protocol-7.command.send.local'} = sub {
    push @sent, shift;
    return $deliver;
};

my %files;
$code{'file.zenka_dir.load'} = sub {
    my $name = shift;
    return exists $files{$name} ? \( my $copy = $files{$name} ) : undef;
};
$code{'file.zenka_dir.write'} = sub {
    my ( $name, $ref ) = @_;
    $files{$name} = $ref->$*;
    return length $files{$name};
};

my @networks;
$code{'netinfo.local_networks'} = sub { return [@networks] };

## --- assertion helpers -------------------------------------------------- ##

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

## --- fake resolvers ----------------------------------------------------- ##
## behaviour per server : silent, or a sub [ question -> rcode, @addrs ]    ##

sub fake_server {
    my $sock = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto     => 'udp',
    ) or die "fake server : $OS_ERROR";
    return $sock;
}

sub addr_of { return '127.0.0.1:' . $_[0]->sockport }

## answer : the zone each fake resolver would give ##
sub zone {
    my %zone = @_;
    return sub {
        my $q = shift;
        return ( 'NOERROR', () ) if $q->qtype eq 'SOA';
        my $a = $zone{ lc $q->qname };
        return ('NXDOMAIN') if not defined $a;
        return ( 'NOERROR', ref $a ? @$a : $a );
    };
}

## drive every pending probe query : answer from its fake server or time it ##
## out when the server is silent                                            ##
sub drive {
    my %behaviour = @_;             ## server address -> zone sub | undef ##
    my @pending   = @io_watchers;
    @io_watchers = ();
    foreach my $w (@pending) {
        my $q    = $w->{'data'};
        my $srv  = $behaviour{ $q->{'server'} };
        my $sock = $srv ? $srv->[0] : undef;
        if ( not $sock or not $srv->[1] ) {
            ## silent : drain and fire the timeout ##
            if ($sock) { my $buf; $sock->recv( $buf, 65535 ) }
            my ($t) = grep { $_->{'params'}{'data'} == $q } @timers;
            $code{ $t->{'params'}{'handler'} }
                ->( FakeEvent->new( $t->{'params'}{'data'} ) );
            next;
        }
        my $buf        = '';
        my $peer       = $sock->recv( $buf, 65535 );
        my $req        = Net::DNS::Packet->new( \$buf );
        my ($question) = $req->question;
        my ( $rcode, @addrs ) = $srv->[1]->($question);
        my $reply
            = Net::DNS::Packet->new( $question->qname, $question->qtype );
        $reply->header->id( $req->header->id );
        $reply->header->qr(1);
        $reply->header->rcode($rcode);
        $reply->push(
            answer => Net::DNS::RR->new(
                name    => $question->qname,
                type    => ( $_ =~ m|:| ? 'AAAA' : 'A' ),
                ttl     => 60,
                address => $_
            )
        ) for @addrs;
        $sock->send( $reply->data, 0, $peer );
        select undef, undef, undef, 0.02;
        $code{ $w->{'handler'} }->( FakeEvent->new($q) );
    }
}

sub probe {
    my ( $dhcp, %behaviour ) = @_;
    @sent = ();
    local $call = { 'args' => "dhcp:eth0 fp-a $dhcp" };
    my $reply = $code{'nameserv.cmd.dns-probe'}->();
    drive(%behaviour);
    my ($msg) = grep { $_->{'command'} eq 'net.dns-behaviour' } @sent;
    return ( $reply, $msg ? $msg->{'call_args'}{'args'} : '' );
}

## --- nameserv probe ----------------------------------------------------- ##

my ( $s1, $s2, $d1 ) = ( fake_server(), fake_server(), fake_server() );
my ( $a1, $a2, $ad ) = map { addr_of($_) } $s1, $s2, $d1;

my $real = zone(
    'fixed.example.test'   => '192.0.2.77',
    'neutral.example.test' => '198.51.100.5'
);
$data{'nameserv'}{'cfg'}{'cache'}{'upstream'} = "$a1 $a2";
$data{'nameserv'}{'cfg'}{'dns_probe'} = {
    'known_answer' => 'fixed.example.test=192.0.2.77',
    'neutral'      => 'neutral.example.test',
};
$data{'nameserv'}{'zones'} = { 'own.example.test' => {} };
$data{'base'}{'interval'}{'cfg'}{'type'}{'dns-probe-wait'}
    = { start => 2.1, factor => 1.01, cap => 2.1, cap_jitter => 0.34 };

my ( $reply, $args ) = probe(
    $ad,
    $a1 => [ $s1, $real ],
    $a2 => [ $s2, $real ],
    $ad => [ $d1, $real ]
);
check( 'open : reply lists queries', $reply->{'data'} =~ m|: 8 queries| );
check( 'open : net told open',       $args            =~ m|^fp-a open\b| );
check( 'open : no probe left active',
    not keys %{ $data{'nameserv'}{'dns_probe'}{'active'} } );
check(
    'wait timer from base.interval.next',
    (   grep { $_->{'params'}{'after'} > 1.5 && $_->{'params'}{'after'} < 3 }
            @timers
    ) == 8
);

( undef, $args ) = probe(
    $ad,
    $a1 => [ $s1, undef ],
    $a2 => [ $s2, undef ],
    $ad => [ $d1, $real ]
);
check( 'blocking-outside : statics silent, dhcp answers',
    $args =~ m|^fp-a blocking-outside\b| );

( undef, $args ) = probe(
    $ad,
    $a1 => [ $s1, undef ],
    $a2 => [ $s2, undef ],
    $ad => [ $d1, undef ]
);
check( 'unknown : nothing answers', $args =~ m|^fp-a unknown no server| );

my $theirs = zone(
    'fixed.example.test'   => '203.0.113.9',
    'neutral.example.test' => '203.0.113.9'
);
( undef, $args ) = probe(
    $ad,
    $a1 => [ $s1, $theirs ],
    $a2 => [ $s2, $theirs ],
    $ad => [ $d1, $theirs ]
);
check(
    'intercepting : known answer forged',
    $args
        =~ m|^fp-a intercepting fixed.example.test via .*203.0.113.9, expected 192.0.2.77|
);
check( 'intercepting : filtering undecided',
    $args =~ m|filtering undecided| );

my $filter = zone( 'fixed.example.test' => '192.0.2.77' );
( undef, $args ) = probe(
    $ad,
    $a1 => [ $s1, $real ],
    $a2 => [ $s2, $real ],
    $ad => [ $d1, $filter ]
);
check( 'filtering : nxdomain from dhcp where ours answers',
    $args =~ m|^fp-a filtering neutral.example.test via \S+ : NXDOMAIN| );

my $block_page = zone( 'neutral.example.test' => '203.0.113.1' );
( undef, $args ) = probe(
    $ad,
    $a1 => [ $s1, $real ],
    $a2 => [ $s2, $real ],
    $ad => [ $d1, $block_page ]
);
check(
    'filtering : other address from dhcp',
    $args =~ m|^fp-a filtering .* : 203.0.113.1|
);

## empty lists : checks skipped with a log line ; own names dropped ##
$data{'nameserv'}{'cfg'}{'dns_probe'} = {
    'known_answer' => 'host.own.example.test=192.0.2.1',
    'neutral'      => 'own.example.test',
};
@logs = ();
( $reply, $args ) = probe(
    $ad,
    $a1 => [ $s1, $real ],
    $a2 => [ $s2, $real ],
    $ad => [ $d1, $real ]
);
check( 'own names never probed : reach queries only',
    $reply->{'data'} =~ m|: 3 queries| );
check( 'skip logged : known answer',
    grep {m|known-answer check skipped|} @logs );
check( 'skip logged : filtering', grep {m|filtering check skipped|} @logs );
check(
    'skipped checks named in detail',
    $args
        =~ m|^fp-a open known-answer check skipped ; filtering check skipped|
);

$data{'nameserv'}{'cfg'}{'cache'}{'upstream'} = '';
( $reply, $args ) = probe( $ad, $ad => [ $d1, $real ] );
check(
    'no static upstream : unknown, no queries',
    $args =~ m|^fp-a unknown no static upstreams|
        && $reply->{'data'} =~ m|: 0 queries|
);

{
    local $call = { 'args' => 'dhcp:eth0 fp-a not-an-ip' };
    check( 'invalid address refused',
        $code{'nameserv.cmd.dns-probe'}->()->{'mode'} eq 'false' );
    $call = { 'args' => 'dhcp:eth0' };
    check( 'usage without addresses',
        $code{'nameserv.cmd.dns-probe'}->()->{'mode'} eq 'false' );
}

## --- net : behaviour beside the policy ---------------------------------- ##

$data{'network'} = {
    'cfg'   => { 'dns_policy_file' => 'dns-policy.state' },
    'lease' => { 'eth0' => { 'reason' => 'BOUND', 'dns' => ['192.0.2.53'] } },
    'dns_policy' => { 'by_fingerprint' => {} },
};
@networks = (
    { 'iface' => 'eth0', 'fingerprint' => 'fp-a', 'role' => 'external' } );
$data{'base'}{'interval'}{'cfg'}{'type'}{'dns-probe'}
    = { start => 1297, factor => 1.6, cap => 28657, cap_jitter => 4181 };

my $p = $code{'network.dns_policy.get'}->('eth0');
check( 'external network starts held', $p->{'policy'} eq 'held' );

@logs = ();
local $call
    = { 'args' => 'fp-a filtering neutral.example.test via x : NXDOMAIN' };
my $r = $code{'network.cmd.dns-behaviour'}->();
check( 'behaviour recorded',
    $r->{'mode'} eq 'size' && $p->{'behaviour'} eq 'filtering' );
check( 'policy unchanged by behaviour', $p->{'policy'} eq 'held' );
check(
    'a changed behaviour is handed to nameserv again',
    scalar @handoffs == 1 && $handoffs[0] eq 'eth0'
);
check( 'change logged',
    grep {m|unmeasured -> filtering \[ policy stays held \]|} @logs );

$p->{'policy'} = 'trusted';
$call = { 'args' => 'fp-a open' };
$code{'network.cmd.dns-behaviour'}->();
check( 'open result keeps the owner policy', $p->{'policy'} eq 'trusted' );
$p->{'policy'} = 'held';
$code{'network.cmd.dns-behaviour'}->();
check( 'open never promotes held', $p->{'policy'} eq 'held' );
@logs     = ();
@handoffs = ();
$code{'network.cmd.dns-behaviour'}->();
check( 'same behaviour : no change line',     not grep {m|->|} @logs );
check( 'same behaviour : no second hand-off', not @handoffs );

$call = { 'args' => 'fp-a trusted' };
check( 'invalid behaviour refused',
    $code{'network.cmd.dns-behaviour'}->()->{'mode'} eq 'false' );
$call = { 'args' => 'fp-zz open' };
check( 'unknown network dropped',
    $code{'network.cmd.dns-behaviour'}->()->{'mode'} eq 'false' );

my $table = $code{'network.cmd.dns-policy'}->()->{'data'};
check( 'dns-policy has a BEHAVIOUR column',
    $table =~ m|POLICY  BEHAVIOUR| && $table =~ m|fp-a  eth0  held  open| );

check( 'behaviour saved',
    $files{'dns-policy.state'} =~ m{^0\.behaviour = open$}m );
$data{'network'}{'dns_policy'}{'by_fingerprint'} = {};
$code{'network.dns_policy.load'}->();
my $back = $data{'network'}{'dns_policy'}{'by_fingerprint'}{'fp-a'};
check(
    'behaviour survives a restart',
    $back->{'behaviour'} eq 'open'
        && $back->{'behaviour_at'} > 0
        && $back->{'policy'} eq 'held'
);

## rhythm : probe at once, then a slow non-round timer ##
@sent   = ();
@timers = ();
$code{'network.dns_probe.schedule'}->( 'eth0', 'BOUND' );
check(
    'lease event probes at once',
    (   grep {
                   $_->{'command'} eq 'nameserv.dns-probe'
                && $_->{'call_args'}{'args'} eq 'dhcp:eth0 fp-a 192.0.2.53'
        } @sent
    ) == 1
);
my $first = $timers[-1]{'params'}{'after'};
check( 'next probe is slow, not round',
    $first > 1200 && $first < 1400 && $first != 1200 );

@sent = ();
$code{'network.dns_probe.schedule'}->( 'eth0', 'RENEW' );
check( 'renew inside the gap : no extra probe', not @sent );

$code{'network.dns_probe.handler.timer'}->( FakeEvent->new('eth0') );
my $second = $timers[-1]{'params'}{'after'};
check( 'rare round probes and grows', @sent == 1 && $second > $first * 1.3 );

## blocked : no query at all to that server ##
@sent = ();
$data{'network'}{'dns_policy'}{'by_fingerprint'}{'fp-a'}{'policy'}
    = 'blocked';
@logs = ();
$code{'network.dns_probe.handler.timer'}->( FakeEvent->new('eth0') );
check( 'blocked network : never probed',
    ( !@sent && ( grep {m|skipped \[ policy blocked \]|} @logs ) ) ? 1 : 0 );
$data{'network'}{'dns_policy'}{'by_fingerprint'}{'fp-a'}{'policy'} = 'held';

## released lease : the rhythm stops ##
$data{'network'}{'lease'}{'eth0'}{'reason'} = 'RELEASE';
$code{'network.dns_probe.handler.timer'}->( FakeEvent->new('eth0') );
check(
    'released lease : rhythm stops, nothing sent',
    ( !@sent && !$data{'network'}{'dns_probe'}{'by_iface'}{'eth0'} ) ? 1 : 0
);
$data{'network'}{'lease'}{'eth0'}{'reason'} = 'BOUND';
$code{'network.dns_probe.schedule'}->( 'eth0', 'BOUND' );

@sent                                            = ();
$networks[0]{'fingerprint'}                      = 'fp-b';
$data{'network'}{'dns_policy'}{'by_fingerprint'} = {};
$code{'network.dns_probe.handler.timer'}->( FakeEvent->new('eth0') );
check(
    'network changed : rhythm stops, nothing sent',
    ( !@sent && !$data{'network'}{'dns_probe'}{'by_iface'}{'eth0'} ) ? 1 : 0
);

printf "\n%d passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,..,.,,,,.,,,,,,,,.,,,,,.,,,,,,,,,.,.,,,..,,...,..,,...,.,.,.,.,,.,,,..,
#ZGBVVMYKVAGKJH67TUWDL6FRPOVH4AXBUIQGT3EH4YDJ7CUCSTQHX7M5CSQNCEMBJEFSOT3KRNAOY
#\\\|JGQULXV7EQDO6545CLE5AJQCSL4V57UFVQCKJL6WIQUALNIFZAS \ / AMOS7 \ YOURUM ::
#\[7]IN4TTVNTEEVOP3FZXNI7FV5Y224XTHGQZSSMDRMJQ4KMDGPFVSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
