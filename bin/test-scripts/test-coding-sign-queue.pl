#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
## coding zenka : open decisions                                            ##
## [ menu pending questions, decision.answered ], the sign queue and        ##
## planned commits. compiles the real coding.*, menu and events.cmd.signal  ##
## modules in one process ; p7-sign-run \ p7-commit are fake scripts in a   ##
## tmp bin dir writing json state files the way the real ones do, driven by ##
## control files [ the owner's y \ n ]. tests are fake scripts. the timer   ##
## is driven by hand [ tick ] ; a restart drops memory and reads again      ##

use File::Spec;
use File::Temp  qw| tempdir |;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use POSIX       ();
use Time::HiRes qw| sleep time |;
use JSON::PP    ();

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
use Digest::BMW ();
use Crypt::Misc qw| encode_b32r |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;
our ( %data, %code, $call );
my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    die "ok() without a name [ a list-context match ? ]\n" if @ARG != 2;
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
    my ( $src, $name ) = @ARG;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x, $src,
        -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error $name : $EVAL_ERROR" if $EVAL_ERROR;
    return $sub;
}

sub read_file {
    my $path = shift;
    open my $fh, '<:encoding(UTF-8)', $path
        or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    return scalar <$fh>;
}

sub write_file {
    my ( $path, $text, $mode ) = @ARG;
    open my $fh, '>:encoding(UTF-8)', $path or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh;
    chmod $mode, $path if defined $mode;
}

sub load_module {
    my $name = shift;
    $code{$name} = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ), $name );
}

load_module($ARG)
    foreach (
    map( {"coding.sign_queue.$ARG"}
        qw| store cfg detach read_rc read_state read_out file_sums check_paths
            enqueue head stop step_entry step_plan tick prune arm describe |
    ),
    map( {"coding.cmd.$ARG"}
        qw| ask answer open sign-queue commit-plan commit-plans | ),
    qw| coding.decision.send coding.handler.decision_reply park.parse_args
    base.reply.mode_text base.chk-sum.bmw.filesum base.chk-sum.bmw.ctx
    events.cmd.signal
    events.signal.access events.signal.grants
    protocol-7-menu.cmd.pending-question-add
    protocol-7-menu.cmd.pending-question-answer
    protocol-7-menu.cmd.pending-question-list
    protocol-7-menu.decision.raise
    protocol-7-menu.handler.decision_signal_reply |
    );

## stubs ##
my ( @logged, @pending, %replies, @signals, @timers );
our $zenka = 'coding';
our $gen   = 0;
$code{'base.logs'} = $code{'base.log'} = sub {
    my @a = @ARG;
    my $l = $a[0] =~ m|\A\d+\z| && @a > 1 ? shift @a : 1;
    my $f = shift @a;
    push @logged, "[$l] " . ( @a ? sprintf( $f, @a ) : $f );
    TRUE;
};
$code{'base.s_warn'} = sub { push @logged, 'warn'; TRUE };
$code{'base.time'}   = sub {time};
$code{'base.gen_id'} = sub { 'GEN' . ++$main::gen };
$code{'protocol-7-menu.pending-indicator-update'} = sub {TRUE};
## the zenka's base.* aliases [ chk-sum.bmw.* ] and the ctx table ##
$code{'chk-sum.bmw.filesum'} = $code{'base.chk-sum.bmw.filesum'};
$code{'chk-sum.bmw.ctx'}     = $code{'base.chk-sum.bmw.ctx'};
$data{'chk-sum'}{'bmw'}      = { map { $ARG => undef } 224, 256, 384, 512 };
*main::encode_b32r           = \&Crypt::Misc::encode_b32r;
$code{'base.callback.cmd_reply'}
    = sub { $replies{ $ARG[0] } = $ARG[1]; TRUE };
$code{'events.signal.raise'} = sub { push @signals, [@ARG];          [] };
$code{'base.interval.next'}  = sub { push @timers,  $ARG[0]{'type'}; 2 };
{

    package FakeTimer;
    sub new    { bless { 'on' => 1 }, shift }
    sub cancel { $_[0]{'on'} = 0 }
}
$code{'event.add_timer'} = sub { FakeTimer->new };

my $tmp
    = tempdir( 'coding-sign-queue-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my ( $repo, $bin, $state, $tests, $ctl, $zdir )
    = map {"$tmp/$ARG"} qw| repo bin state tests ctl zdir |;
mkdir $ARG for $repo, "$repo/src", $bin, $state, $tests, $ctl, $zdir;
write_file( "$repo/src/$ARG", "## $ARG ##\n" ) for qw| a b c d |;
$data{'coding'}{'cfg'}{'sign_queue_root'}      = $repo;
$data{'coding'}{'cfg'}{'sign_queue_bin_dir'}   = $bin;
$data{'coding'}{'cfg'}{'sign_queue_state_dir'} = $state;
$data{'coding'}{'cfg'}{'sign_queue_test_dir'}  = $tests;
$data{'events'}{'signal'}{'grants_file'}
    = "$root_path/cfg/zenki/" . "events/access.signals";

$code{'file.zenka_dir.load'} = sub {
    my $p = "$zdir/$zenka." . shift;
    return undef if !-f $p;
    my $t = read_file($p);
    return \$t;
};
$code{'file.zenka_dir.write'} = sub {
    my ( $name, $sref ) = @ARG;
    write_file( "$zdir/$zenka.$name", $sref->$* );
    TRUE;
};

## the fakes : same state files and output as bin/dev/p7-sign-run \ ##
## p7-commit                                                        ##
write_file( "$bin/p7-sign-run", <<"PERL", 0755 );
#!$EXECUTABLE_NAME
use strict; use warnings; use JSON::PP;
my \$ctl = '$ctl';
my (\$sp, \$op, \@paths);
while (defined(my \$a = shift)) {
    if (\$a eq '-state') { \$sp = shift } elsif (\$a eq '-op') { \$op = shift } else { push \@paths, \$a }
}
open my \$l, '>>', "\$ctl/sign.log"; print \$l "\$\$ \@paths\\n"; close \$l;
my \$s = { status => 'awaiting-approval', paths => [\@paths, 'cfg/protocol-7.src-ver'], pid => \$\$, started => time };
sub w { open my \$f, '>:raw', "\$sp.tmp"; print \$f JSON::PP->new->utf8->encode(\$s); close \$f; rename "\$sp.tmp", \$sp }
w();
for (1 .. 600) { last if -f "\$ctl/answer"; select undef, undef, undef, 0.05 }
open my \$a, '<', "\$ctl/answer" or exit 1; my \$ans = <\$a>; close \$a; unlink "\$ctl/answer";
chomp \$ans;
exit 1 if \$ans eq 'die';
\$s->{status} = \$ans;
\$s->{denied_reason} = 'not now' if \$ans eq 'denied';
\$s->{end_reason} = 'busy' if \$ans eq 'aborted';
\$s->{version} = '6.77.8' if \$ans eq 'approved';
w();
exit(\$ans eq 'approved' ? 0 : 1);
PERL
write_file( "$bin/p7-commit", <<"PERL", 0755 );
#!$EXECUTABLE_NAME
use strict; use warnings; use JSON::PP;
my \$ctl = '$ctl'; my \$dir = '$state';
my \$j = JSON::PP->new->utf8->canonical;
my \$cmd = shift;
open my \$l, '>>', "\$ctl/commit.log"; print \$l "\$cmd \@ARGV\\n"; close \$l;
if (\$cmd eq 'prepare') {
    my \$msg = do { local \$/; <STDIN> };
    if (-f "\$ctl/prepare-refuse") { print STDERR "p7-commit : message form refused\\n"; exit 1 }
    my \$staged = -f "\$ctl/staged" ? do { open my \$f, '<', "\$ctl/staged"; local \$/; <\$f> } : '';
    my \$id = sprintf 'p7-commit-%d-%d', time, \$\$;
    open my \$f, '>:raw', "\$dir/\$id.json";
    print \$f \$j->encode({ op => 'new', message => \$msg, status => 'prepared', staged_files => [ split ' ', \$staged ] });
    close \$f; print "\$id\\n"; exit 0;
}
if (\$cmd eq 'commit') {
    my \$id = shift; open my \$f, '<:raw', "\$dir/\$id.json"; my \$s = \$j->decode(do { local \$/; <\$f> }); close \$f;
    if (-f "\$ctl/commit-refuse") { \$s->{status} = 'refused'; \$s->{report} = 'hook : no version bump' }
    else { \$s->{status} = 'committed'; \$s->{commit} = 'c0ffee' . (\$\$ % 10) }
    open \$f, '>:raw', "\$dir/\$id.json"; print \$f \$j->encode(\$s); close \$f;
    exit(\$s->{status} eq 'committed' ? 0 : 1);
}
exit 2;
PERL
write_file( "$tests/test-pass.pl", "exit 0;\n" );
write_file( "$tests/test-fail.pl", "print qq|FAIL - broken\\n|; exit 1;\n" );

sub cmd {
    local $SIG{__DIE__} = sub { require Carp; Carp::confess(@_) }
        if $ENV{DBG};
    my ( $name, $args, $reply_id ) = @ARG;
    local $call = { 'args' => $args, 'reply_id' => $reply_id // 'silent' };
    my $rv = eval { $code{$name}->() };
    die "$name died : $EVAL_ERROR" if $EVAL_ERROR;
    return $rv;
}
sub tick  { $code{'coding.sign_queue.tick'}->(undef) }
sub entry { $code{'coding.sign_queue.store'}->()->{'entry'}{ shift() } // {} }
sub plan  { $code{'coding.sign_queue.store'}->()->{'plan'}{ shift() }  // {} }
sub answer { write_file( "$ctl/answer", shift() . "\n" ) }
sub staged { write_file( "$ctl/staged", join ' ', @ARG ) }

sub wait_for {    ## tick until the condition holds [ the timer firing ] ##
    my ( $cond, $max ) = @ARG;
    my $until = time + ( $max // 10 );
    while ( time < $until ) { tick(); return TRUE if $cond->(); sleep 0.05 }
    return FALSE;
}

sub lines_of {
    my $f = shift;
    return 0 if !-f $f;
    scalar( () = read_file($f) =~ m{\n}g );
}
sub restart { delete $data{'coding'}{'sign_queue'} }

no strict 'refs';
*{'main::store'} = sub { $code{'coding.sign_queue.store'}->(@ARG) };
use strict 'refs';

## ---- 1 : decisions                                                     ##
## ------------------------------------------------------ the cube stub : ##
## coding -> menu, menu -> events, replies on pump                        ##
$code{'protocol-7.route-send'}
    = sub { push @pending, { %{ shift() }, 'from' => $zenka }; TRUE };

sub pump {
    while ( my $c = shift @pending ) {
        my ( $target, $sub ) = $c->{'command'} =~ m{\A([\w-]+)\.(.+)\z};
        my $rv;
        if ( $target eq 'events' ) {
            local $zenka = 'events';
            $rv = cmd( "events.cmd.$sub",
                "$c->{'from'} $c->{'call_args'}{'args'}" );
        } else {
            local $zenka = $target;
            $rv = cmd( "$target.cmd.$sub", $c->{'call_args'}{'args'} );
        }
        next if ref $c->{'reply'} ne 'HASH';
        local $zenka = $c->{'from'};
        $code{ $c->{'reply'}{'handler'} }->(
            {   'cmd'       => uc $rv->{'mode'},
                'call_args' => { 'args' => $rv->{'data'} },
                'params'    => $c->{'reply'}{'params'}
            }
        );
    }
}

my $rv = cmd( 'coding.cmd.ask',
    'deploy now or later? choices=now,later id=dep1', 11 );
ok( $rv->{'mode'} eq 'deferred',
    'ask : deferred reply [ route-send buffers ]' );
pump();
ok( ( $replies{11}{'data'} // '' ) eq 'decision dep1 open',
    'ask : the menu holds it' );
my $q = $data{'protocol-7-menu'}{'pending-questions'}[0];
ok( $q->{'type'} eq 'choice'
        && $q->{'question'} eq 'deploy now or later?'
        && "@{ $q->{'options'} }" eq 'now later'
        && $q->{'decision'},
    'ask : choice, text, options, decision flag [ key=value, no json ]'
);
cmd( 'coding.cmd.ask', 'what next', 12 );
pump();
ok( $replies{12}{'data'} =~ m{\Adecision GEN\d+ open\z},
    'ask : text question, id from the menu' );
## a json question [ cred-mesh ] is no decision ##
{
    local $zenka = 'protocol-7-menu';
    cmd( 'protocol-7-menu.cmd.pending-question-add',
        '{"type":"password",' . '"question":"key?",' . '"id":"pw1"}' );
}
cmd( 'coding.cmd.open', '', 13 );
pump();
ok( $replies{13}{'data'} =~ m{question\.dep1\.options = now, later}
        && $replies{13}{'data'} !~ m{pw1},
    'open : decisions only, p7 lines'
);
cmd( 'coding.cmd.answer', 'dep1 later please', 14 );
pump();
ok( ( $replies{14}{'mode'} // '' ) eq 'true', 'answer : accepted' );
ok( @signals == 1
        && $signals[0][0] eq 'protocol-7-menu'
        && $signals[0][1] eq 'decision.answered'
        && $signals[0][2]{'id'} eq 'dep1'
        && $signals[0][2]{'answer'} eq 'later_please',
    'answer : decision.answered id= answer= [ granted to the menu ]'
);
cmd( 'coding.cmd.answer', 'dep1 again', 15 );
pump();
ok( $replies{15}{'mode'} eq 'false' && @signals == 1,
    'answer : a gone id is refused, no signal'
);
{
    local $zenka = 'protocol-7-menu';
    cmd( 'protocol-7-menu.cmd.pending-question-answer', 'pw1 secret' );
}
pump();
ok( @signals == 1, 'a json \ password question raises nothing [ journal ]' );
{
    local $zenka = 'coding';
    my $r = cmd( 'events.cmd.signal', 'coding decision.answered id=x' );
    ok( $r->{'mode'} eq 'false',
        'decision.answered not granted to coding [ one raise point ]' );
}
my $park = $code{'park.parse_args'}->('on=decision.answered match.id=dep1');
ok( $park->{'pairs'}{'on'} eq 'decision.answered'
        && $park->{'pairs'}{'match.id'} eq 'dep1',
    'task.park on=decision.answered match.id= parses [ the park path ]'
);

## ---- 2 : sign queue                                   ##
## ----------------------------------------------------- ##
$rv = cmd( 'coding.cmd.sign-queue', 'add src/a message="area : first"' );
ok( $rv->{'data'} eq 'q1 queued : next to sign', 'add : q1 next' );
$rv = cmd( 'coding.cmd.sign-queue', 'add src/b message="area : second"' );
ok( $rv->{'data'} =~ m{\Aq2 queued behind q1},
    'add : q2 behind q1 [ order ]' );
ok( cmd( 'coding.cmd.sign-queue', 'add /etc/passwd message=x' )->{'mode'} eq
        'false',
    'add : an absolute path is refused'
);
ok( cmd( 'coding.cmd.sign-queue', 'add src/a' )->{'mode'} eq 'false',
    'add : message required' );
ok( wait_for(
        sub {
            entry('q1')->{'status'} eq 'signing'
                && -f "$state/" . entry('q1')->{'sign_job'} . '.json';
        }
    ),
    'q1 : sign requested'
);
tick() for 1 .. 3;
ok( lines_of("$ctl/sign.log") == 1,
    'one pending sign at a time [ q2 not started ]' );
ok( entry('q2')->{'status'} eq 'queued', 'q2 waits' );
staged(qw| src/a cfg/protocol-7.src-ver |);
answer('approved');
ok( wait_for( sub { entry('q1')->{'status'} eq 'committed' } ),
    'approved -> prepare -> commit' );
ok( entry('q1')->{'commit'} =~ m{\Ac0ffee}, 'q1 : the commit hash kept' );
my $log = read_file("$ctl/commit.log");
ok( $log =~ m{\Aprepare -op new\ncommit p7-commit-\d+-\d+\n},
    'prepare then commit, op new' );
my ($cid) = $log =~ m{commit (p7-commit-\S+)};
ok( JSON::PP::decode_json( read_file("$state/$cid.json") )->{'message'} eq
        'area : first',
    'the queued message committed'
);
ok( wait_for( sub { entry('q2')->{'status'} eq 'signing' } ),
    'then the next sign [ q2 ]' );

## restart while q2 waits for the owner : the job is re-checked ##
restart();
ok( entry('q2')->{'status'} eq 'signing',
    'restart : q2 read back in flight' );
staged(qw| src/b |);
answer('denied');
ok( wait_for( sub { entry('q2')->{'status'} eq 'stopped' } ),
    'restart resumes : denied seen' );
ok( entry('q2')->{'reason'} eq 'sign denied : not now',
    'denied stops with the reason' );
cmd( 'coding.cmd.sign-queue', 'add src/c message="area : third"' );
tick() for 1 .. 3;
ok( entry('q3')->{'status'} eq 'queued' && lines_of("$ctl/sign.log") == 2,
    'the queue waits behind a stopped entry' );
ok( !$code{'coding.sign_queue.arm'}->(),
    'no timer while the head is stopped'
);
ok( cmd( 'coding.cmd.sign-queue', 'drop q2' )->{'data'} eq 'q2 dropped',
    'drop q2 [ never signed : no staged note ]' );
ok( wait_for( sub { entry('q3')->{'status'} eq 'signing' } ),
    'drop : the queue goes on' );
ok( cmd( 'coding.cmd.sign-queue', 'drop q3' )->{'mode'} eq 'false',
    'drop : an entry in flight is refused' );
## refused commit ##
staged(qw| src/c |);
write_file( "$ctl/commit-refuse", '' );
answer('approved');
ok( wait_for( sub { entry('q3')->{'status'} eq 'stopped' } ),
    'refused commit stops' );
ok( entry('q3')->{'reason'} =~ m{\Acommit refused : hook : no version bump},
    'refused : the hook report' );
unlink "$ctl/commit-refuse";
ok( scalar(
        cmd( 'coding.cmd.sign-queue', 'drop q3' )->{'data'}
            =~ m{\Aq3 dropped -- its signed files are still staged : src/c cfg/protocol-7\.src-ver\z}
    ),
    'drop after the approval : the staged files named'
);
## staged beyond the signed set : never a commit of something else ##
cmd( 'coding.cmd.sign-queue', 'add src/d message="area : four"' );
ok( wait_for( sub { entry('q4')->{'status'} eq 'signing' } ), 'q4 signing' );
staged(qw| src/d src/other-agents-file |);
answer('approved');
ok( wait_for( sub { entry('q4')->{'status'} eq 'stopped' } )
        && entry('q4')->{'reason'} eq 'staged files beyond the signed '
        . 'set : src/other-agents-file',
    'staged files beyond the signed set stop it, no commit'
);
ok( scalar( () = read_file("$ctl/commit.log") =~ m{^commit }mg ) == 2,
    'no commit run for q4 [ only q1 and the refused q3 ]'
);
cmd( 'coding.cmd.sign-queue', 'drop q4' );
## aborted, and a job gone without a final state ##
cmd( 'coding.cmd.sign-queue', 'add src/a message="area : five"' );
ok( wait_for( sub { entry('q5')->{'status'} eq 'signing' } ), 'q5 signing' );
answer('die');
ok( wait_for( sub { entry('q5')->{'status'} eq 'stopped' } )
        && entry('q5')->{'reason'} =~ m{process gone},
    'a sign job gone without a final state stops'
);
cmd( 'coding.cmd.sign-queue', 'drop q5' );
cmd( 'coding.cmd.sign-queue', 'add src/a message="area : six"' );
wait_for( sub { entry('q6')->{'status'} eq 'signing' } );
write_file( "$ctl/prepare-refuse", '' );
answer('approved');
ok( wait_for( sub { entry('q6')->{'status'} eq 'stopped' } )
        && entry('q6')->{'reason'}
        =~ m{\Acommit prepare refused : p7-commit : message form refused},
    'a refused prepare stops with its output'
);
unlink "$ctl/prepare-refuse";
cmd( 'coding.cmd.sign-queue', 'drop q6' );
my $list = cmd( 'coding.cmd.sign-queue', '' )->{'data'};
ok( $list =~ m{entry\.q1\.status = committed}
        && $list =~ m{entry\.q1\.message = area : first},
    'list : p7 lines'
);
ok( read_file("$zdir/coding.sign-queue")
        =~ m{^entry\.q1\.status = committed$}m
        && read_file("$zdir/coding.sign-queue") !~ m|[{}"]\s*:|,
    'persisted in p7 config style'
);

## ---- 3 : planned commits                         ##
## ------------------------------------------------ ##
$rv = cmd( 'coding.cmd.commit-plan',
          'p1 paths=src/a,src/b message="area '
        . ': planned" when="tests=test-pass"' );
ok( $rv->{'data'} eq 'plan p1 waits : tests test-pass, files unchanged',
    'plan p1 with tests=' );
$rv = cmd( 'coding.cmd.commit-plan',
    'p2 paths=src/c message="area : after" after=p1' );
ok( $rv->{'mode'} eq 'true', 'plan p2 after=p1' );
ok( cmd( 'coding.cmd.commit-plan',
        'p3 paths=src/c message=x tests=../../evil' )->{'mode'} eq 'false',
    'a test name outside the test dir is refused'
);
ok( cmd( 'coding.cmd.commit-plan', 'p3 paths=src/c message=x after=nope' )
        ->{'mode'} eq 'false',
    'after= an unknown plan is refused'
);
ok( cmd( 'coding.cmd.commit-plans', '' )->{'data'}
        =~ m{plan\.p2\.waits = plan p1 committed \[ now waiting \], files unchanged},
    'commit-plans : what each waits for'
);
ok( wait_for( sub { plan('p1')->{'status'} eq 'queued' } ),
    'p1 : tests pass -> the sign queue' );
my $pe = plan('p1')->{'entry'};
ok( wait_for( sub { entry($pe)->{'status'} eq 'signing' } ),
    "p1 : $pe signing" );
ok( plan('p2')->{'status'} eq 'waiting', 'p2 waits for p1' );
staged(qw| src/a src/b |);
answer('approved');
ok( wait_for( sub { plan('p1')->{'status'} eq 'committed' } ),
    'p1 committed' );
ok( wait_for( sub { plan('p2')->{'status'} eq 'queued' } ),
    'p2 : after p1 -> queued' );
my $pe2 = plan('p2')->{'entry'};
wait_for( sub { entry($pe2)->{'status'} eq 'signing' } );
staged(qw| src/c |);
answer('approved');
ok( wait_for( sub { plan('p2')->{'status'} eq 'committed' } ),
    'p2 committed' );
## a changed file returns it ##
cmd( 'coding.cmd.commit-plan',
    'p4 paths=src/d message="area : four" tests=test-pass' );
write_file( "$repo/src/d", "## changed ##\n" );
ok( wait_for( sub { plan('p4')->{'status'} eq 'returned' } )
        && plan('p4')->{'reason'} eq 'file changed since the plan : src/d',
    'a changed file returns the plan'
);
## a failed test returns it, and the plan after it ##
cmd( 'coding.cmd.commit-plan',
    'p5 paths=src/d message="area : five" tests=test-pass,test-fail' );
cmd( 'coding.cmd.commit-plan',
    'p6 paths=src/a message="area : six" after=p5' );
ok( wait_for( sub { plan('p5')->{'status'} eq 'returned' } )
        && plan('p5')->{'reason'}
        =~ m{\Atest test-fail failed \[ rc 1 \] : FAIL - broken},
    'a failed test returns the plan'
);
ok( wait_for( sub { plan('p6')->{'status'} eq 'returned' } )
        && plan('p6')->{'reason'} =~ m{\Aafter plan p5 returned},
    'after= a returned plan returns too'
);
## a file changed while the plan waits in the queue ##
cmd( 'coding.cmd.commit-plan', 'p7 paths=src/b message="area : seven"' );
## placeholder ##
cmd( 'coding.cmd.sign-queue', 'add src/c message="area : blocker"' );
restart();
ok( plan('p7')->{'status'} eq 'waiting', 'restart : plans read back' );
ok( wait_for( sub { plan('p7')->{'status'} =~ m{queued|returned} } ),
    'p7 queued' );
## the blocker signs first : change src/b meanwhile ##
my ($blk) = grep { entry($ARG)->{'message'} eq 'area : blocker' }
    keys %{ store()->{'entry'} };
wait_for( sub { entry($blk)->{'status'} eq 'signing' } );
write_file( "$repo/src/b", "## b changed ##\n" );
staged(qw| src/c |);
answer('approved');
my $pe7 = plan('p7')->{'entry'};
ok( wait_for( sub { plan('p7')->{'status'} eq 'returned' } )
        && entry($pe7)->{'reason'} eq 'file changed since the plan : src/b',
    'a file changed in the queue : stopped before its sign, plan returned'
);
ok( cmd( 'coding.cmd.commit-plan',
        'p7 paths=src/b message="area : seven again"' )->{'mode'} eq 'true',
    'a returned plan is planned again'
);
ok( scalar( grep( { $ARG eq 'coding-sign-watch' } @timers ) ),
    'timers from base.interval.next [ coding-sign-watch ]'
);

say "# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,,..,..,,,..,.,,,,.,,.,.,...,.,,,...,,,.,..,,...,...,...,.,.,,..,...,,,,,
#DOZ5K4F4AJE34V3K2V246CMUM2Z7S3FM3P64LLH55GIMG54CLHSESR4E3O2ZVEH5VMQOI72LLB2FE
#\\\|QP7ZPHMEUDLDHZBRWZKDOCEUQZ7CRZSN6UQNSTHCVHR6HFMB5VM \ / AMOS7 \ YOURUM ::
#\[7]IYVWR4ZGM26WTS5IMETPLQBXHH3ZWU5227WJQUJOZIPNKPFK5ECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
