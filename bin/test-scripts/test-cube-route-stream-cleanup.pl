#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use bytes ();    ##  bytes::substr for the eval'd modules, no pragma effect

## cube route + stream cleanup [ todo 7N3 ] : drives the real               ##
## src/base.handler.command.process_reply, src/base.session.cancel_route    ##
## and src/base.gen_id with fake sessions and asserts that  $data{'route'}, ##
## the per-session route tables, the streams tables and the sticky          ##
## stream_cancelled flags are all freed on every  stream-ending path        ##
## [ source gone, cancel, close, orphan close ], that the cancel-flag table ##
## stays bounded under repeated orphaned streams, and that base.gen_id      ##
## validates its parameters.  stage2-style : compiles modules via           ##
## translate/load shims, no zenka started.                                  ##

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

my ( $pass_count, $fail_count ) = ( 0, 0 );
my @sprint_calls;

## shims ##

$code{'base.logs'}     = sub { return 1 };
$code{'base.log'}      = sub { return 1 };
$code{'base.logt'}     = sub { return 1 };
$code{'base.cnt_s'}    = sub { return shift() == 1 ? '' : 's' };
$code{'base.time'}     = sub { return time() };
$code{'base.sprint_t'} = sub {
    my $template_key = shift;
    push @sprint_calls, [ $template_key, @_ ];
    return sprintf '<%s:%s>', $template_key, join ',', @_;
};
$code{'base.format_error'}                   = sub { return ( 'error', '' ) };
$code{'base.stream.emit'}                    = sub { return 1 };
$code{'base.callback.reset_strm_size_timer'} = sub { return 1 };
$code{'base.handler.hooks.has_hooks'}        = sub { return 0 };
$code{'base.handler.hooks'}                  = sub { return 0 };

## AMOS7 truth assertion shim for base.gen_id ##

package AMOS7::Assert::Truth {
    sub is_true { return 1 }
}

package main;

## fake fortuna prng for base.gen_id ##

{

    package FakeFortuna;
    sub new { return bless {}, shift }

    sub string_from {
        my ( $self, $chars, $len ) = @_;
        return join '',
            map { substr $chars, int( rand( length($chars) ) ), 1 } 1 .. $len;
    }
}

## translate + load [ same scheme as test-nameserv-sync-stage2.pl ] ##

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

    ## drop signature block [ last lines starting with # ] ##
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

load_module('base.handler.command.process_reply');
load_module('base.session.cancel_route');
load_module('base.gen_id');

## helpers ##

sub mk_session {
    my $sid = shift;
    $data{'session'}{$sid} = {
        'user'   => 'test',
        'buffer' => { 'output' => '' },
    };
    return $data{'session'}{$sid};
}

sub mk_route {    ## source sid/cmd, target sid/cmd, route id
    my ( $s_sid, $s_cid, $t_sid, $t_cid, $route_id ) = @_;
    $data{'session'}{$s_sid}{'route'}{$s_cid} = $route_id;
    $data{'session'}{$t_sid}{'route'}{$t_cid} = $route_id;
    $data{'route'}{$route_id}                 = {
        'source' => { 'sid' => $s_sid, 'cmd_id' => $s_cid },
        'target' => { 'sid' => $t_sid, 'cmd_id' => $t_cid },
    };
    return $route_id;
}

sub run_reply {
    my %a       = @_;
    my $session = $data{'session'}{ $a{'id'} } or die "no session $a{'id'}";
    my $input   = $a{'input'} // '';
    my $out     = '';
    my $reply   = {
        'event'         => undef,
        'session'       => $session,
        'id'            => $a{'id'},
        'user'          => 'test',
        'cmd'           => $a{'cmd'},
        'cmd_id'        => $a{'cmd_id'},
        'cmd_id_str'    => sprintf( '(%d)', $a{'cmd_id'} ),
        'call_args'     => { 'args' => $a{'args'} // '' },
        'input'         => \$input,
        'output'        => \$out,
        'buffer_length' => $a{'buffer_length'} // length($input),
    };
    return $code{'base.handler.command.process_reply'}->($reply);
}

sub table_counts {    ## global routes + all session route/streams/flags
    my %c = ( 'route' => scalar keys %{ $data{'route'} // {} } );
    for my $sid ( keys %{ $data{'session'} // {} } ) {
        my $s = $data{'session'}{$sid};
        $c{'routes'}    += keys %{ $s->{'route'}            // {} };
        $c{'streams'}   += keys %{ $s->{'streams'}          // {} };
        $c{'cancelled'} += keys %{ $s->{'stream_cancelled'} // {} };
    }
    return %c;
}

##[ scenario 1 : normal STRM lifecycle [ source alive ] ]#####################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(1);    ## producer
mk_session(2);    ## consumer
mk_route( 2, 99, 1, 42, 11 );

run_reply( 'id' => 1, 'cmd' => 'STRM', 'cmd_id' => 42, 'args' => 'open 10' );
check(
    's1: STRM open registered stream state',
    ref $data{'session'}{1}{'streams'}{42} eq 'HASH'
);
check( 's1: open frame forwarded to consumer',
    $data{'session'}{2}{'buffer'}{'output'} =~ m|WPSKVIA| );

run_reply(
    'id'            => 1,
    'cmd'           => 'STRM',
    'cmd_id'        => 42,
    'args'          => '5',
    'input'         => 'hello',
    'buffer_length' => 5
);
check( 's1: chunk forwarded to consumer',
    $data{'session'}{2}{'buffer'}{'output'} =~ m|hello| );

run_reply( 'id' => 1, 'cmd' => 'STRM', 'cmd_id' => 42, 'args' => 'close' );

my %c1 = table_counts();
check( 's1: global route freed after close',    $c1{'route'} == 0 );
check( 's1: session route entries freed',       $c1{'routes'} == 0 );
check( 's1: stream state freed after close',    $c1{'streams'} == 0 );
check( 's1: no cancel flags after clean close', $c1{'cancelled'} == 0 );
check( 's1: close frame forwarded to consumer',
    $data{'session'}{2}{'buffer'}{'output'} =~ m|SVH7LQQ| );

##[ scenario 2 : STRM-SIZE lifecycle [ source alive ] ]#######################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(1);
mk_session(2);
mk_route( 2, 99, 1, 42, 11 );

run_reply(
    'id'     => 1,
    'cmd'    => 'STRM-SIZE',
    'cmd_id' => 42,
    'args'   => 'open 5'
);
check(
    's2: STRM-SIZE open registered stream state',
    ref $data{'session'}{1}{'streams'}{42} eq 'HASH'
);
check( 's2: session blocked by stream',
    ( $data{'session'}{1}{'blocked_by_stream'} // 0 ) == 42 );

run_reply(
    'id'            => 1,
    'cmd'           => 'STRM-SIZE',
    'cmd_id'        => 42,
    'args'          => '5',
    'input'         => 'abcde',
    'buffer_length' => 5
);
run_reply(
    'id'     => 1,
    'cmd'    => 'STRM-SIZE',
    'cmd_id' => 42,
    'args'   => 'close'
);

my %c2 = table_counts();
check( 's2: global route freed after STRM-SIZE close', $c2{'route'} == 0 );
check( 's2: session route entries freed',              $c2{'routes'} == 0 );
check( 's2: stream state freed',                       $c2{'streams'} == 0 );
check( 's2: no ' . 'cancel flags', $c2{'cancelled'} == 0 );
check( 's2: blocking flag cleared',
    not exists $data{'session'}{1}{'blocked_by_stream'} );

##[ scenario 3 : source session gone mid-stream [ the 7N3 leak ] ]############

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(1);
mk_session(2);
mk_route( 2, 99, 1, 42, 11 );

run_reply( 'id' => 1, 'cmd' => 'STRM', 'cmd_id' => 42, 'args' => 'open 10' );
delete $data{'session'}{2};    ## consumer session dies mid-stream ##

run_reply(
    'id'            => 1,
    'cmd'           => 'STRM',
    'cmd_id'        => 42,
    'args'          => '5',
    'input'         => 'hello',
    'buffer_length' => 5
);
check( 's3: producer told to stop with !TRM!',
    $data{'session'}{1}{'buffer'}{'output'} eq "(42)!TRM!\n" );
check( 's3: cancel flag set on producer session',
    ( $data{'session'}{1}{'stream_cancelled'}{42} // 0 ) == TRUE );
check(
    's3: producer session route entry freed [ 7N3 ]',
    not keys %{ $data{'session'}{1}{'route'} // {} }
);
check( 's3: global route entry freed [ 7N3 ]',
    not exists $data{'route'}{11} );
check(
    's3: cube-side stream state freed [ 7N3 ]',
    not keys %{ $data{'session'}{1}{'streams'} // {} }
);

## second chunk : late push lands on unknown-route path, no duplicate !TRM! ##

run_reply(
    'id'            => 1,
    'cmd'           => 'STRM',
    'cmd_id'        => 42,
    'args'          => '5',
    'input'         => 'world',
    'buffer_length' => 5
);
check(
    's3: late chunk dropped without second !TRM!',
    $data{'session'}{1}{'buffer'}{'output'} eq "(42)!TRM!\n"
);

## producer close frame ends the flag ##

run_reply( 'id' => 1, 'cmd' => 'STRM', 'cmd_id' => 42, 'args' => 'close' );
check( 's3: cancel flag released by close frame',
    not keys %{ $data{'session'}{1}{'stream_cancelled'} // {} } );

##[ scenario 4 : 200 source-gone streams stay bounded ]#######################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(1);
mk_session(2);

for my $n ( 1 .. 200 ) {
    my $t_cid = 1000 + $n;
    mk_route( 2, 99, 1, $t_cid, 5000 + $n );
    run_reply(
        'id'     => 1,
        'cmd'    => 'STRM',
        'cmd_id' => $t_cid,
        'args'   => 'open 5'
    );
    delete $data{'session'}{2}{'route'}{99};    ## previous route id reuse
    delete $data{'session'}{2} if $n > 1;
    mk_session(2)              if $n == 1;
    delete $data{'session'}{2} if $n == 1;      ## consumer gone
    run_reply(
        'id'            => 1,
        'cmd'           => 'STRM',
        'cmd_id'        => $t_cid,
        'args'          => '5',
        'input'         => 'xxxxx',
        'buffer_length' => 5
    );
    run_reply(
        'id'     => 1,
        'cmd'    => 'STRM',
        'cmd_id' => $t_cid,
        'args'   => 'close'
    );
}

my %c4 = table_counts();
check( 's4: global route table bounded after 200 dead-consumer streams',
    $c4{'route'} == 0 );
check( 's4: producer route table bounded',  $c4{'routes'} == 0 );
check( 's4: producer stream table bounded', $c4{'streams'} == 0 );
check( 's4: cancel flag table bounded',     $c4{'cancelled'} == 0 );

##[ scenario 5 : orphaned chunk with no route at all ]########################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(3);

run_reply(
    'id'            => 3,
    'cmd'           => 'STRM',
    'cmd_id'        => 555,
    'args'          => '3',
    'input'         => 'abc',
    'buffer_length' => 3
);
check(
    's5: orphan chunk answered with !TRM! to producer',
    $data{'session'}{3}{'buffer'}{'output'} eq "(555)!TRM!\n"
);
check( 's5: cancel flag set for orphan cmd_id',
    ( $data{'session'}{3}{'stream_cancelled'}{555} // 0 ) == TRUE );

run_reply( 'id' => 3, 'cmd' => 'STRM', 'cmd_id' => 555, 'args' => 'close' );
check( 's5: orphan close frame releases the flag',
    not keys %{ $data{'session'}{3}{'stream_cancelled'} // {} } );

##[ scenario 6 : cancel-flag sweep bound ]####################################

%data                              = ();
$data{'regex'}{'base'}             = {};
$data{'net'}{'silent_ignore'}      = {};
$data{'base'}{'strm'}{'local'}     = {};
$data{'base'}{'prng'}{'fortuna'}   = FakeFortuna->new;
$data{'limit'}{'stream_cancelled'} = 5;

mk_session(4);

for my $cid ( 600 .. 611 ) {    ## 12 orphan chunks, producer never closes
    run_reply(
        'id'            => 4,
        'cmd'           => 'STRM',
        'cmd_id'        => $cid,
        'args'          => '1',
        'input'         => 'x',
        'buffer_length' => 1
    );
}
my $flag_count = keys %{ $data{'session'}{4}{'stream_cancelled'} // {} };
check( "s6: flag table swept to limit [ $flag_count <= 6 ]",
    $flag_count <= 6 );

##[ scenario 7 : cancel_route collapses a route completely ]##################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(5);    ## source
mk_session(6);    ## target
mk_route( 5, 77, 6, 88, 21 );
$data{'session'}{6}{'streams'}{88} = { 'received_bytes' => 0 };

$code{'base.session.cancel_route'}->( 5, 'test teardown', 77 );

check(
    's7: source got FALSE route-collapsed reply',
    $data{'session'}{5}{'buffer'}{'output'} eq
        "(77)FALSE command route collapsed\n"
);
check( 's7: producer told to stop with !TRM!',
    $data{'session'}{6}{'buffer'}{'output'} eq "(88)!TRM!\n" );
check( 's7: global route freed', not exists $data{'route'}{21} );
check( 's7: target route entry freed',
    not keys %{ $data{'session'}{6}{'route'} // {} } );
check( 's7: target stream state freed',
    not keys %{ $data{'session'}{6}{'streams'} // {} } );
check(
    's7: cancel flags set on both peers [ bounded by sweep ]',
    ( $data{'session'}{5}{'stream_cancelled'}{77} // 0 ) == TRUE
        && ( $data{'session'}{6}{'stream_cancelled'}{88} // 0 ) == TRUE
);

##[ scenario 8 : stale cancel flag cleared by a fresh open ]##################

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(7);
mk_session(8);
mk_route( 8, 66, 7, 33, 31 );
$data{'session'}{7}{'stream_cancelled'}{33} = TRUE;    ## stale from before

run_reply( 'id' => 7, 'cmd' => 'STRM', 'cmd_id' => 33, 'args' => 'open 9' );
check(
    's8: fresh open clears stale cancel flag for recycled cmd_id',
    not keys %{ $data{'session'}{7}{'stream_cancelled'} // {} }
);
check( 's8: stream state registered',
    ref $data{'session'}{7}{'streams'}{33} eq 'HASH' );

##[ scenario 9 : unknown-route close drops leftover stream state ]############

%data                            = ();
$data{'regex'}{'base'}           = {};
$data{'net'}{'silent_ignore'}    = {};
$data{'base'}{'strm'}{'local'}   = {};
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

mk_session(9);
$data{'session'}{9}{'streams'}{44}          = { 'received_bytes' => 3 };
$data{'session'}{9}{'stream_cancelled'}{44} = TRUE;

run_reply( 'id' => 9, 'cmd' => 'STRM', 'cmd_id' => 44, 'args' => 'close' );
check(
    's9: unknown-route close drops leftover stream state',
    not keys %{ $data{'session'}{9}{'streams'} // {} }
);
check( 's9: unknown-route close drops the flag',
    not keys %{ $data{'session'}{9}{'stream_cancelled'} // {} } );

##[ scenario 10 : base.gen_id parameter validation ]##########################

%data = ();
$data{'base'}{'prng'}{'fortuna'} = FakeFortuna->new;

my $warn_buf = '';
local $SIG{'__WARN__'} = sub { $warn_buf .= join '', @_ };

my %table;
my $gid = $code{'base.gen_id'}->( \%table );
check( 's10: valid gen_id returns defined id', defined $gid );
check( 's10: id is digits only',               ( $gid // '' )  =~ m|^\d+$| );
check( 's10: id does not start with 0',        ( $gid // '0' ) !~ m|^0| );
check( 's10: default id length is 7 [ max_ids 13747, empty table ]',
    length( $gid // '' ) == 7 );
check( 's10: id not taken from table', not exists $table{ $gid // '' } );

$table{$gid} = 1;
my $gid2 = $code{'base.gen_id'}->( \%table );
check( 's10: second id differs', defined $gid2 && $gid2 != $gid );

$warn_buf = '';
my $bad1 = $code{'base.gen_id'}->( \%table, 'abc' );
check( 's10: non-numeric max_ids refused', not defined $bad1 );
check( 's10: non-numeric max_ids warns',   $warn_buf =~ m|max_ids| );

$warn_buf = '';
my $bad2 = $code{'base.gen_id'}->( \%table, -7 );
check( 's10: negative max_ids refused', not defined $bad2 );

$warn_buf = '';
my $bad3 = $code{'base.gen_id'}->( \%table, 0 );
check( 's10: zero max_ids refused', not defined $bad3 );

$warn_buf = '';
my $bad4 = $code{'base.gen_id'}->( \%table, 100, '12a' );
check( 's10: non-digit num_range refused', not defined $bad4 );
check( 's10: non-digit num_range warns',   $warn_buf =~ m|num_range| );

$warn_buf = '';
my $bad5 = $code{'base.gen_id'}->( \%table, 100, '000' );
check( 's10: all-zero num_range refused', not defined $bad5 );

my $gid5 = $code{'base.gen_id'}->( \%table, 100 );
check(
    's10: max_ids 100 yields id length 5',
    defined $gid5 && length($gid5) == 5
);

my $gid6 = $code{'base.gen_id'}->( \%table, 100, '0123456789', 0 );
check( 's10: harmony disabled works', defined $gid6 );

##[ summary ]#################################################################

printf "\n%d passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,.,,,,.,.,.,...,,,.,...,.,.,,,,,..,,,,.,..,,...,...,,..,.,.,.,,,,.,,...,
#LK5WN3BN7C5DPNJNZVGDYSZZFECLGPMKRKNC6VTMYGJ47L23EI3PTBEKZPBKTYC7BF7KPXTJN6KEG
#\\\|DI4WYCZHLIEBAAVSZO3NF4PPS6INIKA5UN4NSRH5O7JDFB5P4KV \ / AMOS7 \ YOURUM ::
#\[7]NGSX5HNNZYGQEQIGHY67R3VJZWCZGKNVVCD2Q4UMTGUGL5PNTYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
