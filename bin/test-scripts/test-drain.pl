#!/usr/bin/perl
use v5.32;
use strict;
use English;
use warnings;

###                                                       ###
## drain harness [ twin restart handover : TQA ]             ##
###                                                       ###

## exercises the real translated source of the drain modules [              ##
## httpd.cmd.drain, httpd.handler.drain_check,  site-yaml.cmd.drain,        ##
## site-yaml.handler.drain_check,  site-yaml.fetch.schedule ] against an    ##
## in-process %data  / %code stub environment with the REAL data keys  [    ##
## $data{'session'}{sid}{'handle'|'watcher'|'http'},  <httpsd.sock>,        ##
## <httpd.sock>, <site-yaml.*> ] -- that is  exactly how httpsd's old drain ##
## broke [ it counted  <base.session.ids>, a key nothing sets ]             ##

use File::stat;
use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

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

our %data;
our %code;
our $call;

##[ fakes ]###################################################################

package FakeWatcher {
    use strict;
    use English;

    sub new {
        my ( $class, $desc ) = @ARG;
        return bless { 'active' => 1, 'desc' => $desc // q|| }, $class;
    }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
}

package FakeEvent {
    use strict;
    use English;

    sub new {
        my ( $class, $w ) = @ARG;
        return bless { 'w' => $w }, $class;
    }
    sub w { shift->{'w'} }
}

package main;

my $now = 1_000_000;    ## stub time ##

my $tmp_store = tempdir( CLEANUP => 1 );

my @log_calls;          ## every base.logs invocation ##
my @timer_calls;        ## event.add_timer param hashes ##
my @exit_calls;         ## base.exit invocations ##
my @route_sends;        ## protocol-7.route-send params ##

%code = (
    'base.logs' => sub {
        my $level = 1;
        $level = shift if @ARG and $ARG[0] =~ m|^\d+$|;
        my $fmt = shift // q||;
        push @log_calls, [ $level, sprintf( $fmt, @ARG ) ];
        return TRUE;
    },
    'base.log'  => sub { return TRUE },
    'base.time' => sub { return $now },
    'base.exit' => sub {
        my $code = shift // 0;
        push @exit_calls, $code;
        return TRUE;
    },
    'event.add_timer' => sub {
        my $params = shift;
        my $timer  = FakeWatcher->new( $params->{'desc'} // q|| );
        push @timer_calls, { 'params' => $params, 'timer' => $timer };
        return $timer;
    },
    'file.zenka_dir.data_path' => sub { return $tmp_store },
    'protocol-7.route-send'    => sub {
        push @route_sends, shift;
        return TRUE;
    },
    'base.stream.close'                => sub { return TRUE },
    'site-yaml.outbox.check-terminate' => sub { return FALSE },
);

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

for my $module (
    qw|
    httpd.cmd.drain
    httpd.handler.drain_check
    site-yaml.cmd.drain
    site-yaml.handler.drain_check
    site-yaml.fetch.schedule
    |
) {
    compile_module($module);
}

my $fail_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub mk_sock {    ## a real open handle : close() genuinely works ##
    open( my $fh, '>', '/dev/null' ) or die $OS_ERROR;
    return $fh;
}

sub reset_state {
    %data        = ();
    @log_calls   = ();
    @timer_calls = ();
    @exit_calls  = ();
    @route_sends = ();
    return;
}

sub mk_session {    ## the REAL session shape ##
    my ( $sid, %kv ) = @ARG;
    $data{'session'}{$sid} = \%kv;
    return $data{'session'}{$sid};
}

sub drain_timer {    ## the armed drain timer, if any ##
    return $timer_calls[-1] // {};
}

sub arm_outbox_record {    ## one unconfirmed outbox record ##
    my $name = shift // 'job-1';
    mkdir "$tmp_store/outbox" if not -d "$tmp_store/outbox";
    open( my $fh, '>', "$tmp_store/outbox/$name.json" )
        or die "outbox write : $OS_ERROR";
    print {$fh} '{}';
    close($fh);
    return;
}

##[ 1 : httpd drain on a busy server ]########################################

say '1 : httpd.cmd.drain : stop accept, count clients, arm the poll';

reset_state();
{
    my $sock = mk_sock();
    $data{'httpd'}{'sock'} = $sock;
    my $lw_in  = FakeWatcher->new;
    my $lw_err = FakeWatcher->new;
    mk_session(
        1,
        'handle'  => $sock,
        'watcher' => {
            'input_handler' => $lw_in,
            'input_error'   => $lw_err,
        },
    );
    mk_session( 2, 'handle' => mk_sock(), 'http' => { 'request' => {} } );
    mk_session( 3, 'handle' => mk_sock(), 'http' => { 'request' => {} } );
    mk_session( 4, 'handle' => mk_sock() );    ## cube link : no http ##

    my $reply = $code{'httpd.cmd.drain'}->();
    ok( ( $reply->{'mode'} // '' ) eq qw| true |, 'drain accepted' );
    ok( ( not $lw_in->is_active and not $lw_err->is_active ),
        'accept watchers canceled' );
    ok( !defined $data{'handle'}{$sock}, 'listen handle dropped' );
    ok( ( $data{'httpd'}{'draining'} // 0 ) == TRUE, 'draining marked' );
    ok( ( scalar @timer_calls ) == 1,                'drain poll armed' );
    ok( ( drain_timer()->{'params'}{'handler'} // '' ) eq
            qw| httpd.handler.drain_check |,
        'poll handler named'
    );
    ok( scalar @exit_calls == 0, 'still running : clients left' );
    ok(
        (   scalar grep { $ARG->[1] =~ m|2 client sessions remaining| }
                @log_calls
        ) == 1,
        'counted 2 client sessions [ cube link ignored ]'
    );

    ## clients finish -> poll exits cleanly ##
    delete $data{'session'}{2};
    delete $data{'session'}{3};
    $code{'httpd.handler.drain_check'}
        ->( FakeEvent->new( drain_timer()->{'timer'} ) );
    ok( ( scalar @exit_calls == 1 and $exit_calls[0] == 0 ),
        'poll : idle -> base.exit(0)' );
    ok( ( not drain_timer()->{'timer'}->is_active ),
        'poll : timer canceled' );
    ok( !exists $data{'httpd'}{'drain_check_timer'},
        'poll : timer key deleted' );
}

##[ 2 : the cap cuts a server that stays busy ]###############################

say '2 : httpd drain cap : exit cleanly below the 30 s force-kill';

reset_state();
{
    my $sock = mk_sock();
    $data{'httpd'}{'sock'} = $sock;
    mk_session(
        1,
        'handle'  => $sock,
        'watcher' => {
            'input_handler' => FakeWatcher->new,
            'input_error'   => FakeWatcher->new,
        },
    );
    mk_session( 2, 'handle' => mk_sock(), 'http' => { 'request' => {} } );

    $code{'httpd.cmd.drain'}->();
    $now += 26;    ## past the 25 s default cap ##
    $code{'httpd.handler.drain_check'}
        ->( FakeEvent->new( drain_timer()->{'timer'} ) );

    ok( scalar @exit_calls == 1, 'cap : exited anyway' );
    ok( ( scalar grep { $ARG->[1] =~ m|drain cap 25s reached| } @log_calls )
            == 1,
        'cap : reason logged'
    );
}

##[ 3 : an idle server exits at once ]########################################

say '3 : httpd drain with no clients : immediate clean exit';

reset_state();
{
    my $sock = mk_sock();
    $data{'httpd'}{'sock'} = $sock;
    mk_session(
        1,
        'handle'  => $sock,
        'watcher' => { 'input_handler' => FakeWatcher->new },
    );
    my $reply = $code{'httpd.cmd.drain'}->();
    ok( ( $reply->{'mode'} // '' ) eq qw| true |, 'drain accepted' );
    ok( scalar @exit_calls == 1,  'idle : base.exit(0) at once' );
    ok( scalar @timer_calls == 0, 'idle : no poll armed' );
}

##[ 4 : httpsd shares the drain [ its own sock key ] ]########################

say '4 : httpsd : the shared drain finds <httpsd.sock>';

reset_state();
{
    my $hsock = mk_sock();
    my $sock  = mk_sock();
    $data{'httpsd'}{'sock'} = $hsock;    ## httpsd's real key ##
    $data{'httpd'}{'sock'}  = $sock;     ## stale httpd key   ##
    mk_session(
        9,
        'handle'  => $hsock,
        'watcher' => { 'input_handler' => FakeWatcher->new },
    );
    mk_session( 8, 'handle' => mk_sock(), 'http' => { 'request' => {} } );

    $code{'httpd.cmd.drain'}->();
    ok( !defined $data{'handle'}{$hsock}, 'httpsd listen socket closed' );
    ok( defined $data{'httpd'}{'sock'},
        'the stale httpd sock key untouched' );
    ok(
        (   scalar grep { $ARG->[1] =~ m|stopping accept \[ httpsd \]| }
                @log_calls
        ) == 1,
        'httpsd identified from <httpsd.sock>'
    );
}

##[ 5 : site-yaml idle drain ]################################################

say '5 : site-yaml.cmd.drain : idle -> immediate exit';

reset_state();
{
    my $reply = $code{'site-yaml.cmd.drain'}->();
    ok( ( $reply->{'mode'} // '' ) eq qw| true |,        'drain accepted' );
    ok( ( $data{'site-yaml'}{'draining'} // 0 ) == TRUE, 'draining marked' );
    ok( scalar @exit_calls == 1,  'idle : base.exit(0) at once' );
    ok( scalar @timer_calls == 0, 'idle : no poll armed' );
}

##[ 6 : site-yaml busy drain, then finishes ]#################################

say '6 : site-yaml drain : finish the step, exit when the outbox confirms';

reset_state();
{
    arm_outbox_record;
    $data{'site-yaml'}{'fetch_queue'}
        = [ { 'url' => 'http://x', 'id' => 1 } ];
    $data{'site-yaml'}{'import_state'}    = { 'scan' => 1 };
    $data{'site-yaml'}{'fetched_streams'} = [ mk_sock() ];

    my $reply = $code{'site-yaml.cmd.drain'}->();
    ok( ( $reply->{'mode'} // '' ) eq qw| true |, 'drain accepted' );
    ok( scalar @timer_calls == 1,                 'busy : poll armed' );
    ok( scalar @exit_calls == 0,                  'busy : still running' );

    ## the in-flight step completes : queue drains, import done, stream ##
    ## closed, outbox record confirmed -> idle -> clean exit            ##
    $data{'site-yaml'}{'fetch_queue'}     = [];
    $data{'site-yaml'}{'import_state'}    = {};
    $data{'site-yaml'}{'fetched_streams'} = [];
    unlink "$tmp_store/outbox/job-1.json";
    $code{'site-yaml.handler.drain_check'}
        ->( FakeEvent->new( drain_timer()->{'timer'} ) );
    ok( scalar @exit_calls == 1, 'finished : base.exit(0)' );
}

##[ 7 : site-yaml cap never loses an outbox record ]##########################

say '7 : site-yaml drain cap : exit with the outbox record intact';

reset_state();
{
    arm_outbox_record('keep-me');
    $data{'site-yaml'}{'fetch_queue'}
        = [ { 'url' => 'http://y', 'id' => 2 } ];

    $code{'site-yaml.cmd.drain'}->();
    $now += 26;
    $code{'site-yaml.handler.drain_check'}
        ->( FakeEvent->new( drain_timer()->{'timer'} ) );

    ok( scalar @exit_calls == 1, 'cap : exited anyway' );
    ok( -f "$tmp_store/outbox/keep-me.json",
        'cap : the unconfirmed record survives on disk' );
}

##[ 8 : fetch.schedule honors draining ]######################################

say '8 : fetch.schedule : no new ticks once draining';

reset_state();
{
    $data{'site-yaml'}{'fetch_queue'}
        = [ { 'url' => 'http://z', 'id' => 3 } ];
    $code{'site-yaml.fetch.schedule'}->(0.1);
    ok( scalar @timer_calls == 1, 'normal : tick scheduled' );

    $data{'site-yaml'}{'draining'} = TRUE;
    $code{'site-yaml.fetch.schedule'}->(0.1);
    ok( scalar @timer_calls == 1, 'draining : no new tick armed' );
    ok( ( scalar grep { $ARG->[1] =~ m|not rescheduling| } @log_calls ) == 1,
        'draining : logged'
    );
}

##[ done ]####################################################################

say q||;
if ($fail_count) {
    say "FAILED : $fail_count test(s)";
    exit 1;
}
say 'all tests passed';
exit 0;

#,,..,,..,,..,,,.,,,,,..,,..,,,.,,,,,,...,.,.,..,,...,..,,,..,,.,,,,,,,,,,...,
#72SR2MJMGVXMEUHBIUELZRAFULW2Y23B4ELEAUP3GA3CIBVSXPXQMYMLOREKA5A3RG23F6YYGCGFE
#\\\|VWPLI4OMLB3OAFKKEU5H32V23EOF27ATN5KKFIHGBY335DM76EX \ / AMOS7 \ YOURUM ::
#\[7]LM2DPCN4SCFMO67A7QOVEZXRCLQ6VBW5PKMFJ4LJKRGJY5XBAOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
