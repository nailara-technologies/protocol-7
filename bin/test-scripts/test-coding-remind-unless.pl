#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## self-cancelling reminders : real bucket and signal modules, fake zenki. ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
use POSIX       qw| strftime |;
use Time::HiRes ();

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
    die "ok() without a name\n" if @ARG != 2;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

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
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval qq|#line 1 "src/$name"\nsub { ${\(join '', @seg)} }|;
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
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ), $name );
}

my ( @logged, @timers, @pending, @sent, %replies );
our $zenka = 'coding';
my ( %answer, %down, %quiet );
$code{'base.log'}  = sub { push @logged, join ' ', @ARG; TRUE };
$code{'base.logs'} = sub { push @logged, join ' ', @ARG; TRUE };
$code{'base.time'} = sub {time};
my $remind_ntime = 'AAAAAAA';
$code{'base.ntime.b32'} = sub { $remind_ntime++ };
$code{'base.callback.cmd_reply'}
    = sub { $replies{ $ARG[0] } = $ARG[1]; TRUE };
$code{'protocol-7.route-send'} = sub {
    my $c = shift;
    push @pending, { %{$c}, 'from' => $zenka };
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent, "$c->{'command'} $c->{'call_args'}{'args'}";
    return TRUE;
};

{

    package FakeTimer;
    sub new       { bless { 'active' => 1, 'args' => $_[1] }, $_[0] }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }
    sub now       { }
}
$code{'event.add_timer'} = sub {
    my $args = shift;
    push @timers, $args;
    return FakeTimer->new($args);
};

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
}

my $src = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $src or die "cannot open src : $OS_ERROR";
my @src = readdir $dh;
closedir $dh;
load_module($ARG) for grep {
    m{\A(?:park\.(?:parse_args|send)\z|events\.(?:plugin|source|fire|handler\.event_triggered|calc_unix|set_up_timers|action\.|access\.|signal\.|cmd\.signal\z|bucket\.|cmd\.bucket-)|plugin\.events\.(?:action|source)\.|base\.interval\.next\z|base\.interval\.rhythm\.|base\.reply\.mode_text\z|coding\.remind\.(?:add|lines|store)\z|coding\.handler\.remind_reply\z|coding\.cmd\.remind(?:ers)?\z)}
} @src;
load_module($ARG) for qw| base.n2u_time base.u2n_time base.round_truncate |;

my $tmp
    = tempdir( 'coding-remind-unless-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
$code{'file.zenka_dir.load'}  = sub {undef};
$code{'file.zenka_dir.write'} = sub {TRUE};

sub run_cmd {
    my ( $as, $name, $args, $reply_id ) = @ARG;
    local $zenka = $as;
    local $call  = { 'args' => $args, 'reply_id' => $reply_id };
    my $rv = eval { $code{$name}->() };
    return { 'mode' => 'false', 'data' => "died : $EVAL_ERROR" }
        if $EVAL_ERROR;
    return $rv;
}

sub pump {
    my $guard = 0;
    while ( my $c = shift @pending ) {
        die "pump loops\n" if ++$guard > 500;
        my ( $target, $sub ) = $c->{'command'} =~ m{\A([\w-]+)\.(.+)\z};
        next if $quiet{$target};
        my $rv;
        if ( $down{$target} ) {
            $rv = { 'mode' => 'false', 'data' => 'client not present' };
        } elsif ( $target eq 'events' ) {
            $rv = run_cmd( 'events', "events.cmd.$sub",
                "$c->{'from'} " . ( $c->{'call_args'}{'args'} // '' ) );
        } elsif ( exists $answer{$target} ) {
            $rv
                = ref $answer{$target} eq qw| CODE |
                ? $answer{$target}->( $c->{'call_args'}{'args'} )
                : $answer{$target};
        } else {
            die "no fake for $c->{'command'}\n";
        }
        next if ref $c->{'reply'} ne 'HASH';
        my $mode  = uc( $rv->{'mode'} // '' );
        my $reply = { 'params' => $c->{'reply'}{'params'} };
        if ( $mode eq 'SIZE' ) {
            $reply->{'data'} = \( $rv->{'data'} );
            $reply->{'cmd'}  = 'SIZE';
        } else {
            $reply->{'cmd'} = $mode;
            $reply->{'call_args'}
                = { 'args' => ( $rv->{'data'} // '' ) =~ s{\n}{\\n}gr };
        }
        local $zenka = $c->{'from'};
        $code{ $c->{'reply'}{'handler'} }->($reply);
    }
}

sub reset_all {
    system 'rm', '-rf', "$tmp/var";
    %data = (
        'events' => {
            'bucket_dir' => "$tmp/var",
            'signal'     => {
                'access_file' => "$root_path/cfg/zenki/cube/access.zenki",
                'grants_file' => "$root_path/cfg/zenki/events/access.signals",
                'journal_path' => "$tmp/var/signal.journal"
            },
            'setup'   => {},
            'enabled' => {}
        },
        'base' => {
            'interval' => {
                'cfg' => {
                    'type' => {
                        'budget-gate-answer' => {
                            'start'      => 89,
                            'factor'     => 1,
                            'cap'        => 89,
                            'cap_jitter' => 0
                        }
                    }
                }
            }
        }
    );
    @logged         = @timers = @pending = @sent  = ();
    %replies        = %answer = %down    = %quiet = ();
    $answer{'task'} = sub {
        return {
            'mode' => 'size',
            'data' => "id          : $_[0]\nstatus      : claimed\n"
        };
    };
    $answer{'coding'} = sub {
        return { 'mode' => 'true', 'data' => "entry.s1.status = queued\n" };
    };
    $answer{'usage'} = sub {
        return { 'mode' => 'size', 'data' => "kimi 7d 50.0 90000\n" };
    };
}

sub entry { $data{'events'}{'buckets'}{'coding'}{'entries'}{ $_[0] } }

sub set_reminder {
    my $unless = shift;
    my $at     = time + 3600;
    my $rv     = run_cmd( 'coding', 'coding.cmd.remind',
        "at=$at to=panel unless=$unless check this", 7 );
    pump();
    my ($id)
        = grep {m{\Aremind-}}
        @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
    return ( $id, $rv );
}

sub fire_reminder {
    my $id = shift;
    local $zenka = 'events';
    $code{'events.handler.event_triggered'}->(
        FakeEvent->new(
            { 'type' => 'at', 'id' => "coding/$id", 'at' => time }
        )
    );
    pump();
}

sub journal {
    return -f "$tmp/var/bucket.journal"
        ? read_file("$tmp/var/bucket.journal")
        : '';
}

reset_all();
my ( $rid, $rv ) = set_reminder('budget:kimi:7d>=100');
ok( defined $rid && entry($rid)->{'unless'} eq 'budget:kimi:7d>=100',
    'remind : unless is parsed and persisted in the bucket entry'
);
my $shown = run_cmd( 'events', 'events.cmd.bucket-show', 'coding' )->{'data'};
ok( $shown =~ m{unless budget:kimi:7d>=100},
    'bucket-show : the waiting reminder shows its condition' );
run_cmd( 'coding', 'coding.cmd.reminders', '', 9 );
pump();
ok( scalar( $replies{9}{'data'} // '' ) =~ m{unless budget:kimi:7d>=100},
    'coding.reminders : the condition is shown too' );
$answer{'usage'} = sub {
    return { 'mode' => 'size', 'data' => "kimi 7d 100.0 90000\n" };
};
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'skipped'
        && !@sent
        && entry($rid)->{'result'} =~ m{budget:kimi:7d>=100 holds}
        && scalar journal() =~ m{state:skipped},
    'budget holding : skipped, no delivery, reason journaled'
);

reset_all();
($rid) = set_reminder('task:abc1234=done');
$answer{'task'} = sub {
    return { 'mode' => 'size', 'data' => "status      : done\n" };
};
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'skipped' && !@sent,
    'task holding : the reminder is skipped'
);

reset_all();
($rid) = set_reminder('sign-queue:empty');
$answer{'coding'} = sub {
    return { 'mode' => 'true', 'data' => "sign queue empty\n" };
};
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'skipped' && !@sent,
    'empty sign queue : the reminder is skipped'
);

reset_all();
local $zenka = 'claude';
$code{'events.signal.raise'}
    ->( 'claude', 'deploy.finished', { 'id' => 'old' } );
($rid) = set_reminder('seen:deploy.finished:id=new');
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'fired'
        && @sent == 1
        && entry($rid)->{'result'} !~ m{unreadable},
    'seen : an old or nonmatching signal does not hold'
);

reset_all();
($rid) = set_reminder('seen:deploy.finished:id=new');
local $zenka = 'claude';
$code{'events.signal.raise'}
    ->( 'claude', 'deploy.finished', { 'id' => 'new' } );
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'skipped' && !@sent,
    'seen holding : a matching signal since set skips delivery' );

reset_all();
($rid) = set_reminder('task:abc1234=done');
$down{'task'} = 1;
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'fired'
        && @sent == 1
        && entry($rid)->{'result'} =~ m{unreadable \[ client not present \]}
        && scalar journal() =~ m{state:fired},
    'unreadable source : fires and journals the note'
);

reset_all();
($rid) = set_reminder('budget:kimi:7d>=100,sign-queue:empty');
$answer{'coding'} = sub {
    return { 'mode' => 'true', 'data' => "sign queue empty\n" };
};
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'skipped'
        && entry($rid)->{'result'} =~ m{sign-queue:empty holds}
        && !@sent,
    'several conditions : any holding condition skips the reminder'
);

reset_all();
($rid) = set_reminder('task:abc1234=done,sign-queue:empty');
fire_reminder($rid);
ok( entry($rid)->{'state'} eq 'fired'
        && @sent == 1
        && entry($rid)->{'result'} !~ m{unreadable},
    'none holding : the reminder fires normally'
);

reset_all();
($rid) = set_reminder('task:abc1234=done');
$quiet{'task'} = 1;
fire_reminder($rid);
my ($guard)
    = grep { $ARG->{'handler'} eq 'events.bucket.unless.handler.guard' }
    @timers;
ok( defined $guard && entry($rid)->{'state'} eq 'waiting',
    'no answer : a guard waits for the source'
);
local $zenka = 'events';
$code{'events.bucket.unless.handler.guard'}
    ->( FakeEvent->new( $guard->{'data'} ) );
pump();
ok( entry($rid)->{'state'} eq 'fired'
        && entry($rid)->{'result'} =~ m{no answer from task},
    'no answer : the guard fires with an unreadable note'
);

reset_all();
my $future = time + 3600;
$rv = run_cmd( 'coding', 'coding.cmd.remind',
    "at=$future to=panel unless=bogus bad condition", 8 );
pump();
ok( ( $replies{8}{'mode'} // '' ) eq 'false'
        && scalar( ( $replies{8}{'data'} // '' ) =~ m{(?:unless|budget) :} ),
    'a malformed condition is refused when the reminder is added'
);

say "1..", $pass + $fail;
say "# pass $pass fail $fail";
exit( $fail ? 1 : 0 );

#,,..,,,.,.,.,...,..,,.,,,.,.,.,,,,..,,..,...,..,,...,..,,...,,..,,..,,,,,..,,
#DTJZSSLIR3FLPPCVGFLD3YIDCUFLBNNF5QUC3TQ7IP7D55B6T6P4753OKTRGQRUPJP3XYBC5XXU56
#\\\|MBT2K2YYLOXUIFQAGOCMNDORODYK6NY342NMMZAGBQIWJMM3LT5 \ / AMOS7 \ YOURUM ::
#\[7]QQHBVMIBXEA2AP7AWE23WVWHWRX7N4IOMCLUNGWNUHWEX43RIMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
