#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## models.cfg.task_zenka as a LIST of task zenki [ todo HWO ] :           ##
## - list parsing : single name works as before, default 'task'           ##
## - source remembered per task id : claims route back to the right zenka ##
## - the local 'task' zenka [ task-notify ] claims directly, remote ones  ##
## peek first, pinned to an unserved model stays pending                  ##
## - per listed zenka : own subscribe + poll state, one zenka down        ##
## [ link presumed down after 90 s, route-send refused ] never blocks the ##
## rest                                                                   ##
## - models.cmd.set-zenki changes the list at run time : re-arms, drops   ##
## streams of removed zenki, clears remembered sources                    ##

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

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;
    use constant UNKNOWN => 2;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## ---------------------------------------------------------------------- ##
## stubs                                                                  ##

my @logged;
my @sent;
my @cancelled_streams;
my %route_fail;         ## zenka => 1 : route-send refuses that zenka ##
my %parse_show_plan;    ## task_id => parsed show hash ##

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf( shift, @ARG ) ]; return };

$code{'protocol-7.route-send'} = sub {
    my $send    = shift              // {};
    my $command = $send->{'command'} // '';
    my ($zenka) = $command =~ m{^(.+)\.[a-z-]+$};
    return 0 if length( $zenka // '' ) and $route_fail{$zenka};
    push @sent, $send;
    return 1;
};

$code{'strm.local.cancel'} = sub {
    push @cancelled_streams, shift;
    return TRUE;
};

my %registered_watchers;
$code{'strm.local.register'} = sub {
    my ( $cmd_id, $handlers ) = @ARG;
    $registered_watchers{$cmd_id} = $handlers;
    return TRUE;
};

my @timers;
$code{'event.add_timer'} = sub {
    my $timer = shift // {};
    push @timers, $timer;
    return bless { %{$timer}, 'active' => 1 }, 'TestTimer';
};

sub TestTimer::cancel    { $_[0]->{'active'} = 0; return }
sub TestTimer::is_active { return $_[0]->{'active'} }

my $parse_show_stub = sub {
    my ( $task_id, $text ) = @ARG;
    return $parse_show_plan{$task_id} // {};
};
$code{'models.task.parse-show'} = $parse_show_stub;

my @enqueued;
$code{'models.task.enqueue'} = sub {
    push @enqueued, shift;
    return TRUE;
};

## the live HWO case wants the REAL parse-show : ':no_tools:' first line + ##
## ':model:' pin handling. compiled here, swapped in for the section, the  ##
## stub restored after                                                     ##
my $real_parse_show = compile_module('models.task.parse-show');
$code{'models.task.parse-show'} = $parse_show_stub;

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## real modules under test ##
compile_module($_)
    for qw| models.task.zenki models.task.zenka-of models.task.cmd
    models.task.remote models.task.dispatch-id models.task.pin-accepted
    models.task.peek-claim models.task.subscribe
    models.task.subscribe-retry models.handler.task-poll
    models.handler.task-poll-step models.handler.task-stream
    models.task.startup models.task.claim-ok models.task.release-claim
    models.task.rescan models.task.set-local-models |;

## .cmd. modules get 'my $call' from the runtime's compiled-in command ##
## header [ bin/Protocol-7 ] : mirror it with an our-scoped $call the  ##
## harness sets before each invocation                                 ##
compile_module( 'models.cmd.set-zenki',   $module_prefix . "\nour \$call;" );
compile_module( 'models.cmd.task-notify', $module_prefix . "\nour \$call;" );

## ---------------------------------------------------------------------- ##
## helpers                                                                ##

sub reset_models_state {
    $data{'models'}
        = { 'cfg' => { 'task_zenka' => 'task', 'task_max_claims' => 0 } };
    @sent                = ();
    @logged              = ();
    @timers              = ();
    @enqueued            = ();
    @cancelled_streams   = ();
    %registered_watchers = ();
    %route_fail          = ();
    %parse_show_plan     = ();
    return;
}

sub sent_commands {
    return map { $ARG->{'command'} // '' } @sent;
}

## a TRUE-reply carrying single-line args, as task.show answers ##
sub true_reply {
    my ( $args, $params ) = @ARG;
    return {
        'cmd'       => qw| TRUE |,
        'call_args' => { 'args' => $args },
        'data'      => '',
        'params'    => $params // {}
    };
}

my $LOCAL_ID  = 'ABC1DEF';
my $PRI_ID    = 'BYQSQFQ';
my $Z_ID      = 'AB12CD3';
my $PRI_ZENKA = 'external.pri.task';
my $Z_ZENKA   = 'external.z.task';

## ---------------------------------------------------------------------- 1 ##
## : list parsing [ single name, default, dedupe, order ]                   ##

say "\n :. task zenki list parsing";

reset_models_state();
ok( join( ' ', $code{'models.task.zenki'}->() ) eq 'task',
    'unset config falls back to task' );

$data{'models'}{'cfg'}{'task_zenka'} = $PRI_ZENKA;
ok( join( ' ', $code{'models.task.zenki'}->() ) eq $PRI_ZENKA,
    'single external name works as before' );

$data{'models'}{'cfg'}{'task_zenka'} = "task $PRI_ZENKA";
ok( join( ' ', $code{'models.task.zenki'}->() ) eq "task $PRI_ZENKA",
    'two zenki listed, order kept' );

$data{'models'}{'cfg'}{'task_zenka'} = "task $Z_ZENKA $PRI_ZENKA task";
ok( join( ' ', $code{'models.task.zenki'}->() ) eq "task $Z_ZENKA $PRI_ZENKA",
    'duplicates dropped'
);

$data{'models'}{'cfg'}{'task_zenka'} = '';
ok( join( ' ', $code{'models.task.zenki'}->() ) eq 'task',
    'empty config falls back to task' );

$data{'models'}{'cfg'}{'task_zenka'} = 'task';
ok( $code{'models.task.remote'}->() == FALSE, 'task only : not remote' );
$data{'models'}{'cfg'}{'task_zenka'} = "$PRI_ZENKA task";
ok( $code{'models.task.remote'}->() == TRUE,
    'mixed list : remote [ any non-task zenka ]'
);

## ---------------------------------------------------------------------- 2 ##
## : claims route back to the remembered source zenka                       ##

say "\n :. source remembered per task id";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "task $PRI_ZENKA";

## local task-notify path : claim the local task zenka directly ##
$code{'models.task.dispatch-id'}->( $LOCAL_ID, qw| task | );
my @cmds = sent_commands();
ok( $cmds[0] eq 'task.claim',
    'local task-notify claims task.claim directly' );
ok( $data{'models'}{'task'}{'source'}->{$LOCAL_ID}{'zenka'} eq 'task',
    'local source remembered' );

## remote peek path ##
@sent = ();
$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
@cmds = sent_commands();
ok( $cmds[0] eq "$PRI_ZENKA.show", 'remote task peeks its own zenka' );
ok( $data{'models'}{'task'}{'source'}->{$PRI_ID}{'zenka'} eq $PRI_ZENKA,
    'remote source remembered' );

## commands for the task route by source, not by config position ##
ok( $code{'models.task.cmd'}->( qw| claim |, $PRI_ID ) eq "$PRI_ZENKA.claim",
    'claim routes to the pri source'
);
ok( $code{'models.task.cmd'}->( qw| complete |, $LOCAL_ID ) eq
        'task.complete',
    'complete routes to the local source'
);
ok( $code{'models.task.cmd'}->( qw| start |, $PRI_ID ) eq "$PRI_ZENKA.start",
    'start routes to the pri source'
);
ok( $code{'models.task.cmd'}->(qw| claim |) eq 'task.claim',
    'no task id : first listed zenka [ old single-name route ]'
);

## ---------------------------------------------------------------------- 3 ##
## : peek chain on the source zenka, pin rule kept                          ##

say "\n :. peek -> claim on the source zenka";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'}  = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_models'} = "OTHERZEN:ABC2DEF";

$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
@cmds = sent_commands();
my $peek_send = $sent[0];

## task served here, pin accepted : claim back on the pri zenka ##
$parse_show_plan{$PRI_ID} = {
    'status'     => 'pending',
    'model'      => 'local',
    'prompt'     => ":no_tools:\nassess this",
    'target_cmd' => 'coding.ask-reply',
    'model_pin'  => 'AAA:ABC2DEF'
};
@sent = ();
$code{'models.handler.task-poll-step'}
    ->( true_reply( 'pending task text', $peek_send->{'reply'}{'params'} ) );
@cmds = sent_commands();
ok( ( grep { $ARG eq "$PRI_ZENKA.claim" } @cmds ),
    'pin served : claim goes back to the pri zenka'
);

## claim answered TRUE : start + enqueue ##
@sent = ();
my $claim_send
    = ( grep { $ARG->{'command'} eq "$PRI_ZENKA.claim" } @sent )[0];

## refused pin : stays pending, never claimed ##
reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'}  = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_models'} = "OTHERZEN:XXXXXXX";

$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
$parse_show_plan{$PRI_ID} = {
    'status'     => 'pending',
    'model'      => 'foreign',
    'prompt'     => ":no_tools:\nassess this",
    'target_cmd' => 'coding.ask-reply',
    'model_pin'  => 'AAA:ABC2DEF'
};
@sent = ();
$code{'models.handler.task-poll-step'}
    ->( true_reply( 'pending task text', $sent[-1] ? {} : {} ) )
    ;    ## params rebuilt below ##

## rebuild : dispatch-id reply params captured before reset ##
## [ simpler : re-run dispatch and keep the send record ]   ##
@sent = ();
$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
my $peek_params = $sent[0]->{'reply'}{'params'};
@sent = ();
$code{'models.handler.task-poll-step'}
    ->( true_reply( 'pending task text', $peek_params ) );
@cmds = sent_commands();
ok( scalar @cmds == 0,
    'pin not served here : left pending, nothing claimed or failed' );

## b7b0f476e guard : a foreign task WITHOUT a :no_tools: first line is   ##
## refused too [ tool use stays with its own host ] -- even when the pin ##
## would be served                                                       ##
reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'}  = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_models'} = "OTHERZEN:ABC2DEF";

$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
$peek_params = $sent[0]->{'reply'}{'params'};
$parse_show_plan{$PRI_ID} = {
    'status'     => 'pending',
    'model'      => 'local',
    'prompt'     => 'assess this with tools',
    'target_cmd' => 'coding.ask-reply',
    'model_pin'  => 'AAA:ABC2DEF'
};
@sent = ();
$code{'models.handler.task-poll-step'}
    ->( true_reply( 'pending task text', $peek_params ) );
ok( scalar sent_commands() == 0,
    'foreign task without :no_tools: : refused, left for its own host' );

## ---------------------------------------------------------------------- 4 ##
## : per-zenka poll + subscribe : one down never blocks the others          ##

say "\n :. per-zenka poll independence";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "$Z_ZENKA $PRI_ZENKA";

## pri : silent for 91 s with a subscribed stream -> presumed down ##
$data{'models'}{'task'}{'streams'}{$PRI_ZENKA} = {
    'subscribed'   => TRUE,
    'cmd_id'       => 7,
    'poll_sent_at' => time - 91,
    'retry_at'     => 0,
    'since'        => undef,
};
## z : healthy, never polled ##
$data{'models'}{'task'}{'streams'}{$Z_ZENKA} = { 'retry_at' => 0 };

@sent = ();
$code{'models.handler.task-poll'}->();
@cmds = sent_commands();

ok( ( grep { $ARG == 7 } @cancelled_streams ),
    'silent zenka : its notice stream cancelled'
);
ok( ( grep { $ARG eq "$Z_ZENKA.subscribe" } @cmds ),
    'healthy zenka still subscribes' );
ok( ( grep { $ARG eq "$Z_ZENKA.next" } @cmds ), 'healthy zenka still polls' );
ok( ( grep {m{^$PRI_ZENKA\.next$}} @cmds ),
    'down zenka : immediate re-poll attempt [ old behavior ]' );
ok( ( not grep {m{^$PRI_ZENKA\.subscribe$}} @cmds ),
    'silent zenka resubscribe held by backoff'
);
ok( $data{'models'}{'task'}{'streams'}->{$PRI_ZENKA}{'subscribed'} == FALSE,
    'silent zenka marked unsubscribed' );
ok( $data{'models'}{'task'}{'streams'}->{$PRI_ZENKA}{'poll_sent_at'},
    'down zenka poll slot re-armed by the immediate retry'
);

## both polls answered -> next tick polls both again, pri resubscribe still ##
## held by its backoff -- the poll never waits for the stream               ##
$data{'models'}{'task'}{'streams'}->{$PRI_ZENKA}{'poll_sent_at'} = undef;
$data{'models'}{'task'}{'streams'}->{$Z_ZENKA}{'poll_sent_at'}   = undef;
@sent                                                            = ();
$code{'models.handler.task-poll'}->();
@cmds = sent_commands();
ok( ( grep { $ARG eq "$Z_ZENKA.next" } @cmds ),
    'answered zenka polled again next tick'
);
ok( ( grep {m{^$PRI_ZENKA\.next$}} @cmds ),
    'down-but-answered zenka polled again, never blocked' );
ok( ( not grep {m{^$PRI_ZENKA\.subscribe$}} @cmds ),
    'resubscribe still on backoff [ poll is independent of the stream ]' );

## route-send refuses the healthy one : slot freed, nothing sticks ##
%route_fail                        = ( $Z_ZENKA => 1 );
$data{'models'}{'task'}{'streams'} = { $Z_ZENKA => { 'retry_at' => 0 } };
@sent                              = ();
$code{'models.handler.task-poll'}->();
@cmds = sent_commands();
ok( ( not grep {m{^$Z_ZENKA\.next$}} @cmds ),
    'refused route : no next in flight left behind'
);
ok( ( $data{'models'}{'task'}{'streams'}->{$Z_ZENKA}{'poll_sent_at'} // '' )
        eq '',
    'refused route : poll slot reset'
);
%route_fail = ();

## ---------------------------------------------------------------------- 5 ##
## : poll-next reply routes the peek to its own zenka                       ##

say "\n :. poll-next keeps its zenka";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "$Z_ZENKA $PRI_ZENKA";
$data{'models'}{'task'}{'streams'}{$PRI_ZENKA} = { 'poll_sent_at' => time };

@sent = ();
$code{'models.handler.task-poll-step'}->(
    true_reply(
        "$PRI_ID [models] assess",
        { 'step' => 'poll-next', 'zenka' => $PRI_ZENKA }
    )
);
@cmds = sent_commands();
ok( ( grep { $ARG eq "$PRI_ZENKA.show" } @cmds ),
    'poll-next peeks on the polled zenka'
);
ok(
    (   $data{'models'}{'task'}{'streams'}->{$PRI_ZENKA}{'poll_sent_at'} // ''
    ) eq '',
    'poll-next frees exactly its own slot'
);

## ---------------------------------------------------------------------- 6 ##
## : notice stream frames dispatch with the stream's zenka as source        ##

say "\n :. notice stream per zenka";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "$Z_ZENKA $PRI_ZENKA";

$code{'models.handler.task-stream'}->(
    {   'cmd'       => qw| STRM |,
        'args'      => qw| open |,
        'cmd_id'    => 42,
        'call_args' => {},
        'params'    => { 'zenka' => $Z_ZENKA }
    }
);
ok( $data{'models'}{'task'}{'streams'}->{$Z_ZENKA}{'subscribed'} == TRUE,
    'STRM open registers the consumer for its zenka' );

@sent = ();
$registered_watchers{42}{'watcher'}->( { 'buf' => "$Z_ID\nnot-an-id\n" } );
@cmds = sent_commands();
ok( ( grep { $ARG eq "$Z_ZENKA.show" } @cmds ),
    'frame dispatched with the stream zenka as source'
);
ok( ( not grep { $ARG eq "$PRI_ZENKA.show" } @cmds ), 'no cross-zenka peek' );
ok( $data{'models'}{'task'}{'source'}->{$Z_ID}{'zenka'} eq $Z_ZENKA,
    'stream-announced source remembered' );

## eof on the stream : only that zenka backs off ##
$registered_watchers{42}{'on_eof'}->();
ok( $data{'models'}{'task'}{'streams'}->{$Z_ZENKA}{'subscribed'} == FALSE,
    'stream close drops its own subscription' );

## ---------------------------------------------------------------------- 7 ##
## : set-zenki at run time                                                  ##

say "\n :. models.set-zenki";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "$Z_ZENKA $PRI_ZENKA";
$data{'models'}{'task'}{'streams'}{'external.gone.task'}
    = { 'subscribed' => TRUE, 'cmd_id' => 9 };
$data{'models'}{'task'}{'source'}->{$PRI_ID}
    = { 'zenka' => $PRI_ZENKA, 'at' => time };
@timers = ();

my $call = { 'args' => "task $PRI_ZENKA" };
$main::call = $call;
my $result = $code{'models.cmd.set-zenki'}->();

ok( $result->{'mode'} eq qw| true |, 'set-zenki accepted' );
ok( $data{'models'}{'cfg'}{'task_zenka'} eq "task $PRI_ZENKA",
    'config replaced with the new list' );
ok( ( grep { $ARG == 9 } @cancelled_streams ),
    'removed zenka loses its stream at once'
);
ok( ( not exists $data{'models'}{'task'}{'streams'}->{'external.gone.task'} ),
    'removed zenka state dropped'
);
ok( scalar keys %{ $data{'models'}{'task'}{'source'} } == 0,
    'remembered sources cleared' );
ok( scalar @timers == 1, 'poll timer re-armed' );

$main::call = { 'args' => 'task;rm -rf' };
my $bad = $code{'models.cmd.set-zenki'}->();
ok( $bad->{'mode'} eq qw| false |, 'garbage list refused' );

## ---------------------------------------------------------------------- 8 ##
## : the live HWO case -- dotless local zenka first, a pinned :no_tools:    ##
## task announced by the local task zenka, pin served here -> claimed [     ##
## tasks like this stayed pending for 30+ min : created before the models   ##
## restart, never notified again -- see section 9 ]                         ##

say "\n :. local pinned :no_tools: task [ live case ]";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'}     = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_agent'}     = 'models';
$data{'models'}{'task'}{'default_model'} = 'local';
$code{'models.task.parse-show'}          = $real_parse_show;

## the local task zenka announces a pinned local assessment ##
$main::call = { 'args' => $LOCAL_ID };
$code{'models.cmd.task-notify'}->();
@cmds = sent_commands();
ok( $cmds[0] eq 'task.claim',
    'dotless local entry first : notify claims task.claim directly' );

## claim answered TRUE : start + show on the local zenka ##
my $live_claim_send = $sent[0];
@sent = ();
$code{'models.handler.task-poll-step'}->(
    true_reply( "claimed $LOCAL_ID", $live_claim_send->{'reply'}{'params'} )
);
@cmds = sent_commands();
ok( ( grep { $ARG eq 'task.start' } @cmds ),
    'claimed : task started on the local zenka'
);
ok( ( grep { $ARG eq 'task.show' } @cmds ),
    'claimed : details fetched from the local zenka'
);

## show answered [ real task.show header ] : enqueue, pin + marker kept ##
my $live_show_send = ( grep { $ARG->{'command'} eq 'task.show' } @sent )[0];
@sent = ();
my $show_text
    = "id          : $LOCAL_ID\nstatus      : claimed\ndescription : "
    . ":no_tools:\\n:local: :simple: :model:OFSQC4I:QDBKEXY: assess "
    . "this listing\ncontext     :\nagent       : models";
$code{'models.handler.task-poll-step'}->(
    {   'cmd'       => qw| TRUE |,
        'call_args' => { 'args' => $show_text },
        'data'      => '',
        'params'    => $live_show_send->{'reply'}{'params'}
    }
);
ok( scalar @enqueued == 1, 'show : exactly one task enqueued' );
ok( ( $enqueued[0]{'model'} // '' ) eq 'local',
    'show : model resolved to local [ :local: backend ]'
);
ok( ( $enqueued[0]{'target_cmd'} // '' ) eq 'coding.ask-reply',
    'show : served by the local coding backend' );
ok( $enqueued[0]{'prompt'} =~ m|:model:OFSQC4I:QDBKEXY:|,
    'show : the model pin stays in the prompt'
);
ok( $enqueued[0]{'prompt'} =~ m|\A:no_tools:|,
    'show : :no_tools: first line kept for the backend'
);

$code{'models.task.parse-show'} = $parse_show_stub;    ## restore ##

## ---------------------------------------------------------------------- 9 ##
## : startup recovery scan -- tasks pending before the restart are never    ##
## re-notified, the local entry has no stream + poll : startup scans the    ##
## local queue once, check-next claims the first pending, each completion   ##
## re-scans the rest                                                        ##

say "\n :. startup recovery scan [ local queue ]";

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = "task $PRI_ZENKA";
@timers                              = ();
@sent                                = ();

my $armed = $code{'models.task.startup'}->();

ok( $armed == TRUE, 'mixed list : timer armed' );
my $scan_send = ( grep { $ARG->{'command'} eq 'task.queue' } @sent )[0];
ok( ( defined $scan_send ), 'startup scans the local pending queue' );
ok( ( $scan_send->{'call_args'}{'args'} // '' ) eq 'status=pending',
    'scan asks for pending tasks only' );
ok( ( $scan_send->{'reply'}{'params'}{'step'} // '' ) eq 'check-next',
    'scan reply feeds the check-next step' );
ok( ( $scan_send->{'reply'}{'params'}{'zenka'} // '' ) eq 'task',
    'scan is keyed to the local zenka' );
ok( ( not grep {m{^$PRI_ZENKA\.queue$}} sent_commands() ),
    'remote zenka gets no scan [ stream + poll cover it ]'
);

## queue answered : two pending local tasks -> first claimed locally ##
@sent = ();
$code{'models.handler.task-poll-step'}->(
    {   'cmd'    => qw| SIZE |,
        'data'   => "OFNVQAQ pending assess one\nBYQSQFQ pending assess two",
        'params' => $scan_send->{'reply'}{'params'}
    }
);
@cmds = sent_commands();
ok( ( grep { $ARG eq 'task.claim' } @cmds ),
    'check-next claims the first pending local task'
);
ok( ( not grep {m{^$PRI_ZENKA\.}} @cmds ),
    'no remote command in the local recovery path'
);

## empty queue : nothing dispatched, no error ##
@sent = ();
$code{'models.handler.task-poll-step'}->(
    {   'cmd'    => qw| SIZE |,
        'data'   => '',
        'params' => $scan_send->{'reply'}{'params'}
    }
);
ok( scalar sent_commands() == 0, 'empty local queue : nothing dispatched' );

## local-only config scans too [ startup returns FALSE, scan still sent ] ##
reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'} = 'task';
@timers                              = ();
@sent                                = ();
$armed                               = $code{'models.task.startup'}->();
ok( $armed == FALSE, 'local only : nothing armed' );
ok( ( grep { $ARG->{'command'} eq 'task.queue' } @sent ),
    'local only : the pending scan still runs'
);

## ---------------------------------------------------------------------- ##
## 10 : claim capacity -- at most one in-flight claim per ready local     ##
## backend serving the pin [ default limit ], 0 = unlimited               ##

say "\n :. claim capacity gate";

my $SECOND_ID  = 'SECON7D';
my $GPU_KEY    = 'OFSQC4I:QDBKEXY';
my $PIN_SERVED = 'AAA:QDBKEXY';

## warm backend knowledge : ONE ready backend serving the pin ##
sub warm_one_backend {
    $data{'models'}{'task'}{'local_models'}
        = { 'at' => time, 'ids' => [$GPU_KEY] };
    return;
}

## --- two announced, one backend -> one claimed, one left pending --- ##

reset_models_state();
delete $data{'models'}{'cfg'}{'task_max_claims'};    ## default limit ##
$data{'models'}{'cfg'}{'task_zenka'} = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_agent'} = 'models';
warm_one_backend();

$main::call = { 'args' => $LOCAL_ID };
$code{'models.cmd.task-notify'}->();
ok( ( grep { $ARG eq 'task.claim' } sent_commands() ),
    'one backend : first announced task claimed'
);

## the claim succeeded -> counted in flight ##
my $cap_claim_send
    = ( grep { $ARG->{'command'} eq 'task.claim' } @sent )[0];
$code{'models.handler.task-poll-step'}->(
    true_reply( "claimed $LOCAL_ID", $cap_claim_send->{'reply'}{'params'} ) );
ok( scalar keys %{ $data{'models'}{'task'}{'claimed'} } == 1,
    'a TRUE claim reply counts the task in flight'
);

## second announcement : at capacity -> left pending, nothing sent ##
@sent       = ();
$main::call = { 'args' => $SECOND_ID };
$code{'models.cmd.task-notify'}->();
ok( scalar sent_commands() == 0,
    'one backend : second task left pending at capacity' );

## --- remote path : same limit, a foreign task is not over-claimed --- ##

$data{'models'}{'cfg'}{'task_models'} = "OTHERZEN:QDBKEXY";
$code{'models.task.dispatch-id'}->( $PRI_ID, $PRI_ZENKA );
my $cap_peek_send = $sent[-1];
$parse_show_plan{$PRI_ID} = {
    'status'     => 'pending',
    'model'      => 'local',
    'prompt'     => ":no_tools:\nassess this",
    'target_cmd' => 'coding.ask-reply',
    'model_pin'  => $PIN_SERVED
};
@sent = ();
$code{'models.handler.task-poll-step'}->(
    true_reply( 'pending task text', $cap_peek_send->{'reply'}{'params'} ) );
ok( ( not grep { $ARG eq "$PRI_ZENKA.claim" } sent_commands() ),
    'remote path : pin served but at capacity -> left pending'
);

## --- completion -> the pending one claimed [ release + re-scan ] --- ##

@sent = ();
$code{'models.task.release-claim'}->($LOCAL_ID);
ok( scalar keys %{ $data{'models'}{'task'}{'claimed'} } == 0,
    'completion released the in-flight slot' );
my $rescan_send = ( grep { $ARG->{'command'} eq 'task.queue' } @sent )[0];
ok( ( defined $rescan_send ), 'release re-scans the local pending queue' );

@sent = ();
$code{'models.handler.task-poll-step'}->(
    {   'cmd'    => qw| SIZE |,
        'data'   => "$SECOND_ID pending assess two",
        'params' => $rescan_send->{'reply'}{'params'}
    }
);
ok( ( grep { $ARG eq 'task.claim' } sent_commands() ),
    'freed slot claims the pending task on re-scan'
);

## re-try the foreign task now -> claimed ##
@sent = ();
$code{'models.task.peek-claim'}->(
    {   'task_id'    => $PRI_ID,
        'model'      => 'local',
        'prompt'     => ":no_tools:\nassess this",
        'target_cmd' => 'coding.ask-reply',
        'model_pin'  => $PIN_SERVED
    }
);
ok( ( grep { $ARG eq "$PRI_ZENKA.claim" } sent_commands() ),
    'after the release the foreign task claims too'
);

## --- limit 0 -> unlimited, both claimed --- ##

reset_models_state();
$data{'models'}{'cfg'}{'task_zenka'}      = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_agent'}      = 'models';
$data{'models'}{'cfg'}{'task_max_claims'} = 0;
warm_one_backend();

$main::call = { 'args' => $LOCAL_ID };
$code{'models.cmd.task-notify'}->();
$main::call = { 'args' => $SECOND_ID };
$code{'models.cmd.task-notify'}->();
ok( scalar( grep { $ARG eq 'task.claim' } sent_commands() ) == 2,
    'limit 0 [unlimited] : both tasks claimed' );

## --- cold backend knowledge : the gate asks coding first --- ##

reset_models_state();
delete $data{'models'}{'cfg'}{'task_max_claims'};    ## default limit ##
$data{'models'}{'cfg'}{'task_zenka'} = "task $PRI_ZENKA";
$data{'models'}{'cfg'}{'task_agent'} = 'models';
## no local_models cache ##

$main::call = { 'args' => $LOCAL_ID };
$code{'models.cmd.task-notify'}->();
my $cold_ask
    = ( grep { $ARG->{'command'} eq 'coding.inference-status' } @sent )[0];
ok( ( defined $cold_ask ),
    'cold cache : the gate asks coding.inference-status first' );
ok( ( $cold_ask->{'reply'}{'params'}{'step'} // '' ) eq 'capacity-models',
    'the answer re-runs the dispatch [ capacity-models step ]'
);

## an unusable answer caches 'none' -> task left pending, no crash ##
@sent = ();
$code{'models.handler.task-poll-step'}->(
    {   'cmd'    => qw| FALSE |,
        'data'   => '',
        'params' => $cold_ask->{'reply'}{'params'}
    }
);
ok( scalar sent_commands() == 0,
    'no ready backend known : task left pending, nothing claimed' );
ok( scalar keys %{ $data{'models'}{'task'}{'claimed'} } == 0,
    'nothing counted on the refused path' );

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,.,.,.,.,.,,..,,..,,.,,..,,,..,..,,.,,,.,.,.,.,...,..,,.,.,.,.,...,..,,...,
#D4KRJL27FNISRTUOMZWNGMK7OCOJ667BABN2EUBR6VNBD6OOQTYIGKMLAZLSYNJTEWQCTKLPHGHMI
#\\\|7XIZTL4WEM5YON7VNLY7DL6PKINQHIBXZNR76DU6I3SINZ73WPM \ / AMOS7 \ YOURUM ::
#\[7]DXID4IGGY3T7EAU7J7YJ3UPJFGEIHCTHKLTAIMVEEXR27RN2MKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
