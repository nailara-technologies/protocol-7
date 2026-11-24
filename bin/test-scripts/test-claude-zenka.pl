#!/usr/bin/env perl
use v5.32;
use strict;
use English;

## claude zenka stage 1 : the real src/claude.* modules drive a FAKE child  ##
## [ fixtures/fake-claude-stream-json.pl, the stream-json wire format ] :   ##
## start, send, events out, a result and its signal, a queued turn, restart ##
## resume, child crash, interrupt, stop, the end_code kill and the          ##
## claude-send action plugin. no zenka, no cube, no real claude : the io    ##
## watchers are pumped by IO::Select, timers and the sender are stubs.      ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use IO::Select;
use POSIX ();

BEGIN {
    my $root = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root;
    unshift @INC, "$root/data/lib-path/pm";
}

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}
## module loading : the same <..> translation the zenka loader does ##

sub translate_code {
    my $code = shift;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>(?=\s*->)|"\$code{$1}"|eg;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>|"\$code{$1}->()"|eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub compile_source {
    my $src = shift;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    my $sub        = eval "sub { $translated }";
    die "compile error : $EVAL_ERROR" if $EVAL_ERROR;
    return $sub;
}

sub read_file {
    my $path = shift;
    open my $fh, '<:encoding(UTF-8)', $path
        or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    return $src;
}

sub load_module {
    my $name = shift;
    $code{$name}
        = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ) );
}

## stubs : log, sender, timers, io watchers, idle timeout ##

my @sent;      ## "command | args" ##
my @timers;    ## add_timer calls ##
my ( $paused, $resumed ) = ( 0, 0 );
my $var_dir = tempdir( CLEANUP => 1 );

$code{'base.log'}                           = sub {TRUE};
$code{'base.logs'}                          = sub {TRUE};
$code{'base.ntime'}                         = sub {time};
$code{'base.s_warn'}                        = sub {TRUE};
$code{'file.zenka_dir.data_path'}           = sub {$var_dir};
$code{'base.zenki.pause_ondemand_timeout'}  = sub { $paused++ };
$code{'base.zenki.resume_ondemand_timeout'} = sub { $resumed++ };
$code{'protocol-7.command.send.local'}      = sub {
    my $c = shift;
    push @sent, join ' | ', $c->{'command'}, $c->{'call_args'}{'args'} // '-';
    return TRUE;
};
$code{'event.add_timer'} = sub { push @timers, shift; return TRUE };

{

    package FakeIO;
    my @all;

    sub new {
        my $s = bless { %{ $_[1] }, 'active' => 1 }, $_[0];
        push @all, $s;
        $s;
    }
    sub w         { $_[0] }
    sub data      { $_[0]{'data'} }
    sub fd        { $_[0]{'fd'} }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }

    sub active {
        @all = grep { $_->{'active'} } @all;
        @all;
    }
}
$code{'event.add_io'} = sub { FakeIO->new(shift) };
$code{'event.del_io'} = sub { my $w = shift; $w->cancel if ref $w; TRUE };

{

    package FakeTimerEvent;
    sub new  { bless { 'data' => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]{'data'} }
}

## one select round over the active watchers, until $until is true ##
sub pump {
    my ( $until, $max ) = @ARG;
    my $end = time + ( $max // 13 );
    while ( time <= $end ) {
        return TRUE if $until->();
        my @w = FakeIO::active();
        last if not @w;
        my ( $r, $wr ) = ( IO::Select->new, IO::Select->new );
        foreach my $x (@w) {
            ( $x->{'poll'} =~ m{w} ? $wr : $r )->add( $x->{'fd'} );
        }
        my ( $rr, $ww ) = IO::Select->select( $r, $wr, undef, 0.1 );
        foreach my $x (@w) {
            next if not $x->is_active;
            my $hit = grep { $_ == $x->{'fd'} }
                ( $x->{'poll'} =~ m{w} ? @{ $ww // [] } : @{ $rr // [] } );
            $code{ $x->{'handler'} }->($x) if $hit;
        }
    }
    return $until->();
}

## the real modules ##
opendir my $dh, "$root_path/src" or die;
my @mods
    = grep {m{\A(?:claude\.|stream_child\.|base\.interval\.)}} readdir $dh;
closedir $dh;
load_module($ARG) foreach @mods, qw| plugin.events.action.claude-send |;

my $fake = "$root_path/bin/test-scripts/fixtures/fake-claude-stream-json.pl";
$data{'claude'}{'cfg'} = {
    'binary' => $EXECUTABLE_NAME,
    'args'   => "$fake -p --input-format stream-json "
        . '--output-format stream-json --verbose',
    'var_dir'   => $var_dir,
    'work_dir'  => $var_dir,
    'interrupt' => 'control',
};
$data{'base'}{'interval'}{'cfg'}{'type'}{'claude-stop'}
    = { 'start' => 3, 'factor' => 1.6, 'cap' => 13, 'cap_jitter' => 2 };
$data{'base'}{'interval'}{'cfg'}{'type'}{'claude-reap'}
    = { 'start' => 1, 'factor' => 1.6, 'cap' => 8, 'cap_jitter' => 1 };
$data{'callbacks'}{'end_code'} = [];

my $cmd = sub {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args };
    return $code{"claude.cmd.$name"}->();
};
my $events  = sub { join "\n", @{ $data{'claude'}{'events'} // [] } };
my $signals = sub {
    grep {m{\Acube\.events\.signal }} @sent;
};

## init : loading the session creates nothing [ before the drop ] ##
{
    local $data{'claude'}{'cfg'}{'var_dir'} = "$var_dir/not-yet";
    ok( !defined $code{'claude.session.load'}->() && !-e "$var_dir/not-yet",
        'session.load : a missing var dir stays missing' );
}

## init ##
$code{'claude.init_code'}->();
ok( $data{'claude'}{'state'} eq 'idle' && !defined $data{'claude'}{'session'},
    'init : idle, no session recorded yet'
);
ok( grep( { $_ eq 'claude.child.end_code' }
        @{ $data{'callbacks'}{'end_code'} } ),
    'init : the child end is an end_code callback'
);

## start, send, events, result ##
my $r = $cmd->( 'start', 'model=fake-model' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{new session},
    'start : a new session [ nothing to resume ]'
);
my $pid1 = $data{'claude'}{'child'}{'pid'};
ok( $pid1 && kill( 0, $pid1 ), 'start : the fake child runs' );
ok( pump( sub { defined $data{'claude'}{'session'} } ),
    'start : the init event records the session id'
);
my $session = $data{'claude'}{'session'} // '';
ok( -f "$var_dir/session.cfg" && do {
        open my $fh, '<', "$var_dir/session.cfg";
        local $/;
        <$fh> =~ m{^session = \Q$session\E$}m;
    },
    'start : session.cfg in p7 config style'
);
ok( $events->() =~ m{init : session \Q$session\E model fake-model},
    'events : init line with the model' );

$r = $cmd->( 'send', 'hello there' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} eq 'turn 1 sent',
    'send : turn 1 sent' );
ok( $paused == 1, 'send : a running turn pauses the idle timeout' );
$r = $cmd->( 'send', 'second turn' );
ok( $r->{'data'} =~ m{queued \[ 1 waiting \]},
    'send : queued while a turn runs'
);
ok( pump(
        sub {
            $data{'claude'}{'turn'} == 2 && !$data{'claude'}{'turn_active'};
        }
    ),
    'result : the queued turn ran after the first'
);
my $ev = $events->();
ok( $ev =~ m{text : echo : hello there},    'events : assistant text' );
ok( $ev =~ m{tool : Read file_path=/tmp/x}, 'events : tool call' );
ok( $ev =~ m{result : file body},           'events : tool result' );
ok( $ev =~ m{final : success \[ 0\.01 usd \] : done : hello there},
    'events : final with cost' );
ok( $ev =~ m{stderr : fake claude : args}, 'events : stderr lines kept' );
my @sig = $signals->();
ok( @sig == 2
        && $sig[0]
        =~ m{\Acube\.events\.signal \| claude\.run\.done cost=0\.0125 session=\Q$session\E state=ok turn=1\z},
    'signal : claude.run.done state=ok with session, cost, turn'
) or say "#   got : @sig";
ok( $resumed >= 2, 'result : the idle timeout resumes' );
ok( abs( $data{'claude'}{'cost'} - 0.025 ) < 1e-9, 'result : cost recorded' );

open my $lfh, '<:encoding(UTF-8)', "$var_dir/events.log";
my @log = <$lfh>;
close $lfh;
ok( @log >= 10 && $log[-1] =~ m{\A\d+ signal : claude\.run\.done},
    'log : every line in events.log' );

## status, tail ##
$r = $cmd->('status');
ok( $r->{'data'}        =~ m{state   : running}
        && $r->{'data'} =~ m{session : \Q$session\E}
        && $r->{'data'} =~ m{turn    : 2 \[ last ok success \]}
        && $r->{'data'} =~ m{cost    : 0\.0250 usd}
        && $r->{'data'} =~ m{last events :},
    'status : state, session, turn, cost, last events'
);
$r = $cmd->( 'tail', '3' );
ok( ( () = $r->{'data'} =~ m{\n}g ) == 3,       'tail : n lines' );
ok( $cmd->( 'tail', 'x' )->{'mode'} eq 'false', 'tail : n must be a number' );

## interrupt ##
ok( $cmd->('interrupt')->{'mode'} eq 'false',
    'interrupt : refused without a turn'
);
$cmd->( 'send', 'slow' );
ok( pump( sub { $events->() =~ m{echo : slow} } ),
    'interrupt : slow turn running' );
$r = $cmd->('interrupt');
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{interrupt-1},
    'interrupt : a control_request sent' );
ok( pump( sub { !$data{'claude'}{'turn_active'} } ),
    'interrupt : the turn ended' );
@sig = $signals->();
ok( $sig[-1] =~ m{state=failed} && $events->() =~ m{control : success},
    'interrupt : control response, signal state=failed' );
ok( $data{'claude'}{'child'}{'pid'} == $pid1 && kill( 0, $pid1 ),
    'interrupt : the session process stays' );

## a grandchild in the group ##
$cmd->( 'send', 'spawn' );
pump( sub { $events->() =~ m{done : spawned (\d+)} } );
my ($grand1) = $events->() =~ m{done : spawned (\d+)};
ok( $grand1 && kill( 0, $grand1 ), 'group : a grandchild runs' );

## stop, restart resume ##
$r = $cmd->('stop');
ok( $r->{'mode'} eq 'true', 'stop : asked' );
ok( pump( sub { $data{'claude'}{'state'} eq 'stopped' } ),
    'stop : stopped on eof' );
ok( grep(
        { ( $_->{'handler'} // '' ) eq 'claude.handler.stop_kill'
                and $_->{'after'} >= 3 } @timers ),
    'stop : a KILL timer from base.interval.next'
);
waitpid( $pid1, 0 ) if kill 0, $pid1;
ok( !kill( 0, $pid1 ), 'stop : the child is gone' );

for my $t ( grep { ( $_->{'handler'} // '' ) eq 'claude.handler.stop_kill' }
    @timers ) {
    $code{'claude.handler.stop_kill'}
        ->( FakeTimerEvent->new( $t->{'data'} ) );
}
select( undef, undef, undef, 0.3 );
ok( !kill( 0, $grand1 ), 'stop : the grandchild ended with the group' );
ok( grep( {m{\Acube\.v7-zenki\.gone_child \| $pid1\z}} @sent ),
    'stop : v7-zenki told the child is gone' );
ok( $cmd->('stop')->{'mode'} eq 'false', 'stop : refused when not running' );

## a fresh zenka : the recorded session resumes ##
delete $data{'claude'}{$_} for qw| session state events child |;
$code{'claude.init_code'}->();
ok( $data{'claude'}{'session'} eq $session,
    'restart : session loaded from session.cfg'
);
$r = $cmd->( 'send', 'after restart' );
ok( $r->{'data'} =~ m{claude started}, 'restart : send starts the child' );
ok( $data{'claude'}{'child'}{'resume'} eq $session,
    'restart : --resume <session>' );
ok( pump(
        sub {
            !$data{'claude'}{'turn_active'}
                && $events->() =~ m{done : after restart};
        }
    ),
    'restart : the turn ran in the resumed session'
);
ok( $events->() =~ m{init : session \Q$session\E},
    'restart : same session id' );

## child crash ##
my $pid2 = $data{'claude'}{'child'}{'pid'};
my $nsig = () = $signals->();
$cmd->( 'send', 'crash' );
ok( pump( sub { $data{'claude'}{'state'} eq 'crashed' } ),
    'crash : state crashed' );
@sig = $signals->();
ok( @sig == $nsig + 1
        && $sig[-1] =~ m{reason=crashed}
        && $sig[-1] =~ m{state=failed},
    'crash : the running turn ends failed [ reason=crashed ]'
);
ok( !$data{'claude'}{'turn_active'}, 'crash : no turn left running' );
pump( sub { defined $data{'claude'}{'child'}{'exit'} }, 3 );

for my $t ( grep { ( $_->{'handler'} // '' ) eq 'claude.handler.reap' }
    @timers ) {
    $code{'claude.handler.reap'}->( FakeTimerEvent->new( $t->{'data'} ) );
}
ok( ( $data{'claude'}{'child'}{'exit'} // '' ) eq '3',
    'crash : exit status 3 collected' );

## end_code : no orphan ##
$cmd->( 'start', 'resume=new' );
my $pid3 = $data{'claude'}{'child'}{'pid'};
ok( $data{'claude'}{'child'}{'resume'} eq '',
    'start : resume=new starts fresh'
);
pump( sub { $events->() =~ m{start .*pid $pid3} } );
$cmd->( 'send', 'spawn' );
pump( sub { !$data{'claude'}{'turn_active'} } );
my ($grand3) = $events->() =~ m{.*done : spawned (\d+)}s;
ok( $grand3 && $grand3 != $grand1 && kill( 0, $grand3 ),
    'end_code : a grandchild runs' );
$code{'claude.child.end_code'}->();
ok( !kill( 0, $pid3 ), 'end_code : the child ended with the zenka' );
select( undef, undef, undef, 0.3 );
ok( !kill( 0, $grand3 ), 'end_code : the grandchild too [ no orphan ]' );

## argument checks ##
ok( $cmd->( 'start', 'bogus=1' )->{'mode'} eq 'false',
    'start : unknown key refused' );
ok( $cmd->( 'send', '  ' )->{'mode'} eq 'false',
    'send : empty text refused' );
ok( $cmd->( 'permission', '7 allow' )->{'data'} =~ m{later stage},
    'permission : a stub' );

## the claude-send action plugin ##
@sent = ();
my $plugin = $code{'plugin.events.action.claude-send'}->();
ok( $plugin->{'name'} eq 'claude-send' && $plugin->{'kind'} eq 'action',
    'plugin : registers as action claude-send' );
$plugin->{'run'}->(
    {   'ev_type' => 'signal',
        'action'  => { 'type' => 'claude-send', 'message' => "go\n on" }
    }
);
ok( "@sent" eq 'cube.claude.send | go on',
    'plugin : sends claude.send <message>'
);
ok( !eval {
        $plugin->{'run'}->( { 'ev_type' => 'at', 'action' => {} } );
        1;
    },
    'plugin : a missing message is refused'
);
load_module('events.bucket.action_route');
ok( $code{'events.bucket.action_route'}->( { 'type' => 'claude-send' } ) eq
        'claude.send',
    'bucket : the claude-send route is checkable'
);

## task.park action=claude-send ##
load_module('park.request');
my $pr = $code{'park.request'}->(
    {   'prefix'  => 'task',
        'task_id' => 'ABCDEFG',
        'count'   => 1,
        'pairs'   => {
            'on'      => 'kimi.run.done',
            'action'  => 'claude-send',
            'message' => 'kimi is done'
        }
    }
);
ok( ( $pr->{'args'} // '' ) eq 'task-ABCDEFG-1 action=claude-send '
        . 'message="kimi is done" '
        . 'on="kimi.run.done"' && $pr->{'record'}{'action'} eq 'claude-send',
    'park : action=claude-send parks a claude turn'
) or say "#   got : $pr->{'args'}";
$pr = $code{'park.request'}->(
    {   'task_id' => 'ABCDEFG',
        'pairs'   => { 'on' => 'x', 'action' => 'nope' }
    }
);
ok( ( $pr->{'error'} // '' ) =~ m{task-continue or claude-send},
    'park : an unknown action is refused' );

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,..,,.,.,...,,.,,..,,.,,,..,,...,,.,,.,,,..,,...,...,.,,,.,,,,..,.,.,,,,,
#2W6NXZT6RW3FT2ASBRW275BIZT6VGL374LKJUNPESQ7H67F2BYM5OFA7TFAOHOV3D7AAQBEPITMME
#\\\|N3YC64KMG5Q2PVTOX5D6PEUC3JUEN5SLZZKWIVUU2RAVJXH7O6G \ / AMOS7 \ YOURUM ::
#\[7]2HNAJHHSWDEZX5VXW74AGEJQY7UB5DBLWFMPBZSEHUM7U7SL2YCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
