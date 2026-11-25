#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## context size reminder : the real src/claude.context.* and claude.live.* ##
## modules on a fixture transcript [ fixtures/claude-context.jsonl ] and a ##
## FAKE inbox socket. never the real session socket or ~/.claude           ##

use File::Spec;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use IO::Socket::UNIX;
use IO::Select;
use Socket qw| SOCK_STREAM |;

my $root;

BEGIN {
    $root
        = abs_path(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
        );
    unshift @INC, "$root/data/lib-path/pm";
}

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;

my ( $pass, $fail ) = ( 0, 0 );

sub ok ($$) {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

sub slurp {
    my $path = shift;
    open my $fh, '<:raw', $path or die "$path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh> // '';
    close $fh;
    return $text;
}

sub spew {
    my ( $path, $text, $mode ) = @ARG;
    open my $fh, ( $mode // '>' ) . ':raw', $path or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh;
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

sub load_module {
    my $name = shift;
    my $src  = slurp("$root/src/$name");
    utf8::decode($src);
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $tmp = tempdir( 'claude-context-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my ( $var, $config, $work ) = map {"$tmp/$ARG"} qw| var config work |;
make_path( $var, $work, "$tmp/root/data/ai-mem/claude" );

my @timers;
$code{'base.log'}                 = $code{'base.logs'} = sub {TRUE};
$code{'base.perlmod.loaded'}      = sub {0};
$code{'base.perlmod.load'}        = sub { eval "require $_[0]; 1" or die };
$code{'file.zenka_dir.data_path'} = sub {$var};
$code{'base.interval.next'}       = sub {187};
$code{'event.add_timer'}
    = sub { push @timers, $_[0]; return 'timer' };
load_module($ARG) foreach qw|
    claude.var_dir claude.session.project_dir
    claude.wire.encode claude.live.sessions claude.live.wire claude.live.post
    claude.context.usage claude.context.store claude.context.check
    claude.context.arm claude.context.tick
    |;
require Cwd;

$data{'claude'}{'cfg'} = {
    'work_dir'      => $work,
    'config_dir'    => $config,
    'handover_root' => "$tmp/root"
};
my $at = $code{'claude.session.project_dir'}->();
make_path( $at->{'dir'}, "$config/projects/-elsewhere" );

my $sid  = '11111111-2222-3333-4444-555555555555';
my $log  = "$at->{'dir'}/$sid.jsonl";
my $base = slurp("$RealBin/fixtures/claude-context.jsonl");

sub turn {    ## one assistant line with this context size ##
    my $tokens = shift;
    return
          '{"type":"assistant","isSidechain":false,"message":{"model":"m",'
        . '"usage":{"input_tokens":2,"cache_read_input_tokens":'
        . ( $tokens - 1002 )
        . ',"cache_creation_input_tokens":1000,"output_tokens":9}}}' . "\n";
}
my $usage = sub { $code{'claude.context.usage'}->( $_[0] // $sid ) };

##[ the transcript tail ]##

ok( !defined $usage->(), 'no transcript : undef' );
spew( $log, $base );
ok( $usage->() == 720000,
    'last real turn : sidechain, synthetic, user and cut lines skipped' );
ok( !defined $usage->('../../etc/passwd'), 'only a uuid names a transcript' );

$data{'claude'}{'cfg'}{'context_tail'} = 1024;
spew( $log, $base . '{"type":"user","text":"' . ( 'x' x 300000 ) . "\"}\n" );
ok( $usage->() == 720000, 'a line far longer than the tail : span grows' );
$data{'claude'}{'cfg'}{'context_tail_max'} = 4096;
ok( !defined $usage->(), 'the span stops at its limit' );
delete @{ $data{'claude'}{'cfg'} }{qw| context_tail context_tail_max |};

my $other = '99999999-2222-3333-4444-555555555555';
spew( "$config/projects/-elsewhere/$other.jsonl", turn(5000) );
ok( $usage->($other) == 5000, 'another work dir : found by its sid' );

##[ offers ]##

my $path  = "$tmp/inbox.sock";
my $inbox = IO::Socket::UNIX->new(
    'Type'   => SOCK_STREAM,
    'Local'  => $path,
    'Listen' => 5
) // die "fake inbox : $OS_ERROR";

sub posts {    ## every message waiting at the fake inbox ##
    my @got;
    while ( IO::Select->new($inbox)->can_read(0.2) ) {
        my $conn = $inbox->accept // last;
        my $text = '';
        while ( IO::Select->new($conn)->can_read(1) ) {
            last if not sysread( $conn, my $chunk, 65536 );
            $text .= $chunk;
        }
        push @got, $text;
    }
    return @got;
}

ok( !$code{'claude.context.arm'}->(), 'no session : no timer' );
$code{'claude.live.sessions'}->()->{'main'}
    = { 'socket' => $path, 'token' => 'T', 'sid' => $sid };
ok( !$code{'claude.context.arm'}->() && !@timers,
    'interval cfg not loaded : no timer'
);
$data{'base'}{'interval'}{'cfg'}{'type'}{'claude-context'}{'minutes'} = 3;
ok( $code{'claude.context.arm'}->()
        && $code{'claude.context.arm'}->()
        && @timers == 1
        && $timers[0]{'after'} == 187,
    'one timer, its delay from base.interval.next'
);

my $check = sub { $code{'claude.context.check'}->() };
my $set   = sub { spew( $log, $base . turn(shift) ) };

$set->(699999);
ok( $check->() == 0 && !posts(), 'below 70 % : nothing' );

spew( $log, $base );
my $handover = "$tmp/root/data/ai-mem/claude/handover-live.md";
spew( $handover, "x\n" );
ok( $check->() == 0 && !posts(), 'a fresh handover : skipped' );
my $old = time - 14 * 60;
utime $old, $old, $handover;
my $count = $check->();
my @got   = posts();
ok( $count == 1 && @got == 1 && index( $got[0],
              'context at 72 % [ 720000 of 1000000 ] : a good '
            . 'moment for a handover or a targeted compaction' ) >= 0,
    'the skipped offer comes after the quiet time'
);
ok( $check->() == 0 && !posts(), 'once per threshold' );

$set->(860000);
ok( $check->() == 1 && ( posts() )[0] =~ m{context at 86 %}, '85 % : again' );
$set->(100000);
$check->();
$set->(900000);
ok( $check->() == 0 && !posts(), 'after a compaction : not armed again' );

delete $data{'claude'}{'context'}{'offered'};    ## as after a restart ##
ok( -f "$var/context.cfg" && $check->() == 0 && !posts(),
    'the offers survive a restart [ context.cfg ]'
);

delete $data{'claude'}{'context'}{'offered'};
unlink "$var/context.cfg";
ok( $check->() == 1 && posts() == 1 && $check->() == 0,
    'both thresholds passed at once : one offer'
);

delete $data{'claude'}{'context'}{'offered'};
unlink "$var/context.cfg";
@{ $data{'claude'}{'cfg'} }{qw| context_window context_thresholds |}
    = ( 200000, '40' );
$set->(90000);
ok( $check->() == 1 && ( posts() )[0] =~ m{45 % \[ 90000 of 200000 \]},
    'window and thresholds from cfg' );

##[ timer round ]##

@timers = ();
delete $data{'claude'}{'context'}{'timer'};
$code{'claude.context.tick'}->();
ok( @timers == 1, 'a tick arms the next round' );
{
    local $code{'claude.context.check'} = sub { die "boom\n" };
    delete $data{'claude'}{'context'}{'timer'};
    $code{'claude.context.tick'}->();
}
ok( @timers == 2, 'a failed check keeps the timer' );
%{ $code{'claude.live.sessions'}->() } = ();
delete $data{'claude'}{'context'}{'timer'};
$code{'claude.context.tick'}->();
ok( @timers == 2, 'the last session gone : no further timer' );

say sprintf '%d passed, %d failed', $pass, $fail;
exit( $fail ? 1 : 0 );

#,,..,...,.,.,,..,.,,,.,,,,.,,,.,,,,.,,,,,.,.,..,,...,...,...,.,.,.,,,.,,,,.,,
#OPLLYMR7AW4KGJDWDJGD27YKFMMXEVQ4UXVHA3QFPMQRM5K75VANAIKBSLOO4ZJN4RYWHKCVLTKDM
#\\\|A5OQIEE62K6JTDTCZT6HMQDNIAS4AQDL4SWM6AEXDX2QGQW4WG4 \ / AMOS7 \ YOURUM ::
#\[7]QP4KDSKWDCP3ZPQRMVM7X3DJGO2WEOATDDKY6B5IGN2Y2NFAMYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
