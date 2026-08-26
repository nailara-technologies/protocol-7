#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                        ###
##  httpd.classify phase 1 : standalone acceptance harness  ##
###                                                        ###

## exercises the real translated module sources [ load, match, record,  ##
## expire, cmd.stats, cmd.history ] against an in-process %data / %code ##
## stub environment -- no live httpd required. covers the task file's   ##
## phase-1 acceptance checks as far as they can run standalone :        ##
## - pattern library loads and compiles from the real YAML files        ##
## - httpd.classify.match unit-level hits for observed probe paths      ##
## - ring bound, stats counters, per-peer history content               ##
## - expiry ttl + max_peers cap behavior                                ##
## - disabled-feature invariant : zero data-tree presence, no-ops       ##
## - enabled-with-empty-library invariant : no classification tags      ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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
use YAML::XS                  ();

##[ p7 runtime environment stubs ]############################################

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

##  stub code refs for the base/format subs the classify modules invoke  ##
%code = (
    'base.file.glob' => sub {
        my $pattern = shift;
        my @files   = glob($pattern);
        return \@files;
    },
    'format.yaml.load_file' => sub {
        my $path = shift // return undef;
        return eval { YAML::XS::LoadFile($path) };
    },
    'base.eval.comp_regex' => sub {
        my ( $regex_str, $error_sref ) = @ARG;
        my $compiled = eval {qr/$regex_str/};
        if ( $EVAL_ERROR or not defined $compiled ) {
            $error_sref->$* = "$EVAL_ERROR" if ref $error_sref;
            return undef;
        }
        return $compiled;
    },
    'base.logs'       => sub { return TRUE },
    'event.add_timer' => sub {
        $data{'test'}{'timers'} //= [];
        push $data{'test'}{'timers'}->@*, shift;
        return TRUE;
    },
);

$data{'system'}{'root_path'} = $main::root_path;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

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

compile_module($_) foreach qw|
    httpd.classify.load
    httpd.classify.match
    httpd.classify.record
    httpd.classify.expire
    httpd.classify.cmd.stats
    httpd.classify.cmd.history
    httpd.classify.cmd.reload-patterns
    httpd.classify.init
    |;

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub invoke_cmd {
    my ( $module_name, $args ) = @ARG;
    $call = { 'args' => $args // '' };
    return $code{$module_name}->($call);
}

##[ 1 : pattern library load from real YAML files ]###########################

say ': library load';

my $library = $code{'httpd.classify.load'}->();
ok( ref $library eq 'HASH', 'load returns library hashref' );
ok( exists $library->{'env-credential-scan'}, 'family env-credential-scan' );
ok( exists $library->{'git-config-leak'},     'family git-config-leak' );
ok( exists $library->{'wp-admin-probe'},      'family wp-admin-probe' );
ok( exists $library->{'phpmyadmin-probe'},    'family phpmyadmin-probe' );
ok( exists $library->{'path-traversal-cgi'},  'family path-traversal-cgi' );
ok( exists $library->{'generic-shell-probe'}, 'family generic-shell-probe' );
ok( exists $library->{'admin-panel-probe'},   'family admin-panel-probe' );
ok( ( $library->{'path-traversal-cgi'}{'severity'} // '' ) eq
        'exploit-attempt',
    'path-traversal-cgi severity is exploit-attempt'
);
my $pattern_total = 0;
map { $pattern_total += scalar $ARG->{'patterns'}->@* } values %{$library};
ok( $pattern_total >= 21,
    "at least 3 patterns per " . "family [ $pattern_total ]" );

##[ 2 : httpd.classify.match unit-level checks ]##############################

say ': match';

my $m1 = $code{'httpd.classify.match'}->( '/.env',         'GET' );
my $m2 = $code{'httpd.classify.match'}->( '/.git/config',  'GET' );
my $m3 = $code{'httpd.classify.match'}->( '/wp-login.php', 'GET' );
my $m4 = $code{'httpd.classify.match'}->( '/storage/.env', 'GET' );
my $m5 = $code{'httpd.classify.match'}->( '/phpmyadmin/',  'GET' );
my $m6 = $code{'httpd.classify.match'}->( '/manager/html', 'GET' );
my $m7 = $code{'httpd.classify.match'}->( '/index.html',   'GET' );

ok( ( $m1->{'family'} // '' ) eq 'env-credential-scan',
    '/.env -> env-credential-scan' );
ok( ( $m1->{'name'} // '' ) eq 'dotenv-root', '/.env -> dotenv-root' );
ok( defined $m1->{'severity'},                'match carries severity' );
ok( ( $m2->{'family'} // '' ) eq 'git-config-leak',
    '/.git/config -> ' . 'git-config-leak'
);
ok( ( $m3->{'family'} // '' ) eq 'wp-admin-probe',
    '/wp-login.php -> ' . 'wp-admin-probe'
);
ok( ( $m4->{'family'} // '' ) eq 'env-credential-scan',
    '/storage/.env -> laravel-storage-env' );
ok( ( $m5->{'family'} // '' ) eq 'phpmyadmin-probe',
    '/phpmyadmin/ -> phpmyadmin-probe' );
ok( ( $m6->{'family'} // '' ) eq 'admin-panel-probe',
    '/manager/html -> admin-panel-probe' );
ok( ( not defined $m7 ), 'legitimate path returns undef' );

##[ 3 : record -- rolling ring, counters, history content ]###################

say ': record';

$data{'httpd'}{'classify'}{'enabled'} = 1;

my $peer = '192.0.2.13';
my $r1   = $code{'httpd.classify.record'}
    ->( $peer, { 'method' => 'GET', 'path' => '/.env', 'status' => 404 } );
my $r2 = $code{'httpd.classify.record'}->(
    $peer, { 'method' => 'GET', 'path' => '/.git/config', 'status' => 404 }
);
my $r3 = $code{'httpd.classify.record'}->(
    $peer, { 'method' => 'GET', 'path' => '/wp-login.php', 'status' => 404 }
);
$code{'httpd.classify.record'}->(
    $peer, { 'method' => 'GET', 'path' => '/clean-page', 'status' => 200 }
);

ok( defined($r1) and defined($r2) and defined($r3),
    'record returns match hashref for classified requests'
);

my $stats = $data{'httpd'}{'classify'}{'stats'};
ok( ( $stats->{'total_requests'}   // 0 ) == 4, 'total_requests == 4' );
ok( ( $stats->{'total_classified'} // 0 ) == 3, 'total_classified == 3' );
ok( ( $stats->{'by_family'}{'env-credential-scan'} // 0 ) == 1,
    'by_family env-credential-scan == 1' );
ok( ( $stats->{'by_family'}{'git-config-leak'} // 0 ) == 1,
    'by_family git-config-leak == 1' );
ok( ( $stats->{'by_family'}{'wp-admin-probe'} // 0 ) == 1,
    'by_family wp-admin-probe == 1' );

my $peer_state = $data{'httpd'}{'classify'}{'peer'}{$peer};
ok( ( $peer_state->{'request_count'} // 0 ) == 4, 'peer request_count == 4' );
ok( scalar( $peer_state->{'ring'}->@* ) == 4,
    'peer ring ' . 'holds 4 entries'
);
ok( defined $peer_state->{'first_seen'}
        and defined $peer_state->{'last_seen'},
    'first_seen / last_seen present'
);

##  ring bound : 70 more requests must leave ring at 64 [ default ]  ##
$code{'httpd.classify.record'}
    ->( $peer, { 'method' => 'GET', 'path' => "/seq-$ARG", 'status' => 200 } )
    foreach 1 .. 70;
ok( scalar( $peer_state->{'ring'}->@* ) == 64,
    'ring bounded ' . 'at ring_size 64'
);

##  ring entries carry no body data, ever  ##
my $ring_dump = join ' ', map { join ' ', %{$ARG} } $peer_state->{'ring'}->@*;
ok( $ring_dump !~ m{password|secret|body|content},
    'ring entries contain no request body fields'
);

##  query strings are stripped before match/store  ##
$code{'httpd.classify.record'}->(
    $peer, { 'method' => 'GET', 'path' => '/.env?x=secret', 'status' => 404 }
);
my $last = $peer_state->{'ring'}[-1];
ok( ( $last->{'path'} // '' ) eq '/.env',
    'query string stripped ' . 'from stored path'
);
ok( ( $last->{'family'} // '' ) eq 'env-credential-scan',
    'match still hits with query string present'
);

##[ 4 : cmd.stats + cmd.history ]#############################################

say ': cmd handlers';

my $stats_reply = invoke_cmd( 'httpd.classify.cmd.stats', '' );
ok( ( $stats_reply->{'mode'} // '' ) eq 'true', 'cmd.stats mode true' );
ok( ( $stats_reply->{'data'} // '' ) =~ m|total classified : 4|,
    'cmd.stats shows classified total' );
ok( ( $stats_reply->{'data'} // '' ) =~ m|peer hash size   : 1|,
    'cmd.stats shows peer_hash_size' );
ok( ( $stats_reply->{'data'} // '' ) =~ m|oldest peer age  : \d+s|,
    'cmd.stats shows oldest_peer_age' );

my $hist_reply = invoke_cmd( 'httpd.classify.cmd.history', $peer );
ok( ( $hist_reply->{'mode'} // '' ) eq 'true', 'cmd.history mode true' );
ok( ( $hist_reply->{'data'} // '' ) =~ m|\[classify=env-credential-scan/|,
    'history shows classify tag' );
ok( ( $hist_reply->{'data'} // '' ) =~ m|status=404|,
    'history shows status code' );

my $hist_none = invoke_cmd( 'httpd.classify.cmd.history', '198.51.100.7' );
ok( ( $hist_none->{'mode'} // '' ) eq 'false',
    'cmd.history false for unknown peer'
);

my $reload_reply = invoke_cmd( 'httpd.classify.cmd.reload-patterns', '' );
ok( ( $reload_reply->{'mode'} // '' ) eq 'true',
    'cmd.reload-patterns ' . 'mode true'
);
ok( ( $reload_reply->{'data'} // '' ) =~ m|7 families|,
    'reload reports ' . '7 families' );
ok( exists $data{'httpd'}{'classify'}{'peer'}{$peer},
    'reload leaves per-peer state untouched'
);

##[ 5 : expire -- ttl + max_peers cap ]#######################################

say ': expire';

##  ttl : age the peer entry past ttl  ##
$peer_state->{'last_seen'} = time - 7200;
$code{'httpd.classify.expire'}->();
ok( ( not exists $data{'httpd'}{'classify'}{'peer'}{$peer} ),
    'ttl eviction removes stale peer' );

##  max_peers cap : fill past a low cap and sweep  ##
$data{'httpd'}{'classify'}{'max_peers'} = 10;
my $now = time;
foreach my $n ( 1 .. 13 ) {
    $data{'httpd'}{'classify'}{'peer'}{"203.0.113.$n"} = {
        'first_seen'    => $now - 100,
        'last_seen'     => $now - $n,    ##  higher n = older  ##
        'request_count' => 1,
        'classified'    => {},
        'ring'          => [],
    };
}
$code{'httpd.classify.expire'}->();
my $remaining = scalar keys $data{'httpd'}{'classify'}{'peer'}->%*;
ok( $remaining == 10, "max_peers cap enforced [ $remaining left ]" );
ok( exists $data{'httpd'}{'classify'}{'peer'}{'203.0.113.1'},
    'cap eviction dropped oldest first [ freshest survived ]'
);

##[ 6 : disabled invariant -- zero presence, all no-ops ]#####################

say ': disabled invariant';

delete $data{'httpd'}{'classify'};
delete $data{'httpd'}{'classify'};    ##  twice : ensure gone  ##

my $m_off = $code{'httpd.classify.match'}->( '/.env', 'GET' );
ok( ( not defined $m_off ), 'match undef when feature branch absent' );
ok( ( not exists $data{'httpd'}{'classify'} ),
    'match does not autovivify <httpd.classify>'
);

my $r_off = $code{'httpd.classify.record'}->(
    '192.0.2.99', { 'method' => 'GET', 'path' => '/.env', 'status' => 404 }
);
ok( ( not defined $r_off ), 'record no-op when disabled' );
ok( ( not exists $data{'httpd'}{'classify'} ),
    'record leaves zero data-tree presence'
);

my $e_off = $code{'httpd.classify.expire'}->();
ok( ( not exists $data{'httpd'}{'classify'} ), 'expire no-op when disabled' );

my $s_off = invoke_cmd( 'httpd.classify.cmd.stats', '' );
ok( ( $s_off->{'mode'} // '' ) eq 'false', 'cmd.stats reports disabled' );
ok( ( not exists $data{'httpd'}{'classify'} ),
    'cmd.stats leaves zero data-tree presence'
);

##[ 7 : enabled + empty library -- no classification side effects ]###########

say ': empty-library invariant';

$data{'httpd'}{'classify'} = {
    'enabled'   => 1,
    'ring_size' => 64,
    'peer_ttl'  => 3600,
    'max_peers' => 10000,
    'peer'      => {},
    'stats'     =>
        { 'total_requests' => 0, 'total_classified' => 0, 'by_family' => {} },
    'library' => {},    ##  empty pattern library  ##
};

my $r_empty = $code{'httpd.classify.record'}->(
    '192.0.2.42', { 'method' => 'GET', 'path' => '/.env', 'status' => 404 }
);
ok( ( not defined $r_empty ),
    'empty library : record returns undef [ no classify tag in log line ]' );
ok( $data{'httpd'}{'classify'}{'stats'}{'total_requests'} == 1,
    'empty library : request still counted' );
ok( $data{'httpd'}{'classify'}{'stats'}{'total_classified'} == 0,
    'empty library : nothing classified' );

## the log-annotation path appends nothing when match is undef, so the     ##
## emitted log line is byte-identical to the disabled case [ verified here ##
## at the exact sprintf used by httpd.request_handler ]                    ##
my $log_disabled = sprintf ' < %s > %s%s', '192.0.2.42', '/.env', '';
my $log_empty    = sprintf ' < %s > %s%s', '192.0.2.42', '/.env',
    ( defined $r_empty ? ' [classify=...]' : '' );
ok( $log_disabled eq $log_empty,
    'log line byte-identical : disabled vs enabled-empty-library' );

##[ 8 : init -- disabled guard and enabled wiring ]###########################

say ': init';

delete $data{'httpd'}{'classify'};
my $init_off = $code{'httpd.classify.init'}->();
ok( not($init_off), 'init returns false when disabled' );
ok( ( not exists $data{'httpd'}{'classify'} ),
    'init leaves zero data-tree presence when disabled'
);
ok( ( not scalar @{ $data{'test'}{'timers'} // [] } ),
    'no timer registered when disabled' );

$data{'httpd'}{'classify'}{'enabled'} = 1;
my $init_on = $code{'httpd.classify.init'}->();
ok( $init_on, 'init returns true when enabled' );
ok( ref $data{'httpd'}{'classify'}{'peer'} eq 'HASH',
    'peer hash ' . 'initialized' );
ok( ( $data{'httpd'}{'classify'}{'ring_size'} // 0 ) == 64,
    'ring_size default applied' );
ok( scalar @{ $data{'test'}{'timers'} // [] } == 1,
    'expire timer ' . 'registered' );
ok( ( $data{'test'}{'timers'}[0]{'handler'} // '' ) eq
        'httpd.classify.expire',
    'timer handler is httpd.classify.expire'
);
ok( ( $data{'base'}{'cmd'}{'classify.stats'} // '' ) eq
        'httpd.classify.cmd.stats',
    'dotted alias classify.stats registered'
);
ok( ( $data{'base'}{'cmd'}{'classify.history'} // '' ) eq
        'httpd.classify.cmd.history',
    'dotted alias classify.history registered'
);
ok( ( $data{'base'}{'cmd'}{'classify.reload'} // '' ) eq
        'httpd.classify.cmd.reload-patterns',
    'dotted alias classify.reload registered'
);
ok( ( not exists $data{'base'}{'cmd'}{'reload'} ),
    'no bare reload collision [ base.cmd.reload untouched ]'
);
ok( scalar keys $data{'httpd'}{'classify'}{'library'}->%* == 7,
    'init preloaded 7 pattern families' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,...,.,,,,.,,,,,,,.,,,,,,.,.,,.,,...,.,,,..,,...,..,,.,.,..,,.,.,,..,...,
#3TSV5KNG2IG5UY7L563INKP7U2EG255WBVYOPSBVQRRSSPRPGLMGR22QIKVL644UZ7A4EJOSWGLSM
#\\\|7N4FAZ5TWEJ262VFWLCAUDUUWQTQRJYZSDKFCN3SLLEBCCPHAG4 \ / AMOS7 \ YOURUM ::
#\[7]OAU6QAJHEFPGMORIYGTFSTVNHCXDOOESG436JILQ5QF4EZ4RKEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
