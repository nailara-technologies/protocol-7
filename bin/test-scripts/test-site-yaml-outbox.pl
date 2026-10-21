#!/usr/bin/env perl

use v5.24;
use strict;
use English;
use warnings;

## site-yaml durable outbox transport : REAL site-yaml.outbox.* modules +
## site-yaml.handler.fetch_tick + the three new commands, stubbed dependencies
## [ fetch pipeline, stream layer, routing ]. covers : hold mode writes the
## payload into the outbox [ no route-send ], outbox-confirm unlinks +
## validates names, subscribe-fetched backlog order [ oldest first ] and the
## auto-terminate condition true / false cases

use bytes;

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
use JSON::PP                  ();

## fetch_tick + outbox-list call into JSON:: / JSON::XS :: provide both ##
no warnings 'once';
*JSON::encode_json     = \&JSON::PP::encode_json;
*JSON::decode_json     = \&JSON::PP::decode_json;
*JSON::XS::encode_json = \&JSON::PP::encode_json
    if not defined &JSON::XS::encode_json;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

my $fail_count = 0;
my $test_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- test environment                                 ##
## ---------------------------------------------------- ##

my $tmpdir = tempdir( 'p7-outbox-test-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );

my @routed;
my @pushed;
my @closed;
my $push_fails = 0;    ## when > 0, base.stream.push returns 0 that often ##

$data{'file'}{'zenka_dir'}{'data_path'} = $tmpdir;

$code{'base.logs'}                = sub {return};
$code{'base.log'}                 = sub {return};
$code{'base.perlmod.autoload'}    = sub {return};
$code{'file.zenka_dir.data_path'} = sub { return $tmpdir };
$code{'base.ntime.b32'}           = sub { return 'B32TEST' };

$code{'base.stream.open'} = sub {
    my $arg = shift;
    return { 'sid' => $arg->{'sid'}, 'cmd_id' => $arg->{'cmd_id'} };
};
$code{'base.stream.push'} = sub {
    my ( $h, $chunk_ref ) = @ARG;
    if ( $push_fails > 0 ) { $push_fails--; return 0 }
    push @pushed, $$chunk_ref;
    return bytes::length($$chunk_ref);
};
$code{'base.stream.close'} = sub {
    my $h = shift;
    push @closed, $h;
    return 1;
};

$code{'protocol-7.route-send'} = sub {
    my $arg = shift;
    push @routed, $arg;
    return TRUE;
};

## fetch pipeline stubs [ drive the callback synchronously ] ##
$code{'site-yaml.async_fetch.request'} = sub {
    my ( $id, $url, $cb ) = @ARG;
    $cb->('<html>stepstone posting</html>');
    return;
};
$code{'site-yaml.stepstone.job_from_html'} = sub {
    my ( $url, $html ) = @ARG;
    return { 'id' => '12345', 'url' => $url, 'title' => 'test job' };
};
$code{'site-yaml.fetch.state'}    = sub {return};
$code{'site-yaml.fetch.schedule'} = sub {return};
$code{'site-yaml.fetch.backoff'}  = sub {return};

## --- compile REAL modules                         ##
## ------------------------------------------------ ##

my $cmd_header = q{my $call = {}; if ( ref( $ARG[0] ) eq 'HASH' ) }
    . q{{ $call = $ARG[0] } else { $call->{'args'} = $ARG[0] }};

compile_module( 'site-yaml.outbox.dir',             '' );
compile_module( 'site-yaml.outbox.write',           '' );
compile_module( 'site-yaml.outbox.check-terminate', '' );
compile_module( 'site-yaml.cmd.subscribe-fetched',  $cmd_header );
compile_module( 'site-yaml.cmd.outbox-confirm',     $cmd_header );
compile_module( 'site-yaml.cmd.outbox-list',        $cmd_header );
compile_module( 'site-yaml.handler.fetch_tick',     '' );

sub outbox_files {
    my $dir = "$tmpdir/outbox";
    return () if not -d $dir;
    opendir my $dh, $dir or return ();
    my @f = sort grep {m|^[^.][^/]*\.json$|} readdir($dh);
    closedir $dh;
    return @f;
}

sub reset_state {
    @routed            = ();
    @pushed            = ();
    @closed            = ();
    $data{'site-yaml'} = {};
    if ( -d "$tmpdir/outbox" and opendir my $dh, "$tmpdir/outbox" ) {
        unlink map {"$tmpdir/outbox/$_"}
            grep {m|^[^.]|} readdir($dh);
        closedir $dh;
    }
    return;
}

## --- fetch_tick hold mode                         ##
## ------------------------------------------------ ##

say ':: fetch_tick :hold: writes the outbox, no route-send';

reset_state();
my $old_umask = umask 0;    ## observe the mkdir 0750 mode verbatim ##
$data{'site-yaml'}{'fetch_queue'} = [
    {   'id'            => '12345',
        'url'           => 'https://www.stepstone.de/x--12345-inline.html',
        'reply_handler' => ':hold:',
    }
];
$data{'site-yaml'}{'fetched_streams'} = [ { 'sid' => 1, 'cmd_id' => 9 } ];
$code{'site-yaml.handler.fetch_tick'}->();

umask $old_umask;

my @files = outbox_files();
ok( @files == 1, 'hold mode : exactly one outbox record' );
ok( ( $files[0] // '' ) eq 'B32TEST-12345.json',
    'record name is <ntime b32>-<job id>.json'
);

my $dir_mode = ( stat "$tmpdir/outbox" )[2] & 0777;
ok( $dir_mode == 0750, 'outbox dir created mode 0750' );

my $content = do {
    open my $fh, '<', "$tmpdir/outbox/$files[0]" or die $!;
    local $INPUT_RECORD_SEPARATOR = undef;
    <$fh>;
};
my $job = eval { JSON::PP::decode_json($content) };
ok( ( ref $job eq 'HASH' and ( $job->{"id"} // '' ) eq '12345' ),
    'outbox record holds the same json payload' );

ok( @routed == 0, 'hold mode : nothing route-sent' );

ok( @pushed == 1, 'hold mode : one frame pushed to open fetched-streams' );
my $frame = eval { JSON::PP::decode_json( $pushed[0] // '' ) };
ok(
    (           ref $frame eq 'HASH'
            and ( $frame->{'name'} // '' ) eq 'B32TEST-12345'
            and ref $frame->{'job'} eq 'HASH'
            and ( $frame->{'job'}{'id'} // '' ) eq '12345'
    ),
    'frame is one json line {name,job}'
);

## dead subscriber handle is dropped on push failure ##
reset_state();
$data{'site-yaml'}{'fetched_streams'} = [ { 'sid' => 7, 'cmd_id' => 3 } ];
$push_fails = 1;
my $name = $code{'site-yaml.outbox.write'}->( '999', '{"id":"999"}' );
ok( $name eq 'B32TEST-999', 'outbox.write returns the record name' );
ok( scalar @{ $data{'site-yaml'}{'fetched_streams'} // [] } == 0,
    'push returning 0 drops the subscriber handle' );

## --- fetch_tick local default unchanged ##
## ----------------------------------     ##

say ':: fetch_tick local default still route-sends';

reset_state();
$data{'site-yaml'}{'fetch_queue'} = [
    {   'id'            => '12345',
        'url'           => 'https://www.stepstone.de/x--12345-inline.html',
        'reply_handler' => 'jobsite.job-upsert',
    }
];
$code{'site-yaml.handler.fetch_tick'}->();

ok( outbox_files() == 0, 'local mode : no outbox record' );
ok(
    (           @routed == 1
            and ( $routed[0]{'command'} // '' ) eq 'jobsite.job-upsert'
            and length( $routed[0]{'call_args'}{'args'} // '' )
    ),
    'local mode : route-send to jobsite.job-upsert as before'
);

## --- outbox-confirm                                      ##
## ------------------------------------------------------- ##

say ':: outbox-confirm';

reset_state();
$data{'site-yaml'}{'fetched_streams'} = [ { 'sid' => 1, 'cmd_id' => 9 } ];
$code{'site-yaml.outbox.write'}->( '12345', '{"id":"12345"}' );

my $reply
    = $code{'site-yaml.cmd.outbox-confirm'}->( { 'args' => '../evil' } );
ok( ( $reply->{'mode'} // '' ) eq 'false', 'slashes rejected' );

$reply = $code{'site-yaml.cmd.outbox-confirm'}->( { 'args' => 'sub/dir' } );
ok( ( $reply->{'mode'} // '' ) eq 'false', 'path segments rejected' );

$reply = $code{'site-yaml.cmd.outbox-confirm'}->( { 'args' => '' } );
ok( ( $reply->{'mode'} // '' ) eq 'false', 'empty name rejected' );

ok( outbox_files() == 1, 'rejected confirms leave the record alone' );

## queue non-empty : auto-terminate must not fire even after the unlink ##
$data{'site-yaml'}{'fetch_queue'} = ['pending'];
$reply = $code{'site-yaml.cmd.outbox-confirm'}
    ->( { 'args' => 'B32TEST-12345' } );
ok( ( $reply->{'mode'} // '' ) eq 'true', 'valid name replies true' );
ok( outbox_files() == 0,                  'valid name unlinks the record' );
ok( @closed == 0, 'non-empty fetch queue keeps the stream open' );

$reply = $code{'site-yaml.cmd.outbox-confirm'}
    ->( { 'args' => 'B32TEST-12345' } );
ok( ( $reply->{'mode'} // '' ) eq 'true', 'already gone is true as well' );

## --- auto-terminate condition                 ##
## -------------------------------------------- ##

say ':: auto-terminate condition';

## everything drained : confirm re-check closes the stream ##
reset_state();
$data{'site-yaml'}{'fetched_streams'} = [ { 'sid' => 1, 'cmd_id' => 9 } ];
$reply = $code{'site-yaml.cmd.outbox-confirm'}
    ->( { 'args' => 'never-existed' } );
ok( ( $reply->{'mode'} // '' ) eq 'true', 'confirm on empty outbox true' );
ok( @closed == 1, 'empty queue + no import + empty outbox : stream closed' );
ok( scalar @{ $data{'site-yaml'}{'fetched_streams'} // [] } == 0,
    'stream list cleaned' );

## false cases ##
reset_state();
$data{'site-yaml'}{'fetched_streams'} = [ { 'sid' => 1, 'cmd_id' => 9 } ];
$data{'site-yaml'}{'fetch_queue'}     = ['pending'];
$data{'site-yaml'}{'import_state'}    = {};
$code{'site-yaml.outbox.write'}->( '1', '{"id":"1"}' );
my $term = $code{'site-yaml.outbox.check-terminate'}->();
ok( ( $term == FALSE and @closed == 0 ),
    'false : unconfirmed record in outbox'
);

unlink map {"$tmpdir/outbox/$_"} outbox_files();
$term = $code{'site-yaml.outbox.check-terminate'}->();
ok( ( $term == FALSE and @closed == 0 ), 'false : fetch queue non-empty' );

$data{'site-yaml'}{'fetch_queue'}  = [];
$data{'site-yaml'}{'import_state'} = { 'import-1' => { 'page' => 1 } };
$term = $code{'site-yaml.outbox.check-terminate'}->();
ok( ( $term == FALSE and @closed == 0 ), 'false : import still running' );

$data{'site-yaml'}{'import_state'} = {};
$term = $code{'site-yaml.outbox.check-terminate'}->();
ok( ( $term == TRUE and @closed == 1 ), 'true : all three conditions met' );

## --- subscribe-fetched : backlog order ##
## ------------------------------------  ##

say ':: subscribe-fetched backlog';

reset_state();
$code{'site-yaml.outbox.write'}->( '2', '{"id":"2"}' );
$code{'site-yaml.outbox.write'}->( '1', '{"id":"1"}' );
$push_fails = 0;

my @before = outbox_files();
ok( ( join( ' ', @before ) ) eq 'B32TEST-1.json B32TEST-2.json',
    'backlog seed sorted as written' );

$reply = $code{'site-yaml.cmd.subscribe-fetched'}
    ->( { 'args' => '', 'session_id' => 5, 'command_id' => 11 } );

ok( ( $reply->{'mode'} // '' ) eq 'deferred', 'subscribe replies deferred' );
ok( @pushed == 2, 'backlog pushed one frame per record' );

my @frame_names = map {
    my $f = eval { JSON::PP::decode_json($ARG) };
    ref $f eq 'HASH' ? ( $f->{'name'} // '?' ) : '?'
} @pushed;
ok( ( join( ' ', @frame_names ) ) eq 'B32TEST-1 B32TEST-2',
    'backlog delivered oldest first' );

## outbox non-empty here : no auto-terminate despite drained queue ##
ok( @closed == 0, 'backlog pending keeps the stream open' );

## --- outbox-list                                             ##
## ----------------------------------------------------------- ##

say ':: outbox-list';

$reply = $code{'site-yaml.cmd.outbox-list'}->( { 'args' => '' } );
ok( ( $reply->{'mode'} // '' ) eq 'size', 'outbox-list replies size mode' );
my $list = eval { JSON::PP::decode_json( $reply->{'data'} ) };
ok(
    (           ref $list eq 'ARRAY'
            and @{$list} == 2
            and ( $list->[0]{'name'} // '' ) eq 'B32TEST-1'
            and $list->[0]{'size'} > 0
    ),
    'outbox-list returns {name,size} records'
);

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,,,,,,.,,.,,,..,,,,,,,.,,,.,,,,,,,,,.,.,.,.,...,...,..,,..,,,..,,,,,,,,,
#ZJNE2UFVGTBC7UMI6V5QSEGVDBCJOIUC6SDKOXNHXU7MBDHF7JHUFM5VJRZQ77UZUQ3N2ZWGGBZ4E
#\\\|M72BQRFRKUA5OOCAKQFPOJAPUM7G4UAASM6MAKSMMCJ27A4L6VW \ / AMOS7 \ YOURUM ::
#\[7]7NTSONPQFHJWZ7A5H2JMTCBTJSO3ECAYO63W33XSVFNFHXW5X4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
