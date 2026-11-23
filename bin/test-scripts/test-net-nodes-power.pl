#!/usr/bin/env perl
use v5.32.0;
use strict;
use warnings;
use English;

use Test::More;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

use constant { TRUE => 5, FALSE => 0 };

our %data;
our %code;
our $call;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[\$(\w+)\]>(?=\s*->)}{chr(36).qq|code{\$$1}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{(?<!\?)<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $root = tempdir( CLEANUP => 1 );
my %state_file;
my @logged;
my @sent;
my @replies;
my @timers;
$code{'base.log'} = sub { push @logged, $ARG[1]; TRUE };
$code{'base.logs'}
    = sub { shift; push @logged, sprintf( shift, @ARG ); TRUE };
$code{'file.zenka_dir.write'}
    = sub { $state_file{ $ARG[0] } = ${ $ARG[1] }; 1 };
$code{'file.zenka_dir.load'}
    = sub { exists $state_file{ $ARG[0] } ? \$state_file{ $ARG[0] } : undef };
my $deliver = 1;
$code{'protocol-7.command.send.local'}
    = sub { push @sent, shift; return $deliver };
$code{'base.callback.cmd_reply'} = sub { push @replies, [@ARG]; TRUE };
$code{'event.add_timer'}         = sub { push @timers,  shift;  TRUE };
$code{'base.host.trusted_file'}  = sub { return TRUE };
my $reachable = FALSE;
$code{'power.host_reachable'} = sub { return $reachable };
load_src($ARG)
    for
    qw| base.reply.mode_text base.interval.next base.interval.rhythm.non-linear |;
$data{'base'}{'interval'}{'cfg'}{'type'}{'wake-fallback'}
    = { start => 3.1, factor => 1.3, cap => 13 };
load_src($ARG)
    for qw| netinfo.role_overrides netinfo.local_networks netinfo.network_of
    nodes.ifaces.record nodes.ifaces.age_out nodes.ifaces.save nodes.ifaces.parse
    nodes.ifaces.load nodes.cmd.node-macs power.wake.decide power.wake.send
    power.wake.schedule_next power.wake.round power.handler.wake_next power.cmd.wake
    power.handler.wake_reply network.lease.announce network.interfaces.roles
    network.cmd.roles |;
$data{'nodes'}{'cfg'}{'ifaces_file'} = 'node-ifaces.state';

## a fake host : eth0 192.0.2.0/24 with the default route [ gateway arp ], ##
## br0 198.51.100.0/24, ext0 203.0.113.0/24                                ##
my $proc = "$root/proc";
mkdir $proc;
mkdir "$proc/net";

sub write_file {
    my ( $p, $t ) = @ARG;
    open my $fh, '>', $p or die;
    print $fh $t;
    close $fh;
}

sub routes {
    my $default = shift // 'eth0';
    my $gw      = $default eq 'eth0' ? '0100000A' : '017100CB';
    write_file(
        "$proc/net/route",
        "Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\t"
            . "Metric\tMask\tMTU\tWindow\tIRTT\neth0\t00000000\t"
            . ( $default eq 'eth0' ? '010200C0' : '00000000' )
            . "\t0003\t0\t0\t100\t00000000\t0\t0\t0\n"
            . (
            $default eq 'ext0'
            ? "ext0\t00000000\t017100CB\t0003\t0\t0\t50\t00000000\t0\t0\t0\n"
            : ''
            )
            . "eth0\t000200C0\t00000000\t0001\t0\t0\t100\t00FFFFFF\t0\t0\t0\n"
            . "br0\t006433C6\t00000000\t0001\t0\t0\t100\t00FFFFFF\t0\t0"
            . "\t0\next0\t007100CB\t00000000\t0001\t0\t0\t100\t00FFFFFF"
            . "\t0\t0\t0\n"
    );
}
routes();
write_file( "$proc/net/arp",
    "IP address       HW type     Flags       HW address            Mask     "
        . "Device\n192.0.2.1        0x1         0x2         "
        . "02:00:00:00:00:01     *        eth0\n" );
$data{'netinfo'}{'cfg'}{'proc_root'}  = $proc;
$data{'netinfo'}{'cfg'}{'roles_file'} = "$root/net.cfg";

## rule 3 : roles ##
my $nets = $code{'netinfo.local_networks'}->();
my %r    = map { $ARG->{'iface'} => $ARG } @$nets;
is $r{'eth0'}{'role'}, 'external',
    'default route iface without a role : external';
is $r{'br0'}{'role'}, 'unknown', 'other iface : unknown';
is $r{'eth0'}{'fingerprint'}, 'eth0,192.0.2.0/24,02:00:00:00:00:01',
    'fingerprint with gateway mac';
is $r{'br0'}{'fingerprint'}, 'br0,198.51.100.0/24,-', 'no gateway : -';
is $r{'br0'}{'broadcast'},   '198.51.100.255',        'broadcast';
write_file( "$root/net.cfg",
          "net.role.eth0 = lan\nnet.role.ext0 "
        . ": external\nnet.role.br0 = bogus\n" );
$nets = $code{'netinfo.local_networks'}->();
%r    = map { $ARG->{'iface'} => $ARG } @$nets;
is $r{'eth0'}{'role'},        'lan',         'host-config makes eth0 lan';
is $r{'eth0'}{'role_source'}, 'host-config', 'role source';
is $r{'ext0'}{'role'},        'external',    'host-config external';
is $r{'br0'}{'role'},         'unknown',     'invalid role value ignored';
$code{'base.host.trusted_file'} = sub { return ( FALSE, 'group writable' ) };
is $code{'netinfo.local_networks'}->()->[0]{'role'}, 'external',
    'untrusted roles file not read';
$code{'base.host.trusted_file'} = sub { return TRUE };

$code{'network.interfaces.collect'} = sub {
    return {
        lo   => { type => 'loopback' },
        eth0 => { type => 'wired' },
        br0  => { type => 'virtual' },
        ext0 => { type => 'wired' },
        eth9 => { type => 'wired' }
    };
};
my $roles = $code{'network.cmd.roles'}->()->{'data'};
like $roles,
    qr|^eth0\s+lan\s+host-config\s+eth0,192\.0\.2\.0/24,02:00:00:00:00:01$|m,
    'net.roles eth0';
like $roles, qr|^eth9\s+unknown\s+default\s+-$|m, 'net.roles unrouted iface';
like $roles, qr|^lo\s+-\s+-\s+-$|m,               'loopback has no role';

## rule 1 : observations per network, never overwritten ##
my $now = time;
$code{'nodes.ifaces.record'}->(
    'lap',
    {   iface   => 'eth0',
        hwaddr  => '52:54:00:AA:00:01',
        ip_addr => '192.0.2.20'
    },
    'pinned'
);
$code{'nodes.ifaces.record'}->(
    'lap',
    {   iface   => 'eth0',
        hwaddr  => '52:54:00:aa:00:01',
        ip_addr => '192.0.2.20'
    }
);
$code{'nodes.ifaces.record'}->(
    'lap',
    {   iface   => 'wlan0',
        hwaddr  => '52:54:00:aa:00:02',
        ip_addr => '198.51.100.20'
    }
);
my $obs = $data{'nodes'}{'ifaces'}{'lap'}{'obs'};
is scalar @$obs, 2, 'two observations';
my ($e) = grep { $ARG->{'iface'} eq 'eth0' } @$obs;
is $e->{'count'}, 2, 'same network : times seen counted';
is $e->{'network'}, 'eth0,192.0.2.0/24,' . '02:00:00:00:00:01',
    'network fingerprint stored';
## the gateway changes [ another switch \ dock, same subnet ] : a new entry ##
write_file( "$proc/net/arp",
    "IP address       HW type     Flags       HW address            Mask     "
        . "Device\n192.0.2.1        0x1         0x2         "
        . "02:00:00:00:00:99     *        eth0\n" );
$code{'nodes.ifaces.record'}->(
    'lap',
    {   iface   => 'eth0',
        hwaddr  => '52:54:00:aa:00:01',
        ip_addr => '192.0.2.21'
    }
);
is scalar @{ $data{'nodes'}{'ifaces'}{'lap'}{'obs'} }, 3,
    'other network : new observation, old kept';
## an address outside every local network : kept with network - ##
$code{'nodes.ifaces.record'}->(
    'lap',
    { iface => 'eth1', hwaddr => '52:54:00:aa:00:03', ip_addr => '10.9.9.9' }
);
ok(
    (   grep { $ARG->{'network'} eq '-' }
            @{ $data{'nodes'}{'ifaces'}{'lap'}{'obs'} }
    ),
    'unknown network kept as -'
);
ok !$code{'nodes.ifaces.record'}
    ->( 'lap', { iface => 'eth1', hwaddr => 'zz' } ), 'bad mac refused';

## age out ##
my $aged = {
    obs => [
        { seen => $now - 2000000 },
        { seen => $now - 10 },
        map { +{ seen => $now - $ARG } } 1 .. 20
    ]
};
is $code{'nodes.ifaces.age_out'}->( $aged, $now ), 13,
    'old dropped, newest 13 kept';
is $aged->{'obs'}[0]{'seen'}, $now - 1, 'newest first';

## persistence ##
like $state_file{'node-ifaces.state'},
    qr|^lap\.obs = eth0,192\.0\.2\.0/24,02:00:00:00:00:01 eth0 52:54:00:aa:00:01 192\.0\.2\.20 \d+ 2$|m,
    'state line';
unlike $state_file{'node-ifaces.state'}, qr|[{}"]|, 'state : no json';
$data{'nodes'}{'ifaces'} = {};
ok $code{'nodes.ifaces.load'}->(), 'observations read';
is scalar @{ $data{'nodes'}{'ifaces'}{'lap'}{'obs'} }, 4,
    'all observations back';
is $data{'nodes'}{'ifaces'}{'lap'}{'trust'}, 'pinned', 'trust back';
my $hostile
    = $code{'nodes.ifaces.parse'}->( "x.obs = eth0,1.2.3.0/24,- eth0 "
        . "52:54:00:aa:00:01 1.2.3.4 1 "
        . "1;rm\nx.trust = PINNED\n" );
ok !keys %$hostile, 'hostile lines dropped';
my $old = $code{'nodes.ifaces.parse'}
    ->( "x.obs = - eth0 52:54:00:aa:00:01 1.2.3.4 5 1\n", $now );
is scalar @{ $old->{'x'}{'obs'} }, 0, 'aged out on load';

$call = { args => 'lap' };
my $macs = $code{'nodes.cmd.node-macs'}->()->{'data'};
like $macs,
    qr|^eth0,192\.0\.2\.0/24,02:00:00:00:00:99 eth0 52:54:00:aa:00:01 192\.0\.2\.21 \d+ 1$|m,
    'node-macs line';
like $macs, qr|\ntrust pinned\n\z|, 'trust last';
$call = { args => 'a;b' };
is $code{'nodes.cmd.node-macs'}->()->{'mode'}, 'false', 'bad name';

## rule 2 + 3 : order of tries, nothing outside observations, never ##
## external                                                         ##
$nets = $code{'netinfo.local_networks'}->();    ## eth0 lan, gw ..:99 now ##
## wlan0 seen a minute earlier : the newest observation leads ##
$macs =~ s{^(br0,\S+ wlan0 \S+ \S+) (\d+)}{ "$1 " . ( $2 - 60 ) }me;
my $d = $code{'power.wake.decide'}->( { lines => $macs, networks => $nets } );
is $d->{'action'}, 'send', 'pinned + current network : send';
is_deeply [ map {"$ARG->{'tier'} $ARG->{'iface'} $ARG->{'ip'}"}
        @{ $d->{'tries'} } ],
    [ '1 eth0 192.0.2.21', '1 wlan0 198.51.100.20', '2 eth0 192.0.2.20' ],
    'exact network first, then the earlier gateway on the same subnet';
is $d->{'tries'}[0]{'broadcast'}, '192.0.2.255', 'subnet broadcast';
ok !(
    grep {
        $ARG->{'broadcast'} eq '255.255.255.255' or $ARG->{'iface'} eq 'eth1'
    } @{ $d->{'tries'} }
    ),
    'no all-ones broadcast, no observation without network';
$d = $code{'power.wake.decide'}
    ->( { lines => $macs, networks => $nets, want_iface => 'wlan0' } );
is_deeply [ map { $ARG->{'local'} } @{ $d->{'tries'} } ], ['br0'],
    'named iface only';

## eth0 external : its observations are never used ##
write_file( "$root/net.cfg", "net.role.eth0 = external\n" );
$d = $code{'power.wake.decide'}
    ->( { lines => $macs, networks => $code{'netinfo.local_networks'}->() } );
is_deeply [ map { $ARG->{'local'} } @{ $d->{'tries'} } ], ['br0'],
    'external iface skipped, even when observed there';
write_file( "$root/net.cfg", "net.role.eth0 = lan\n" );

## rule 4 : not on any of its networks ##
my $away = join "\n",
    'eth5,10.1.0.0/16,02:00:00:00:00:55 eth0 52:54:00:aa:00:01 10.1.2.3 '
    . ( $now - 7200 ) . ' 4',
    '- eth1 52:54:00:aa:00:03 10.9.9.9 ' . ( $now - 99999 ) . ' 1',
    'trust pinned', '';
$d = $code{'power.wake.decide'}->( { lines => $away, networks => $nets } );
is $d->{'action'}, 'away', 'no current network : away';
is $d->{'group'}[0]{'network'}, 'eth5,10.1.0.0/16,02:00:00:00:00:55',
    'newest observation first';
$d = $code{'power.wake.decide'}->(
    {   lines    => ( $macs =~ s|trust pinned|trust offered|r ),
        networks => $nets
    }
);
is $d->{'action'}, 'hint', 'not pinned : hint';

## power.wake end to end ##
my @packets;
$code{'power.plugin.wol.open'} = sub {
    return { mac => $ARG[0]{'mac'}, broadcast => $ARG[0]{'broadcast'} };
};
$code{'power.plugin.wol.set'} = sub { push @packets, $ARG[0]; return ['E'] };
$call = { args => 'lap', reply_id => 77 };
is $code{'power.cmd.wake'}->()->{'mode'}, 'deferred',        'wake defers';
is $sent[-1]{'command'},                  'nodes.node-macs', 'asks nodes';
$code{'power.handler.wake_reply'}->(
    { cmd => 'SIZE', data => \$macs, params => $sent[-1]{'reply'}{'params'} }
);
like $replies[-1][1]{'data'},
    qr|^magic packets sent to lap on 2 networks \[ eth0 52:54:00:aa:00:01 via eth0, wlan0 52:54:00:aa:00:02 via br0 \] ; 3 repeats queued$|,
    'all current networks at once';
is scalar @packets, 2, 'round 1 : one packet per network, '
    . 'tier 2 deduped [ same mac + broadcast ]';
is_deeply [ sort map { $ARG->{'broadcast'} } @packets ],
    [ '192.0.2.255', '198.51.100.255' ],
    'subnet broadcasts only';
is $timers[-1]{'handler'}, 'power.handler.wake_next', 'repeat timer';
ok $timers[-1]{'after'} > 0 && $timers[-1]{'after'} <= 17,
    'delay from the wake-fallback rhythm';
my $ev = sub {
    my $data = shift;
    bless { w => bless( { data => $data }, 'W' ) }, 'E';
};
{
    no strict 'refs';
    *{'E::w'}    = sub { $ARG[0]{'w'} };
    *{'W::data'} = sub { $ARG[0]{'data'} };
}
## tier 2 joins in round 1 : a different mac on an earlier gateway ##
my $tier2 = "$macs"
    =~ s{^(eth0,192\.0\.2\.0/24,02:00:00:00:00:01 eth0) 52:54:00:aa:00:01}{$1 52:54:00:aa:00:07}mr;
@packets = ();
$code{'power.handler.wake_reply'}->(
    {   cmd    => 'SIZE',
        data   => \$tier2,
        params => { host => 'lap', reply_id => 82 }
    }
);
is scalar @packets, 3, 'tier 2 sent in the first round, not after a timeout';
is $packets[-1]{'mac'}, '52:54:00:aa:00:07',
    'tier 2 after tier 1 in the round';
my $job = $timers[-1]{'data'};
$code{'power.handler.wake_next'}->( $ev->($job) );
is scalar @packets,       6, 'repeat round resends all';
is $job->{'rounds_left'}, 2, 'rounds counted down';
$code{'power.handler.wake_next'}->( $ev->($job) ) for 1 .. 2;
is $job->{'rounds_left'}, 0, 'repeats used up';
my $n_timers = @timers;
$code{'power.handler.wake_next'}->( $ev->($job) )
    if $job->{'rounds_left'} > 0;
is scalar @timers, $n_timers, 'no timer after the last round';
## the host answers : repeats stop ##
$code{'power.handler.wake_reply'}->(
    {   cmd    => 'SIZE',
        data   => \$macs,
        params => { host => 'lap', reply_id => 83 }
    }
);
$job      = $timers[-1]{'data'};
$n_timers = @timers;
my $n_pk = @packets;
$reachable = TRUE;
$code{'power.handler.wake_next'}->( $ev->($job) );
is scalar @packets, $n_pk,     'host answers : repeats stop';
is scalar @timers,  $n_timers, 'no further timer';
$reachable = FALSE;
## a network gone between rounds : its try is skipped ##
routes();
write_file(
    "$proc/net/route", join '',
    grep { !m|^br0| }
        do { open my $f, '<', "$proc/net/route"; <$f> }
);
$n_pk = @packets;
$code{'power.handler.wake_next'}->( $ev->($job) );
is scalar @packets, $n_pk + 1, 'detached br0 skipped, eth0 still sent';
ok !( grep { $ARG->{'broadcast'} eq '255.255.255.255' } @packets ),
    'never all-ones';
routes();
my $n_away = @packets;

$code{'power.handler.wake_reply'}->(
    {   cmd    => 'SIZE',
        data   => \$away,
        params => { host => 'lap', reply_id => 81 }
    }
);
like $replies[-1][1]{'data'},
    qr|^lap last seen on eth5,10\.1\.0\.0/16,02:00:00:00:00:55 \[ 2\.0 h ago \], not reachable from here\n  eth5|,
    'away answer lists the group';
is $replies[-1][1]{'mode'}, 'false', 'away is not a success';
is scalar @packets,         $n_away, 'away : no packet';

my $offered = $macs =~ s|trust pinned|trust offered|r;
$code{'power.handler.wake_reply'}->(
    {   cmd    => 'SIZE',
        data   => \$offered,
        params => { host => 'lap', reply_id => 78 }
    }
);
like $replies[-1][1]{'data'},
    qr|not pinned .* power\.add-wol-device lap 52:54:00:aa:00:01 eth0|,
    'hint with add-wol-device';

## registered wol device : only on an attached non-external iface ##
$data{'power'}{'cfg'}{'devices'}{'nas'}
    = { driver => 'wol', mac => '52:54:00:aa:00:09', iface => 'br0' };
$data{'power'}{'cfg'}{'devices'}{'far'}
    = { driver => 'wol', mac => '52:54:00:aa:00:0a', iface => 'ext0' };
$data{'power'}{'cfg'}{'devices'}{'old'}
    = { driver => 'wol', mac => '52:54:00:aa:00:0b' };
$code{'power.handler.wake_reply'}->(
    {   cmd       => 'FALSE',
        call_args => { args => 'x' },
        params    => { host => 'nas', reply_id => 79 }
    }
);
like $replies[-1][1]{'data'}, qr|magic packet sent to wol device nas|,
    'wol device on br0';
is $packets[-1]{'broadcast'}, '198.51.100.255', 'device subnet broadcast';
write_file( "$root/net.cfg", "net.role.ext0 = external\n" );

foreach my $dev (qw| far old |) {
    $code{'power.handler.wake_reply'}->(
        {   cmd       => 'FALSE',
            call_args => { args => 'x' },
            params    => { host => $dev, reply_id => 80 }
        }
    );
    like $replies[-1][1]{'data'}, qr|not an attached lan|,
        "wol device $dev refused [ external \\ no iface ]";
}
is scalar @packets, $n_away + 1, 'no blind broadcast';

## net : discover re-announce on new link \ lease ##
$data{'network'}{'cfg'}{'discover_announce_cmd'}
    = 'discover.reset-broadcast-timer';
@sent = ();
foreach my $r (qw| BOUND REBOOT CARRIER BOUND6 CARRIER6 |) {
    ok $code{'network.lease.announce'}->( $r, 'eth0' ), "announce on $r";
}
foreach my $r (qw| RENEW REBIND RELEASE NOCARRIER EXPIRE |) {
    ok !$code{'network.lease.announce'}->( $r, 'eth0' ), "no announce on $r";
}
is scalar @sent,        5,                                'five sends';
is $sent[0]{'command'}, 'discover.reset-broadcast-timer', 'discover command';
ok !exists $sent[0]{'reply'}, 'fire and forget';
$deliver = 0;
ok !$code{'network.lease.announce'}->( 'BOUND', 'eth0' ),
    'not delivered reported';
like $logged[-1], qr|not delivered|, 'not delivered logged';

## nodes details reply [ discover.host_details text ] -> per iface table ##
require Crypt::Misc;
$code{'base.s_warn'} = sub {TRUE};
load_src('nodes.handler.discover_details_reply');
my $pk = Crypt::Misc::encode_b32r( 'k' x 32 );
my $details
    = "   host : peer\n ip_addr : 192.0.2.30\n  hwaddr : 52:54:00:aa:00:30\n "
    . "  iface : enp3s0\n    pkey : $pk\n   trust : pinned\n";
$code{ 'nodes.handler.discover_details' . '_reply' }
    ->( { params => { name => 'peer' }, data => $details } );
is $data{'nodes'}{'ifaces'}{'peer'}{'obs'}[0]{'hwaddr'}, '52:54:00:aa:00:30',
    'details reply adds an observation';
is $data{'nodes'}{'ifaces'}{'peer'}{'obs'}[0]{'network'},
    'eth0,192.0.2.0/24,02:00:00:00:00:99',
    'observation tied to the local network';
is $data{'nodes'}{'ifaces'}{'peer'}{'trust'}, 'pinned', 'details trust kept';
is $data{'nodes'}{'local-network'}{'online-hosts'}{'peer'}{'hwaddr'},
    '52:54:00:aa:00:30', 'old hwaddr field still filled';

done_testing;

#,,..,,,.,,,,,,.,,..,,...,,,,,,.,,..,,,,,,.,,,..,,...,...,..,,,.,,,,.,..,,.,.,
#7IIZQZGZZAJWKLPVN4ELRJHL6MMJP44FV35ZFLIXC34XWCFARAGIKWJLPVTEJMRNX7WIUB4ULG3FW
#\\\|YJ3AJVIDXG22KUBIUVQNUP2C6FDE4LSRBTWDAEMDNCUOLOQTTQ3 \ / AMOS7 \ YOURUM ::
#\[7]WLBCPLDGIMJQCZFUZLQA2K7MVAT5QKAQBLI4XJFVSTIGPUWM6YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
