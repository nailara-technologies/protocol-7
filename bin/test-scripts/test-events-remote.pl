#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
use POSIX       qw| strftime |;
use Digest::BMW ();
use Crypt::Misc qw| encode_b32r |;

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
use AMOS7::Switch;

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
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<:encoding(UTF-8)', $path or die "cannot read $path";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;

    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    $code{$name} = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile $name : $EVAL_ERROR" if $EVAL_ERROR;
}

my @logged;
$code{'base.logs'} = sub {
    my ( $level, $format, @args ) = @ARG;
    push @logged,
        { 'level' => $level, 'message' => sprintf( $format, @args ) };
    return TRUE;
};
$code{'base.perlmod.load'}   = sub {TRUE};
$code{'base.perlmod.loaded'} = sub {TRUE};
$code{'chk-sum.bmw.L13-str'} = sub {
    return substr( encode_b32r( Digest::BMW::bmw_512( $ARG[0] ) ), 0, 13 );
};

load_module($ARG) for qw|
    events.signal.encode events.signal.decode
    events.signal.journal_write events.signal.journal_read
    events.cmd.signals-since events.remote.line events.remote.gone
    events.remote.state events.remote.poll events.notify.map
    events.notify.apply events.notify.send events.handler.notify_sessions
    base.reply.mode_text
    |;

my $tmp = tempdir( 'events-remote-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
$data{'events'}{'signal'}{'journal_path'} = "$tmp/signal.journal";
$data{'system'}{'node'}{'name'}           = 'azurum';
$data{'system'}{'conf_path'}              = "$root_path/cfg";
my $now = time - 100;
$code{'events.signal.journal_write'}->(
    {   'time'   => $now - 1,
        'name'   => 'placement.complete',
        'source' => 'n7fs',
        'values' => { 'rc' => 0, 'target' => 'old' },
        'woken'  => []
    }
);
$code{'events.signal.journal_write'}->(
    {   'time'   => $now,
        'name'   => 'place.complete',
        'source' => 'n7fs',
        'values' => { 'rc' => 0, 'host' => 'sdb', 'target' => 'fast disk' },
        'woken'  => []
    }
);
$code{'events.signal.journal_write'}->(
    {   'time'   => $now,
        'name'   => 'private.secret',
        'source' => 'test',
        'values' => { 'token' => 'never-export' },
        'woken'  => []
    }
);

$call = { 'args' => 'not-a-time' };
ok( $code{'events.cmd.signals-since'}->()->{'mode'} eq 'false',
    'sender : a unix time is required' );
$call = { 'args' => $now - 2 };
my $sent = $code{'events.cmd.signals-since'}->();
ok( $sent->{'mode'} eq 'size'
        && $sent->{'data'} =~ m{name:placement\.complete}
        && $sent->{'data'} =~ m{name:place\.complete}
        && $sent->{'data'} !~ m{private|never-export},
    'sender : the default publishes only the two placement names'
);
ok( $code{'events.cmd.signals-since'}->()->{'data'} eq $sent->{'data'},
    'sender : host, time and sorted values give stable BMW ids'
);
ok( $sent->{'data'}
        =~ m|\Aremote\.[A-Z0-9]{13} = host:azurum time:\d+ name:placement\.complete values:rc=0,target=old\n|,
    'sender : native lines carry the raising host and escaped values'
);

$data{'events'}{'remote'}{'publish'} = 'place.complete';
my $place_only = $code{'events.cmd.signals-since'}->()->{'data'};
ok( $place_only =~ m{name:place\.complete}
        && $place_only !~ m{placement\.complete|private},
    'sender : the configured publication list fails closed'
);
$call = { 'args' => $now };
ok( $code{'events.cmd.signals-since'}->()->{'data'} eq '',
    'sender : the time comparison is strictly newer'
);

my $map = $code{'events.notify.map'}->();
ok( ( $map->{'on'}{'place.complete@azurum'}{'to'} // '' ) eq 'notify session',
    'delivery : the remote placement signal uses the live-session path'
);

my @delivered;
$data{'system'}{'root_path'}           = $tmp;
$code{'base.interval.next'}            = sub {55};
$code{'protocol-7.command.send.local'} = sub {
    push @delivered, $ARG[0];
    return TRUE;
};
$code{'protocol-7.route-send'} = sub {
    my $route = $ARG[0];
    push @delivered, $route;
    if ( $route->{'command'} eq 'claude.sessions' ) {
        $code{ $route->{'reply'}{'handler'} }->(
            {   'mode'   => 'size',
                'data'   => "main : since now\n",
                'params' => $route->{'reply'}{'params'}
            }
        );
    }
    return TRUE;
};
my $notice = $code{'events.notify.apply'}->(
    'events.remote', 'place.complete@azurum',
    { 'rc' => 0, 'host' => 'sdb', 'target' => 'fast disk' }, $now
);
my ($session_post)
    = grep { $ARG->{'command'} eq 'claude.session-post' } @delivered;
ok( $notice->{'text'} eq 'place.complete@azurum rc=0 '
        . 'host=sdb target=fast disk'
        && $session_post->{'call_args'}{'args'} eq
        'to=main place.complete@azurum rc=0 '
        . 'host=sdb target=fast disk from=events',
    'delivery : the registered live session receives the rendered signal'
);

my ($remote_line) = grep {m{name:place\.complete}} split m{\n}, $place_only;
$data{'system'}{'path'}{'zenka-dirs'}{'var_P7'} = $tmp;
$data{'events'}{'remote'}{'pull'} = { 'azurum' => 'place.complete' };
$data{'events'}{'remote'}{'states'}{'azurum'}
    = $code{'events.remote.state'}->('azurum');
my $handle = { 'data' => { 'alias' => 'azurum' }, 'exit' => 0 };
$data{'events'}{'remote'}{'runs'}{'azurum'} = {
    'handle'   => $handle,
    'records'  => 0,
    'hits'     => 0,
    'max_time' => $now - 1,
    'stderr'   => []
};
my @raised;
$code{'events.signal.raise'} = sub {
    push @raised, [@ARG];
    return [];
};
$code{'events.remote.line'}->( $remote_line, $handle );
$code{'events.remote.line'}->( $remote_line, $handle );
ok( @raised == 1
        && $raised[0][1] eq 'place.complete@azurum'
        && $raised[0][2]{'target'} eq 'fast disk'
        && $raised[0][2]{'from'} eq 'azurum',
    'receiver : one new record is raised once with original values + from'
);
my $refused
    = $remote_line =~ s{name:place\.complete}{name:placement.complete}r;
$code{'events.remote.line'}->( $refused, $handle );
ok( @raised == 1
        && $data{'events'}{'remote'}{'runs'}{'azurum'}{'refused'} == 1,
    'receiver : an unlisted alias + name pair is refused'
);
$code{'events.remote.line'}->( 'not a native record', $handle );
ok( $data{'events'}{'remote'}{'runs'}{'azurum'}{'invalid'} == 1,
    'receiver : malformed output is not accepted' );

my @arm;
$code{'events.remote.arm'} = sub { push @arm, [@ARG]; TRUE };
$code{'events.remote.gone'}->( 'eof', $handle );
ok( @arm == 1 && $arm[0][1] == TRUE,
    'receiver : a new record resets the next poll to its start rhythm' );
ok( -f "$tmp/events/remote-pull/azurum.state",
    'state : the cursor and ids live below the events var dir' );
my $loaded = $code{'events.remote.state'}->('azurum');
my ($id) = $remote_line =~ m|\Aremote\.([A-Z0-9]{13})|;
ok( $loaded->{'last_time'} == $now && exists $loaded->{'seen'}{$id},
    'state : last time and the seen BMW id survive a reload'
);

$data{'events'}{'remote'}{'states'}{'azurum'} = $loaded;
$data{'events'}{'remote'}{'runs'}{'azurum'}{'interval'} = {};
my ( $spawn, $kill_armed );
$code{'stream_child.user_env'} = sub { {} };
$code{'stream_child.start'}    = sub {
    $spawn = $ARG[0];
    return { 'ok' => TRUE, 'handle' => $handle };
};
$code{'stream_child.arm'} = sub { $kill_armed = $ARG[0]; TRUE };
{

    package FakeEvent;
    sub new  { bless { 'data' => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
}
$code{'events.remote.poll'}->( FakeEvent->new( { 'alias' => 'azurum' } ) );
ok( join( ' ', @{ $spawn->{'cmd'} } ) eq "::: azurum events.signals-since "
        . ( $now - 1 )
        && $spawn->{'env'}{'PROTOCOL_7_BIN_P7R_USER'} eq 'events-pull'
        && $spawn->{'stop'} eq 'KILL'
        && $spawn->{'interval'}{'stop'} eq 'events-remote-pull-timeout'
        && $kill_armed == $handle,
    'poll : async ::: child, overlap cursor and bounded kill timer'
);

my $finish_pull = sub {
    my ( $stderr, $exit, $hits ) = @ARG;
    $handle->{'exit'} = $exit;
    $data{'events'}{'remote'}{'runs'}{'azurum'} = {
        'handle'  => $handle,
        'records' => 0,
        'hits'    => $hits,
        'stderr'  => $stderr
    };
    @logged = ();
    $code{'events.remote.gone'}->( 'eof', $handle );
    return $logged[0];
};
my @pin_lines = ( ' :. ' . ( 'A' x 39 ), ' :. ' . ( 'A' x 38 ) );
foreach my $case (
    [   ': pinned host-root [ azurum.cube \\ 10.0.110.8:42 ]', 0, 2,
        'new pin'
    ],
    [   ': pinned host-root [ azurum.cube \\ '
            . '10.0.110.8:42 ] [ owner-certified ]',
        1,
        1,
        'owner-certified pin'
    ],
    [   ': host-root ROTATED [ azurum.cube \\ '
            . '10.0.110.8:42 ] [ owner-certified ]',
        0,
        2,
        'owner-certified rotation'
    ],
) {
    my ( $header, $hits, $level, $name ) = @{$case};
    my $log = $finish_pull->( [ $header, @pin_lines ], 0, $hits );
    ok( ( $log->{'level'} // -1 ) == $level
            && $log->{'message'} =~ m{\Q$header\E},
        "completion : $name is informational, not an error"
    );
}
my $log = $finish_pull->(
    [   ': pinned host-root [ azurum.cube \\ 10.0.110.8:42 ]',
        @pin_lines, '<< real remote error >>'
    ],
    0, 0
);
ok( ( $log->{'level'} // -1 ) == 0
        && $log->{'message'} =~ m{<< real remote error >>},
    'completion : real stderr stays level 0 with its text'
);
$log = $finish_pull->(
    [ ': pinned host-root [ azurum.cube \\ 10.0.110.8:42 ]', @pin_lines ],
    1, 0
);
ok( ( $log->{'level'} // -1 ) == 0
        && $log->{'message'} =~ m{pinned host-root},
    'completion : nonzero exit keeps informational stderr at level 0'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,,,,,,,...,.,,,..,,.,.,...,.,,,,..,,..,,.,,..,,...,...,...,.,.,...,,.,,,,,,
#B63JLNEVIJ5HUFEC37WQK6QDPEIADHSDOC443R3XWUAKPJRWZQ5NZAXUWX2IYSG2JCZ2RPQQKSGYE
#\\\|LIOM3GHRVKL72JYJONJVOBCLVH74I2HZUD46L7CXYJZV7XF2AKK \ / AMOS7 \ YOURUM ::
#\[7]B226UPA6HKFESUSJV7EKGQ7XXCF24L65JYECB7NASMP57FFZ3SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
