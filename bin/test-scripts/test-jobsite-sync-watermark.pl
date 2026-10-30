#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## jobsite sync watermarks : drives the REAL jobsite.sync.push on synthetic ##
## state :                                                                  ##
## - a url with no per-url watermark gets a FULL push                       ##
## [ a newly added backend only got pings until a manual sync -- live bug ] ##
## - the legacy global watermark migrates to the ONE configured url         ##
## [ unambiguous ] -> incremental push there                                ##
## - a url with a known per-url watermark pushes incrementally              ##
## - with several urls the legacy global value cannot be attributed :       ##
## dropped, every url without its own watermark gets a full push            ##

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

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

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
## stubs                                                                  ##

my @logged;
my @captured_queue;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf( shift, @ARG ) ]; return };
$code{'base.cnt_s'}    = sub { return $ARG[0] == 1 ? '' : 's' };
$code{'base.cfg_bool'} = sub {
    my $value = shift // '';
    return $value =~ m{^(1|yes|true)$}i ? TRUE : FALSE;
};
$code{'base.ntime.b32'}                 = sub { return qw| NCYCLE | };
$code{'base.ntime_BASE32_to_numerical'} = sub {
    my $ntime = shift // '';
    return length $ntime ? 0 + $ntime : 0;
};
$code{'jobsite.job.load_all'} = sub {
    return {
        1 => { 'last_modified' => '2' },
        2 => { 'last_modified' => '4' },
        3 => { 'last_modified' => '5' },
    };
};

$code{'jobsite.replica.enabled'} = sub { return FALSE };

## capture the queue instead of sending chunks ##
$code{'jobsite.sync.push_chunk'} = sub {
    my $queue = $data{'jobsite'}{'sync'}{'push_queue'} // [];
    push @captured_queue, [
        map {
            {%$ARG}
        } $queue->@*
    ];
    delete $data{'jobsite'}{'sync'}{'push_queue'};
    delete $data{'jobsite'}{'sync'}{'push_urls'};
    $data{'jobsite'}{'sync'}{'push_in_progress'} = FALSE;
    return;
};

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## real modules under test ##
compile_module($_)
    for qw| jobsite.sync.token_for_url jobsite.sync.role_for_url |;
compile_module( 'jobsite.sync.push', $module_prefix );

## ---------------------------------------------------------------------- ##
## helpers                                                                ##

sub reset_sync_state {
    $data{'jobsite'}{'sync'} = {};
    $data{'jobsite'}{'cfg'}  = {};
    @captured_queue          = ();
    return;
}

## run one push cycle for the configured urls : returns pushed ids per url ##
sub pushed_ids {
    my %by_url;
    for my $item ( map { $ARG->@* } @captured_queue ) {
        push $by_url{ $item->{'url'} }->@*,
            map { $ARG->{'id'} } $item->{'chunk'}->@*;
    }
    return \%by_url;
}

my $tmp = tempdir( 'p7-jss-watermark-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };

my $URL_A = 'http://127.0.0.1/jobs-sync';
my $URL_B = 'http://192.0.2.53/jobs-sync';

## ---------------------------------------------------------------------- 1 ##
## : known per-url watermark -> incremental                                 ##

say "\n :. per-url watermark";

reset_sync_state();
$data{'jobsite'}{'cfg'}{'sync_urls'} = $URL_A;
$data{'jobsite'}{'sync'}{'last_ntime'}->{$URL_A} = '3';

$code{'jobsite.sync.push'}->( undef, FALSE );

my $ids = pushed_ids();
ok( join( ' ', sort $ids->{$URL_A}->@* ) eq '2 3',
    'known watermark -> only jobs changed since then'
);

## ---------------------------------------------------------------------- 2 ##
## : single url, no per-url watermark, legacy global set -> migration       ##

say "\n :. legacy global watermark migration [ single url ]";

reset_sync_state();
$data{'jobsite'}{'cfg'}{'sync_urls'}          = $URL_A;
$data{'jobsite'}{'sync'}{'last_server_ntime'} = '3';

$code{'jobsite.sync.push'}->( undef, FALSE );

ok( ( $data{'jobsite'}{'sync'}{'last_ntime'}->{$URL_A} // '' ) eq '3',
    'legacy global watermark migrated to the single configured url'
);
$ids = pushed_ids();
ok( join( ' ', sort $ids->{$URL_A}->@* ) eq '2 3',
    'migrated watermark -> incremental push, not a ping'
);

## ---------------------------------------------------------------------- 3 ##
## : single url, no watermark at all -> full push                           ##

say "\n :. no watermark anywhere -> full push";

reset_sync_state();
$data{'jobsite'}{'cfg'}{'sync_urls'} = $URL_A;

$code{'jobsite.sync.push'}->( undef, FALSE );

$ids = pushed_ids();
ok( join( ' ', sort $ids->{$URL_A}->@* ) eq '1 2 3',
    'fresh url receives every job once' );

## ---------------------------------------------------------------------- 4 ##
## : several urls -> legacy global cannot be attributed : dropped           ##

say "\n :. legacy global dropped with several urls [ full push each ]";

reset_sync_state();
$data{'jobsite'}{'cfg'}{'sync_urls'}             = "$URL_A $URL_B";
$data{'jobsite'}{'sync'}{'last_server_ntime'}    = '3';
$data{'jobsite'}{'sync'}{'last_ntime'}->{$URL_B} = '4';

$code{'jobsite.sync.push'}->( undef, FALSE );

## note : the push loop reads                                              ##
## $data{'jobsite'}{'sync'}{'last_ntime'}->{$url}, so the key autovivifies ##
## -- assert it carries no VALUE [ the legacy '3' ]                        ##
ok( ( $data{'jobsite'}{'sync'}{'last_ntime'}->{$URL_A} // '' ) ne '3',
    'global watermark NOT attributed to any url' );
$ids = pushed_ids();
ok( join( ' ', sort $ids->{$URL_A}->@* ) eq '1 2 3',
    'new url in a multi-url set gets a full push'
);
ok( join( ' ', sort $ids->{$URL_B}->@* ) eq '3',
    'known url still pushes incrementally'
);

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,.,,,..,,,,,,,,,,,..,,.,,..,,.,.,,.,,...,..,,...,...,.,,,..,,..,,,,.,.,.,
#YULWGKESRCEB6QDJOVX6ONEPUSBHWZOBLV6XEIHTVYZ3O2TI3RAWWYSTOYBG2DXJHJKSVLZ6OHZLQ
#\\\|LGLOQWUW35JS264FPX77OI5ZYZO5GUM66DSAW7U6YRUEAA3AU3P \ / AMOS7 \ YOURUM ::
#\[7]KZJJIGJ65OJOMV3TYMBIN3H2QBTDESMIXXTPVBGWDMNRBDH4QKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
