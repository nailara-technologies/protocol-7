#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## v7-zenki liveness sweep [ 2026-10-06 ]  compiles the real                ##
## v7-zenki.handler.liveness_sweep + its liveness dependency                ##
## v7-zenki.sub-process.pid_alive [ /proc check ] and the real              ##
## v7-zenki.child.add ; the sig_chld handler, instance id list, logs and    ##
## ntime are stubbed. uses a real live pid [ $$ ], a real dead pid [ fork + ##
## waitpid ], a real zombie [ fork, exit, NOT reaped ] and real /proc data. ##
## no zenka started, restarted or reloaded.                                 ##

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## stubs : everything the sweep and child.add call outside themselves ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub {return};
## fixed : worst case ##
$code{'base.ntime'} = sub { return '3225760654008' };
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'} = sub { return '[ test ]' };
$code{'v7-zenki.instance_ids'}
    = sub { return keys %{ $data{'v7-zenki'}{'zenka'}{'instance'} // {} } };
my @sig_calls;
$code{'v7-zenki.handler.sig_chld'} = sub {
    my ( $pid, $exit_code ) = @ARG;
    push @sig_calls, [ $pid, $exit_code ];
    return;
};

compile_module('v7-zenki.sub-process.pid_alive');
compile_module('v7-zenki.child.add');
my $sweep = compile_module('v7-zenki.handler.liveness_sweep');

## zombies stay unreaped until the very end ##
my @zombie_pids;

sub reset_state {
    $data{'v7-zenki'} = {};
    $data{'zenka'}    = {};
    @logged           = ();
    @sig_calls        = ();
    return;
}

sub add_instance {
    my ( $instance_id, $pid, $extra ) = @ARG;
    my $instance = {
        qw| zenka_name | => "zenka-$instance_id",
        qw| process |    => { qw| id | => $pid },
    };
    foreach my $key ( keys %{ $extra // {} } ) {
        $instance->{$key} = $extra->{$key};
    }
    $data{'v7-zenki'}{'zenka'}{'instance'}{$instance_id} = $instance;
    return $instance;
}

sub dead_pid {
    my $pid = fork // die "fork failed : $OS_ERROR";
    exit 0 if $pid == 0;
    waitpid( $pid, 0 );
    return $pid;
}

sub zombie_pid {
    my $pid = fork // die "fork failed : $OS_ERROR";
    exit 0 if $pid == 0;
    ## the child takes a moment to die : wait for state Z explicitly ##
    foreach my $try ( 1 .. 50 ) {
        last if proc_state($pid) eq qw| Z |;
        select undef, undef, undef, 0.1;
    }
    push @zombie_pids, $pid;
    return $pid;
}

sub proc_state {
    my $pid = shift;
    open( my $fh, '<', "/proc/$pid/stat" ) or return '';
    my $stat = readline($fh) // '';
    close($fh);
    my ($state) = $stat =~ m{\)\s+(\S)}o;
    return $state // '';
}

## a restart timer double : is_active as constructed ##
package TestRestartTimer;
use English;
my $test_timer_active = 1;

sub new {
    my $class = shift;
    $test_timer_active = shift // 1;
    return bless {}, $class;
}
sub is_active { return $test_timer_active }

package main;
use English;

say ': live pid';

reset_state();
add_instance( 'i-live', $$ );
my $count = $sweep->();
ok( $count == 0, 'live pid : nothing recovered' );
ok( !@sig_calls, 'live pid : no sig_chld call' );
ok( !keys %{ $data{'v7-zenki'}{'child'} // {} },
    'live pid : no child entry added'
);

say ': dead pid [ reaped, /proc entry gone ]';

reset_state();
my $dead = dead_pid();
add_instance( 'i-dead', $dead );
$count = $sweep->();
ok( $count == 1, 'dead pid : return value counts the recovery' );
ok( scalar(@sig_calls) == 1
        && $sig_calls[0][0] == $dead
        && $sig_calls[0][1] == -1,
    'dead pid : sig_chld injected as ( pid, -1 )'
);
my $child_entry = $data{'v7-zenki'}{'child'}{$dead} // {};
ok( ( $child_entry->{'instance_id'} // '' ) eq 'i-dead'
        && ( $child_entry->{'liveness'} // 0 ) == TRUE,
    'dead pid : child entry restored with instance_id + liveness flag'
);

say ': zombie pid [ state Z, not reaped ]';

reset_state();
my $zombie = zombie_pid();
ok( proc_state($zombie) eq qw| Z |, 'setup : child really is a zombie' );
add_instance( 'i-zombie', $zombie );
$count = $sweep->();
ok( $count == 1, 'zombie : treated like dead [ counted ]' );
ok( scalar(@sig_calls) == 1 && $sig_calls[0][0] == $zombie,
    'zombie : sig_chld injected' );
ok( exists $data{'v7-zenki'}{'child'}{$zombie},
    'zombie : child entry restored' );

say ': instance being stopped';

reset_state();
my $dead_stop = dead_pid();
add_instance( 'i-stop', $dead_stop );
$data{'zenka'}{'instance'}{'shutdown'}{'i-stop'} = 1;
$count = $sweep->();
ok( $count == 1, 'stopping : counted' );
ok( scalar(@sig_calls) == 1 && $sig_calls[0][0] == $dead_stop,
    'stopping : sig_chld recorded' );
ok( !exists $data{'v7-zenki'}{'child'}{$dead_stop},
    'stopping : NO child entry added [ the stop completes instead ]' );

say ': pending restart timer owns the instance';

reset_state();
my $dead_timer = dead_pid();
add_instance( 'i-timer', $dead_timer,
    { qw| timer | => { qw| restart | => TestRestartTimer->new(1) } } );
$count = $sweep->();
ok( $count == 0, 'active restart timer : skipped entirely' );
ok( !@sig_calls, 'active restart timer : no sig_chld call' );
ok( !exists $data{'v7-zenki'}{'child'}{$dead_timer},
    'active restart timer : no child entry'
);

reset_state();
my $dead_timer2 = dead_pid();
add_instance( 'i-timer2', $dead_timer2,
    { qw| timer | => { qw| restart | => TestRestartTimer->new(0) } } );
$count = $sweep->();
ok( $count == 1 && scalar(@sig_calls) == 1,
    'inactive restart timer : NOT skipped [ recovered ]' );

say ': still tracked on the next sweeps';

reset_state();
my $dead_track = dead_pid();
add_instance( 'i-track', $dead_track );
$count = $sweep->();
ok( $count == 1 && scalar(@sig_calls) == 1,
    'first sweep : recovered, one injection'
);
my $logged_before = scalar @logged;
$count = $sweep->();
ok( $count == 0, 'second sweep : not counted again' );
my @new_logs = @logged[ $logged_before .. $#logged ];
ok( scalar(@new_logs) == 1
        && $new_logs[0][0] == 0
        && $new_logs[0][1] =~ m{still tracked}o,
    'second sweep : exactly one level-0 still-tracked log'
);
ok( scalar(@sig_calls) == 1, 'second sweep : no second sig_chld' );
$logged_before = scalar @logged;
$count         = $sweep->();
ok( scalar(@logged) == $logged_before && $count == 0,
    'third sweep : silence' );

say ': forgotten once no instance tracks the pid';

## state carries over : recovered still holds $dead_track ##
delete $data{'v7-zenki'}{'zenka'}{'instance'}{'i-track'};
$count = $sweep->();
ok( !exists $data{'v7-zenki'}{'liveness'}{'recovered'}{$dead_track},
    'pid no instance tracks any more is dropped from the recovered map'
);

say ': non-numeric and too-small pids ignored';

reset_state();
add_instance( 'i-bad-a', 'abc' );
add_instance( 'i-bad-1', 1 );
add_instance( 'i-bad-0', 0 );
$count = $sweep->();
ok( $count == 0 && !@sig_calls && !keys %{ $data{'v7-zenki'}{'child'} // {} },
    'pids that are not numeric or < 2 are ignored'
);

## reap every zombie the sweep refused to reap [ stubbed sig_chld ] ##
waitpid( $ARG, 0 ) for @zombie_pids;

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,.,,,,,.,..,,.,.,,,.,,,,,,.,,,,,,...,..,,.,.,...,...,...,.,,,,.,,,,,,,.,,
#XS7OSZLYLGEV6HQHKMAPZOX72AKBWVI5TMVIY4NKPVD5VY4Z6Z5234LOWNAIQRIZFGY5BRMIRV5UA
#\\\|Z7GQBGX3MOBEUGJATY5YWQAZRYTFAZTNK6RD5HK7M3H6EWPOIFT \ / AMOS7 \ YOURUM ::
#\[7]JL3TV5NP7UARM6Z5VI5QLFCHA6BJ6WASEDBKTTKLYHUHT2XPLODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
