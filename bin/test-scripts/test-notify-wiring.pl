#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## notifications stage 1 : the notify action plugin, the signal -> notify ##
## map [ cfg/zenki/events/notify.map ] applied per signal and state, the  ##
## ticker status lines, do-not-disturb off \ on \ timed, warning-sound    ##
## profiles to mpv options. compiles the real src modules ; the command   ##
## sender, popups, ticker drawing and the sound are fakes recording what  ##
## they get. no zenka, no popup, no sound                                 ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use POSIX      qw| mktime |;

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
use AMOS7::Config;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

my $root_path = $main::root_path;

our %data;
our %code;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

## module loading : the <..> translation of the zenka loader ##

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
    my ( $src, $is_cmd ) = @ARG;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    ## a command gets its call as the first argument [ bin/Protocol-7 ] ##
    my $head
        = $is_cmd
        ? 'my $call = ref $ARG[0] eq q|HASH| ? $ARG[0] : { args => $ARG[0] };'
        : '';
    my $sub = eval "sub { $head $translated }";
    die "compile error : $EVAL_ERROR" if $EVAL_ERROR;
    return $sub;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<:encoding(UTF-8)', $path or die "cannot read $path";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    $code{$name} = compile_source( $src, $name =~ m{\.cmd\.} );
}

load_module($ARG) for qw|
    events.notify.map events.notify.apply events.notify.send
    events.notify.ticker events.signal.raise events.bucket.action_route
    plugin.events.action.notify
    notify.cmd.cue notify.cmd.dnd notify.dnd.active notify.dnd.parse_span
    ticker.cmd.status-set ticker.cmd.status-clear ticker.status.compose
    ticker.status.apply |;

## fakes ##

my ( @sent, @logged, @popups, @sounds, @parsed, $dismissed );
$code{'base.log'}  = sub { push @logged, join ' ', @ARG; TRUE };
$code{'base.logs'} = sub {
    my ( $l, $f, @a ) = @ARG;
    push @logged, sprintf $f, @a;
    TRUE;
};
$code{'base.time'}                     = sub {time};
$code{'base.perlmod.load'}             = sub {TRUE};
$code{'base.perlmod.loaded'}           = sub {TRUE};
$code{'events.signal.journal_write'}   = sub {TRUE};
$code{'events.plugin.registry'}        = sub { { 'source' => {} } };
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent, "$c->{'command'} | " . ( $c->{'call_args'}{'args'} // '' );
    TRUE;
};
$code{"notify.cmd.$ARG"} = do {
    my $lv = $ARG;
    sub { push @popups, "$lv | $ARG[0]{'args'}"; { 'mode' => 'true' } }
    }
    for qw| info warn loves |;
$code{'notify.sound.play'}      = sub { push @sounds, shift; TRUE };
$code{'ticker.parse_text'}      = sub { push @parsed, shift; TRUE };
$code{'ticker.start_animation'} = sub {TRUE};
$code{'ticker.emit_event'}      = sub {TRUE};
$code{'ticker.dismiss_now'}     = sub { $dismissed++; TRUE };

my $tmp = tempdir( CLEANUP => 1 );
$data{'system'}{'conf_path'} = "$root_path/cfg";
sub reset_all { @sent = @logged = @popups = @sounds = @parsed = () }

## the real map : defaults the spec names ##

my $noon  = mktime( 0, 0,  12, 24, 10, 126 );
my $night = mktime( 0, 30, 2,  24, 10, 126 );
my $apply = $code{'events.notify.apply'};

my $r = $apply->( 'claude', 'claude.run.done', { 'state' => 'ok' }, $noon );
ok( $r->{'level'} eq 'info' && $r->{'sound'} eq 'soft',
    'map : claude.run.done ok is quiet [ info, soft ]'
);
$r = $apply->(
    'claude',                                         'claude.run.done',
    { 'state' => 'failed', 'reason' => 'max_turns' }, $noon
);
ok( $r->{'level'} eq 'warn'
        && $r->{'sound'} eq 'aware'
        && $r->{'text'} eq 'claude run failed max_turns',
    'map : claude.run.done failed is loud, reason filled in'
);
$r = $apply->( 'kimi', 'kimi.run.done', { 'state' => 'crashed' }, $noon );
ok( $r->{'level'} eq 'warn', 'map : kimi.run.done crashed is loud' );
$r = $apply->( 'kimi', 'kimi.run.done', { 'state' => 'end_turn' }, $noon );
ok( $r->{'level'} eq 'info' && $r->{'text'} eq 'kimi run end_turn',
    'map : kimi.run.done other state falls back to the quiet entry'
);
ok( $r->{'ticker'} eq 'clear' && $r->{'key'} eq 'kimi.run',
    'map : run.done clears the run ticker line'
);

reset_all();
my %u = ( 'provider' => 'claude', 'window' => '5h', 'used' => '91.0' );
$r = $apply->(
    'usage',                                    'usage.threshold',
    { %u, 'percent' => 90, 'crossed' => 'up' }, $noon
);
ok( $r->{'level'} eq 'warn' && $r->{'text'} eq 'claude 5h at 91.0 %',
    'map : usage.threshold 90 up warns' );
$r = $apply->(
    'usage',                                    'usage.threshold',
    { %u, 'percent' => 75, 'crossed' => 'up' }, $noon
);
ok( $r->{'level'} eq 'info', 'map : usage.threshold 75 up informs' );
$r = $apply->(
    'usage',                                      'usage.threshold',
    { %u, 'percent' => 90, 'crossed' => 'down' }, $noon
);
ok( $r->{'level'} eq 'none', 'map : usage.threshold down : nothing' );
$r = $apply->(
    'usage',                                    'usage.window.reset',
    { 'provider' => 'kimi', 'window' => '7d' }, $noon
);
ok( $r->{'text'} eq 'kimi 7d window reset', 'map : usage.window.reset' );
ok( !defined $apply->( 'x', 'decision.answered', {}, $noon ),
    'map : a signal with no entry notifies nothing'
);
ok( 3 == grep( {m{\Acube\.notify\.cue \| }} @sent ),
    'send : three cues sent, none for level=none'
);
ok( grep( { $ARG eq 'cube.notify.cue | warn sound=aware claude 5h at 91.0 %' }
        @sent ),
    'send : the cue line carries level, sound and text'
);

## quiet hours ##
$r = $apply->( 'claude', 'claude.run.done', { 'state' => 'failed' }, $night );
ok( $r->{'sound'} eq 'soft', 'quiet hours : aware becomes soft at night' );

## a map of its own : quiet = none, ticker set on start, alarm reserved ##
open my $mfh, '>:encoding(UTF-8)', "$tmp/notify.map" or die;
print {$mfh} <<'MAP';
notify.on.kimi.run.start : level=none ticker=set key=kimi.{run} text=kimi \
                           run {run}
notify.on.x.alarm = level=warn sound=alarm text=wake
notify.quiet.hours = 22:30 - 06:00
notify.quiet.sound = none
MAP
close $mfh;
$data{'events'}{'notify'}{'map_file'} = "$tmp/notify.map";
reset_all();
$r = $apply->( 'kimi', 'kimi.run.start', { 'run' => 7 }, $noon );
ok( "@sent" eq 'cube.ticker.status-set | kimi.7 kimi run 7',
    'map : run.start sets a keyed ticker line, no popup [ : continues ]'
);
$r = $apply->( 'x', 'x.alarm', {}, $noon );
ok( $r->{'sound'} eq 'alert' && grep( {m{alarm loop}} @logged ),
    'map : sound=alarm is played as alert and logged [ later stage ]'
);
$r = $apply->( 'x', 'x.alarm', {}, $night );
ok( $r->{'sound'} eq 'none', 'quiet hours : quiet.sound none silences' );
## the plugin goes through the same send : quiet hours and alarm ##
open $mfh, '>:encoding(UTF-8)', "$tmp/all-day.map" or die;
print {$mfh} "notify.quiet.hours = 0-23:59\nnotify.quiet.sound = soft\n";
close $mfh;
$data{'events'}{'notify'}{'map_file'} = "$tmp/all-day.map";
reset_all();
$code{'plugin.events.action.notify'}->()->{'run'}->(
    { 'action' => { 'level' => 'warn', 'sound' => 'alert', 'text' => 'x' } }
);
ok( "@sent" eq 'cube.notify.cue | warn sound=soft x',
    'plugin : quiet hours apply to the action too'
);
$data{'events'}{'notify'}{'map_file'} = "$tmp/notify.map";
reset_all();
$code{'events.notify.send'}->(
    { 'level' => 'info', 'sound' => 'alarm', 'text' => 'y', 'time' => $noon }
);
ok( "@sent" eq 'cube.notify.cue | info sound=alert y',
    'send : sound=alarm goes out as alert'
);
$data{'events'}{'notify'}{'map_file'} = "$tmp/missing.map";
ok( !defined $apply->( 'claude', 'claude.run.done', {}, $noon ),
    'map : no file, no notification' );

## raise applies the map in one place ##
$data{'events'}{'notify'}{'map_file'}
    = "$root_path/cfg/zenk" . "i/events/notify.map";
reset_all();
$code{'events.signal.raise'}
    ->( 'kimi', 'kimi.run.done', { 'state' => 'error' } );
ok( grep( {m{\Acube\.notify\.cue \| warn }} @sent )
        && grep( { $ARG eq 'cube.ticker.status-clear | kimi.run' } @sent ),
    'raise : events.signal.raise applies the map'
);
{
    local $code{'events.notify.apply'} = sub { die "boom\n" };
    reset_all();
    $code{'events.signal.raise'}->( 'kimi', 'kimi.run.done', {} );
    ok( grep( {m{notification for signal 'kimi.run.done' failed : boom}}
            @logged ),
        'raise : a failing notification is logged, the raise goes on'
    );
}

## the action plugin ##
my $plugin = $code{'plugin.events.action.notify'}->();
ok( $plugin->{'name'} eq 'notify' && $plugin->{'kind'} eq 'action',
    'plugin : registers as action notify' );
reset_all();
$plugin->{'run'}->(
    {   'ev_type' => 'bucket',
        'action'  => { 'level' => 'loves', 'text' => "sign\n request" }
    }
);
ok( "@sent" eq 'cube.notify.cue | loves sound=none sign request',
    'plugin : any wake sends one cue' );
ok( !eval {
        $plugin->{'run'}
            ->( { 'action' => { 'level' => 'loud', 'text' => 'x' } } );
        1;
    },
    'plugin : an unknown level dies'
);
ok( !eval {
        $plugin->{'run'}->( { 'action' => { 'level' => 'info' } } );
        1;
    },
    'plugin : no text dies'
);
ok( $code{'events.bucket.action_route'}->( { 'type' => 'notify' } ) eq
        'notify.cue',
    'bucket : notify routes to notify.cue'
);

## notify.cue and do-not-disturb ##
my $cue = $code{'notify.cmd.cue'};
my $dnd = $code{'notify.cmd.dnd'};
reset_all();
$cue->( { 'args' => "warn sound=aware it's done" } );
ok( "@popups" eq q{warn | 'protocol-7' 'its done'} && "@sounds" eq 'aware',
    'cue : dnd off pops up and plays the profile' );
reset_all();
$cue->( { 'args' => 'info done' } );
ok( @popups == 1 && !@sounds, 'cue : sound=none plays nothing' );
ok( $cue->( { 'args' => 'loud x' } )->{'mode'} eq 'false',
    'cue : an unknown level is refused' );

reset_all();
ok( $dnd->( { 'args' => 'on' } )->{'data'} eq 'do not disturb : on',
    'dnd : on' );
$cue->( { 'args' => 'warn sound=alert run failed' } );
ok( !@popups
        && !@sounds
        && "@sent"
        =~ m{\Acube\.ticker\.status-set \| notify\.held\.\d+\.1 \[ warn \] run failed\z},
    'dnd on : no popup, no sound, the ticker keeps it'
);
ok( $dnd->( { 'args' => 'off' } )->{'data'} eq
        'do not disturb : off [ 1 held on the ticker ]',
    'dnd off : the held line stays [ nothing lost ]'
);
reset_all();
$cue->( { 'args' => 'info back' } );
ok( @popups == 1, 'dnd off : popups again' );
$dnd->( { 'args' => 'clear-held' } );
ok( "@sent" =~ m{\Acube\.ticker\.status-clear \| notify\.held\.\d+\.1\z},
    'dnd clear-held : the held ticker lines go' );

ok( $dnd->( { 'args' => 'on for=13m' } )->{'data'}
        =~ m{\Ado not disturb : on until },
    'dnd timed : on for 13m'
);
my $until = $data{'notify'}{'dnd'}{'state'}{'until'};
ok( $until - time >= 779 && $until - time <= 781,
    'dnd timed : until in 13 minutes' );
$data{'notify'}{'dnd'}{'state'}{'until'} = time - 1;
reset_all();
$cue->( { 'args' => 'info later' } );
ok( @popups == 1, 'dnd timed : ends when read after its time' );
ok( $dnd->( { 'args' => 'on for=soon' } )->{'mode'} eq 'false',
    'dnd : a bad span is refused' );
ok( $code{'notify.dnd.parse_span'}->('1h30m') == 5400, 'dnd : span 1h30m' );

## ticker status lines ##
my ( $set, $clear )
    = @code{qw| ticker.cmd.status-set ticker.cmd.status-clear |};
$data{'ticker'}{'status'}{'initialized'} = TRUE;
$data{'ticker'}{'content'}{'txt'}        = 'feed text';
reset_all();
$set->( { 'args' => 'claude.run claude running' } );
ok( $parsed[-1] eq 'claude running :: feed text',
    'ticker : a status line scrolls in front of the content'
);
$data{'ticker'}{'status'}{'lines'}{'claude.run'}{'time'} -= 5;
$set->( { 'args' => 'kimi.run kimi running' } );
ok( $parsed[-1] eq 'claude running :: kimi running :: feed text',
    'ticker : lines in the order set' );
$set->( { 'args' => 'kimi.run kimi running 3m' } );
ok( $parsed[-1] eq 'claude running :: kimi running 3m :: feed text',
    'ticker : the same key replaces its line' );
$clear->( { 'args' => 'claude.run' } );
ok( $parsed[-1] eq 'kimi running 3m :: feed text',
    'ticker : clear removes it' );
ok( $clear->( { 'args' => 'nope' } )->{'data'} eq q|no status line 'nope'|,
    'ticker : clearing an unknown key is harmless' );
delete $data{'ticker'}{'content'}{'txt'};
$dismissed = 0;
$clear->( { 'args' => 'kimi.run' } );
ok( $dismissed == 1, 'ticker : no lines and no content dismisses' );
$data{'ticker'}{'content'}{'txt'} = 'feed text';
$set->( { 'args' => 'a.run a' } );
$data{'ticker'}{'hidden'} = TRUE;
$dismissed = 0;
my $n = @parsed;
$clear->( { 'args' => 'a.run' } );
$set->( { 'args' => 'b.run b' } );
ok( @parsed == $n && !$dismissed && $data{'ticker'}{'hidden'},
    'ticker : hidden stays hidden on set \ clear, the line is kept'
);
$data{'ticker'}{'hidden'} = FALSE;
$data{'ticker'}{'display'}{'mode'} = 'notify';
$set->( { 'args' => 'c.run c' } );
ok( @parsed == $n, 'ticker : the one-shot notify mode is not composed' );
delete $data{'ticker'}{'display'}{'mode'};
$data{'ticker'}{'status'}{'initialized'} = FALSE;
$n = @parsed;
$set->( { 'args' => 'early text' } );
ok( @parsed == $n && $data{'ticker'}{'status'}{'lines'}{'early'},
    'ticker : before the window is sized the line waits'
);
ok( $set->( { 'args' => 'bad/key x' } )->{'mode'} eq 'false',
    'ticker : a bad key is refused' );

## warning-sound profiles -> mpv options [ -print : nothing plays ] ##
my $ws   = "$root_path/bin/warning-sound";
my %want = (
    'soft'  => '-speed=0.24 -volume=55',
    'aware' => '-speed=0.5 -volume=66',
    'alert' => '-speed=1.0 -volume=77'
);
foreach my $p ( sort keys %want ) {
    my $out = qx|$^X $ws -profile $p -print 2>&1|;
    ok( $out =~ m|-audio-pitch-correction=no \Q$want{$p}\E |
            && $out !~ m{-volume=77.*-volume},
        "warning-sound : $p -> $want{$p}"
    );
}
my $out = qx|$^X $ws -print -loop=2 2>&1|;
ok( $out =~ m{-volume=77 -loop=2 },
    'warning-sound : no profile as before, options passed on' );
qx|$^X $ws -profile alarm -print 2>&1|;
ok( $CHILD_ERROR != 0, 'warning-sound : alarm is reserved [ later stage ]' );

say "\n$pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,,,,,,,,,,,,,.,,,,..,,,.,,,,,.,,,.,,,..,,..,,...,...,..,,,.,,.,.,.,.,...,
#6DJQDHGMUCYMPZCR6CL4TAZQZRYIUY47YPFHPY5BDVG2LXXGOGUSHKBIJVSRZC64HQC32JRCLLHVS
#\\\|OJPV75JIENZFPCJ3JLMBD4M67CSENMTIYHF7VPJRNMSZ2FSJBBZ \ / AMOS7 \ YOURUM ::
#\[7]MOSDASU3FYUWOOUXM5N5MELM3PZ2LYVUIPDSCFRYRTOLFDUPBWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
