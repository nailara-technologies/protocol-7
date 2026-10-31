#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                            ###
## compaction suspend : backend lock handover harness           ##
###                                                            ###

##       replays the task-LUFFZYI deadlock [ 2026-10-31 ] against the       ##
##       real translated sources of coding.async.backend_acquire /          ##
##       backend_release / backend_dispatch_next / lock_token,              ##
##       coding.task.enqueue_round, coding.async.send_request,              ##
##       coding.async.compact_context and                                   ##
##       coding.callback.http_complete -- no live coding zenka              ##
##       required :                                                         ##
##                                                                          ##
##       - a task re-enters its own gpu lock for round 3                    ##
##       [ token rotates ] while the previous request's connection is       ##
##       still closing, send_request suspends for an inference              ##
##       compaction child on the SAME backend, the child queues             ##
##       behind the parent's lock, and the earlier request's late           ##
##       http_complete arrives with the pre-rotation token. the             ##
##       parent must have handed the lock over at suspend time : the        ##
##       child gets the backend, the late completion's stale-token          ##
##       release is skipped WITHOUT freeing the child's lock, and the       ##
##       parent re-acquires fresh when it resumes after the child           ##
##       - regression guard [ the reverted 2026-09-24 fix class ] : a       ##
##       plain multi-round task without compaction keeps its own lock       ##
##       across rounds through the re-entry shortcut                        ##

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
use JSON::PP                  ();

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;

my @log_calls;       ## every base.logs invocation [ level, rendered ]      ##
my @sent_requests;   ## coding.async.request invocations [ task_id ]        ##
my @enqueued;        ## coding.task.enqueue invocations [ task hashref ]    ##

%code = (
    'base.logs' => sub {
        my ( $level, $fmt, @args ) = @ARG;
        push @log_calls, [ $level, sprintf( $fmt, @args ) ];
        return TRUE;
    },
    'base.log'      => sub { return TRUE },
    'base.time'     => sub { return 13000 },
    'base.ntime'    => sub { return 3211306825624 },
    'base.cfg_bool' => sub { return FALSE },           ## thermal gate off ##
    'coding.async.state_machine' => sub {
        my ( $op, $task_id ) = @ARG;
        return $data{'coding'}{'async'}{'task_state'}{$task_id}
            if $op eq qw| get |;
        return;
    },
    'coding.async.state_manager' => sub {
        my ( $op, $task_id, $fields ) = @ARG;
        if ( $op eq qw| get | ) {
            return $data{'coding'}{'async'}{'task_state'}{$task_id};
        } elsif ( $op eq qw| set | ) {
            my $st = $data{'coding'}{'async'}{'task_state'}{$task_id} //= {};
            $st->{$ARG} = $fields->{$ARG} for keys %{$fields};
            return $st;
        }
        return;
    },
    'coding.helper.task_id_generator' => sub { return qw| task-CHILD01 | },
    'coding.task.enqueue'             => sub {
        my $task = shift;
        push @enqueued, $task;
        return { success => TRUE, task_id => $task->{'id'} };
    },
    'coding.image.select_refs' => sub {
        return { tokens => 0, selected => [], per_image => {} };
    },
    'coding.helper.dry_last_n'       => sub { return 0 },
    'coding.sanitize.jinja_messages' => sub { return TRUE },
    'coding.async.request'           => sub {
        my ($task_id) = @ARG;
        push @sent_requests, $task_id;
        return { success => TRUE, task_id => $task_id, mode => qw| stream | };
    },
);

my $fail_count = 0;

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

compile_module('coding.async.lock_token');
compile_module('coding.async.backend_acquire');
compile_module('coding.async.backend_release');
compile_module('coding.async.backend_dispatch_next');
compile_module('coding.task.enqueue_round');
compile_module('coding.async.send_request');
compile_module('coding.async.compact_context');
compile_module('coding.callback.http_complete');

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub reset_state {
    @log_calls                              = ();
    @sent_requests                          = ();
    @enqueued                               = ();
    %data                                   = ();
    $data{'coding'}{'task'}{'queue_paused'} = FALSE;
    $data{'coding'}{'inference_servers'}{'gpu'}
        = { 'status' => qw| ready |, 'n_ctx' => 8192 };
    $data{'inference'}{'model'}{'max_tokens'}     = 4096;
    $data{'inference'}{'model'}{'context_length'} = 8192;
    return;
}

sub mk_task_rec {
    my ( $id, %extra ) = @ARG;
    my $rec = {
        'description' => 'test task',
        'no_tools'    => 1,
        'analysis'    => { 'routed_to'  => qw| gpu | },
        'execution'   => { 'model_used' => qw| default | },
        %extra,
    };
    $data{'coding'}{'task'}{'queue'}{$id} = $rec;
    return $rec;
}

say ': 1. [ task-LUFFZYI replay ] round re-enters, suspends for a compaction '
    . 'child on the same backend, earlier request completes late';

reset_state();
{
    $data{'coding'}{'cfg'}{'compaction_inference'} = qw| yes |;
    $data{'coding'}{'cfg'}{'context-auto-compact-threshold'}
        = 400;    ## absolute token threshold [ > 100 ] ##

    my $parent = qw| task-PARENT1 |;
    my @msgs   = (
        { 'role' => qw| system |, 'content' => 's' x 100 },
        { 'role' => qw| user |,   'content' => 'u' x 100 },
    );
    push @msgs,
        { 'role' => 'assistant', 'content' => 'a' x 400 },
        { 'role' => 'user',      'content' => 't' x 400 }
        for 1 .. 4;    ## 10 msgs, ~3400 chars -> est ~1487 tok > 400 ##

    mk_task_rec($parent);
    $data{'coding'}{'async'}{'task_state'}{$parent} = {
        'state'       => qw| streaming |,
        'backend'     => qw| gpu |,
        'round'       => 3,
        'request_seq' => 3,        ## the request still closing on the wire ##
        'messages'    => \@msgs,
        'tools'       => [],
    };

    ## previous request holds the lock with token 193 ##
    $data{'coding'}{'state'}{'backend'}{'gpu'} = {
        'lock'          => $parent,
        'lock_token'    => 193,
        'token_counter' => 193,
        'queue'         => [],
    };

    ## round 3 enqueued from inside the previous request's callback chain ##
    ## [ finish chunk processed before the connection's close event ]     ##
    my $res = do {
        local $data{'coding'}{'async'}{'lock_ctx'} = {
            'task_id' => $parent,
            'backend' => qw| gpu |,
            'token'   => 193
        };
        $code{'coding.task.enqueue_round'}->( $parent, 3 );
    };

    my $bs = $data{'coding'}{'state'}{'backend'}{'gpu'};

    ok( scalar( grep { $ARG->[1] =~ m{\[reenter\]} } @log_calls ) == 1,
        'round 3 re-entered the parent`s own lock [ token rotated ]'
    );
    ok( scalar(@enqueued) == 1,
        'compaction child enqueued via inference compaction path' );
    my $pstate = $data{'coding'}{'async'}{'task_state'}{$parent};
    ok( ( $pstate->{'compaction_pending'} // '' ) eq qw| task-CHILD01 |,
        'parent suspended with compaction_pending set' );
    ok( ( $pstate->{'state'} // '' ) eq qw| subtask |,
        'parent in subtask-wait state' );

    ## the deadlock check : lock must NOT stay with the suspended parent ##
    ok( !defined $bs->{'lock'},
        'parent handed the gpu lock over at '
            . 'suspend time [ not held while waiting ]'
    );
    ok( scalar( grep { $ARG->[1] =~ m{released gpu lock} } @log_calls ) == 1,
        'suspend-time release logged'
    );

    say ': 2. the compaction child executes and gets the backend';

    ## coding.task.execute -> async.request init : state exists before the ##
    ## child's acquire [ mirrors coding.async.request's init-before-lock ] ##
    mk_task_rec( qw| task-CHILD01 |, 'metadata' => { 'is_compaction' => 1 } );
    $data{'coding'}{'async'}{'task_state'}{qw| task-CHILD01 |} = {
        'state'       => qw| streaming |,
        'backend'     => qw| gpu |,
        'round'       => 1,
        'request_seq' => 0,
        'messages'    => [ { 'role' => qw| user |, 'content' => 'sum' } ],
        'tools'       => [],
    };
    my $acq = $code{'coding.async.backend_acquire'}
        ->( qw| task-CHILD01 |, qw| gpu | );
    ok( $acq->{'acquired'},
              'child acquired the backend [ pre-fix : '
            . 'queued behind the suspended parent forever ]' );
    my $child_token = $bs->{'lock_token'};

    say ': 3. late completion of the parent`s earlier '
        . 'request arrives with the pre-rotation token';

    do {
        local $data{'coding'}{'async'}{'lock_ctx'} = {
            'task_id' => $parent,
            'backend' => qw| gpu |,
            'token'   => 193
        };
        $code{'coding.callback.http_complete'}->(
            $parent,
            { 'bytes_received' => 17498, 'chunks_received' => 79 },
            3    ## seq matches : no new request went out for round 3 ##
        );
    };

    ok( scalar( grep { $ARG->[1] =~ m{stale callback} } @log_calls ) == 0,
        'seq check passes [ 3 == 3 ] : the seq '
            . 'filter alone cannot catch this completion'
    );
    ok( ( $bs->{'lock'} // '' ) eq qw| task-CHILD01 |,
        'child`s lock untouched by the late '
            . 'completion [ stale-token protection intact ]'
    );
    ok( ( $bs->{'lock_token'} // 0 ) == $child_token,
        'child`s token not rotated or freed'
    );
    ok( scalar( grep { $ARG->[1] =~ m{skip release} } @log_calls ) >= 1,
        'late release attempt skipped [ not holder / stale token ]'
    );

    say ': 4. child completes, parent resumes and re-acquires fresh';

    ## child done : releases its own lock from inside its callback chain ##
    do {
        local $data{'coding'}{'async'}{'lock_ctx'} = {
            'task_id' => qw| task-CHILD01 |,
            'backend' => qw| gpu |,
            'token'   => $child_token
        };
        $code{'coding.async.backend_release'}
            ->( qw| task-CHILD01 |, qw| gpu |, $child_token );
    };
    ok( !defined $bs->{'lock'}, 'child released the lock on completion' );

    ## async.complete's compaction resume applied : markers cleared, then ##
    ## subtask_advance -> enqueue_round as a FRESH caller [ no lock ctx ] ##
    delete $pstate->{'compaction_pending'};
    delete $pstate->{'compact_start'};
    delete $pstate->{'compact_end'};
    $pstate->{'compaction_applied_round'} = 3;
    $pstate->{'state'}                    = qw| streaming |;

    @sent_requests = ();
    $res           = $code{'coding.task.enqueue_round'}->( $parent, 3 );
    ok( ( $bs->{'lock'} // '' ) eq $parent,
        'parent re-acquired the lock on resume'
    );
    ok( scalar(@sent_requests) == 1 && $sent_requests[0] eq $parent,
        'parent`s resumed round dispatched a request' );
}

say ': 5. [ regression : reverted 2026-09-24 fix class ] '
    . 'plain multi-round task keeps its own lock across rounds';

reset_state();
{
    $data{'coding'}{'cfg'}{'compaction_inference'} = qw| no |;

    my $task = qw| task-PLAIN01 |;
    mk_task_rec($task);
    $data{'coding'}{'async'}{'task_state'}{$task} = {
        'state'       => qw| streaming |,
        'backend'     => qw| gpu |,
        'round'       => 1,
        'request_seq' => 1,
        'messages'    => [
            { 'role' => qw| system |, 'content' => 's' },
            { 'role' => qw| user |,   'content' => 'u' },
        ],
        'tools' => [],
    };

    ## round 1 : fresh acquire on a free backend ##
    my $res = $code{'coding.task.enqueue_round'}->( $task, 1 );
    my $bs  = $data{'coding'}{'state'}{'backend'}{'gpu'};
    ok( ( $bs->{'lock'} // '' ) eq $task, 'round 1 acquired the lock' );
    ok( scalar(@sent_requests) == 1,      'round 1 request dispatched' );
    my $round1_token = $bs->{'lock_token'};

    ## round 2 : continuation inside the request's own callback chain, ##
    ## presenting the current token -- must re-enter, NOT queue behind ##
    ## itself                                                          ##
    ## [ the reverted task_state-existence check broke exactly this ]  ##
    my $res2 = do {
        local $data{'coding'}{'async'}{'lock_ctx'} = {
            'task_id' => $task,
            'backend' => qw| gpu |,
            'token'   => $round1_token
        };
        $code{'coding.task.enqueue_round'}->( $task, 2 );
    };
    ok( ( $bs->{'lock'} // '' ) eq $task,
        'round 2 kept the task`s own lock [ re-entry shortcut ]' );
    ok( scalar( grep { $ARG eq $task } @{ $bs->{'queue'} } ) == 0,
        'task did NOT queue behind its own lock' );
    ok( ( $bs->{'lock_token'} // 0 ) != $round1_token,
        'token rotated on re-entry' );
    ok( scalar(@sent_requests) == 2, 'round 2 request dispatched' );
    ok( scalar( grep { $ARG->[1] =~ m{\[reenter\]} } @log_calls ) == 1,
        're-entry logged' );
}

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,.,,..,,,,.,.,,,,,.,,,,,...,.,,,,,,,.,.,.,.,..,,...,...,...,,,,,.,,,...,.,.,
#2JB4SHJC5MNFG7HPAOJ435UFXIDNJLNAED6KKRS3KAZQN7LTXUQJSKHQ62KEVG4UYTTEISA3RGCZK
#\\\|4E2QCQI2UTVDPD746MLWLVY5ZNPLFAGSLHZUJFAL7XKWKXIOZJC \ / AMOS7 \ YOURUM ::
#\[7]HDUNLNK2K64KV2J6FXMFYPZVJ5MW76QNMT5LDAVOEU24C3F6D2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
