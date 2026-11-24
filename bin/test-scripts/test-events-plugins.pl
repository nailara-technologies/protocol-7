#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## events zenka stage 1 : action \ source types as plugins, named signals. ##
## compiles the real src modules ; the built-in actions are compared with  ##
## the ORIGINAL events.handler.event_triggered [ fixtures/ ] run on the    ##
## same setups -- same commands sent, same stacks, same log lines ; the    ##
## timetable source is compared with the direct calc_unix_table \          ##
## set_up_timers calls ; unknown types are refused ; signals are raised,   ##
## matched, journaled and refused without a grant. no zenka started, no    ##
## real cube : the command sender, timers and dependency check are stubs.  ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
use POSIX qw| strftime |;

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

## stubs : log, command sender, timers, dependency check ##

my @sent;      ## command sends : "command | args" ##
my @logged;    ## log lines, formatted ##
my @timers;    ## add_timer calls : "handler at" ##

sub fmt_log {
    my @a     = @ARG;
    my $level = $a[0] =~ m|\A\d+\z| && @a > 1 ? shift @a : 1;
    my $fmt   = shift @a;
    return "[$level] " . ( @a ? sprintf( $fmt, @a ) : $fmt );
}

$code{'base.log'}  = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.logs'} = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.s_warn'}
    = sub { push @logged, 'warn ' . sprintf( shift, @ARG ); TRUE };
$code{'base.time'}                     = sub {time};
$code{'dependency.ok'}                 = sub {TRUE};
$code{'file.put'}                      = sub {TRUE};
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent,
        join ' | ', $c->{'command'},
        $c->{'call_args'} ? ( $c->{'call_args'}{'args'} // '-' ) : '-';
    return TRUE;
};

{

    package FakeTimer;
    sub new       { bless { 'active' => 1, 'args' => $_[1] }, $_[0] }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }
    sub now       { $main::now_called++ }
}
our $now_called = 0;
$code{'event.add_timer'} = sub {
    my $args = shift;
    push @timers, join ' ', $args->{'handler'}, $args->{'at'} // '-';
    return FakeTimer->new($args);
};

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
}

## the original handler [ stage 0, before the plugins ] : a frozen copy of ##
## events.handler.event_triggered, kept in fixtures/ so the comparison     ##
## outlives the commit that replaced it                                    ##

my $orig_src = read_file(
    File::Spec->catfile(
        $root_path,
        qw| bin test-scripts fixtures events.handler.event_triggered.stage0 |
    )
);
my $have_orig
    = $orig_src =~ m{if \( \$action_type eq qw\| zenka-present \| \)};
ok( $have_orig, 'the frozen stage 0 handler is in fixtures/' );

load_module($ARG) for qw|
    events.plugin.registry
    events.plugin.known
    events.plugin.check_setup
    events.source.arm_all
    events.fire
    events.handler.event_triggered
    events.action.tile_apply
    events.action.overlay_apply
    events.calc_unix_table
    events.set_up_timers
    events.recalc
    events.access.grants
    events.signal.grants
    events.signal.access
    events.signal.raise
    events.signal.encode
    events.signal.decode
    events.signal.journal_write
    events.signal.journal_read
    events.cmd.signal
    events.cmd.signals
    events.cmd.plugins
    events.cmd.trigger_event
    |;

my $plugin_dir = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $plugin_dir or die "cannot open src : $OS_ERROR";
my @plugin_files
    = grep {m{\Aplugin\.events\.(?:action|source)\.[\w-]+\z}} readdir $dh;
closedir $dh;
load_module($ARG) for @plugin_files;

## fresh state ##

sub reset_state {
    %data                                     = ();
    @sent                                     = @logged = @timers = ();
    $data{'events'}{'setup'}                  = {};
    $data{'events'}{'enabled'}                = {};
    $data{'events'}{'timetable'}              = {};
    $data{'events'}{'timers'}                 = {};
    $data{'events'}{'signal'}{'journal_path'} = $main::journal;
    $data{'events'}{'signal'}{'access_file'}  = $main::access_file;
    $data{'events'}{'signal'}{'grants_file'}  = $main::grants_file;
    return;
}

my $tmp = tempdir( 'events-plugins-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
our $journal     = "$tmp/var/signal.journal";
our $access_file = "$tmp/access.zenki";
our $grants_file = "$tmp/access.signals";

## registry and listing ##

reset_state();
my $reg     = $code{'events.plugin.registry'}->();
my @actions = sort keys %{ $reg->{'action'} };
my @sources = sort keys %{ $reg->{'source'} };

is_deeply_list(
    \@actions,
    [   sort qw|
            send-command task-continue claude-send kimi-send notify zenka-present
            playlist-show-entry
            playlist-hide-entry playlist-exclusive-entry tile-show tile-hide
            overlay-show overlay-hide |
    ],
    'registry : every built-in action type is registered'
);
is_deeply_list( \@sources, [qw| bucket-dependency signal timetable |],
          'registry : timetable, signal and '
        . 'bucket-dependency sources are registered' );
ok( !grep( { !ref $reg->{'action'}{$ARG}{'run'} } @actions ),
    'registry : each action has run' );
ok( !grep( { !ref $reg->{'source'}{$ARG}{'arm'}
                or !ref $reg->{'source'}{$ARG}{'disarm'} } @sources ),
    'registry : each source has arm \ disarm'
);
ok( !grep( { !length $reg->{'action'}{$ARG}{'describe'} } @actions ),
    'registry : each action describes itself' );

my $listing = $code{'events.cmd.plugins'}->();
ok( $listing->{'mode'} eq 'size'
        && $listing->{'data'} =~ m{source\s+signal}
        && $listing->{'data'} =~ m{action\s+send-command},
    'events.plugins lists sources and actions'
);
is_deeply_list( [ $code{'events.plugin.known'}->('action') ],
    \@actions, 'events.plugin.known lists the action names' );

## a registration that does not match its module name is refused ##

{
    local $code{'plugin.events.action.bogus-name'} = sub {
        {   'name'     => 'other',
            'kind'     => 'action',
            'describe' => 'x',
            'run'      => sub { }
        }
    };
    my $r = $code{'events.plugin.registry'}->();
    ok( !exists $r->{'action'}{'bogus-name'}
            && !exists $r->{'action'}{'other'},
        'registry : a mismatched registration is not registered'
    );
    ok( scalar( grep {m{not registered : name}} @logged ),
        'registry : it is logged' );
}

sub is_deeply_list {
    my ( $got, $want, $name ) = @ARG;
    ok( ( join "\0", @{$got} ) eq ( join "\0", @{$want} ), $name )
        or say '#   got  : '
        . join( ' ', @{$got} )
        . "\n#   want : "
        . join( ' ', @{$want} );
}

## built-in actions : the new path against the original handler ##

sub add_entry {
    my ( $id, $name, $action ) = @ARG;
    $data{'events'}{'setup'}{$id}
        = { 'name' => $name, 'action' => $action, 'dep_id' => undef };
    $data{'events'}{'enabled'}{$name} = 1;
}

my @scenarios = (
    [   'send-command at',
        { 'type' => 'send-command', 'command' => 'weather.refresh now' },
        'at'
    ],
    [   'send-command bare',
        { 'type' => 'send-command', 'command' => 'jobsite.scan' }, 'at'
    ],
    [   'send-command start refused',
        { 'type' => 'send-command', 'command' => 'x.y' },
        'start'
    ],
    [ 'send-command no command', { 'type' => 'send-command' }, 'at' ],
    [   'zenka-present at',
        { 'type' => 'zenka-present', 'zenka-name' => 'forensics' }, 'at'
    ],
    [   'zenka-present start',
        { 'type' => 'zenka-present', 'zenka-name' => 'forensics' }, 'start'
    ],
    [   'zenka-present end',
        { 'type' => 'zenka-present', 'zenka-name' => 'forensics' }, 'end'
    ],
    [ 'zenka-present no name', { 'type' => 'zenka-present' }, 'at' ],
    [   'playlist-show start',
        { 'type' => 'playlist-show-entry', 'b32id' => 'PL1' }, 'start'
    ],
    [   'playlist-show end',
        { 'type' => 'playlist-show-entry', 'b32id' => 'PL1' }, 'end'
    ],
    [ 'playlist-show no id', { 'type' => 'playlist-show-entry' }, 'start' ],
    [   'playlist-hide start',
        { 'type' => 'playlist-hide-entry', 'b32id' => 'PL2' }, 'start'
    ],
    [   'playlist-hide end',
        { 'type' => 'playlist-hide-entry', 'b32id' => 'PL2' }, 'end'
    ],
    [   'playlist-exclusive start',
        { 'type' => 'playlist-exclusive-entry', 'b32id' => 'PL3' }, 'start'
    ],
    [   'playlist-exclusive end',
        { 'type' => 'playlist-exclusive-entry', 'b32id' => 'PL3' }, 'end'
    ],
    [   'tile-show start',
        { 'type' => 'tile-show', 'tile-group-name' => 'night' }, 'start'
    ],
    [   'tile-show end',
        { 'type' => 'tile-show', 'tile-group-name' => 'night' }, 'end'
    ],
    [   'tile-hide start',
        { 'type' => 'tile-hide', 'tile-group-name' => 'night' }, 'start'
    ],
    [ 'tile-show no name', { 'type' => 'tile-show' }, 'start' ],
    [   'overlay-show start',
        { 'type' => 'overlay-show', 'tile-group-name' => 'clock' }, 'start'
    ],
    [   'overlay-show end',
        { 'type' => 'overlay-show', 'tile-group-name' => 'clock' }, 'end'
    ],
    [   'overlay-hide start',
        { 'type' => 'overlay-hide', 'tile-group-name' => 'clock' }, 'start'
    ],
    [   'overlay-hide end',
        { 'type' => 'overlay-hide', 'tile-group-name' => 'clock' }, 'end'
    ],
);

sub run_handler {
    my ( $handler, $action, $ev_type, $enabled ) = @ARG;
    reset_state();
    add_entry( 7, 'entry-seven', $action );
    $data{'events'}{'enabled'}{'entry-seven'} = $enabled // 1;
    $data{'events'}{'unix'}{'timetable'}{7} = { 'at' => time + 60 };
    my $err;
    my $ok = eval {
        $handler->(
            FakeEvent->new(
                {   'id'   => 7,
                    'type' => $ev_type,
                    'at'   => 4242 + int( rand 1000 ),
                    'name' => 'entry-seven'
                }
            )
        );
        1;
    };
    $err = $EVAL_ERROR =~ s{ at \(eval \d+\) line \d+.*}{}sr unless $ok;
    ## the timers carry a random slot : compare handler names only ##
    my @t = map { ( split ' ', $ARG )[0] } @timers;
    return {
        'sent'   => [@sent],
        'logged' => [ grep { !m{\[IGNORED\] .* already fired} } @logged ],
        'timers' => \@t,
        'err'    => $err,
        'stack'  => canonical( $data{'events'}{'stack'} ),
        'unix'   => exists $data{'events'}{'unix'}{'timetable'}{7}
        ? 'kept'
        : 'deleted',
    };
}

sub canonical {
    my $v = shift;
    return 'undef' if not defined $v;
    if ( ref $v eq 'ARRAY' ) {
        return '[' . join( ',', map { canonical($ARG) } @{$v} ) . ']';
    }
    if ( ref $v eq 'HASH' ) {
        return '{'
            . join( ',',
            map { "$ARG=>" . canonical( $v->{$ARG} ) } sort keys %{$v} )
            . '}';
    }
    return "$v";
}

if ($have_orig) {
    my $orig = compile_source($orig_src);
    foreach my $sc (@scenarios) {
        my ( $label, $action, $ev_type ) = @{$sc};
        my $old = run_handler( $orig, { %{$action} }, $ev_type );
        my $new = run_handler( $code{'events.handler.event_triggered'},
            { %{$action} }, $ev_type );
        $old->{'err'} //= '';
        $new->{'err'} //= '';
        my $same = canonical($old) eq canonical($new);
        ok( $same, "unchanged : $label" )
            or say "#   old : "
            . canonical($old)
            . "\n#   new : "
            . canonical($new);
    }
    ## the early returns : not enabled \ guard ##
    my $act = { 'type' => 'send-command', 'command' => 'a.b' };
    my $old = run_handler( compile_source($orig_src), { %{$act} }, 'at', 0 );
    my $new = run_handler(
        $code{'events.handler.event_triggered'},
        { %{$act} },
        'at', 0
    );
    ok( canonical($old) eq canonical($new),
        'unchanged : a disabled entry is ignored, no recalc' );
}

## the new path's own expectations ##

my $r1 = run_handler( $code{'events.handler.event_triggered'},
    { 'type' => 'send-command', 'command' => 'weather.refresh now' }, 'at' );
ok( $r1->{'sent'}[0] eq 'cube.weather.refresh | now',
    'send-command sends through the cube'
);
ok( scalar( grep { $ARG eq 'events.recalc' } @{ $r1->{'timers'} } ),
    'at : the recalc timer is armed' );
ok( $r1->{'unix'} eq 'deleted', 'at : the unix entry is dropped' );
my $r2 = run_handler( $code{'events.handler.event_triggered'},
    { 'type' => 'tile-show', 'tile-group-name' => 'night' }, 'start' );
ok( scalar(
        grep { $ARG eq 'cube.tile.switch-group | night' } @{ $r2->{'sent'} }
    ),
    'tile-show switches the group'
);
ok( !@{ $r2->{'timers'} }, 'start : no recalc timer' );

## unknown types refused at load ##

reset_state();
add_entry( 1, 'good', { 'type' => 'send-command', 'command' => 'a.b' } );
add_entry( 2, 'bad-action', { 'type' => 'no-such-action' } );
add_entry( 3, 'no-type',    {} );
add_entry( 4, 'good-signal',
    { 'type' => 'send-command', 'command' => 'c.d' } );
$data{'events'}{'timetable'}{1} = { 'at' => '03:47' };
$data{'events'}{'timetable'}{2} = { 'at' => '04:47' };
$data{'events'}{'timetable'}{4}
    = { 'on' => 'x.done', 'match' => { 'run' => '1' } };
my @refused = $code{'events.plugin.check_setup'}->();
ok( "@refused" eq '2 3', 'unknown action type and missing type are refused' );
ok( scalar(
        grep {
            m{event 'bad-action' refused : unknown action type 'no-such-action' \[ known : [^\]]*send-command}
        } @logged
    ),
    'refusal is logged with the known types'
);
ok( exists $data{'events'}{'setup'}{1} && exists $data{'events'}{'setup'}{4},
    'the other entries still load'
);
ok( !exists $data{'events'}{'setup'}{2}
        && !exists $data{'events'}{'timetable'}{2}
        && !$data{'events'}{'enabled'}{'bad-action'},
    'a refused entry is removed everywhere'
);
ok( !exists $data{'events'}{'timetable'}{4}
        && $data{'events'}{'entry'}{'source_cfg'}{4}{'signal'}{'on'} eq
        'x.done',
    'signal keys leave the timetable section'
);
ok( "@{ $data{'events'}{'entry'}{'sources'}{4} }" eq 'signal'
        && "@{ $data{'events'}{'entry'}{'sources'}{1} }" eq 'timetable',
    'sources are recorded per entry'
);

{
    ## a needed source that is not loaded ##
    reset_state();
    add_entry( 1, 'waits', { 'type' => 'send-command', 'command' => 'a.b' } );
    $data{'events'}{'timetable'}{1} = { 'on' => 'x.done' };
    local $code{'plugin.events.source.signal'};
    delete $code{'plugin.events.source.signal'};
    my @r = $code{'events.plugin.check_setup'}->();
    ok( "@r" eq '1' && scalar(
            grep {
                m{unknown source type 'signal' \[ known : bucket-dependency, timetable \]}
            } @logged
        ),
        'an entry needing a source that is not loaded is refused'
    );
    $code{'plugin.events.source.signal'} = compile_source(
        read_file(
            File::Spec->catfile(
                $root_path, 'src', 'plugin.events.source.signal'
            )
        )
    );
}

## the timetable source : same timers as the direct calls ##

sub timetable_setup {
    reset_state();
    add_entry( 1, 'upgrade',
        { 'type' => 'zenka-present', 'zenka-name' => 'dist-upgrade' } );
    add_entry( 2, 'window',
        { 'type' => 'tile-show', 'tile-group-name' => 'night' } );
    $data{'events'}{'timetable'}{1} = { 'at' => '03:47' };
    $data{'events'}{'timetable'}{2}
        = { 'start' => '20:00', 'end' => '21:30' };
}

timetable_setup();
$code{'events.calc_unix_table'}->();
$code{'events.set_up_timers'}->();
my @direct
    = sort map { s{ \d+(?:\.\d+)?\z}{}r . ' ' . ( ( split ' ', $ARG )[1] ) }
    @timers;
my %direct_unix
    = map { $ARG => canonical( $data{'events'}{'unix'}{'timetable'}{$ARG} ) }
    keys %{ $data{'events'}{'unix'}{'timetable'} };

timetable_setup();
$code{'events.plugin.check_setup'}->();
$code{'events.source.arm_all'}->();
my @via
    = sort map { s{ \d+(?:\.\d+)?\z}{}r . ' ' . ( ( split ' ', $ARG )[1] ) }
    @timers;
my %via_unix
    = map { $ARG => canonical( $data{'events'}{'unix'}{'timetable'}{$ARG} ) }
    keys %{ $data{'events'}{'unix'}{'timetable'} };

ok( @direct == 3 && "@direct" eq "@via",
    'timetable : the same timers as the direct calls' )
    or say "#   direct : @direct\n#   via    : @via";
ok( canonical( \%direct_unix ) eq canonical( \%via_unix ),
    'timetable : the same unix table' );
ok( $data{'events'}{'timetable'}{1}{'next'}
        && $data{'events'}{'timetable'}{1}{'left'},
    'timetable : next \ left are kept for list events'
);

## recalc keeps working ##

@timers = ();
$code{'events.recalc'}->();
ok( scalar @timers == 3, 'timetable : recalc re-arms the timers' );
my $armed_before = scalar grep { $ARG->is_active }
    map { values %{$ARG} } values %{ $data{'events'}{'timers'} };
ok( $armed_before == 3,
    'timetable : recalc leaves one active timer per time' );

## the timetable source disarms ##

{
    my $src = $code{'events.plugin.registry'}->()->{'source'}{'timetable'};
    my @t   = map { values %{$ARG} } values %{ $data{'events'}{'timers'} };
    $src->{'disarm'}->( [ 1, 2 ] );
    ok( !grep( { $ARG->is_active } @t )
            && !keys %{ $data{'events'}{'unix'}{'timetable'} },
        'timetable : disarm cancels the timers and drops the unix entries'
    );
}

## events.trigger_event keeps working for timer ids ##

timetable_setup();
$code{'events.plugin.check_setup'}->();
$code{'events.source.arm_all'}->();
$now_called = 0;
$call       = { 'args' => '1' };
my $trig = $code{'events.cmd.trigger_event'}->();
ok( $trig->{'mode'} eq 'true' && $now_called == 1,
    'trigger_event fires a timer id' );
$call = { 'args' => 'claude.run.done' };
ok( $code{'events.cmd.trigger_event'}->()->{'mode'} eq 'false',
    'trigger_event still wants a numeric id' );

## signals ##

mkdir "$tmp/var";
open my $afh, '>:encoding(UTF-8)', $grants_file or die;
print {$afh} <<'EOF';
   .:[ test signal grants ]:.

   events.signal.claude  =  claude.run.done \
                     claude.window.*  # a comment
   events.signal.kimi    =  kimi.run.done
   events.signal.*       =  net.changed
   events.signal.sloppy  =  *
   ## events.signal.ghost = ghost.done
EOF
close $afh;

sub signal_setup {
    reset_state();
    add_entry( 1, 'on-claude-done',
        { 'type' => 'send-command', 'command' => 'coding.resume now' } );
    add_entry( 2, 'on-claude-ok',
        { 'type' => 'send-command', 'command' => 'coding.next now' } );
    add_entry( 3, 'on-kimi-done',
        { 'type' => 'zenka-present', 'zenka-name' => 'kimi' } );
    add_entry( 4, 'off',
        { 'type' => 'send-command', 'command' => 'never.sent now' } );
    $data{'events'}{'enabled'}{'off'} = 0;
    $data{'events'}{'timetable'}{1}   = { 'on' => 'claude.run.done' };
    ## the section files give the flat key 'match.state' ##
    $data{'events'}{'timetable'}{2}
        = { 'on' => 'claude.run.done', 'match.state' => 'ok' };
    $data{'events'}{'timetable'}{3} = { 'on' => 'kimi.run.done' };
    $data{'events'}{'timetable'}{4} = { 'on' => 'claude.run.done' };
    unlink $journal;
    $code{'events.plugin.check_setup'}->();
    $code{'events.source.arm_all'}->();
}

signal_setup();
ok( join( ' ',
        sort { $a <=> $b } keys %{ $data{'events'}{'signal'}{'armed'} } ) eq
        '1 2 3 4',
    'signal : the waiting entries are armed'
);

$call = { 'args' => 'claude claude.run.done state=failed run=9' };
my $res = $code{'events.cmd.signal'}->();
ok( $res->{'mode'} eq 'true' && $res->{'data'} =~ m{1 woken},
    'signal : raised, one entry woken [ the '
        . 'match filters, disabled stays quiet ]'
) or say '#   ' . ( $res->{'data'} // 'undef' );
ok( "@sent" eq 'cube.coding.resume | now',
    'signal : the woken entry ran its action'
) or say "#   @sent";

@sent = ();
$call = { 'args' => 'claude claude.run.done state=ok run=10' };
$res  = $code{'events.cmd.signal'}->();
ok( $res->{'data'} =~ m{2 woken}
        && "@sent" eq 'cube.coding.resume | now cube.coding.next | now',
    'signal : a matching value wakes several entries in id order'
) or say "#   @sent";

@sent = ();
$call = { 'args' => 'kimi kimi.run.done' };
$res  = $code{'events.cmd.signal'}->();
ok( $res->{'mode'} eq 'true' && "@sent" eq 'cube.v7-zenki.start_once | kimi',
    'signal : zenka-present woken by a signal starts the zenka'
) or say "#   @sent";

@sent = ();
$call = { 'args' => 'claude kimi.run.done' };
$res  = $code{'events.cmd.signal'}->();
ok( $res->{'mode'} eq 'false' && !@sent && $res->{'data'} =~ m{may not raise},
    'access : another zenka\'s signal name is refused'
);

$call = { 'args' => 'claude claude.window.reset' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'true',
    'access : a prefix grant covers the names under it'
);
$call = { 'args' => 'claude claude.window' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'access : a prefix grant does not cover the bare prefix'
);
$call = { 'args' => 'kimi net.changed' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'true',
    'access : the wildcard user list grants everyone'
);
$call = { 'args' => 'sloppy anything.at.all' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'true',
    'access : events.signal.* grants every name'
);
$call = { 'args' => 'ghost ghost.done' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'access : a commented grant grants nothing'
);
$call = { 'args' => 'stranger claude.run.done' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'access : an unlisted zenka is refused' );

## names come from access.signals only : route-looking tokens in the cube ##
## access file grant nothing                                              ##
open my $ofh, '>:encoding(UTF-8)', $access_file or die;
print {$ofh} "   access.cmd.usr.oldstyle = events.signal "
    . "events.signal.old.done events.signal.*\n";
close $ofh;
$call = { 'args' => 'oldstyle old.done' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'access : events.signal.<name> in access.zenki grants nothing'
);

## the source is never a parameter : the first token is the cube session ##
@sent = ();
$call = { 'args' => 'kimi claude.run.done source=claude' };
$res  = $code{'events.cmd.signal'}->();
ok( $res->{'mode'} eq 'false' && !@sent,
    'source : a declared source value does not change who raised it' );

## argument checks ##
$call = { 'args' => 'claude' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'signal : a name is required' );
$call = { 'args' => 'claude Bad_Name' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'signal : the name is lowercase dotted' );
$call = { 'args' => 'claude claude.run.done novalue' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'signal : values are key=value' );
$call = { 'args' => '' };
ok( $code{'events.cmd.signal'}->()->{'mode'} eq 'false',
    'signal : no source is refused' );

## journal ##

$call = { 'args' => 'claude claude.run.done state=ok note=has%20pct run=11' };
$code{'events.cmd.signal'}->();
ok( -s $journal, 'journal : the signal file exists' );
open my $jfh, '<:encoding(UTF-8)', $journal or die;
my @jl = <$jfh>;
close $jfh;
ok( @jl >= 4
        && !
        grep(
        { !
                m{\Asignal\.[a-z0-9._-]+ = time:\S+ source:\S+ woken:\S+ values:\S+\n\z}
        } @jl ),
    'journal : one config style line per signal'
    )
    or print "#   $ARG"
    for @jl;
ok( $jl[0]
        =~ m|\Asignal\.claude\.run\.done = time:\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d source:claude woken:on-claude-done values:run=9,state=failed\n\z|,
    'journal : time, name, source, woken entries and values'
) or print "#   $jl[0]";
ok( $jl[0] !~ m{kimi.run.done}
        && scalar( grep {m{\Asignal\.kimi\.run\.done}} @jl ),
    'journal : every raised signal is a line'
);
ok( !grep( {m{claude\.kimi\.run\.done}} @jl ),
    'journal : a refused signal is not journaled'
);

my $recs = $code{'events.signal.journal_read'}->(2);
ok( @{$recs} == 2
        && $recs->[-1]{'values'}{'note'} eq 'has%20pct'
        && $recs->[-1]{'values'}{'run'} eq '11',
    'journal : read back last n, values decoded'
);

$data{'events'}{'signal'}{'journal_path'} = "$tmp/var/new.journal";
$code{'events.signal.journal_write'}->(
    {   'time'   => time,
        'name'   => 'x.y',
        'source' => 'a b',
        'values' => { 'k k' => "v=1,2\x{e9}" },
        'woken'  => ['e one']
    }
);
my $back = $code{'events.signal.journal_read'}->(5);
ok( $back->[0]{'source'} eq 'a b'
        && $back->[0]{'values'}{'k k'} eq "v=1,2\x{e9}"
        && $back->[0]{'woken'}[0] eq 'e one',
    'journal : awkward text round trips through the escape'
);

my $list = $code{'events.cmd.signals'}->();
$call = { 'args' => '3' };
$list = $code{'events.cmd.signals'}->();
ok( $list->{'mode'} eq 'size'
        && $list->{'data'} =~ m{x\.y from a b : woke e one},
    'events.signals lists the last signals'
) or say '#   ' . ( $list->{'data'} // $list->{'mode'} );
$call = { 'args' => 'many' };
ok( $code{'events.cmd.signals'}->()->{'mode'} eq 'false',
    'events.signals wants a number' );

## journal and a failing write ##

$data{'events'}{'signal'}{'journal_path'}
    = '/proc/no/such/di' . 'r/signal.journal';
$code{'events.signal.journal_write'}->(
    {   'time'   => time,
        'name'   => 'a.b',
        'source' => 'claude',
        'values' => {},
        'woken'  => []
    }
);
ok( scalar( grep {m{signal journal : cannot}} @logged ),
    'journal : a failed write is logged' );
$call = { 'args' => '1' };
ok( $code{'events.cmd.signals'}->()->{'data'}
        =~ m{a\.b from claude : woke nothing},
    'journal : the in-memory list still lists it'
);

## an action that dies does not stop the others ##

signal_setup();
## no command : dies ##
$data{'events'}{'setup'}{1}{'action'} = { 'type' => 'send-command' };
@sent = ();
my $w = $code{'events.signal.raise'}
    ->( 'claude', 'claude.run.done', { 'state' => 'ok' } );
ok( "@{$w}" eq 'on-claude-ok'
        && "@sent" eq 'cube.coding.next | now'
        && scalar( grep {m{woken by signal 'claude.run.done' failed}}
            @logged ),
    'raise : a dying action is logged, the next entry still runs'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,..,...,..,,...,.,,,.,,,.,.,.,,,...,,,.,,..,..,,...,...,,..,.,.,.,,,,.,,,.,,
#B3SBTCCBD56UC6KHFZWL3C3WOV4JCWPOZ6HMKNZE5BXWLXSSFPU2G5JZUSIBFGK2IKHEZIVNLSQL4
#\\\|KXPEPFKVEPGLI2VTQJF6BDHNXVT4CFODSDJODO43Q26OD5PEF35 \ / AMOS7 \ YOURUM ::
#\[7]V7KKJSM3F3V55266OGJD675CD5JLGJXOFKLV6EOBC6LDVET7DADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
