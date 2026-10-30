#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;
use bytes;

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir = File::Spec->updir;
    my $root   = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use JSON::XS;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;

my $fail = 0;
my $pass = 0;

sub ok ($;$) {
    my ( $condition, $label ) = @ARG;
    if ($condition) { $pass++; say "  ok   : $label"; return }
    $fail++;
    say "  FAIL : $label";
    return;
}

my $pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my $name = shift;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $!";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$pragmas sub {\n$prefix\n# "
        . "line 1 \"$name\"\n$translated\n}";
    die "compile failed for $name : $EVAL_ERROR" if not defined $cref;
    $code{$name} = $cref;
    return $cref;
}

my @logs;
my @timers;
my @posts;
my @reverse;
my $mem = {};
$code{'base.logs'}                      = sub { push @logs, [@ARG]; return };
$code{'base.cnt_s'}                     = sub { $ARG[0] == 1 ? '' : 's' };
$code{'base.ntime.b32'}                 = sub {'99'};
$code{'base.ntime_BASE32_to_numerical'} = sub { 0 + ( $ARG[0] // 0 ) };
$code{'event.add_timer'}         = sub { push @timers, $ARG[0]; return };
$code{'clients.http.post'}       = sub { push @posts,  $ARG[0]; return TRUE };
$code{'clients.https.post'}      = $code{'clients.http.post'};
$code{'jobsite.replica.enabled'} = sub {
    length( $data{'jobsite'}{'cfg'}{'primary_url'} // '' ) ? TRUE : FALSE;
};
$code{'jobsite.replica.complete'}       = sub {return};
$code{'jobsite.sync.token_for_url'}     = sub {'token'};
$code{'plugin.web.jobs.cache.read_all'} = sub {$mem};
$code{'plugin.web.jobs.cache.path'}     = sub {'/unused'};
$code{'plugin.web.jobs.cache.write'}    = sub {
    $mem->{ $ARG[0] } = { %{ $ARG[1] } };
    return TRUE;
};
$code{'plugin.web.jobs.removed_log.append'} = sub {TRUE};
$code{'plugin.web.jobs.events.notify'}      = sub {return};
$code{'plugin.web.jobs.reverse.queue'} = sub { push @reverse, $ARG[0]; TRUE };
$code{'plugin.web.jobs.reverse.flush'} = sub { [] };
$code{'plugin.web.jobs.prefs.read'}    = sub { {} };
$code{'plugin.web.jobs.prefs.write'}   = sub {TRUE};
$code{'plugin.web.jobs.store.prune'}   = sub {return};
my @saved_unsent;
$code{q|jobsite.replica.unsent-save|} = sub {
    push @saved_unsent, [ @{ $data{jobsite}{replica}{unsent} // [] } ];
    return;
};
$code{q|jobsite.replica.pull_soon|} = sub {return};

compile_module($_) for qw| jobsite.replica.pull-response
    web.jobs.sync_ui_authorized
    jobsite.replica.complete jobsite.sync.role_for_url
    jobsite.replica.forward-local-response jobsite.replica.forward-response
    plugin.web.jobs.sync |;
$code{'jobsite.cmd.scan'}
    = eval "$pragmas sub {\n$prefix\nmy \$call = shift;\n"
    . p7_syntax__translate(
    do {
        open my $fh, '<', "$main::root_path/src/jobsite.cmd.scan" or die $!;
        join '', <$fh>;
    }
    ) . "\n}";
die $EVAL_ERROR if $EVAL_ERROR;

say "\n :. pull parsing and local replacement";
$data{'jobsite'}{'cfg'}{'primary_url'} = 'https://primary/jobs-sync';
$code{'jobsite.replica.pull-response'}->(
    {   'ok'   => TRUE,
        'body' => JSON::XS::encode_json(
            { 'jobs' => [ { 'id' => 'J1', 'reason' => 'match' } ] }
        ),
    }
);
my $replacement = JSON::XS::decode_json( $posts[-1]{'body'} );
ok( $replacement->{'role'} eq 'replica'
        && $replacement->{'jobs'}[0]{'reason'} eq 'match',
    'primary jobs ride unchanged in a replacement batch'
);
## clients.https delivers characters : a „ or \x{20ac} must not fail the ##
## pull                                                                  ##
$code{q|jobsite.replica.pull-response|}->(
    {   q|ok|   => TRUE,
        q|body| => JSON::XS->new->encode(
            {   q|jobs| => [
                    {   q|id|     => q|J9|,
                        q|reason| => qq|\x{201e}ok\x{201c} \x{20ac}|
                    }
                ]
            }
        ),
    }
);
my $wide = JSON::XS::decode_json( $posts[-1]{q|body|} );
ok( $wide->{jobs}[0]{id} eq q|J9|
        && $wide->{jobs}[0]{reason} eq qq|\x{201e}ok\x{201c} \x{20ac}|,
    q|a character-decoded https body with wide characters is accepted|
);
my $post_count = scalar @posts;
$code{'jobsite.replica.pull-response'}->( { 'ok' => TRUE, 'body' => '{}' } );
ok( scalar @posts == $post_count,
    'invalid primary payload keeps the last set' );

say "\n :. backoff and state-change logging";
$data{'jobsite'}{'cfg'}{'replica_pull_interval'} = 120;
$data{'jobsite'}{'replica'}                      = {};
@logs                                            = @timers = ();
$code{'jobsite.replica.complete'}->(FALSE);
$code{'jobsite.replica.complete'}->(FALSE);
ok( $timers[0]{'after'} == 120 && $timers[1]{'after'} == 240,
    'failure doubles the next delay' );
ok( scalar @logs == 1, 'repeated failures log only the first state change' );
$data{'jobsite'}{'replica'}{'next_delay'} = 1800;
$code{'jobsite.replica.complete'}->(FALSE);
ok( $timers[-1]{'after'} == 1800
        && $data{'jobsite'}{'replica'}{'next_delay'} == 1800,
    'backoff is capped at thirty minutes'
);
$code{'jobsite.replica.complete'}->(TRUE);
ok( $timers[-1]{'after'} == 120
        && $data{'jobsite'}{'replica'}{'next_delay'} == 120,
    'success resets the pull interval'
);
ok( scalar @logs == 2, 'recovery logs one state change' );

say "\n :. replica gates and role resolution";
my $scan = $code{'jobsite.cmd.scan'}->( { 'args' => '' } );
ok( $scan->{'mode'} eq 'false'
        && $scan->{'data'} eq 'replica of https://primary/jobs-sync',
    'explicit scan names the primary instead of running'
);
$data{'jobsite'}{'cfg'}{'sync_url_roles'} = 'https://primary/jobs-sync=ui';
ok( $code{'jobsite.sync.role_for_url'}->('https://primary/jobs-sync') eq 'ui',
    'ui role resolves for the primary url'
);

say "\n :. ui forwarding payload";
$data{'web'}{'jobs'}{'sync_ui_authorized'} = TRUE;
$code{'jobsite.replica.forward-local-response'}->(
    {   'ok'   => TRUE,
        'body' => JSON::XS::encode_json(
            { 'reverse' => [ { 'id' => 'J1', 'stage' => 'applied' } ] }
        ),
    }
);
my $forwarded = JSON::XS::decode_json( $posts[-1]{'body'} );
ok( $forwarded->{'role'} eq 'ui'
        && $forwarded->{'jobs'}[0]{'stage'} eq 'applied',
    'collected reverse actions are forwarded as ui'
);

## the flushed actions survive a failed forward and go first next time ##
ok( @{ $saved_unsent[-1] } == 1,
    q|forwarded actions are kept until confirmed| );
$code{q|jobsite.replica.forward-response|}->(
    {   q|ok|   => TRUE,
        q|body| => q|{"ok":false,"error":"ui role not authorized"}|
    }
);
ok( @{ $data{jobsite}{replica}{unsent} } == 1
        && $timers[-1]{handler} eq q|jobsite.replica.forward-retry|,
    q|an ok:false reply keeps the actions and arms a retry|
);
$code{q|jobsite.replica.forward-local-response|}->(
    {   q|ok|   => TRUE,
        q|body| => JSON::XS::encode_json(
            { q|reverse| => [ { q|id| => q|J2|, q|stage| => q|review| } ] }
        ),
    }
);
my $resent = JSON::XS::decode_json( $posts[-1]{q|body|} );
ok( @{ $resent->{jobs} } == 2 && $resent->{jobs}[0]{id} eq q|J1|,
    q|unsent actions go first, fresh ones after| );
$code{q|jobsite.replica.forward-response|}
    ->( { q|ok| => TRUE, q|body| => q|{"ok":true}| } );
ok( !@{ $data{jobsite}{replica}{unsent} },
    q|a confirmed forward clears the unsent list|
);

sub web_sync {
    my $payload = shift;
    my $reply   = $code{'plugin.web.jobs.sync'}
        ->( { 'args' => JSON::XS::encode_json($payload) } );
    return JSON::XS::decode_json( $reply->{'data'} );
}

say "\n :. ui role keyed on the verified user";
my %sessions = (
    q|tok-r| => { q|user_id| => q|jobsite-replica| },
    q|tok-p| => { q|user_id| => q|jobsite-push| }
);
$code{q|plugin.web.auth.verify_session|}
    = sub { $sessions{ $ARG[0] // q|| } };
$data{web}{cfg}{jobs_sync_ui_users} = q|jobsite-replica|;
ok( $code{q|web.jobs.sync_ui_authorized|}->(q|tok-r|),
    q|a listed user may send role ui| );
ok( !$code{q|web.jobs.sync_ui_authorized|}->(q|tok-p|),
    q|another verified user may not| );
ok( !$code{q|web.jobs.sync_ui_authorized|}->(q|tok-x|),
    q|an unverified token may not| );
$data{web}{cfg}{jobs_sync_ui_users} = q||;
ok( !$code{q|web.jobs.sync_ui_authorized|}->(q|tok-r|),
    q|no listed users : nobody| );

say "\n :. replacement and authorized ui conflict guard";
$mem = {
    'J1' => {
        'id'     => 'J1',
        'status' => 'review',
        'stage'  => 'review',
        'notes'  => 'stale local note'
    },
    'OLD' => { 'id' => 'OLD', 'status' => 'new', 'stage' => 'new' },
};
$data{'plugin'}{'web'}{'jobs'}{'cache'} = $mem;
web_sync(
    {   'role' => 'replica',
        'jobs' =>
            [ { 'id' => 'J1', 'status' => 'review', 'summary' => 'fresh' } ],
    }
);
ok( !exists $mem->{'OLD'},
    'replacement removes ids absent from the primary' );
ok( $mem->{'J1'}{'score_summary'} eq 'fresh',
    'jobs.json summary alias survives the local sync path' );
ok( !exists $mem->{'J1'}{'notes'},
    'replacement does not preserve stale local browser fields' );

$mem->{'J1'}{'stage'} = 'interviewed';
$data{'web'}{'jobs'}{'sync_ui_authorized'} = FALSE;
my $denied
    = web_sync(
    { 'role' => 'ui', 'jobs' => [ { 'id' => 'J1', 'stage' => 'applied' } ] }
    );
ok( !$denied->{'ok'} && $mem->{'J1'}{'stage'} eq 'interviewed',
    'unauthorized ui role cannot change stage' );

$data{'web'}{'jobs'}{'sync_ui_authorized'} = TRUE;
@reverse = ();
my $conflict = web_sync(
    {   'role' => 'ui',
        'jobs' => [
            { 'id' => 'J1', 'stage' => 'applied', 'base_stage' => 'review' }
        ],
    }
);
ok( scalar $conflict->{'conflicts'}->@* == 1
        && $mem->{'J1'}{'stage'} eq 'interviewed',
    'primary reuses base_stage to reject a stale forwarded stage'
);
ok( scalar @reverse == 0, 'a conflicted stage is not queued again' );

say '';
say "passed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,.,,.,,,,,,,.,,,,..,.,.,,,,,,,.,,..,,,.,,.,,..,,...,...,...,,..,..,,...,...,
#BZCCJBD3VQQDOXT5VMI4LCZSZITYL24VEPWYI5V6QSKOVNLALIWQVZYBMRJTB5VJ4B2M57S24TVDA
#\\\|LDWB5UDE24AOKW3ZKAQNMNET5RUA45PK7CPKMG5FPKM2S2BBAYK \ / AMOS7 \ YOURUM ::
#\[7]JHYJIUIOA4OTCKIQQXOYHXPS2VUZG76Q722QYSMIEW5YWPYMQMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
