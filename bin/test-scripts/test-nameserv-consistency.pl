#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv consistency check : own records, glue, NS sets, ptr -- warns    ##
## only, never changes anything. it compiles the real                       ##
## src/nameserv.consistency.* modules and drives them with stubs :          ##
## base.logs, event.add_io, event.add_timer, a fake Net::DNS::Resolver with ##
## canned answers and a fake real-address source. no zenka started.         ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root_path = $main::root_path;

## state ##

our %data;
our %code;
our $call;    ## cmd modules read the command parameter from here ##

$data{'nameserv'}{'cfg'}{'dn_names'}       = 'dn1110.protocol-7.network';
$data{'nameserv'}{'cfg'}{'dn_peers_names'} = 'dn0110.protocol-7.network';
$data{'nameserv'}{'consistency'}{'last_findings'} = {};

my $zone_records = [
    {   'name'  => 'acme.v7.ax',
        'type'  => qw| NS |,
        'value' => 'dn1110.protocol-7.network'
    }
];

$data{'nameserv'}{'zones'} = {
    'acme.v7.ax' => {
        'records' => $zone_records,
        'serial'  => 100,
        'ttl'     => 3900
    },
    'test.v7.ax' => { 'records' => [], 'serial' => 200, 'ttl' => 3900 },
};

my @log_lines;       ## rendered base.logs output ##
my @io_watches;      ## event.add_io registrations ##
my @timers;          ## event.add_timer registrations ##
our @dns_queries;    ## queries the fake resolver saw ##

$code{'base.logs'} = sub {
    my $level = shift;
    my $fmt   = shift;
    push @log_lines, sprintf $fmt, @ARG;
    return 1;
};

$code{'event.add_io'} = sub {
    my $params = shift;
    my $w      = TestWatcher->new($params);
    push @io_watches, $w;
    return $w;
};
$code{'event.add_timer'} = sub {
    my $params = shift;
    my $w      = TestWatcher->new($params);
    push @timers, $w;
    return $w;
};

package TestWatcher {

    sub new {
        my $class = shift;
        return bless { active => 1, params => shift }, $class;
    }
    sub is_active { return shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return 1 }
}

package FakeEvent {

    sub new {
        my $class = shift;
        return bless { w => FakeW->new(shift) }, $class;
    }
    sub w { return shift->{'w'} }
}

package FakeW {
    sub new  { my $class = shift; return bless { data => shift }, $class }
    sub data { return shift->{'data'} }
}

package FakeSock {
    sub new   { my $class = shift; return bless { ckey => shift }, $class }
    sub close { return 1 }
}

package FakeRR {
    sub new      { my $class = shift; return bless {@_}, $class }
    sub type     { return shift->{'type'} }
    sub address  { return shift->{'value'} }
    sub nsdname  { return shift->{'value'} }
    sub ptrdname { return shift->{'value'} }
    sub serial   { return shift->{'value'} }
}

package FakePacket {

    sub new    { my $class = shift; return bless { answer => [@_] }, $class }
    sub header { return shift }
    sub rcode  { return qw| NOERROR | }
    sub answer { return @{ shift->{'answer'} } }
}

package Net::DNS::Resolver {

    sub new {
        my $class = shift;
        return bless { params => {@_} }, $class;
    }

    sub recurse {
        my $self = shift;
        $self->{'recurse'} = shift;
        return 1;
    }

    sub bgsend {
        my $self    = shift;
        my $name    = lc shift;
        my $type    = shift;
        my $key     = sprintf '%s %s', $type, $name;
        my $ns_list = join ',', @{ $self->{'params'}->{'nameservers'} // [] };
        $key .= sprintf ' @%s', $ns_list if length $ns_list;
        push @main::dns_queries, $key;
        die "unexpected dns query : $key"
            if not exists $main::canned{$key};
        my $answer = $main::canned{$key};
        $self->{'packet'} = ref $answer eq qw| FakePacket | ? $answer : undef;
        return FakeSock->new($key);
    }

    sub bgread { return shift->{'packet'} }
}

package main;

## canned resolver answers : FakePacket for a reply, TIMEOUT for silence ##

our %canned;    ## the fake resolver reaches it as %main::canned ##

my $dn   = 'dn1110.protocol-7.network';
my $peer = 'dn0110.protocol-7.network';

my $real_v4 = '203.0.113.7';
my $real_v6 = '2001:db8::90c6';

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
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
    nameserv.consistency.host-name
    nameserv.consistency.reverse-name
    nameserv.consistency.real-addresses
    nameserv.consistency.run
    nameserv.consistency.query
    nameserv.consistency.handler.answer
    nameserv.consistency.handler.timeout
    nameserv.consistency.complete
    nameserv.consistency.evaluate-dn
    nameserv.consistency.finish
    nameserv.cmd.consistency
    |
) {
    load_module($mod);
}

## fake real addresses and host name : fixed, no system calls ##

$code{'nameserv.consistency.real-addresses'} = sub {
    return { 'v4' => [$real_v4], 'v6' => [$real_v6] };
};
$code{'nameserv.consistency.host-name'} = sub { return 'testhost.local' };

my $rev_v4 = $code{'nameserv.consistency.reverse-name'}->($real_v4);
my $rev_v6 = $code{'nameserv.consistency.reverse-name'}->($real_v6);

%canned = (
    "A $dn" => FakePacket->new(
        FakeRR->new( 'type' => qw| A |, 'value' => '198.51.100.3' )
    ),
    "AAAA $dn"              => FakePacket->new(),
    "NS protocol-7.network" => FakePacket->new(
        FakeRR->new(
            'type'  => qw| NS |,
            'value' => 'dn1110.protocol-7.network.'
        ),
        FakeRR->new( 'type' => qw| NS |, 'value' => 'ns.other.example.' )
    ),
    "NS acme.v7.ax" => FakePacket->new(
        FakeRR->new(
            'type'  => qw| NS |,
            'value' => 'dn1110.protocol-7.network.'
        ),
        FakeRR->new( 'type' => qw| NS |, 'value' => 'ns2.example.org.' )
    ),
    "NS test.v7.ax" => FakePacket->new(
        FakeRR->new(
            'type'  => qw| NS |,
            'value' => 'dn1110.protocol-7.network.'
        ),
        FakeRR->new( 'type' => qw| NS |, 'value' => "$peer." )
    ),
    "A $peer"           => FakePacket->new(),
    "AAAA $peer"        => FakePacket->new(),
    "A ns2.example.org" => FakePacket->new(
        FakeRR->new( 'type' => qw| A |, 'value' => '192.0.2.53' )
    ),
    "AAAA ns2.example.org"          => FakePacket->new(),
    "SOA acme.v7.ax \@198.51.100.3" =>
        FakePacket->new( FakeRR->new( 'type' => qw| SOA |, 'value' => 100 ) ),
    "SOA acme.v7.ax \@192.0.2.53"   => qw| TIMEOUT |,
    "SOA test.v7.ax \@198.51.100.3" =>
        FakePacket->new( FakeRR->new( 'type' => qw| SOA |, 'value' => 150 ) ),
    "PTR $rev_v4" => FakePacket->new(
        FakeRR->new( 'type' => qw| PTR |, 'value' => 'mail.example.org.' )
    ),
    "PTR $rev_v6" => FakePacket->new(
        FakeRR->new(
            'type'  => qw| PTR |,
            'value' => 'DN1110.PROTOCOL-7.NETWORK.'
        )
    ),
);

sub fake_event {    ## event.add_* handlers receive the event ##
    my $data = shift;
    return FakeEvent->new($data);
}

sub drain_run {    ## answer or time out every pending query ##
    my $state = $data{'nameserv'}{'consistency'}{'state'};
    die 'no consistency run state' if not ref $state;
    my $guard = 0;
    while ( scalar keys %{ $state->{'queries'} } ) {
        die 'drain guard tripped' if ++$guard > 1000;
        my ($id) = sort keys %{ $state->{'queries'} };
        my $q    = $state->{'queries'}->{$id};
        my $ckey = ref $q->{'sock'} ? $q->{'sock'}->{'ckey'} : '';
        if ( ( $canned{$ckey} // '' ) eq qw| TIMEOUT | ) {
            $code{'nameserv.consistency.handler.timeout'}
                ->( fake_event($id) );
        } else {
            $code{'nameserv.consistency.handler.answer'}->( fake_event($id) );
        }
    }
    return;
}

sub last_findings {
    return $data{'nameserv'}{'consistency'}{'last_run'}->{'findings'} // [];
}

sub new_log_lines {    ## log lines since the given offset ##
    my $since = shift;
    return () if $since > $#log_lines;
    return @log_lines[ $since .. $#log_lines ];
}

## assertion helpers ##

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

sub timer_like {    ## last registered timer matching a handler name ##
    my $name = shift;
    my @hit  = grep { $ARG->{'params'}{'handler'} eq $name } @timers;
    return scalar @hit ? $hit[-1] : undef;
}

## --- the command before any run -------------------------------------- ##

$call = { 'args' => '' };
my $result = $code{'nameserv.cmd.consistency'}->($call);
check 'command without a run says so',
    (       ref $result
        and $result->{'mode'} eq qw| true |
        and $result->{'data'} eq 'no consistency run yet' );

## --- run 1 : every finding text --------------------------------------- ##

my $log_offset  = scalar @log_lines;
my $timer_count = scalar @timers;
my $watch_count = scalar @io_watches;

$code{'nameserv.consistency.run'}->();

my $state = $data{'nameserv'}{'consistency'}{'state'};
check 'run state is active with pending queries',
    (       ref $state
        and $state->{'active'}
        and scalar keys %{ $state->{'queries'} } == 7 );

check 'one io watcher and one 5 s timer per query',
    (       scalar(@timers) - $timer_count == 7
        and scalar(@io_watches) - $watch_count == 7
        and timer_like(qw| nameserv.consistency.handler.timeout |)
        ->{'params'}{'after'} == 5 );

drain_run();

check 'run finished',                            not $state->{'active'};
check '18 queries asked after the run finished', scalar @dns_queries == 18;
check 'ptr asked for both real addresses',
    ( scalar( grep {m|^PTR |} @dns_queries ) == 2 );

my @want_findings = (
    'add AAAA dn1110.protocol-7.network : 2001:db8::90c6',
    'add dn0110.protocol-7.network to the NS set of acme.v7.ax',
    'add glue AAAA dn1110.protocol-7.network : 2001:db8::90c6 [ registrar ]',
    'dn0110.protocol-7.network does not answer for test.v7.ax',
    'dn1110.protocol-7.network serves '
        . 'test.v7.ax with serial 150, expected 200',
    'ns2.example.org does not answer for acme.v7.ax',
    'set ptr 203.0.113.7 -> dn1110.protocol-7.network [ hoster ]',
    'update A dn1110.protocol-7.network : 198.51.100.3 -> 203.0.113.7',
    'update glue dn1110.protocol-7.network : A '
        . '198.51.100.3 -> 203.0.113.7 [ registrar ]',
);

my @findings = @{ last_findings() };
check 'run 1 found every expected finding', (
    scalar @findings == 9
        and scalar(
        grep {
            my $text = $ARG;
            grep { $text eq $ARG } @want_findings
        } @findings
        ) == 9
);

my @logged = new_log_lines($log_offset);
check 'every finding logged once at level 1',
    (       scalar @logged == 9
        and scalar( grep {m|^: consistency : |} @logged ) == 9
        and scalar( grep {m|^: consistency : resolved|} @logged ) == 0 );

## --- run 2 : identical, nothing new is logged ------------------------- ##

@dns_queries = ();
$log_offset  = scalar @log_lines;

$code{'nameserv.consistency.run'}->();
drain_run();

check 'run 2 found the same findings', scalar @{ last_findings() } == 9;
my @run2_logs = new_log_lines($log_offset);
check 'run 2 logged nothing', scalar @run2_logs == 0;

## --- run 3 : a changed address updates and resolves findings ---------- ##

my $real_v6_new = '2001:db8::90c7';
my $rev_v6_new  = $code{'nameserv.consistency.reverse-name'}->($real_v6_new);
$canned{"PTR $rev_v6_new"} = FakePacket->new(
    FakeRR->new(
        'type'  => qw| PTR |,
        'value' => 'dn1110.protocol-7.network.'
    )
);

$code{'nameserv.consistency.real-addresses'} = sub {
    return { 'v4' => [$real_v4], 'v6' => [$real_v6_new] };
};

$log_offset = scalar @log_lines;

$code{'nameserv.consistency.run'}->();
drain_run();

@logged = new_log_lines($log_offset);
check 'changed finding logged, old one resolved', (
    scalar(
        grep {
            $_ eq ': consistency : add AAAA '
                . 'dn1110.protocol-7.network : 2001:db8::90c7'
        } @logged
        )
        and scalar(
        grep {
            $_ eq ': consistency : resolved : add AAAA '
                . 'dn1110.protocol-7.network : 2001:db8::90c6'
        } @logged
        )
        and scalar( grep {m|^: consistency : (?!resolved)|} @logged ) == 2
        and scalar( grep {m|^: consistency : resolved|} @logged ) == 2
);

## --- the glue check stays silent when glue is not expected ------------ ##

$canned{'NS protocol-7.network'} = FakePacket->new(
    FakeRR->new( 'type' => qw| NS |, 'value' => 'ns.other.example.' ) );

$log_offset = scalar @log_lines;

$code{'nameserv.consistency.run'}->();
drain_run();

@logged = new_log_lines($log_offset);
check 'no glue findings when the parent is not delegated to us',
    (       scalar( grep {m|glue|} @{ last_findings() } ) == 0
        and scalar( grep {m|^: consistency : (?!resolved)|} @logged ) == 0
        and scalar( grep {m|^: consistency : resolved : .*glue|} @logged )
        == 2 );

$canned{'NS protocol-7.network'} = FakePacket->new(
    FakeRR->new(
        'type'  => qw| NS |,
        'value' => 'dn1110.protocol-7.network.'
    ),
    FakeRR->new( 'type' => qw| NS |, 'value' => 'ns.other.example.' )
);

## --- the command : run now, in progress, show last run ---------------- ##

$call   = { 'args' => 'run:' };
$result = $code{'nameserv.cmd.consistency'}->($call);
check 'command run: starts a run',
    (       ref $result
        and $result->{'mode'} eq qw| true |
        and $result->{'data'} eq 'consistency run started' );

$call   = { 'args' => 'run' };
$result = $code{'nameserv.cmd.consistency'}->($call);
check 'second run refused while one is active',
    (       ref $result
        and $result->{'mode'} eq qw| false |
        and $result->{'data'} eq 'consistency run already in progress' );

drain_run();

$call   = { 'args' => '' };
$result = $code{'nameserv.cmd.consistency'}->($call);
check 'command shows the last run with its findings',
    (       ref $result
        and $result->{'mode'} eq qw| size |
        and $result->{'data'} =~ m|: consistency last run : |
        and $result->{'data'} =~ m|: consistency : update A |
        and $result->{'data'} =~ m|update glue | );

## --- no dn names : checks 1, 2 and 4 skip with one line --------------- ##

$data{'nameserv'}{'cfg'}{'dn_names'} = '';
@dns_queries = ();

$log_offset = scalar @log_lines;

$code{'nameserv.consistency.run'}->();
drain_run();

@logged = new_log_lines($log_offset);
check 'no dn_names logs exactly one new line [ the skip line ]',
    (       scalar @logged == 6
        and scalar( grep {m|^: consistency : (?!resolved)|} @logged ) == 1
        and scalar( grep {m|^: consistency : resolved|} @logged ) == 5
        and $logged[0] eq ': consistency : dn_names not configured : '
        . 'skipping own record, glue and ptr checks' );
check 'checks 2 and 4 sent no queries',
    (       scalar( grep {m|^PTR |} @dns_queries ) == 0
        and scalar( grep {m|^NS protocol-7\.network$|} @dns_queries ) == 0 );

$data{'nameserv'}{'cfg'}{'dn_names'} = 'dn1110.protocol-7.network';

## --- no dn peers : check 3 skips silently ------------------------------ ##

$data{'nameserv'}{'cfg'}{'dn_peers_names'} = '';

$log_offset = scalar @log_lines;

$code{'nameserv.consistency.run'}->();
drain_run();

@logged = new_log_lines($log_offset);
check 'no peers skips check 3 : its findings resolve, the skip line too',
    (       scalar( grep {m|^: consistency : (?!resolved)|} @logged ) == 5
        and scalar( grep {m|^: consistency : resolved|} @logged ) == 5
        and scalar( grep {m|NS set of|} @{ last_findings() } ) == 0
        and scalar( grep {m|dn_names not configured|} @{ last_findings() } )
        == 0 );

$data{'nameserv'}{'cfg'}{'dn_peers_names'} = 'dn0110.protocol-7.network';

## --- nothing is ever written to the zones ------------------------------ ##

my $zones = $data{'nameserv'}{'zones'};
check 'zones untouched [ same refs, same serials ]',
    (       $zones->{'acme.v7.ax'}->{'records'} == $zone_records
        and $zones->{'acme.v7.ax'}->{'serial'} == 100
        and $zones->{'test.v7.ax'}->{'serial'} == 200 );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,...,,,.,,,.,,,.,,..,,,.,,,.,.,.,.,.,..,,..,,...,..,,.,.,,..,,.,,,.,,.,,,
#JNBAN4ORXQXNAR6UYTE3AIUA7NTBDSYUYRTLXVASCHP54DV5SFBSD6J225Y4NW6U3EABRTSPYFVGO
#\\\|3WE5CY7DKM4RUK4UGB4R6HAGMT4UKLQSW6IWUPITDSWO7RMBRUF \ / AMOS7 \ YOURUM ::
#\[7]RHDMAGZQR7JKLXY7XDO7PC73KYXFQV45FBLSU5NOGMEMCY6VLCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
