#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## v7-zenki start-up heartbeat probe : after verification an instance goes ##
## 'online' only once it answers a heartbeat ; FALSE \ no reply is a       ##
## start-up error [ from 'starting' ] ; heartbeat.disabled and cube skip   ##
## the probe. REAL v7-zenki.startup_probe \ .handler.startup_probe_reply \ ##
## .handler.startup_probe_timeout \ .handler.instance_verification ; the   ##
## status change, send.local and timers are recorded. no zenka.            ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

my $fail_count = 0;
my $test_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- stubs ------------------------------------------------------------- ##

## a timer object : cancel \ is_active, the handler called with an event ##
{

    package FakeTimer;
    sub new { my ( $c, $p ) = @_; return bless { p => $p, active => 1 }, $c }
    sub cancel    { $_[0]{active} = 0; return }
    sub is_active { return $_[0]{active} }
    sub w         { return $_[0] }
    sub data      { return $_[0]{p}{'data'} }
}

my ( @logged, @status, @sent, @timers );
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.time'} = sub { return '100.0000' };
$code{'base.cfg_bool'}
    = sub { return ( $ARG[0] // '' ) =~ m{^(1|yes|true)$}i };
$code{'zenka.change_status'} = sub {
    push @status, [@ARG];
    $data{'v7-zenki'}{'zenka'}{'instance'}{ $ARG[0] }{'status'} = $ARG[1];
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub { push @sent, $ARG[0]; return };
$code{'event.add_timer'}               = sub {
    my $timer = FakeTimer->new( $ARG[0] );
    push @timers, $timer;
    return $timer;
};

compile_module($ARG) for qw| v7-zenki.startup_probe
    v7-zenki.handler.startup_probe_reply
    v7-zenki.handler.startup_probe_timeout
    v7-zenki.handler.instance_verification |;

sub instance { return $data{'v7-zenki'}{'zenka'}{'instance'}{ $ARG[0] } }

sub new_instance {
    my ( $id, %extra ) = @ARG;
    $data{'v7-zenki'}{'zenka'}{'instance'}{$id} = {
        'zenka_name'            => 'probe-test',
        'status'                => 'starting',
        'root_sid'              => 1,
        'cube_sid'              => 4000 + $id,
        'instance_verification' => 'KEY',
        %extra
    };
    @status = @sent = @timers = @logged = ();
    return instance($id);
}

sub reply {    ## the reply handler gets ONE hash [ params inside ] ##
    my ( $id, $cmd, $args, $probe_id ) = @ARG;
    return $code{'v7-zenki.handler.startup_probe_reply'}->(
        {   'cmd'       => $cmd,
            'call_args' => { 'args' => $args },
            'params'    => {
                'instance_id' => $id,
                'probe_id'    => $probe_id
                    // instance($id)->{'startup_probe'}{'id'}
            }
        }
    );
}

sub fire_timeout {
    return $code{ 'v7-zenki.handler.st' . 'artup_probe_timeout' }->( $ARG[0] );
}

$data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}{'probe-test'} = {};
$data{'v7-zenki'}{'start_setup'}{'globals'} = {};

say ':: verification -> probe -> online';

new_instance(1);
$code{'v7-zenki.handler.instance_verification'}->( 1, 'KEY' );
ok( !@status, 'verified : not online yet' );
ok( @sent == 1 && $sent[0]{'command'} eq '1.4001.heart',
    '  :.. heartbeat probe sent over the instance route'
);
ok( @timers == 1 && $timers[0]{p}{'after'} == 17,
    '  :.. timeout armed [ 17 s default ]'
);
reply( 1, 'TRUE', 'beating [ 0.0002 secs ]' );
ok( @status == 1 && $status[0][1] eq 'online', 'beating : online' );
ok( !$timers[0]->is_active && !exists instance(1)->{'startup_probe'},
    '  :.. timer cancelled, probe state gone' );

say ':: refused \ no reply : start-up error';

new_instance(2);
$code{'v7-zenki.handler.instance_verification'}->( 2, 'KEY' );
reply( 2, 'FALSE', 'command not known' );
ok( @status == 1 && $status[0][1] eq 'error', 'FALSE : error' );
ok( grep( { $ARG->[0] eq '0' && $ARG->[1] =~ m|refused| } @logged ),
    '  :.. logged at level 0' );

new_instance(3);
$code{'v7-zenki.handler.instance_verification'}->( 3, 'KEY' );
fire_timeout( $timers[0] );
ok( @status == 1 && $status[0][1] eq 'error', 'no reply : error' );
ok( grep( { $ARG->[0] eq '0' && $ARG->[1] =~ m|no start-up heartbeat| }
        @logged ),
    '  :.. logged at level 0'
);
ok( !defined reply( 3, 'TRUE', 'beating', 1 ) && @status == 1,
    '  :.. a late reply afterwards changes nothing'
);

say ':: stale and out-of-state events';

new_instance(4);
$code{'v7-zenki.handler.instance_verification'}->( 4, 'KEY' );
my $first_timer = $timers[0];
reply( 4, 'TRUE', 'beating', 99 );
ok( !@status, 'a reply for another probe id : ignored' );
instance(4)->{'status'} = 'error';    ## the process ended meanwhile ##
reply( 4, 'TRUE', 'beating' );
ok( !@status, 'instance no longer starting : no status change' );

new_instance(5);
$code{'v7-zenki.handler.instance_verification'}->( 5, 'KEY' );
instance(5)->{'status'} = 'offline';
fire_timeout( $timers[0] );
ok( !@status, 'timeout while not starting : ignored' );

say ':: memory pressure extends the wait';

new_instance(6);
$data{'v7-zenki'}{'pressure'}{'level'} = 'elevated';
$code{'v7-zenki.handler.instance_verification'}->( 6, 'KEY' );
fire_timeout( $timers[-1] ) for 1 .. 3;
ok( !@status && @timers == 4, 'elevated : 3 extensions, no error yet' );
fire_timeout( $timers[-1] );
ok( @status == 1 && $status[0][1] eq 'error',
    '  :.. the 4th timeout : error'
);
delete $data{'v7-zenki'}{'pressure'};

say ':: no probe : heartbeat disabled \ cube \ failed verification';

new_instance(7);
$data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}{'probe-test'}
    = { 'heartbeat' => { 'disabled' => 'yes' } };
$code{'v7-zenki.handler.instance_verification'}->( 7, 'KEY' );
ok( @status == 1 && $status[0][1] eq 'online' && !@sent,
    'heartbeat.disabled : online at once, no probe'
);
$data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}{'probe-test'} = {};

new_instance( 8, 'is-cube' => TRUE );
$code{'v7-zenki.handler.instance_verification'}->( 8, 'KEY' );
ok( @status == 1 && $status[0][1] eq 'online' && !@sent,
    'cube : online at once, no probe' );

new_instance(9);
$code{'v7-zenki.handler.instance_verification'}->( 9, 'WRONG' );
ok( @status == 1 && $status[0][1] eq 'error' && !@sent,
    'verification failed : error, no probe'
);

## configured timeout ##
new_instance(10);
$data{'v7-zenki'}{'start_setup'}{'globals'}{'heartbeat'}{'timeout'} = 29;
$code{'v7-zenki.handler.instance_verification'}->( 10, 'KEY' );
ok( $timers[0]{p}{'after'} == 29, 'heartbeat.timeout from globals used' );

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,...,,,.,,,,,,,.,,,,,..,,.,,,,.,,.,.,.,,,..,,...,...,..,,,..,,,,,,.,,,.,,
#KN56LSDXYB2ENSHWTXSNRBL2BOUGRAFOIWX5EY62VVEHOAWE7OOC5IJJDNXCQTATPZJ5ECNW5TISM
#\\\|CT5B6RXJ67KEE5RBIGKW5QJC4UR4CUHOGZJ5VLFDRDGGXKCP3AI \ / AMOS7 \ YOURUM ::
#\[7]ICAHKHHYYZBIJJUVD4W4PO3MNWB5IASEQEHCZJWUJVWI6DMESCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
