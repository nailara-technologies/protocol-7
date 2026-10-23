#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## jobsite export-mark + last_export_at sync [ QLK ] : drives the REAL      ##
## plugin.web.jobs.sync / jobsite.sync.apply_reverse /                      ##
## jobsite.handler.sync-response / jobsite.sync.push_chunk on synthetic     ##
## state :                                                                  ##
## - export marks are a newest-wins record pair, the mark time IS the       ##
## exported_at batch epoch ; an unmark arrives as a null pair and is        ##
## stamped with the reception epoch                                         ##
## - an older mark [ stale browser, slower host ] never clobbers a newer    ##
## local mark, on the web side [ single + batch path ] and on the jobsite   ##
## side [ apply_reverse ]                                                   ##
## - marks learned by a jobsite ride its ordinary batch push to every       ##
## sync_url and are re-queued as reverse entries on the receiving web, so   ##
## every connected jobsite learns them too                                  ##
## - last_export_at rides every batch body as prefs, max-merges into the    ##
## web-side relay copy and is handed back in the response for the pushing   ##
## jobsite to adopt [ numeric-newest, same rule as  jobsite.cmd.set-prefs ] ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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

use JSON::XS;
use YAML::XS;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## ---------------------------------------------------------------------- ##
## shared state                                                           ##

my $tmp = tempdir( 'p7-jss-export-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $web_jobs_dir = "$tmp/webjobs";
mkdir $web_jobs_dir or die "mkdir $web_jobs_dir : $OS_ERROR";

$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };
$data{'plugin'}{'web'}{'jobs'}
    = { 'index' => {}, 'cache' => {}, 'reverse' => [] };

my $mem = {};          ## web cache content for cache.read_all             ##
my @posted;            ## captured clients.http.post arguments             ##
my @logged;            ## captured log lines                               ##
my %job_store;         ## jobsite-side job records                          ##
my $client_prefs = {}; ## jobsite-side client prefs blob                    ##

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.cnt_s'}
    = sub { return $ARG[0] == 1 ? '' : 's' };
$code{'base.ntime.b32'}                 = sub { return '42' };
$code{'base.ntime_BASE32_to_numerical'} = sub {
    my $ntime = shift // '';
    return length $ntime ? 0 + $ntime : 0;
};
$code{'base.cfg_bool'} = sub {
    my $value = shift // '';
    return $value =~ m{^(1|yes|true)$}i ? TRUE : FALSE;
};

## format.yaml.load_file contract : list context ( data, err ) , scalar ##
## context data only                                                    ##
$code{'format.yaml.load_file'} = sub {
    my $path = shift // '';
    return ( undef, 'not a file' ) if not length $path or not -f $path;
    my $loaded = eval { YAML::XS::LoadFile($path) };
    return ( undef,   $EVAL_ERROR ) if $EVAL_ERROR;
    return ( $loaded, undef );
};

## web-side stubs                                                          ##
$code{'plugin.web.jobs.cache.path'}     = sub { return $web_jobs_dir };
$code{'plugin.web.jobs.cache.read_all'} = sub { return $mem };
$code{'plugin.web.jobs.cache.write'}    = sub {
    my ( $id, $job ) = @ARG;
    return FALSE if not length $id or ref $job ne 'HASH';
    $mem->{$id} = { %{$job} };
    return TRUE;
};
$code{'plugin.web.jobs.removed_log.append'} = sub { return TRUE };
$code{'plugin.web.jobs.store.prune'}        = sub {return};

## jobsite-side stubs                                                      ##
$code{'jobsite.job.read'}  = sub { return $job_store{ $ARG[0] } };
$code{'jobsite.job.write'} = sub {
    my ( $id, $job ) = @ARG;
    return FALSE if not length $id or ref $job ne 'HASH';
    $job_store{$id} = { %{$job} };
    return TRUE;
};
$code{'jobsite.job.trash'}          = sub { return ( TRUE, 'stubbed' ) };
$code{'jobsite.client_prefs.read'}  = sub { return {%$client_prefs} };
$code{'jobsite.client_prefs.write'} = sub {
    my $prefs = shift // {};
    return FALSE if ref $prefs ne 'HASH';
    $client_prefs = { %{$prefs} };
    return TRUE;
};
$code{'jobsite.state.persist'} = sub { return TRUE };
$code{'clients.http.post'}     = sub {
    my $call = shift // {};
    push @posted, $call;
    return TRUE;
};

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## real modules under test ##
compile_module($_)
    for qw| plugin.web.jobs.prefs.read plugin.web.jobs.prefs.write
    plugin.web.jobs.reverse.queue plugin.web.jobs.reverse.flush
    jobsite.sync.apply_reverse jobsite.handler.sync-response
    jobsite.sync.push_chunk plugin.web.jobs.sync |;

## ---------------------------------------------------------------------- ##
## helpers                                                                ##

sub reset_web_state {
    $mem = {};
    $data{'plugin'}{'web'}{'jobs'}{'reverse'} = [];
    unlink "$web_jobs_dir/jobs-prefs.yaml";
    unlink "$web_jobs_dir/reverse-pending.yaml";
    return;
}

sub web_sync {
    my $payload = shift;
    my $json    = JSON::XS::encode_json($payload);
    return $code{'plugin.web.jobs.sync'}->( { 'args' => $json } );
}

sub web_response {
    my $result = web_sync(shift);
    return JSON::XS::decode_json( $result->{'data'} );
}

sub reverse_entries {
    return $data{'plugin'}{'web'}{'jobs'}{'reverse'};
}

## ========================================================================= ##
say "\n :. browser mark on unmarked job [ single update ]";

reset_web_state();
my $resp = web_response(
    {   'id'             => 'J1',
        'exported_stage' => 'interviewed',
        'exported_at'    => 1000,
    }
);
ok( ( $mem->{'J1'}{'exported_stage'} // '' ) eq 'interviewed',
    'mark applied to cache' );
ok( ( $mem->{'J1'}{'exported_at'} // 0 ) == 1000,
    'exported_at keeps the batch epoch'
);
my @rev = reverse_entries()->@*;
ok( scalar @rev == 1
        && ( $rev[0]{'exported_stage'} // '' ) eq 'interviewed'
        && ( $rev[0]{'exported_at'}    // 0 ) == 1000,
    'reverse entry queued for jobsite'
);
ok( $resp->{'ok'}, 'response ok' );

## ------------------------------------------------------------------------- ##
say "\n :. older browser mark never clobbers a newer local mark";

web_response(
    {   'id'             => 'J1',
        'exported_stage' => 'applied',
        'exported_at'    => 3000,
    }
);
$resp = web_response(
    {   'id'             => 'J1',
        'exported_stage' => 'rejected',
        'exported_at'    => 2000,         ## older than local 3000 ##
    }
);
ok( ( $mem->{'J1'}{'exported_stage'} // '' ) eq 'applied',
    'newer local mark kept' );
ok( scalar reverse_entries()->@* == 2,
    'no reverse entry for the rejected mark [ newer 3000 queued before ]' );

## ------------------------------------------------------------------------- ##
say "\n :. newer browser mark wins";

$resp = web_response(
    {   'id'             => 'J1',
        'exported_stage' => 'rejected',
        'exported_at'    => 4000,
    }
);
ok( ( $mem->{'J1'}{'exported_stage'} // '' ) eq 'rejected',
    'newer mark applied' );

## ------------------------------------------------------------------------- ##
say "\n :. browser unmark arrives as null pair, stamped with reception time";

$resp = web_response(
    {   'id'             => 'J1',
        'exported_stage' => undef,
        'exported_at'    => undef,
    }
);
ok( exists $mem->{'J1'}{'exported_stage'}
        && !defined $mem->{'J1'}{'exported_stage'},
    'mark cleared in cache'
);
ok( ( $mem->{'J1'}{'exported_at'} // 0 ) > 4000,
    'unmark carries a fresh record time'
);
@rev = reverse_entries()->@*;
ok( scalar @rev == 4
        && exists $rev[-1]{'exported_stage'}
        && !defined $rev[-1]{'exported_stage'}
        && ( $rev[-1]{'exported_at'} // 0 ) > 4000,
    'unmark reverse entry carries the clear + its time'
);

## ------------------------------------------------------------------------- ##
say "\n :. batch push merges marks newest-wins + re-queues reverse";

reset_web_state();
$resp = web_response(
    {   'since' => '',
        'jobs'  => [
            {   'id'             => 'J2',
                'status'         => 'review',
                'stage'          => 'review',
                'exported_stage' => 'archived',
                'exported_at'    => 1111
            }
        ],
    }
);
ok( ( $mem->{'J2'}{'exported_stage'} // '' ) eq 'archived',
    'batch mark merged into cache' );
ok( scalar( grep { exists $_->{'exported_stage'} } $resp->{'reverse'}->@* )
        == 1,
    'receiving web re-queues reverse so its jobsite learns the mark'
);

$resp = web_response(
    {   'since' => '',
        'jobs'  => [
            {   'id'             => 'J2',
                'status'         => 'review',
                'stage'          => 'review',
                'exported_stage' => 'skipped',
                'exported_at'    => 999
            }
        ],
    }
);
ok( ( $mem->{'J2'}{'exported_stage'} // '' ) eq 'archived',
    'older batch mark does not clobber' );
ok( scalar $resp->{'reverse'}->@* == 0, 'no re-queue for the skipped mark' );

## batch unmark [ learned via apply_reverse on the pushing jobsite ]      ##
$resp = web_response(
    {   'since' => '',
        'jobs'  => [
            {   'id'             => 'J2',
                'status'         => 'review',
                'stage'          => 'review',
                'exported_stage' => undef,
                'exported_at'    => 2222
            }
        ],
    }
);
ok( exists $mem->{'J2'}{'exported_stage'}
        && !defined $mem->{'J2'}{'exported_stage'}
        && ( $mem->{'J2'}{'exported_at'} // 0 ) == 2222,
    'batch unmark forwarded with its record time'
);
ok( scalar( grep { !defined $_->{'exported_stage'} } $resp->{'reverse'}->@* )
        == 1,
    'unmark re-queued as reverse entry'
);

## ------------------------------------------------------------------------- ##
say "\n :. last_export_at max-merge through the web relay";

reset_web_state();
$resp = web_response(
    {   'since' => '',
        'jobs'  => [],
        'prefs' => { 'last_export_at' => 5000 },
    }
);
ok( ( $resp->{'prefs'}{'last_export_at'} // 0 ) == 5000,
    'newer pref returned in the batch response'
);

$resp = web_response(
    {   'since' => '',
        'jobs'  => [],
        'prefs' => { 'last_export_at' => 4000 },
    }
);
ok( ( $resp->{'prefs'}{'last_export_at'} // 0 ) == 5000,
    'older pref does not regress the relay copy'
);

reset_web_state();
$resp = web_response( { 'since' => '', 'jobs' => [] } );
ok( !exists $resp->{'prefs'}, 'no prefs key while relay copy is empty' );

## ------------------------------------------------------------------------- ##
say "\n :. apply_reverse : newest-wins on the jobsite side";

%job_store = ( 'J5' => { 'stage' => 'review', 'status' => 'review' } );
$code{'jobsite.sync.apply_reverse'}->( [
        {   'id'             => 'J5',
            'exported_stage' => 'interviewed',
            'exported_at'    => 1000
        }
    ]
);
ok( ( $job_store{'J5'}{'exported_stage'} // '' ) eq 'interviewed'
        && ( $job_store{'J5'}{'exported_at'} // 0 ) == 1000,
    'mark applied to jobsite record'
);

$code{'jobsite.sync.apply_reverse'}->(
    [ { 'id' => 'J5', 'exported_stage' => 'applied', 'exported_at' => 900 } ]
);
ok( ( $job_store{'J5'}{'exported_stage'} // '' ) eq 'interviewed',
    'older mark rejected' );

$code{'jobsite.sync.apply_reverse'}->(
    [ { 'id' => 'J5', 'exported_stage' => undef, 'exported_at' => 1500 } ] );
ok( exists $job_store{'J5'}{'exported_stage'}
        && !defined $job_store{'J5'}{'exported_stage'}
        && ( $job_store{'J5'}{'exported_at'} // 0 ) == 1500,
    'unmark applied with its record time'
);

$code{'jobsite.sync.apply_reverse'}->( [
        {   'id'             => 'J5',
            'exported_stage' => 'archived',
            'exported_at'    => 1200
        }
    ]
);
ok( !defined $job_store{'J5'}{'exported_stage'},
    'older mark does not resurrect after the unmark'
);

## ------------------------------------------------------------------------- ##
say "\n :. sync-response adopts a newer last_export_at only";

$client_prefs = { 'last_export_at' => 5000 };
my $body = JSON::XS::encode_json(
    {   'ok'    => JSON::XS::true(),
        'ntime' => '99',
        'prefs' => { 'last_export_at' => 7000 },
    }
);
$code{'jobsite.handler.sync-response'}
    ->( { 'ok' => TRUE, 'body' => $body, 'params' => {} } );
ok( ( $client_prefs->{'last_export_at'} // 0 ) == 7000,
    'newer remote export time adopted' );

$body = JSON::XS::encode_json(
    {   'ok'    => JSON::XS::true(),
        'ntime' => '99',
        'prefs' => { 'last_export_at' => 3000 },
    }
);
$code{'jobsite.handler.sync-response'}
    ->( { 'ok' => TRUE, 'body' => $body, 'params' => {} } );
ok( ( $client_prefs->{'last_export_at'} // 0 ) == 7000,
    'older remote export time ignored' );

## ------------------------------------------------------------------------- ##
say "\n :. push_chunk carries last_export_at on the batch body";

@posted                                = ();
$client_prefs                          = { 'last_export_at' => 6000 };
$data{'jobsite'}{'sync'}{'url_tokens'} = {};
$data{'jobsite'}{'sync'}{'push_queue'} = [
    {   'url'   => 'http://192.0.2.53/jobs-sync',
        'since' => '',
        'chunk' => [],
    }
];
$code{'jobsite.sync.push_chunk'}->();
my $posted_body = JSON::XS::decode_json( $posted[0]{'body'} );
ok( ( $posted_body->{'prefs'}{'last_export_at'} // 0 ) == 6000,
    'prefs on the wire for every chunk and ping' );

@posted                                = ();
$client_prefs                          = {};
$data{'jobsite'}{'sync'}{'push_queue'} = [
    {   'url'   => 'http://192.0.2.53/jobs-sync',
        'since' => '',
        'chunk' => [],
    }
];
$code{'jobsite.sync.push_chunk'}->();
$posted_body = JSON::XS::decode_json( $posted[0]{'body'} );
ok( !exists $posted_body->{'prefs'},
    'no prefs key while the local blob has none' );

## ------------------------------------------------------------------------- ##
## summary                                                                   ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,.,,.,.,...,,.,,,,.,..,,.,,,..,,,..,,,,,..,,...,...,.,.,,,.,,,,,,,.,,.,,
#IZJZPSGNVGNSGR3PSABSONAXRKOPRTKW44OXTROICDP4AR4QJJMHDTQDK52IFC2JQTDULOZ4NGWHC
#\\\|L7ZF2ZZIVA6FCIFUW7I6K5E3E2TVI7S63LGKZS3BDHG6H4JDEGM \ / AMOS7 \ YOURUM ::
#\[7]FJFKA7UFFSWQLZP6K4GH5GW4QM2VMBLIJLGMPSLGTMNZDE7IVOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
