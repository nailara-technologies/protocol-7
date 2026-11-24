#!/usr/bin/env perl
use v5.32;
use strict;
use English;

## the stream_child helper : the real src/stream_child.* modules drive a  ##
## FAKE child [ fixtures/fake-stream-child.pl ] : partial lines, a big    ##
## write that blocks, stderr, eof, a crash, stop steps TERM -> KILL, the  ##
## process group and its grandchild, end_code, env and cwd. no zenka : io ##
## watchers are pumped by IO::Select, timers are recorded and fired       ##

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

## stubs : log, sender, timers, io watchers ##

my @sent;      ## "command | args" ##
my @timers;    ## armed timers ##

$code{'base.log'}                      = sub {TRUE};
$code{'base.logs'}                     = sub {TRUE};
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent, join ' | ', $c->{'command'}, $c->{'call_args'}{'args'} // '-';
    return TRUE;
};

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
$code{'event.add_io'}    = sub { FakeIO->new(shift) };
$code{'event.add_timer'} = sub {
    my $t = bless { %{ +shift }, 'active' => 1 }, 'FakeIO::Timer';
    push @timers, $t;
    return $t;
};
{

    package FakeIO::Timer;
    sub w      { $_[0] }
    sub data   { $_[0]{'data'} }
    sub cancel { $_[0]{'active'} = 0 }
}

## one select round over the active watchers, until $until is true ##
sub pump {
    my ( $until, $max ) = @ARG;
    my $end = time + ( $max // 8 );
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

## fire the armed timers [ active ones, or every one with $all ] ##
sub fire {
    my $all = shift;
    my @due = grep { $all or $_->{'active'} } @timers;
    @timers = ();
    foreach my $t (@due) {
        $t->{'active'} = 0;
        $code{ $t->{'handler'} }->($t);
    }
    return scalar @due;
}

sub alive { my $pid = shift; defined $pid and kill( 0, $pid ) }

## the real modules ##
opendir my $dh, "$root_path/src" or die;
my @mods = grep {m{\A(?:stream_child\.|base\.interval\.)}} readdir $dh;
closedir $dh;
load_module($ARG) foreach @mods;
ok( scalar( grep {m{\Astream_child\.}} @mods ) >= 15,
    'modules : the stream_child set loads'
);

my $bad_header = grep {
    my $f = $ARG;
    grep { m{^#\s*(?:descr|param)\s*=\s*(.+)$} and length($1) > 55 }
        split m{\n},
        read_file("$root_path/src/$f")
} grep {m{\Astream_child\.}} @mods;
ok( !$bad_header, 'modules : descr and param at most 55 characters' );

for my $type (qw| sc-stop sc-reap sc-exit |) {
    $data{'base'}{'interval'}{'cfg'}{'type'}{$type} = {
        'start'      => 0.2,
        'factor'     => 1.2,
        'cap'        => 0.5,
        'cap_jitter' => 0.1
    };
}

## the owner side : recorded ##
my ( @lines, @errs, @gone, @notes );
$code{'t.line'} = sub { push @lines, [ shift, shift ] };
$code{'t.err'}  = sub { push @errs,  shift };
$code{'t.gone'} = sub { push @gone,  [ shift, shift ] };
$code{'t.note'} = sub {
    my ( $kind, $info ) = @ARG;
    push @notes, join ' ', $kind, map {"$ARG=$info->{$ARG}"} sort keys %$info;
};

my $fake = "$root_path/bin/test-scripts/fixtures/fake-stream-child.pl";

sub start {
    my %over = @ARG;
    @lines = @errs = @gone = @notes = ();
    my $r = $code{'stream_child.start'}->(
        {   'cmd' => [ $EXECUTABLE_NAME, $fake, @{ $over{'args'} // [] } ],
            'on_line'   => 't.line',
            'on_stderr' => 't.err',
            'on_gone'   => 't.gone',
            'on_note'   => 't.note',
            'interval'  => {
                'stop' => 'sc-stop',
                'reap' => 'sc-reap',
                'exit' => 'sc-exit'
            },
            %over,
        }
    );
    die "start : $r->{'error'}" if not $r->{'ok'};
    pump(
        sub {
            grep { $_->[0] eq 'ready' } @lines;
        }
    );
    return $r->{'handle'};
}

sub saw {
    my $want = shift;
    grep { $_->[0] eq $want } @lines;
}

sub reap {
    my $h = shift;
    fire(TRUE) while not defined $h->{'exit'} and @timers;
}

## argument checks ##

ok( $code{'stream_child.start'}->( { 'cmd' => [] } )->{'error'} eq
        'no command',
    'start : no command refused'
);
ok(
    (   $code{'stream_child.start'}
            ->( { 'cmd' => ['x'], 'stop' => 'close | ter' } )->{'error'} // ''
    ) =~ m{stop step},
    'start : a bad stop step refused'
);

## lines, partial lines, stderr ##

my $h = start( 'env' => { 'SC_TEST' => 'v7' }, 'cwd' => '/tmp' );
ok( alive( $h->{'pid'} ), 'start : the fake child runs' );
ok( $code{'stream_child.status'}->($h)->{'state'} eq 'running',
    'status : running' );
ok( grep( { $_->{'pid'} == $h->{'pid'} }
        @{ $code{'stream_child.status'}->() } ),
    'status : listed among the running children'
);
$code{'stream_child.write'}->( $h, "hello\n" );
ok( pump( sub { saw('got 5') } ), 'write : a line answered' );
ok( $lines[-1][1] == $h,          'on_line : gets the handle' );
$code{'stream_child.write'}->( $h, "part\n" );
ok( pump( sub { saw('partial') } ), 'partial : two reads, one line' );
ok( !saw('par'),                    'partial : no half line delivered' );
$code{'stream_child.write'}->( $h, "err oops \xe2\x86\x92\n" );
ok( pump( sub {@errs} ) && $errs[0] eq "oops \xe2\x86\x92",
    'stderr : one line, octets as sent' );
$code{'stream_child.write'}->( $h, "env SC_TEST\ncwd\n" );
ok( pump( sub { saw('env v7') } ),   'env : added to the child environment' );
ok( pump( sub { saw('cwd /tmp') } ), 'cwd : the child runs in it' );
ok( Cwd::getcwd() ne '/tmp',         'cwd : the zenka directory is back' );

## eof : the last partial line, gone, exit status ##

$code{'stream_child.write'}->( $h, "nonl\n" );
ok( pump( sub {@gone} ),          'eof : gone' );
ok( saw('no newline at the end'), 'eof : the partial last line delivered' );
ok( $gone[0][0] eq 'eof' && $gone[0][1] == $h,
    'eof : on_gone ( eof, handle )' );
reap($h);
ok( ( $h->{'exit'} // '' ) eq '0',               'eof : exit 0 collected' );
ok( !grep( { $_->is_active } FakeIO::active() ), 'eof : no watcher left' );
ok( !$code{'stream_child.write'}->( $h, "x\n" ),
    'write : refused once gone' );
ok( !$code{'stream_child.stop'}->($h), 'stop : FALSE once gone' );
ok( !@sent, 'report : nothing sent without report' );

## crash ##

$h = start( 'report' => TRUE );
$code{'stream_child.write'}->( $h, "crash 3\n" );
ok( pump( sub {@gone} ), 'crash : gone' );
ok( !$h->{'stopping'},   'crash : not a stop' );
reap($h);
ok( ( $h->{'exit'} // '' ) eq '3', 'crash : exit 3 collected' );
ok( grep( { $_ eq "exit exit=3 signal=0" } @notes ), 'crash : an exit note' );
ok( grep( {m{\Acube\.v7-zenki\.gone_child \| $h->{'pid'}\z}} @sent ),
    'report : v7-zenki told the pid is gone' );

## a big write that blocks : pend_in and the write watcher ##

$h = start( 'args' => [ 'slow', 1 ] );
my $big = ( 'x' x 300_000 ) . "\n";
$code{'stream_child.write'}->( $h, $big );
ok( length $h->{'pend_in'} > 0 && defined $h->{'w_in'},
    'big write : the rest queued, a write watcher armed'
);
ok( pump( sub { saw('got 300000') } ), 'big write : every byte arrived' );
ok( !length $h->{'pend_in'} && !defined $h->{'w_in'},
    'big write : queue empty, watcher gone'
);

## stop : end of input is enough ##

@timers = ();
ok( $code{'stream_child.stop'}->($h), 'stop : asked' );
ok( $code{'stream_child.stop'}->($h), 'stop : a second ask is TRUE too' );
ok( @timers == 1,        'stop : one step timer from base.interval.next' );
ok( !defined $h->{'in'}, 'stop : stdin closed [ close step ]' );
ok( pump( sub {@gone} ), 'stop : gone on end of input' );
ok( $h->{'stopping'},    'stop : marked stopping' );
fire(TRUE);
ok( !grep( {m{\Asignal}} @notes ), 'stop : the old step timer is a no-op' );

## escalation : close | TERM | KILL | gone on a deaf child ##

$h = start( 'stop' => 'close | TERM | KILL | gone' );
$code{'stream_child.write'}->( $h, "deaf\n" );
pump( sub { saw('deaf') } );
$code{'stream_child.stop'}->($h);
my $deadline = time + 8;
while ( !@gone and time < $deadline ) {
    pump( sub {@gone}, 0.3 );
    fire() if !@gone;
}
reap($h);
ok( @gone && !alive( $h->{q|pid|} ), q|escalation : the deaf child ended| );
ok( grep( { $_ eq 'signal signal=TERM' } @notes )
        && grep( { $_ eq 'signal signal=KILL' } @notes ),
    'escalation : TERM, then KILL'
);
reap($h);
ok( ( $h->{'signal'} // 0 ) == 9, 'escalation : ended by KILL' );

## the process group : a grandchild that ignores TERM ##

$h = start( 'group' => TRUE, 'stop' => 'close TERM | KILL' );
$code{'stream_child.write'}->( $h, "grand deaf\n" );
pump(
    sub {
        grep { $_->[0] =~ m{\Agrand \d+} } @lines;
    }
);
my ($grand) = map { $_->[0] =~ m{\Agrand (\d+)} } @lines;
ok( alive($grand), 'group : a grandchild runs' );
ok( getpgrp( $h->{q|pid|} ) == $h->{q|pid|},
    'group : the child leads its own group'
);
@timers = ();
$code{'stream_child.stop'}->($h);
ok( grep( { $_ eq 'signal signal=TERM' } @notes ), 'group : TERM at once' );
ok( pump( sub {@gone} ),                           'group : the child gone' );
ok( alive($grand), 'group : the grandchild ignored TERM' );
ok( @timers >= 1,  'group : a KILL step armed after gone' );
fire(TRUE);
select( undef, undef, undef, 0.3 );
ok( !alive($grand), 'group : KILL took the grandchild' );

## end_code : synchronous, owner only, no orphan ##

$h = start( 'group' => TRUE, 'stop' => 'close TERM | KILL' );
$code{'stream_child.write'}->( $h, "grand deaf\n" );
pump(
    sub {
        grep { $_->[0] =~ m{\Agrand \d+} } @lines;
    }
);
($grand) = map { $_->[0] =~ m{\Agrand (\d+)} } @lines;
my $forked = fork();
if ( !$forked ) {
    $code{'stream_child.end_code'}->($h);
    POSIX::_exit(0);
}
waitpid( $forked, 0 );
ok( alive( $h->{'pid'} ), 'end_code : a forked copy leaves the child alone' );
$code{'stream_child.end_code'}->($h);
ok( !alive( $h->{'pid'} ), 'end_code : the child is gone' );
select( undef, undef, undef, 0.3 );
ok( !alive($grand), 'end_code : the grandchild too [ KILL ]' );
$code{'stream_child.end_code'}->($h);
ok( TRUE, 'end_code : a second call is harmless' );

$h = start( 'stop' => 'close | TERM | KILL | gone' );
$code{'stream_child.write'}->( $h, "deaf\n" );
pump( sub { saw('deaf') } );
$code{'stream_child.end_code'}->($h);
ok( !alive( $h->{'pid'} ), 'end_code : a deaf child ends by the KILL step' );

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,..,,,.,.,,,...,..,,.,,,.,,,...,,,,,..,,.,.,..,,...,...,.,,,,.,,,..,,,,,,..,
#JQKRVJQZL3EV46SA3SHZMN6MMMES75SHZC7B6LLJOGJFRIIJBBSYDSVEHQCYS5GX2P6RIANR36E5W
#\\\|STPQUSWOC4EFJ53M4SVUXAGPQC7J2GD7IW4563IPD3PK3S3QNOJ \ / AMOS7 \ YOURUM ::
#\[7]OPHSNNGQ5EKXV6OYTNNVHWGEWEKXZHSYP2MM56EQ3E2LFSZPBSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
