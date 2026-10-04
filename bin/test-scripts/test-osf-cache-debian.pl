#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;
## same default layer bin/Protocol-7 sets : modules compiled below by
## string eval inherit it -> binary reads must ask for :raw themselves ##
use open qw| :encoding(UTF-8) |;
## bin/Protocol-7 also imports File::stat [ object-returning stat ] ##
use File::stat;

###                                                                  ###
##  osf-cache : debian index readers + holdings scan + hash lookup   ##
###                                                                  ###

## exercises the real translated module sources against small fixtures in   ##
## bin/test-scripts/fixtures/osf-cache/ - no live zenka required :          ##
## - InRelease header + checksum section parse, signature not good          ##
## - Packages streaming parse into the by_anchor index                      ##
## - anchoring : correct expect anchors, wrong one does not                 ##
## - sha512-only fixture pair : SHA512 section + SHA512 stanza fields       ##
## - apt cache scan : listed .deb anchored, unlisted not, ONE pass per file ##
## computes every index algo plus bmw384 [ B32 ]                            ##
## - hash layers : anchors are '<algo>:<hex>' everywhere, bmw384 is the     ##
## protocol-7 internal id carried beside the size                           ##
## - large index streaming : generated 20k-stanza file read line-wise       ##

use File::Spec;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use Digest::SHA ();
use Digest::MD5 ();
use Crypt::Misc qw| encode_b32r |;
use File::Temp  qw| tempdir |;

## base.chk-sum.bmw.384.B32 calls it fully qualified ##
require Digest::BMW;

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    ## .cmd. modules get the loader's $call header [ bin/Protocol-7 ] ##
    $translated
        = "my \$call = ref( \$ARG[0] ) eq q|HASH| "
        . "? \$ARG[0] : { args => \$ARG[0] };\n"
        . "my \$reply = { mode => q|false|, data => q|| };\n"
        . $translated
        if $module_name =~ m{\.cmd\.};
    my $cref = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module('osf-cache.debian.read_inrelease');
compile_module('osf-cache.debian.read_packages');
compile_module('osf-cache.holdings.scan_apt_cache');
compile_module('osf-cache.holdings.scan_file');
compile_module('osf-cache.holdings.state_save');
compile_module('osf-cache.holdings.state_load');
compile_module('osf-cache.lookup.query_local');
compile_module('osf-cache.lookup.format_has_reply');
compile_module('osf-cache.lookup.parse_has_reply');
compile_module('osf-cache.lookup.merge_replies');
compile_module('osf-cache.index.build');
compile_module('osf-cache.init_code');
compile_module('osf-cache.startup');
compile_module('osf-cache.cmd.has');
compile_module('osf-cache.cmd.status');
compile_module('osf-cache.cmd.rescan');
compile_module('osf-cache.holdings.rescan_step');
compile_module('osf-cache.peers.list');
compile_module('osf-cache.handler.peers_list');
compile_module('osf-cache.cmd.lookup');
compile_module('osf-cache.lookup.with_peers');
compile_module('osf-cache.handler.has_reply');
compile_module('osf-cache.lookup.complete');
compile_module('osf-cache.lookup.format_lookup_reply');
compile_module('osf-cache.lookup.timeout');
compile_module('format.yaml.pre_init');
compile_module('format.yaml.write_file');
compile_module('format.yaml.load_file');

## the bmw wrappers are files named base.* ; the modules call the short   ##
## chk-sum.bmw.* names [ base.chk-sum.bmw.pre_init aliases the family via ##
## swap_subs in the zenka ] - register them under the short names         ##

compile_module('base.chk-sum.bmw.encode_digest');
$code{'chk-sum.bmw.encode_digest'} = $code{'base.chk-sum.bmw.encode_digest'};
compile_module('base.chk-sum.bmw.384.B32');
$code{'chk-sum.bmw.384.B32'} = $code{'base.chk-sum.bmw.384.B32'};

##[ format.yaml wiring [ standalone stubs ] ]#################################
##                                                                          ##
## the format.yaml wrappers resolve their dependencies through the p7 call  ##
## syntax : %code entries for <[base.*]> calls and %data for                ##
## <format.yaml.*> values. the zenka provides the real ones ; here they are ##
## minimal standalone stubs. pre_init must run once before the first        ##
## write_file / load_file call.                                             ##

$code{'base.perlmod.autoload'} = sub {
    my $module = shift // return undef;
    eval "require $module" or die $EVAL_ERROR;
    return 5;
};

$code{'base.logs'} = sub {
    my $level  = shift;
    my $format = shift // '';
    push @{ $data{'test'}{'logs'} }, sprintf $format, @_;
    return 5;
};

$code{'base.log'} = sub {
    my $level  = shift;
    my $format = shift // '';
    push @{ $data{'test'}{'logs'} }, sprintf $format, @_;
    return 5;
};

$code{'base.buffer.add_line'} = sub {
    my ( $buffer_name, $line ) = @ARG;
    push @{ $data{'test'}{'buffer_lines'} }, "$buffer_name : $line";
    return 5;
};

$code{'base.str.eval_error'} = sub {
    my $error = $EVAL_ERROR // '';
    $error =~ s|\s*\n.*||s;
    $error =~ s|\s+$||;
    return $error;
};

call_module('format.yaml.pre_init');

## stage 2b : the zenka flow modules need these two stubs as well ##
my $zenka_data_dir = tempdir( CLEANUP => 1 );

$code{'file.zenka_dir.data_path'} = sub {
    return $zenka_data_dir;
};

## watcher stub with the Event->timer interface the modules use [ data, ##
## cancel, is_active ] - fire_timer below invokes the handler like the  ##
## event loop would [ my \$event = shift ; \$event->w->data ]            ##
package TestWatcher;
use English;

sub new {
    my ( $class, $params ) = @ARG;
    return bless { 'params' => $params, 'cancelled' => 0 }, $class;
}

sub data       { return $ARG[0]->{'params'}{'data'} }
sub cancel     { $ARG[0]->{'cancelled'} = 1; return }
sub is_active  { return !$ARG[0]->{'cancelled'} }
sub cancelled  { return $ARG[0]->{'cancelled'} }

## the event object a timer handler receives : $event->w is the watcher ##
package TestEvent;
use English;

sub w { return $ARG[0]->{'w'} }

package main;

$code{'event.add_timer'} = sub {
    my $params  = shift // {};
    my $watcher = TestWatcher->new($params);
    push @{ $data{'test'}{'timers'} },   $params;
    push @{ $data{'test'}{'watchers'} }, $watcher;
    return $watcher;
};

## stage 2c : route-send, id generation and the deferred-reply callback ##
$code{'protocol-7.route-send'} = sub {
    my $params = shift // {};
    push @{ $data{'test'}{'route_sends'} }, $params;
    return 1;
};

$code{'base.gen_id'} = sub {
    return ++$data{'test'}{'gen_id'};
};

## mirrors base.callback.cmd_reply : emits the reply and deletes the    ##
## <base.cmd_reply> pending entry itself                                ##
$code{'base.callback.cmd_reply'} = sub {
    my ( $reply_id, $reply ) = @ARG;
    $data{'test'}{'cmd_replies'}{$reply_id} = $reply;
    delete $data{'base'}{'cmd_reply'}{$reply_id};
    return 5;
};

sub call_module {
    my ( $module_name, $params ) = @ARG;
    return $code{$module_name}->($params);
}

sub fixture_path {
    my $name = shift;
    return File::Spec->catfile( $RealBin, 'fixtures', 'osf-cache', $name );
}

sub slurp_file {
    my $path = shift;
    open( my $fh, '<', $path ) or die "cannot read $path : $OS_ERROR";
    my $content = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
    close($fh);
    return $content;
}

sub write_fixture {
    my ( $path, $content ) = @ARG;
    open( my $fh, '>', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close($fh);
}

##[ stage 2c : fake event-loop helpers ]######################################

## invoke a timer handler the way the event loop would : my $event = shift ##
sub fire_timer {
    my $watcher = shift;
    my $params  = $watcher->{'params'};
    my $event   = bless { 'w' => $watcher }, 'TestEvent';
    return $code{ $params->{'handler'} }->($event);
}

## deliver a reply to a recorded route-send [ process_reply shape ] ##
sub deliver_reply {
    my ( $send, $reply ) = @ARG;
    my $handler = $send->{'reply'}{'handler'} // return;
    return $code{$handler}->(
        {   'sid'       => 7,
            'cmd'       => $reply->{'cmd'},
            'data'      => $reply->{'data'},
            'call_args' => { 'args' => $reply->{'args'} // '' },
            'params'    => $send->{'reply'}{'params'} // {},
        }
    );
}

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ fixture materialization [ runtime hashes ] ]##############################
##                                                                          ##
## the commit-time signing tool appends an AMOS7 DATA SIGNATURE footer to   ##
## every tracked file - including these fixtures - so any digest baked into ##
## a committed fixture goes stale on the next re-sign. the fixtures carry   ##
## @PLACEHOLDERS@ instead ; the real values are computed here at runtime    ##
## and substituted - Packages first, then InRelease [ whose hashes cover    ##
## the substituted Packages content ]. the sha512-only pair is built the    ##
## same way, one directory later.                                           ##

my $fix_dir = tempdir( CLEANUP => 1 );

my $hello_deb_path = fixture_path('fake-hello_2.12.3-1_amd64.deb');
my $hello_content  = slurp_file($hello_deb_path);
my $hello_size     = -s $hello_deb_path;
my $hello_md5      = Digest::MD5::md5_hex($hello_content);
my $hello_sha256   = Digest::SHA::sha256_hex($hello_content);
my $hello_sha512   = Digest::SHA::sha512_hex($hello_content);

## bmw384 reference through the in-memory module [ checked against the scan ##
## result below ; both must match ]                                         ##
my $hello_bmw384 = $code{'chk-sum.bmw.384.B32'}->( \$hello_content );

my $packages_path = "$fix_dir/fixture_Packages";
{
    my $packages_tpl = slurp_file( fixture_path('fixture_Packages') );
    $packages_tpl =~ s{\@DEB_SIZE\@}{$hello_size}g;
    $packages_tpl =~ s{\@DEB_MD5\@}{$hello_md5}g;
    $packages_tpl =~ s{\@DEB_SHA256\@}{$hello_sha256}g;
    write_fixture( $packages_path, $packages_tpl );
}

my $packages_size   = -s $packages_path;
my $packages_md5    = Digest::MD5::md5_hex( slurp_file($packages_path) );
my $packages_sha1   = Digest::SHA::sha1_hex( slurp_file($packages_path) );
my $packages_sha256 = Digest::SHA::sha256_hex( slurp_file($packages_path) );

my $inrelease_path = "$fix_dir/fixture_InRelease";
{
    my $inrelease_tpl = slurp_file( fixture_path('fixture_InRelease') );
    $inrelease_tpl =~ s{\@PACKAGES_MD5\@}{$packages_md5}g;
    $inrelease_tpl =~ s{\@PACKAGES_SHA1\@}{$packages_sha1}g;
    $inrelease_tpl =~ s{\@PACKAGES_SHA256\@}{$packages_sha256}g;
    $inrelease_tpl =~ s{\@PACKAGES_SIZE\@}{$packages_size}g;
    write_fixture( $inrelease_path, $inrelease_tpl );
}

## the sha512-only fixture pair anchors the same fixture .deb ##

my $packages512_path = "$fix_dir/fixture_Packages_sha512only";
{
    my $tpl = slurp_file( fixture_path('fixture_Packages_sha512only') );
    $tpl =~ s{\@DEB_SIZE\@}{$hello_size}g;
    $tpl =~ s{\@DEB_SHA512\@}{$hello_sha512}g;
    write_fixture( $packages512_path, $tpl );
}

my $packages512_size = -s $packages512_path;
my $packages512_sha512
    = Digest::SHA::sha512_hex( slurp_file($packages512_path) );

my $inrelease512_path = "$fix_dir/fixture_InRelease_sha512only";
{
    my $tpl = slurp_file( fixture_path('fixture_InRelease_sha512only') );
    $tpl =~ s{\@PACKAGES_SHA512\@}{$packages512_sha512}g;
    $tpl =~ s{\@PACKAGES_SIZE\@}{$packages512_size}g;
    write_fixture( $inrelease512_path, $tpl );
}

##[ 1 : InRelease parse + signature verdict ]#################################

say ': InRelease parse + signature';

## the B32 alphabet encode_b32r emits, checked against a REAL digest - RFC ##
## 4648 [ A-Z 2-7 ], unpadded, 77 chars for a bmw384 : never guessed       ##
my $abc_bmw_b32 = encode_b32r( Digest::BMW::bmw_384('abc') );

ok( $abc_bmw_b32 =~ m|^[A-Z2-7]{77}$|o,
    'bmw384 B32 alphabet verified against a real digest [ A-Z 2-7, 77 ]' );

my $ir = call_module( 'osf-cache.debian.read_inrelease',
    { 'path' => $inrelease_path } );

ok( ref $ir eq qw| HASH | && $ir->{'mode'} eq qw| true |, 'mode true' );

my $ir_data = $ir->{'data'} // {};

ok( ( $ir_data->{'origin'}   // '' ) eq qw| FixtureOS |, 'origin parsed' );
ok( ( $ir_data->{'suite'}    // '' ) eq qw| stable |,    'suite parsed' );
ok( ( $ir_data->{'codename'} // '' ) eq qw| fixture |,   'codename parsed' );
ok( ( $ir_data->{'date'}     // '' ) eq 'Fri, 02 Oct 2026 20:13:57 UTC',
    'date parsed' );
ok( ( $ir_data->{'valid_until'} // '' ) eq 'Fri, 09 Oct 2026 20:13:57 UTC',
    'valid-until parsed' );

my $ir_files = $ir_data->{'files'} // {};

ok( scalar keys %$ir_files == 1, 'exactly one sha256 section entry' );

my $ir_entry = $ir_files->{'main/binary-amd64/Packages'} // {};

ok( ( $ir_entry->{'algo'} // '' ) eq qw| sha256 |,
    'entry carries its algo [ sha256 ]'
);
ok( ( $ir_entry->{'hash'} // '' ) eq $packages_sha256,
    'Packages relpath anchored to the runtime-computed sha256'
);
ok( ( $ir_entry->{'size'} // 0 ) == $packages_size, 'Packages size parsed' );

ok( ( $ir_data->{'signature'} // '' ) ne qw| good |,
    'fixture signature is not good [ bad or unverified ]'
);
ok( defined $ir_data->{'signature'}
        && $ir_data->{'signature'} =~ m{^(?:bad|unverified)$},
    "signature verdict is '$ir_data->{'signature'}'"
);

my $ir_missing = call_module(
    'osf-cache.debian.read_inrelease',
    { 'path' => fixture_path('no-such-file') }
);

ok( ref $ir_missing eq qw| HASH | && $ir_missing->{'mode'} eq qw| false |,
    'missing file returns mode false' );

##[ 2 : Packages streaming parse + anchor index ]#############################

say ': Packages streaming parse';

my $pr = call_module( 'osf-cache.debian.read_packages',
    { 'path' => $packages_path } );

ok( ref $pr eq qw| HASH | && $pr->{'mode'} eq qw| true |, 'mode true' );

my $pr_data = $pr->{'data'} // {};

ok( ( $pr_data->{'entries'} // 0 ) == 3, 'three stanzas indexed' );
ok( ( $pr_data->{'file_sha256'} // '' ) eq $packages_sha256,
    'computed file sha256 matches reference digest'
);
ok( ( $pr_data->{'file_sha512'} // '' ) eq
        Digest::SHA::sha512_hex( slurp_file($packages_path) ),
    'computed file sha512 matches reference digest'
);
ok( ( $pr_data->{'anchored'} // 1 ) == 0, 'anchored 0 without expect' );

my $by_anchor = $pr_data->{'by_anchor'} // {};
ok( scalar keys %$by_anchor == 3, 'index holds three anchor keys' );

ok( join( ',', @{ $pr_data->{'algos'} // [] } ) eq qw| sha256 |,
    'algos lists the sorted algos seen' );

my $hello = $by_anchor->{"sha256:$hello_sha256"} // {};

ok( ( $hello->{'package'} // '' ) eq qw| hello |
        && ( $hello->{'version'}      // '' ) eq '2.12.3-1'
        && ( $hello->{'architecture'} // '' ) eq qw| amd64 |
        && ( $hello->{'filename'}     // '' ) eq
        'pool/main/h/hello/hello_2.12.3-1_amd64.deb'
        && ( $hello->{'size'} // '' ) eq $hello_size,
    'hello entry : package, version, arch, filename, size'
);

ok( exists $by_anchor->{
              'sha256:aabbccddeeff0011223344556677'
            . '8899aabbccddeeff00112233445566778899'
        }
        && (
        $by_anchor->{
                  'sha256:aabbccddeeff0011223344556677'
                . '8899aabbccddeeff00112233445566778899'
        } // {}
        )->{'package'} eq qw| goodbye |,
    'goodbye entry indexed by its anchor token'
);

#,,,,,,..,,,.,..,,..,,.,.,,,.,...,,,,,.,.,..,,..,,...,...,...,..,,.,.,...,...,
#DHS7UCBOIFRG3TMFGCWM5EEZIP576PFQG7C3CXZAYN2J5DUW2VUGARGZLIZDQ5PSAX3S3Q6RIK3EM
#\\\|OZJWLRB2QRC2KX5H7FV2HNUBKUP3DFL2GK7UGR5IJW6A2ZVH753 \ / AMOS7 \ YOURUM ::
#\[7]5TC2YAM7O3E5VV4BNTIS3BGJUACB5SOZMEMTOPLZ5DKIYCJ2WEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

##[ 3 : anchoring against the InRelease hash ]################################

say ': anchoring';

my $pr_anchored = call_module(
    'osf-cache.debian.read_packages',
    {   'path'   => $packages_path,
        'expect' => {
            'algo' => $ir_entry->{'algo'},
            'hash' => $ir_entry->{'hash'},
        },
    }
);

ok( $pr_anchored->{'mode'} eq qw| true |
        && $pr_anchored->{'data'}{'anchored'} == 1,
    'anchored 1 when the digest of the expect algo matches'
);

my $pr_wrong = call_module(
    'osf-cache.debian.read_packages',
    {   'path'   => $packages_path,
        'expect' => { 'algo' => qw| sha256 |, 'hash' => ( 'f' x 64 ) },
    }
);

ok( $pr_wrong->{'mode'} eq qw| true | && $pr_wrong->{'data'}{'anchored'} == 0,
    'anchored 0 on tampered expect hash'
);

my $pr_512 = call_module(
    'osf-cache.debian.read_packages',
    {   'path'   => $packages_path,
        'expect' => {
            'algo' => qw| sha512 |,
            'hash' => Digest::SHA::sha512_hex( slurp_file($packages_path) ),
        },
    }
);

ok( $pr_512->{'mode'} eq qw| true | && $pr_512->{'data'}{'anchored'} == 1,
    'anchored 1 when expect carries the file sha512' );

##[ 4 : sha512-only fixture pair ]############################################

say ': sha512-only fixture pair';

my $ir512 = call_module( 'osf-cache.debian.read_inrelease',
    { 'path' => $inrelease512_path } );

my $ir512_entry = $ir512->{'data'}{'files'}->{'main/binary-amd64/Packages'}
    // {};

ok( $ir512->{'mode'} eq qw| true |
        && ( $ir512_entry->{'algo'} // '' ) eq qw| sha512 |
        && ( $ir512_entry->{'hash'} // '' ) eq $packages512_sha512
        && ( $ir512_entry->{'size'} // 0 ) == $packages512_size,
    'sha512-only InRelease : entry carries algo sha512 + runtime hash'
);

my $pr512 = call_module( 'osf-cache.debian.read_packages',
    { 'path' => $packages512_path } );

my $by_anchor512 = $pr512->{'data'}{'by_anchor'} // {};

ok( $pr512->{'mode'} eq qw| true |
        && ( $by_anchor512->{"sha512:$hello_sha512"} // {} )->{'package'} eq
        qw| hello |,
    'sha512-only Packages : hello indexed under its sha512 anchor'
);

ok( join( ',', @{ $pr512->{'data'}{'algos'} // [] } ) eq qw| sha512 |,
    'sha512-only Packages : algos lists sha512' );

my $pr512_anchored = call_module(
    'osf-cache.debian.read_packages',
    {   'path'   => $packages512_path,
        'expect' => {
            'algo' => $ir512_entry->{'algo'},
            'hash' => $ir512_entry->{'hash'},
        },
    }
);

ok( $pr512_anchored->{'data'}{'anchored'} == 1,
    'sha512-only pair anchors with its own sha512'
);

## and the scan anchors the fixture .deb through the sha512 token ##

my $s512_dir = tempdir( CLEANUP => 1 );
foreach my $deb_name (
    qw|
    fake-hello_2.12.3-1_amd64.deb
    igt-gpu-tools_2.5-1_amd64.deb
    |
) {
    symlink fixture_path($deb_name), "$s512_dir/$deb_name"
        or die "symlink failed : $OS_ERROR";
}

my $scan512 = call_module(
    'osf-cache.holdings.scan_apt_cache',
    {   'dir'   => $s512_dir,
        'index' => {
            'anchors' => $by_anchor512,
            'algos'   => [qw| sha512 |],
        },
    }
);

my %s512_by_name
    = map { $ARG->{'name'} => $ARG } @{ $scan512->{'data'}{'files'} };

ok( ( $s512_by_name{'fake-hello_2.12.3-1_amd64.deb'}{'anchor'} // '' ) eq
        "sha512:$hello_sha512"
        && $s512_by_name{'fake-hello_2.12.3-1_amd64.deb'}{'anchored'} == 1,
    'scan anchors the fixture .deb through the sha512 token'
);

ok( !defined $s512_by_name{'igt-gpu-tools_2.5-1_amd64.deb'}{'anchor'}
        && $s512_by_name{'igt-gpu-tools_2.5-1_amd64.deb'}{'anchored'} == 0,
    'the unanchored .deb stays unanchored under the sha512 index'
);

##[ 5 : holdings scan over a fixture cache dir ]##############################

say ': holdings scan';

my $tmp_dir = tempdir( CLEANUP => 1 );

foreach my $deb_name (
    qw|
    fake-hello_2.12.3-1_amd64.deb
    igt-gpu-tools_2.5-1_amd64.deb
    |
) {
    symlink fixture_path($deb_name), "$tmp_dir/$deb_name"
        or die "symlink failed : $OS_ERROR";
}

## a flat anchor map exercises the index shape normalization ##
my $scan = call_module(
    'osf-cache.holdings.scan_apt_cache',
    { 'dir' => $tmp_dir, 'index' => $by_anchor }
);

ok( ref $scan eq qw| HASH | && $scan->{'mode'} eq qw| true |, 'mode true' );

my $scan_data = $scan->{'data'} // {};
my %by_name   = map { $ARG->{'name'} => $ARG } $scan_data->{'files'}->@*;

ok( scalar keys %by_name == 2, 'two .deb files scanned' );

my $hello_deb = $by_name{'fake-hello_2.12.3-1_amd64.deb'} // {};
ok( ( $hello_deb->{'anchored'} // 0 ) == 1
        && ( $hello_deb->{'anchor'}  // '' ) eq "sha256:$hello_sha256"
        && ( $hello_deb->{'package'} // '' ) eq qw| hello |
        && ( $hello_deb->{'version'} // '' ) eq '2.12.3-1',
    'listed .deb anchored under its sha256 anchor token'
);

ok( ( $hello_deb->{'digests'}{'sha256'} // '' ) eq $hello_sha256,
    'one pass records the sha256 digest' );

ok( defined $hello_deb->{'digests'}{'bmw384'}
        && $hello_deb->{'digests'}{'bmw384'} eq $hello_bmw384,
    'bmw384 of the fixture .deb matches <[chk-sum.bmw.384.B32]>'
);

my $igt_deb = $by_name{'igt-gpu-tools_2.5-1_amd64.deb'} // {};
ok( ( $igt_deb->{'anchored'} // 1 ) == 0
        && !defined $igt_deb->{'anchor'}
        && ( $igt_deb->{'package'} // '' ) eq qw| igt-gpu-tools |
        && ( $igt_deb->{'version'} // '' ) eq '2.5-1',
    'unlisted .deb not anchored, name parsed from file name'
);

ok( ( $igt_deb->{'digests'}{'bmw384'} // '' ) =~ m|^[A-Z2-7]{77}$|o,
    'unanchored .deb still carries its bmw384 internal id'
);

ok( ( $scan_data->{'anchored_count'} // 0 ) == 1, 'anchored_count is 1' );
ok( ( $scan_data->{'total_bytes'} // 0 )
        == ( $hello_deb->{'size'} // 0 ) + ( $igt_deb->{'size'} // 0 ),
    'total_bytes is the sum of both files'
);
ok( ( $scan_data->{'anchored_bytes'} // 0 ) == ( $hello_deb->{'size'} // 0 ),
    'anchored_bytes is the listed .deb only'
);

my $scan_missing = call_module( 'osf-cache.holdings.scan_apt_cache',
    { 'dir' => "$tmp_dir/no-such-dir", 'index' => $by_anchor } );

ok( ref $scan_missing eq qw| HASH | && $scan_missing->{'mode'} eq qw| false |,
    'missing cache dir returns mode false'
);

##[ 6 : large index streaming path ]##########################################

say ': large index streaming';

my $large_path    = "$tmp_dir/large_Packages";
my $large_stanzas = 20000;
{
    open( my $lfh, '>', $large_path ) or die $OS_ERROR;
    foreach my $n ( 1 .. $large_stanzas ) {
        printf $lfh "Package: generated-%05d\n", $n;
        print $lfh "Version: 1.0-$n\n",
            "Architecture: amd64\n",
            "Filename: pool/main/g/generated/generated_$n\_amd64.deb\n",
            "Size: 1000\n",
            "SHA256: ",
            substr( Digest::SHA::sha256_hex("payload-$n"), 0, 64 ),
            "\n\n";
    }
    close($lfh);
}

my $large_sha256 = Digest::SHA::sha256_hex( slurp_file($large_path) );

my $lr = call_module( 'osf-cache.debian.read_packages',
    { 'path' => $large_path } );

ok( $lr->{'mode'} eq qw| true | && $lr->{'data'}{'entries'} == $large_stanzas,
    "$large_stanzas stanzas streamed and indexed"
);
ok( ( $lr->{'data'}{'file_sha256'} // '' ) eq $large_sha256,
    'large file sha256 matches reference digest'
);
ok( scalar keys %{ $lr->{'data'}{'by_anchor'} } == $large_stanzas,
    'large index holds one anchor key per stanza' );

my $large_index = $lr->{'data'}{'by_anchor'};

my $lr_anchored = call_module(
    'osf-cache.debian.read_packages',
    {   'path'   => $large_path,
        'expect' => { 'algo' => qw| sha256 |, 'hash' => $large_sha256 },
    }
);

ok( $lr_anchored->{'data'}{'anchored'} == 1,
    'large file anchored with its own hash'
);

my $large_scan = call_module( 'osf-cache.holdings.scan_apt_cache',
    { 'dir' => $tmp_dir, 'index' => $large_index } );

ok( $large_scan->{'mode'} eq qw| true |,
    'holdings scan runs against large index'
);

##[ 7 : stage 2 - incremental scan ]##########################################

say ': stage 2 - incremental scan';

my $s2_dir = tempdir( CLEANUP => 1 );

my %s2_content = (
    'aa-pkg_1.0-1_amd64.deb' => 'aa-package-content',
    'bb-pkg_2.0-1_amd64.deb' => 'bb-package-content',
);
foreach my $deb_name ( sort keys %s2_content ) {
    open( my $dfh, '>', "$s2_dir/$deb_name" ) or die $OS_ERROR;
    print {$dfh} $s2_content{$deb_name};
    close($dfh);
}

my $aa_sha256
    = Digest::SHA::sha256_hex( $s2_content{'aa-pkg_1.0-1_amd64.deb'} );
my $aa_sha512
    = Digest::SHA::sha512_hex( $s2_content{'aa-pkg_1.0-1_amd64.deb'} );
my $aa_bmw384 = $code{'chk-sum.bmw.384.B32'}
    ->( \$s2_content{'aa-pkg_1.0-1_amd64.deb'} );

my %s2_index = ( "sha256:$aa_sha256" =>
        { 'package' => qw| aa-pkg |, 'version' => '1.0-1' }, );

my $s2_scan1 = call_module(
    'osf-cache.holdings.scan_apt_cache',
    { 'dir' => $s2_dir, 'index' => \%s2_index }
);

ok( $s2_scan1->{'mode'} eq qw| true | && $s2_scan1->{'data'}{'rehashed'} == 2,
    'first scan rehashes both files'
);

my %s2_by_name
    = map { $ARG->{'name'} => $ARG } @{ $s2_scan1->{'data'}{'files'} };

ok( ( $s2_by_name{'aa-pkg_1.0-1_amd64.deb'}{'mtime'} // 0 ) > 0
        && ( $s2_by_name{'aa-pkg_1.0-1_amd64.deb'}{'ctime'} // 0 ) > 0
        && length( $s2_by_name{'aa-pkg_1.0-1_amd64.deb'}{'inode'} // '' ),
    'entries carry mtime, ctime and inode'
);

my $s2_scan2 = call_module(
    'osf-cache.holdings.scan_apt_cache',
    {   'dir'      => $s2_dir,
        'index'    => \%s2_index,
        'previous' => $s2_scan1->{'data'}{'files'},
    }
);

ok( $s2_scan2->{'data'}{'rehashed'} == 0,
    'second scan rehashes 0 [ digests reused ]'
);

my %s2_by_name2
    = map { $ARG->{'name'} => $ARG } @{ $s2_scan2->{'data'}{'files'} };

ok( ( $s2_by_name2{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'sha256'} // '' ) eq
        $aa_sha256
        && ( $s2_by_name2{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'bmw384'}
        // '' ) eq $aa_bmw384,
    'reused digests match the first scan'
);

sleep 1;
utime( time, time, "$s2_dir/bb-pkg_2.0-1_amd64.deb" )
    or die "utime failed : $OS_ERROR";

my $s2_scan3 = call_module(
    'osf-cache.holdings.scan_apt_cache',
    {   'dir'      => $s2_dir,
        'index'    => \%s2_index,
        'previous' => $s2_scan1->{'data'}{'files'},
    }
);

ok( $s2_scan3->{'data'}{'rehashed'} == 1, 'touched file rehashes exactly 1' );

## an index that needs an algo the previous entry lacks -> rehash all ##
my %s2_index_both = (
    "sha256:$aa_sha256" =>
        { 'package' => qw| aa-pkg |, 'version' => '1.0-1' },
    "sha512:$aa_sha512" =>
        { 'package' => qw| aa-pkg |, 'version' => '1.0-1' },
);

my $s2_scan_wide = call_module(
    'osf-cache.holdings.scan_apt_cache',
    {   'dir'      => $s2_dir,
        'index'    => \%s2_index_both,
        'previous' => $s2_scan1->{'data'}{'files'},
    }
);

ok( $s2_scan_wide->{'data'}{'rehashed'} == 2,
    'index needing a new algo rehashes every file lacking it' );

my %s2_wide_by_name
    = map { $ARG->{'name'} => $ARG } @{ $s2_scan_wide->{'data'}{'files'} };

ok( ( $s2_wide_by_name{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'sha512'} // '' )
        eq $aa_sha512,
    'the wide index records the sha512 digest'
);

## the current index decides anchoring - never the previous state ##
my $s2_scan4 = call_module(
    'osf-cache.holdings.scan_apt_cache',
    {   'dir'      => $s2_dir,
        'index'    => {},
        'previous' => $s2_scan3->{'data'}{'files'},
    }
);

my %s2_by_name4
    = map { $ARG->{'name'} => $ARG } @{ $s2_scan4->{'data'}{'files'} };

ok( $s2_scan4->{'data'}{'rehashed'} == 0
        && ( $s2_by_name4{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'sha256'}
        // '' ) eq $aa_sha256,
    'hash still reused when the index no longer carries it'
);

ok( ( $s2_by_name4{'aa-pkg_1.0-1_amd64.deb'}{'anchored'} // 1 ) == 0
        && !defined $s2_by_name4{'aa-pkg_1.0-1_amd64.deb'}{'anchor'},
    'previously anchored file becomes unanchored when the index changed'
);

##[ 8 : stage 2 - state save / load ]#########################################

say ': stage 2 - state save / load';

my $state_path = "$s2_dir/holdings-state.yaml";

my $saved = call_module(
    'osf-cache.holdings.state_save',
    {   'path'     => $state_path,
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( ref $saved eq qw| HASH | && $saved->{'mode'} eq qw| true |,
    'state save mode true' );

my $loaded = call_module( 'osf-cache.holdings.state_load',
    { 'path' => $state_path } );

my $loaded_holdings = $loaded->{'data'}{'holdings'} // {};
my %loaded_by_name
    = map { $ARG->{'name'} => $ARG } @{ $loaded_holdings->{'files'} // [] };

ok( $loaded->{'mode'} eq qw| true |
        && ( $loaded_holdings->{'anchored_count'} // -1 ) == 1
        && ( $loaded_by_name{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'sha256'}
        // '' ) eq $aa_sha256
        && ( $loaded_by_name{'aa-pkg_1.0-1_amd64.deb'}{'digests'}{'bmw384'}
        // '' ) eq $aa_bmw384,
    'state round trip preserves the scan result incl. bmw384'
);

my $loaded_missing = call_module( 'osf-cache.holdings.state_load',
    { 'path' => "$s2_dir/no-such-state.yaml" } );

ok( ref $loaded_missing eq qw| HASH |
        && $loaded_missing->{'mode'} eq qw| true |
        && ref $loaded_missing->{'data'}{'holdings'} eq qw| HASH |
        && scalar keys %{ $loaded_missing->{'data'}{'holdings'} } == 0,
    'missing state file -> mode true with empty holdings'
);

my $corrupt_path = "$s2_dir/corrupt-state.yaml";
write_fixture( $corrupt_path, "not yaml: [unclosed" );

my $loaded_corrupt = call_module( 'osf-cache.holdings.state_load',
    { 'path' => $corrupt_path } );

ok( ref $loaded_corrupt eq qw| HASH |
        && $loaded_corrupt->{'mode'} eq qw| false |,
    'corrupt state file -> mode false'
);

## a version 1 state [ the sha256-only shape ] loads as no previous state ##
my $v1_path = "$s2_dir/version-1-state.yaml";
write_fixture( $v1_path, "version: 1\nholdings:\n  anchored_count: 9\n" );

my $loaded_v1
    = call_module( 'osf-cache.holdings.state_load', { 'path' => $v1_path } );

ok( ref $loaded_v1 eq qw| HASH |
        && $loaded_v1->{'mode'} eq qw| true |
        && scalar keys %{ $loaded_v1->{'data'}{'holdings'} } == 0,
    'version 1 state -> mode true with empty holdings [ full rehash ]'
);

my $v7_path = "$s2_dir/version-7-state.yaml";
write_fixture( $v7_path, "version: 7\nholdings: {}\n" );

my $loaded_v7
    = call_module( 'osf-cache.holdings.state_load', { 'path' => $v7_path } );

ok( ref $loaded_v7 eq qw| HASH | && $loaded_v7->{'mode'} eq qw| false |,
    'state file with version != 1 or 2 -> mode false' );

##[ 9 : stage 2 - query_local ]###############################################

say ': stage 2 - query_local';

my $q_held = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => ["sha256:$aa_sha256"],
        'holdings' => $s2_scan1->{'data'},
    }
);

my $q_held_entry = $q_held->{'data'}{'held'}{"sha256:$aa_sha256"} // {};

ok( $q_held->{'mode'} eq qw| true |
        && ( $q_held_entry->{'size'} // -1 )
        == $s2_by_name{'aa-pkg_1.0-1_amd64.deb'}{'size'}
        && ( $q_held_entry->{'bmw384'} // '' ) eq $aa_bmw384,
    'anchored token answered with size and bmw384'
);

my $bb_sha256
    = Digest::SHA::sha256_hex( $s2_content{'bb-pkg_2.0-1_amd64.deb'} );

my $q_unanchored = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => ["sha256:$bb_sha256"],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( $q_unanchored->{'mode'} eq qw| true |
        && scalar keys %{ $q_unanchored->{'data'}{'held'} } == 0,
    'unanchored cached .deb never reported as held'
);

my $q_upper = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => [ sprintf 'sha256:%s', uc $aa_sha256 ],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( $q_upper->{'mode'} eq qw| true |
        && exists $q_upper->{'data'}{'held'}{"sha256:$aa_sha256"},
    'uppercase hex accepted and lowercased'
);

my $q_wrong_algo = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => ["sha512:$aa_sha512"],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( $q_wrong_algo->{'mode'} eq qw| true |
        && scalar keys %{ $q_wrong_algo->{'data'}{'held'} } == 0,
    'valid sha512 token of a sha256-anchored file is not held'
);

my $q_short = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => [ 'sha256:' . substr( $aa_sha256, 0, 63 ) ],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( ref $q_short eq qw| HASH | && $q_short->{'mode'} eq qw| false |,
    '63-char hash rejected' );

my $q_md5 = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => [ 'md5:' . ( 'a' x 32 ) ],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( ref $q_md5 eq qw| HASH | && $q_md5->{'mode'} eq qw| false |,
    'non-sha algo token rejected' );

my $q_many = call_module(
    'osf-cache.lookup.query_local',
    {   'hashes'   => [ ( 'sha256:' . ( 'a' x 64 ) ) x 1025 ],
        'holdings' => $s2_scan1->{'data'},
    }
);

ok( ref $q_many eq qw| HASH | && $q_many->{'mode'} eq qw| false |,
    '1025 hashes rejected' );

##[ 10 : stage 2 - wire format round trip ]###################################

say ': stage 2 - wire format';

my %wire_map = (
    'sha256:'
        . ( '11' x 32 ) => {
        'size'   => 10,
        'bmw384' => encode_b32r( 'w' x 48 ),
        },
    'sha256:'
        . ( '22' x 32 ) => {
        'size'   => 20,
        'bmw384' => encode_b32r( 'x' x 48 ),
        },
    'sha512:'
        . ( '33' x 64 ) => {
        'size'   => 30,
        'bmw384' => encode_b32r( 'y' x 48 ),
        },
);

my $formatted = call_module( 'osf-cache.lookup.format_has_reply',
    { 'held' => \%wire_map } );

my $expected_wire = join(
    "\n",
    map {
        sprintf '%s %s %s',
            $ARG, $wire_map{$ARG}{'size'}, $wire_map{$ARG}{'bmw384'}
    } sort keys %wire_map
);

ok( $formatted->{'mode'} eq qw| true |
        && ref $formatted->{'data'} eq ''
        && $formatted->{'data'} eq $expected_wire,
    'format : one sorted line per anchor, three fields'
);

my $reparsed = call_module( 'osf-cache.lookup.parse_has_reply',
    { 'reply' => $formatted->{'data'} } );

my $reparsed_held = $reparsed->{'data'}{'held'} // {};

ok( $reparsed->{'mode'} eq qw| true |
        && ( $reparsed->{'data'}{'bad_lines'} // -1 ) == 0
        && join( ',', sort keys %$reparsed_held ) eq
        join( ',', sort keys %wire_map )
        && (
        join( ',',
            map { $reparsed_held->{$ARG}{'size'} } sort keys %wire_map )
        ) eq '10,20,30'
        && (
        join( ',',
            map { $reparsed_held->{$ARG}{'bmw384'} } sort keys %wire_map )
        ) eq
        join( ',', map { $wire_map{$ARG}{'bmw384'} } sort keys %wire_map ),
    'format / parse round trip is exact'
);

my $empty_format
    = call_module( 'osf-cache.lookup.format_has_reply', { 'held' => {} } );

my $empty_reparse = call_module(
    'osf-cache.lookup.parse_has_reply',
    { 'reply' => $empty_format->{'data'} }
);

ok( $empty_format->{'data'} eq ''
        && $empty_reparse->{'mode'} eq qw| true |
        && scalar keys %{ $empty_reparse->{'data'}{'held'} } == 0
        && $empty_reparse->{'data'}{'bad_lines'} == 0,
    'empty map round trips to empty string'
);

my $good_line = sprintf 'sha256:%s 44 %s', ( '44' x 32 ),
    encode_b32r( 'z' x 48 );

my $bad_reparse = call_module(
    'osf-cache.lookup.parse_has_reply',
    {         'reply' => "garbage line\n"
            . $good_line . "\n"
            . sprintf( 'sha256:%s 45 %s', ( '55' x 32 ), ( 'A' x 76 ) . '0' )
            . "\nmd5:"
            . ( 'a' x 32 ) . " 9 "
            . encode_b32r( 'm' x 48 ) . "\n"
    }
);

my $bad_held = $bad_reparse->{'data'}{'held'} // {};

ok( $bad_reparse->{'mode'} eq qw| true |
        && ( $bad_reparse->{'data'}{'bad_lines'} // -1 ) == 3
        && scalar keys %$bad_held == 1
        && ( $bad_held->{ 'sha256:' . ( '44' x 32 ) }{'size'} // 0 ) == 44,
    'malformed lines counted [ bad line, bad bmw, wrong algo ]'
);

##[ 11 : stage 2 - merge_replies ]############################################

say ': stage 2 - merge_replies';

my $h1 = 'sha256:' . ( 'aa' x 32 );
my $h2 = 'sha256:' . ( 'bb' x 32 );
my $h3 = 'sha256:' . ( 'cc' x 32 );
my $h4 = 'sha256:' . ( 'dd' x 32 );
my $h5 = 'sha256:' . ( 'ee' x 32 );
my $hx = 'sha256:' . ( 'ff' x 32 );    ## never asked ##

my $bmw_a = encode_b32r( 'a' x 48 );
my $bmw_b = encode_b32r( 'b' x 48 );
my $bmw_c = encode_b32r( 'c' x 48 );

my $reply_A = sprintf "%s %d %s\n%s %d %s\n%s %d %s\n",
    $h1, 10, $bmw_a, $h2, 20, $bmw_a, $hx, 99, $bmw_a;
my $reply_B = sprintf "%s %d %s\n%s %d %s\n",
    $h1, 10, $bmw_a, $h3, 999, $bmw_a;
my $reply_D = sprintf "%s %d %s\n", $h5, 50, $bmw_b;
my $reply_E = sprintf "%s %d %s\n", $h5, 50, $bmw_c;

my $merged = call_module(
    'osf-cache.lookup.merge_replies',
    {   'replies' => {
            'node-a' => $reply_A,
            'node-b' => $reply_B,
            'node-c' => undef,
            'node-d' => $reply_D,
            'node-e' => $reply_E,
        },
        'expect' => {
            $h1 => 10,
            $h2 => 20,
            $h3 => 30,
            $h4 => 40,
            $h5 => 50,
        },
    }
);

my $merge_data = $merged->{'data'} // {};

ok( $merged->{'mode'} eq qw| true |, 'merge mode true' );

ok( join( ',', @{ $merge_data->{'holders'}{$h1} // [] } ) eq 'node-a,node-b'
        && ( $merge_data->{'bmw384'}{$h1} // '' ) eq $bmw_a,
    'anchor with two agreeing holders lists both + the agreed bmw384'
);

ok( join( ',', @{ $merge_data->{'holders'}{$h2} // [] } ) eq 'node-a',
    'anchor with one holder' );

ok( join( ',', @{ $merge_data->{'failed_nodes'} // [] } ) eq 'node-c',
    'undef reply listed in failed_nodes' );

ok( scalar @{ $merge_data->{'conflicts'} // [] } == 1
        && $merge_data->{'conflicts'}[0]{'node'} eq 'node-b'
        && $merge_data->{'conflicts'}[0]{'anchor'} eq $h3
        && $merge_data->{'conflicts'}[0]{'size'} == 999,
    'size mismatch is a conflict, not a holder'
);

ok( ( $merge_data->{'unrequested'}{'node-a'} // 0 ) == 1,
    'unrequested anchor counted per node' );

my $bmw_conflicts_h5 = $merge_data->{'bmw_conflicts'}{$h5} // {};

ok( !exists $merge_data->{'holders'}{$h5}
        && join( ',', @{ $bmw_conflicts_h5->{$bmw_b} // [] } ) eq 'node-d'
        && join( ',', @{ $bmw_conflicts_h5->{$bmw_c} // [] } ) eq 'node-e',
    'bmw384 disagreement -> bmw_conflicts, not holders'
);

ok( join( ',', @{ $merge_data->{'missing'} // [] } ) eq
        join( ',', sort ( $h3, $h4, $h5 ) ),
    'anchors without a size-agreeing holder are missing [ conflicts count ]'
);

##[ 12 : stage 2b - scan_file split ]#########################################

say ': stage 2b - scan_file split';

my $sf_path = "$s2_dir/aa-pkg_1.0-1_amd64.deb";

my $sf_first = call_module(
    'osf-cache.holdings.scan_file',
    {   'path'    => $sf_path,
        'name'    => 'aa-pkg_1.0-1_amd64.deb',
        'anchors' => \%s2_index,
        'algos'   => [qw| sha256 |],
    }
);

ok( ref $sf_first eq qw| HASH |
        && $sf_first->{'anchored'} == 1
        && $sf_first->{'rehashed'} == 1
        && ( $sf_first->{'anchor'} // '' ) eq "sha256:$aa_sha256",
    'scan_file hashes + anchors one .deb [ rehashed 1 ]'
);

my $sf_reuse = call_module(
    'osf-cache.holdings.scan_file',
    {   'path'     => $sf_path,
        'name'     => 'aa-pkg_1.0-1_amd64.deb',
        'anchors'  => \%s2_index,
        'algos'    => [qw| sha256 |],
        'previous' => $sf_first,
    }
);

ok( ref $sf_reuse eq qw| HASH |
        && $sf_reuse->{'rehashed'} == 0
        && ( $sf_reuse->{'digests'}{'sha256'} // '' ) eq $aa_sha256
        && ( $sf_reuse->{'digests'}{'bmw384'} // '' ) eq $aa_bmw384,
    'scan_file reuses the previous entry [ rehashed 0 ]'
);

my $sf_wide = call_module(
    'osf-cache.holdings.scan_file',
    {   'path'     => $sf_path,
        'name'     => 'aa-pkg_1.0-1_amd64.deb',
        'anchors'  => \%s2_index_both,
        'algos'    => [qw| sha256 sha512 |],
        'previous' => $sf_first,
    }
);

ok( ref $sf_wide eq qw| HASH |
        && $sf_wide->{'rehashed'} == 1
        && ( $sf_wide->{'digests'}{'sha512'} // '' ) eq $aa_sha512,
    'scan_file rehashes when the previous entry lacks an algo'
);

my $sf_missing = call_module(
    'osf-cache.holdings.scan_file',
    {   'path'    => "$s2_dir/no-such-file.deb",
        'anchors' => {},
        'algos'   => [],
    }
);

ok( !defined $sf_missing, 'scan_file returns undef for a missing file' );

##[ 13 : stage 2b - index.build ]#############################################

say ': stage 2b - index.build';

## the index builder expects the apt list dir naming : <base>_InRelease ##
## plus <base>_<flat relpath> for every Packages entry                  ##
my $ib_dir = tempdir( CLEANUP => 1 );
write_fixture( "$ib_dir/fixture_InRelease", slurp_file($inrelease_path) );
write_fixture( "$ib_dir/fixture_main_binary-amd64_Packages",
    slurp_file($packages_path) );

my $ib = call_module( 'osf-cache.index.build', { 'lists_dir' => $ib_dir } );

my $ib_data = $ib->{'data'}            // {};
my $ib_src  = $ib_data->{'sources'}[0] // {};

ok( $ib->{'mode'} eq qw| true | && scalar @{ $ib_data->{'sources'} } == 1,
    'index.build reports one source per InRelease' );

## the fixture signature is never 'good' -> the trust rule keeps the ##
## anchors map empty, exactly like osf-holdings today                ##
ok( ( $ib_src->{'signature'} // '' ) =~ m{^(?:bad|unverified)$}o
        && scalar keys %{ $ib_data->{'anchors'} } == 0
        && scalar @{ $ib_data->{'algos'} } == 0,
    'not-good signature : sources listed, zero contributing anchors'
);

ok( ( $ib_src->{'inrelease'} // '' ) eq qw| fixture |
        && ( $ib_src->{'entries'}                 // 0 ) == 3
        && ( $ib_src->{'packages'}[0]{'entries'}  // 0 ) == 3
        && ( $ib_src->{'packages'}[0]{'anchored'} // 0 ) == 1,
    'source carries inrelease, entries and the Packages anchor state'
);

my $ib_missing_dir = call_module( 'osf-cache.index.build',
    { 'lists_dir' => "$ib_dir/no-such-dir" } );

ok( ref $ib_missing_dir eq qw| HASH |
        && $ib_missing_dir->{'mode'} eq qw| false |,
    'missing lists dir returns mode false'
);

##[ 14 : stage 2b - zenka flow [ init, startup, rescan, commands ] ]##########

say ': stage 2b - zenka flow';

## a mini cache dir the scan can own ##
my $zc_dir = tempdir( CLEANUP => 1 );
foreach my $deb_name (
    qw|
    fake-hello_2.12.3-1_amd64.deb
    igt-gpu-tools_2.5-1_amd64.deb
    |
) {
    symlink fixture_path($deb_name), "$zc_dir/$deb_name"
        or die "symlink failed : $OS_ERROR";
}

my $init_r = call_module( 'osf-cache.init_code', 0 );

ok( $init_r == 0
        && ( $data{'osf-cache'}{'cfg'}{'cache_dir'} // '' ) eq
        qw| /var/cache/apt/archives |
        && ( $data{'osf-cache'}{'cfg'}{'lists_dir'} // '' ) eq
        qw| /var/lib/apt/lists |
        && ( $data{'osf-cache'}{'cfg'}{'state_path'} // '' ) eq
        "$zenka_data_dir/holdings.yaml"
        && ( $data{'osf-cache'}{'cfg'}{'scan_slice'} // 0 ) == 4,
    'init_code sets the config defaults [ pre-drop shape ]'
);

$data{'osf-cache'}{'cfg'}{'cache_dir'}  = $zc_dir;
$data{'osf-cache'}{'cfg'}{'lists_dir'}  = $ib_dir;
$data{'osf-cache'}{'cfg'}{'state_path'} = "$zc_dir/holdings.yaml";
$data{'osf-cache'}{'cfg'}{'scan_slice'} = 1;
$data{'osf-cache'}{'holdings'}          = { 'kept' => 1 };

my $init_re = call_module( 'osf-cache.init_code', 1 );

ok( $init_re == 0
        && ( $data{'osf-cache'}{'cfg'}{'cache_dir'} // '' ) eq $zc_dir
        && ( $data{'osf-cache'}{'holdings'}{'kept'} // 0 ) == 1,
    'reinit keeps the existing config and holdings untouched'
);

delete $data{'osf-cache'}{'scan'};
delete $data{'osf-cache'}{'holdings'};

my $has_early = call_module( 'osf-cache.cmd.has',
    { 'args' => "sha256:$hello_sha256" } );

ok( ref $has_early eq qw| HASH |
        && $has_early->{'mode'} eq qw| false |
        && $has_early->{'data'} eq 'holdings not ready',
    'cmd.has refuses before the first rescan finished'
);

my $startup_r = call_module( 'osf-cache.startup', {} );

my $timer_count = scalar @{ $data{'test'}{'timers'} };

ok( $startup_r == 0
        && $timer_count == 1
        && ( $data{'test'}{'timers'}[-1]{'handler'} // '' ) eq
        qw| osf-cache.holdings.rescan_step |
        && ref $data{'osf-cache'}{'index'} eq qw| HASH |
        && exists $data{'osf-cache'}{'index'}{'anchors'},
    'startup builds the index and arms exactly one rescan timer'
);

my $rescan = call_module( 'osf-cache.cmd.rescan', {} );

ok( $rescan->{'mode'} eq qw| true |
        && ( $rescan->{'data'} eq 'rescan started'
        || $rescan->{'data'} =~ m{^rescan already running} ),
    'cmd.rescan answers [ startup scan or fresh start ]'
);

## slice 1 over 2 files : tick one processes one file and re-arms ##
$data{'test'}{'timers'} = [];

my $tick_one = call_module( 'osf-cache.holdings.rescan_step', {} );

my $scan_progress = $data{'osf-cache'}{'scan'};

ok( $tick_one == 0
        && $scan_progress->{'running'} == 1
        && $scan_progress->{'total'} == 2
        && scalar @{ $scan_progress->{'files'} } == 1
        && scalar @{ $data{'test'}{'timers'} } == 1,
    'rescan tick hashes scan_slice files and re-arms the timer'
);

my $tick_two = call_module( 'osf-cache.holdings.rescan_step', {} );

my $zc_holdings = $data{'osf-cache'}{'holdings'} // {};

ok( $tick_two == 0
        && $scan_progress->{'running'} == 0
        && $scan_progress->{'done'} == 1
        && scalar @{ $zc_holdings->{'files'} } == 2
        && scalar @{ $data{'test'}{'timers'} } == 1
        && -f "$zc_dir/holdings.yaml",
    'last tick swaps holdings in, state_saves, no re-arm [ timer count flat ]'
);

my $has_late = call_module( 'osf-cache.cmd.has',
    { 'args' => "sha256:$hello_sha256 sha512:$hello_sha512" } );

ok( $has_late->{'mode'} eq qw| size |
        && ref $has_late->{'data'} eq ''
        && $has_late->{'data'} eq '',
    'cmd.has answers after the rescan [ no anchors : bad signature ]'
);

my $status = call_module( 'osf-cache.cmd.status', {} );

ok( $status->{'mode'} eq qw| size |
        && $status->{'data'} =~ m{^holdings : 2 files}m
        && $status->{'data'} =~ m{^scan     : idle}m
        && $status->{'data'} =~ m{^state    : \Q$zc_dir\E/holdings\.yaml}m,
    'cmd.status reports holdings, scan progress and state path'
);

## a second rescan reuses the state : nothing to rehash ##
my $rescan2 = call_module( 'osf-cache.cmd.rescan', {} );

$data{'test'}{'timers'} = [];
call_module( 'osf-cache.holdings.rescan_step', {} );
call_module( 'osf-cache.holdings.rescan_step', {} );

my $zc_holdings2 = $data{'osf-cache'}{'holdings'} // {};

ok( $rescan2->{'data'} eq 'rescan started'
        && ( $zc_holdings2->{'rehashed'} // -1 ) == 0,
    'second rescan reuses the saved state [ rehashed 0 ]'
);

##[ 15 : binary content under the zenka's utf-8 default layer ]##############

say ': binary content [ every byte value, utf-8 default layer active ]';

## the fixtures are ascii -> a plain '<' open passed here while the live ##
## zenka died on 964 utf-8 decode errors. every byte value 0..255 below  ##
my $bin_dir  = tempdir( CLEANUP => 1 );
my $bin_path = "$bin_dir/bin-pkg_1.0-1_amd64.deb";
my $bin_data = join '', map { chr $ARG } 0 .. 255, reverse 0 .. 255;
open( my $bin_fh, '>:raw', $bin_path ) or die "cannot write $bin_path";
print {$bin_fh} $bin_data;
close($bin_fh);

my $bin_entry = call_module(
    'osf-cache.holdings.scan_file',
    {   'path'    => $bin_path,
        'name'    => 'bin-pkg_1.0-1_amd64.deb',
        'anchors' => {},
        'algos'   => [qw| sha256 |],
    }
);

ok( ref $bin_entry eq qw| HASH |
        && ( $bin_entry->{'digests'}{'sha256'} // '' ) eq
        Digest::SHA::sha256_hex($bin_data),
    'scan_file hashes raw bytes, not utf-8 decoded characters'
);

##[ 16 : stage 2c - per-subname instance config ]##############################

say ': stage 2c - per-subname instance config';

my $saved_cfg = delete $data{'osf-cache'}{'cfg'};

$data{'system'}{'zenka'}{'subname'} = 'peer';
$data{'osf-cache'}{'cfg'}{'by_subname'}{'peer'}{'cache_dir'}
    = qw| /var/protocol-7/osf-cache/peer-archives |;

call_module( 'osf-cache.init_code', 0 );

ok( ( $data{'osf-cache'}{'cfg'}{'cache_dir'} // '' ) eq
        qw| /var/protocol-7/osf-cache/peer-archives |
        && ( $data{'osf-cache'}{'cfg'}{'state_path'} // '' ) eq
        "$zenka_data_dir/holdings.peer.yaml"
        && ( $data{'osf-cache'}{'cfg'}{'lookup_timeout'} // 0 ) == 5,
    'subname peer : by_subname cache dir, subnamed state, lookup timeout'
);

delete $data{'osf-cache'}{'cfg'};
call_module( 'osf-cache.init_code', 0 );

ok( ( $data{'osf-cache'}{'cfg'}{'cache_dir'} // '' ) eq
        qw| /var/cache/apt/archives |
        && ( $data{'osf-cache'}{'cfg'}{'state_path'} // '' ) eq
        "$zenka_data_dir/holdings.peer.yaml",
    'subname without by_subname : default cache dir, subnamed state path'
);

delete $data{'system'}{'zenka'}{'subname'};
delete $data{'osf-cache'}{'cfg'};
call_module( 'osf-cache.init_code', 0 );

ok( ( $data{'osf-cache'}{'cfg'}{'cache_dir'} // '' ) eq
        qw| /var/cache/apt/archives |
        && ( $data{'osf-cache'}{'cfg'}{'state_path'} // '' ) eq
        "$zenka_data_dir/holdings.yaml",
    'no subname : the original defaults'
);

$data{'osf-cache'}{'cfg'} = $saved_cfg;

##[ 17 : stage 2c - peer discovery [ cube session table ] ]####################

say ': stage 2c - peer discovery';

## this instance's own cube session [ base.get_session_id stores it ] ##
$data{'user'}{'cube'}{'session'} = { 7 => 1 };
$data{'session'}{7} = { 'user' => 'cube', 'cube_sid' => 4242 };

my $sessions_table = join( "\n",
    ' usid  protocol    type   mode   uname             since',
    '----------------------------------------------------------',
    ' 4242  protocol-7  zenka  ----   osf-cache         2h 13m',
    ' 4301  protocol-7  zenka  ----   osf-cache[peer]   5m 2s',
    ' 4302  protocol-7  zenka  ----   osf-cache         41s',
    ' 4400  protocol-7  zenka  ----   coding            3d 1h',
    '' );

$data{'test'}{'route_sends'} = [];
my $pl = call_module(
    'osf-cache.peers.list',
    {   'callback' => qw| osf-cache.lookup.with_peers |,
        'params'   => { 'lookup_id' => '77' },
    }
);

ok( $pl->{'mode'} eq qw| true |
        && scalar @{ $data{'test'}{'route_sends'} } == 1
        && ( $data{'test'}{'route_sends'}[0]{'command'} // '' ) eq qw| list |
        && ( $data{'test'}{'route_sends'}[0]{'call_args'}{'args'} // '' ) eq
        'sessions osf-cache'
        && ( $data{'test'}{'route_sends'}[0]{'reply'}{'handler'} // '' ) eq
        qw| osf-cache.handler.peers_list |,
    'peers.list asks cube for list sessions osf-cache [ async ]'
);

## a pending lookup the callback can continue [ state shape cmd.lookup ##
## writes ] ; the parse proof : own sid out, [subname] in, coding out   ##
$data{'osf-cache'}{'lookup'}{'pending'}{'77'} = {
    'reply_id'       => 'r-peers',
    'anchors'        => [$h1],
    'expect'         => { $h1 => 10 },
    'started'        => time,
    'peers_resolved' => 0,
    'replies'        => {},
    'pending'        => {},
};

deliver_reply( $data{'test'}{'route_sends'}[0],
    { 'cmd' => qw| SIZE |, 'data' => $sessions_table } );

my @has_sends = grep { ( $ARG->{'command'} // '' ) =~ m{^\d+\.has$} }
    @{ $data{'test'}{'route_sends'} };

ok( scalar @has_sends == 2
        && join( ',', map { $ARG->{'command'} } @has_sends ) eq
        '4301.has,4302.has'
        && !exists $data{'test'}{'cmd_replies'}{'r-peers'},
    'table parse : own sid excluded, [subname] peer in, other zenki out'
);

delete $data{'osf-cache'}{'lookup'}{'pending'}{'77'};

##[ 18 : stage 2c - lookup state machine ]#####################################

say ': stage 2c - lookup state machine';

## the local index is the size truth the replies merge against ##
$data{'osf-cache'}{'index'} = {
    'anchors' => {
        $h1 => { 'size' => 10 },
        $h2 => { 'size' => 20 },
        $h3 => { 'size' => 30 },
        $h4 => { 'size' => 40 },
        $h5 => { 'size' => 50 },
    },
    'algos'   => [qw| sha256 |],
    'sources' => [],
};

sub start_lookup {
    my ( $reply_id, $token_str ) = @ARG;
    $data{'test'}{'route_sends'} = [];
    $data{'test'}{'timers'}      = [];
    $data{'test'}{'watchers'}    = [];
    return call_module( 'osf-cache.cmd.lookup',
        { 'args' => $token_str, 'reply_id' => $reply_id } );
}

sub resolve_peers {
    deliver_reply( $data{'test'}{'route_sends'}[0],
        { 'cmd' => qw| SIZE |, 'data' => $sessions_table } );
    return;
}

sub pending_lookups {
    return scalar keys %{ $data{'osf-cache'}{'lookup'}{'pending'} // {} };
}

## flow 1 : all peers answer ##
$data{'base'}{'cmd_reply'}{'r-1'} = { 'fake' => 1 };    ## framework entry ##
my $lk1 = start_lookup( 'r-1', "$h1 $h2" );

my @lk1_ids = keys %{ $data{'osf-cache'}{'lookup'}{'pending'} // {} };

ok( $lk1->{'mode'} eq qw| deferred |
        && scalar @lk1_ids == 1
        && scalar @{ $data{'test'}{'timers'} } == 1
        && ( $data{'test'}{'timers'}[0]{'handler'} // '' ) eq
        qw| osf-cache.lookup.timeout |
        && ( $data{'test'}{'timers'}[0]{'data'}{'lookup_id'} // '' ) eq
        $lk1_ids[0]
        && ( $data{'test'}{'timers'}[0]{'after'} // 0 ) == 5,
    'lookup defers : state keyed by lookup id, one 5s timeout timer'
);

resolve_peers();

@has_sends = grep { ( $ARG->{'command'} // '' ) =~ m{^\d+\.has$} }
    @{ $data{'test'}{'route_sends'} };

ok( scalar @has_sends == 2
        && join( ',', map { $ARG->{'command'} } @has_sends ) eq
        '4301.has,4302.has'
        && ( $has_sends[0]{'call_args'}{'args'} // '' ) eq "$h1 $h2"
        && ( $has_sends[0]{'reply'}{'handler'} // '' ) eq
        qw| osf-cache.handler.has_reply |,
    'fan-out : <sid>.has <tokens> to each peer with a reply handler'
);

deliver_reply( $has_sends[0],
    { 'cmd' => qw| SIZE |, 'data' => "$h1 10 $bmw_a\n$h2 20 $bmw_a" } );

ok( !exists $data{'test'}{'cmd_replies'}{'r-1'},
    'no completion while a peer is still pending' );

deliver_reply( $has_sends[1],
    { 'cmd' => qw| SIZE |, 'data' => "$h1 10 $bmw_a" } );

my $r1 = $data{'test'}{'cmd_replies'}{'r-1'} // {};

ok( ( $r1->{'mode'} // '' ) eq qw| size |
        && $r1->{'data'} =~ m{^\Q$h1\E 2 holders : 4301 4302$}m
        && $r1->{'data'} =~ m{^\Q$h2\E 1 holders : 4301$}m
        && $r1->{'data'} !~ m{missing|failed|conflict}
        && pending_lookups() == 0
        && $data{'test'}{'watchers'}[0]->cancelled
        && !exists $data{'base'}{'cmd_reply'}{'r-1'},
    'last reply completes : holders lines, state + timer + entry gone'
);

## flow 2 : one peer times out ##
start_lookup( 'r-2', $h3 );
resolve_peers();
@has_sends = grep { ( $ARG->{'command'} // '' ) =~ m{^\d+\.has$} }
    @{ $data{'test'}{'route_sends'} };
deliver_reply( $has_sends[0],
    { 'cmd' => qw| SIZE |, 'data' => "$h3 30 $bmw_a" } );

fire_timer( $data{'test'}{'watchers'}[0] );

my $r2 = $data{'test'}{'cmd_replies'}{'r-2'} // {};

ok( ( $r2->{'mode'} // '' ) eq qw| size |
        && $r2->{'data'} =~ m{^\Q$h3\E 1 holders : 4301$}m
        && $r2->{'data'} =~ m{^failed peers : 4302$}m,
    'timeout completes with what arrived : silent peer is a failed peer'
);

ok( pending_lookups() == 0
        && scalar @{ $data{'test'}{'timers'} } == 1,
    'timeout cleanup : no pending state, no new timer armed'
);

## flow 3 : zero peers ##
start_lookup( 'r-3', $h1 );
deliver_reply( $data{'test'}{'route_sends'}[0],
    {   'cmd'  => qw| SIZE |,
        'data' => " 4242  protocol-7  zenka  ----   osf-cache  1m\n"
    } );

my $r3 = $data{'test'}{'cmd_replies'}{'r-3'} // {};

ok( ( $r3->{'mode'} // '' ) eq qw| true |
        && ( $r3->{'data'} // '' ) eq 'no peers'
        && pending_lookups() == 0
        && $data{'test'}{'watchers'}[0]->cancelled,
    'zero peers : mode true no peers, lookup cleaned up'
);

## flow 4 : unknown anchor refused up front ##
my $lk4 = start_lookup( 'r-4', $hx );

ok( $lk4->{'mode'} eq qw| false |
        && $lk4->{'data'} =~ m{^unknown anchor : \Q$hx\E}
        && scalar @{ $data{'test'}{'route_sends'} } == 0
        && scalar @{ $data{'test'}{'timers'} } == 0
        && pending_lookups() == 0,
    'unknown anchor refused before any state, send or timer'
);

## flow 5 : the token checks are exactly the has checks ##
my $lk5 = start_lookup( 'r-5', 'md5:abcd' );

ok( $lk5->{'mode'} eq qw| false |
        && $lk5->{'data'} eq 'invalid hash : md5:abcd'
        && pending_lookups() == 0,
    'invalid token fails with the query_local message'
);

## flow 6 : size conflict and bmw conflict surface in the reply ##
start_lookup( 'r-6', "$h4 $h5" );
resolve_peers();
@has_sends = grep { ( $ARG->{'command'} // '' ) =~ m{^\d+\.has$} }
    @{ $data{'test'}{'route_sends'} };
deliver_reply( $has_sends[0],
    { 'cmd' => qw| SIZE |, 'data' => "$h4 999 $bmw_a\n$h5 50 $bmw_b" } );
deliver_reply( $has_sends[1],
    { 'cmd' => qw| SIZE |, 'data' => "$h4 40 $bmw_a\n$h5 50 $bmw_c" } );

my $r6 = $data{'test'}{'cmd_replies'}{'r-6'} // {};

ok( ( $r6->{'mode'} // '' ) eq qw| size |
        && $r6->{'data'} =~ m{^\Q$h4\E 1 holders : 4302$}m
        && $r6->{'data'} =~ m{^conflict : \Q$h4\E 4301 size 999$}m,
    'size mismatch : holder from the agreeing peer, conflict line'
);

ok( $r6->{'data'} =~ m{^bmw conflict : \Q$h5\E$}m
        && $r6->{'data'} =~ m{^  \Q$bmw_b\E : 4301$}m
        && $r6->{'data'} =~ m{^  \Q$bmw_c\E : 4302$}m
        && $r6->{'data'} =~ m{^missing : \Q$h5\E$}m,
    'bmw disagreement : bmw conflict lines, anchor also in missing'
);

## flow 7 : the peer LIST itself times out ##
start_lookup( 'r-7', $h1 );
fire_timer( $data{'test'}{'watchers'}[0] );

my $r7 = $data{'test'}{'cmd_replies'}{'r-7'} // {};

ok( ( $r7->{'mode'} // '' ) eq qw| false |
        && ( $r7->{'data'} // '' ) eq
        'lookup timeout [ peer list never arrived ]'
        && pending_lookups() == 0,
    'unresolved peer list fails the lookup instead of faking missing'
);

## flow 8 : the peer query itself fails ##
start_lookup( 'r-8', $h1 );
deliver_reply( $data{'test'}{'route_sends'}[0], { 'cmd' => qw| FALSE | } );

my $r8 = $data{'test'}{'cmd_replies'}{'r-8'} // {};

ok( ( $r8->{'mode'} // '' ) eq qw| true |
        && ( $r8->{'data'} // '' ) eq 'no peers'
        && pending_lookups() == 0,
    'failed peer query completes as no peers'
);

## flow 9 : an empty has reply is a valid 'holds nothing', not a failure ##
start_lookup( 'r-9', $h1 );
resolve_peers();
@has_sends = grep { ( $ARG->{'command'} // '' ) =~ m{^\d+\.has$} }
    @{ $data{'test'}{'route_sends'} };
deliver_reply( $has_sends[0], { 'cmd' => qw| SIZE |, 'data' => '' } );
deliver_reply( $has_sends[1], { 'cmd' => qw| SIZE |, 'data' => '' } );

my $r9 = $data{'test'}{'cmd_replies'}{'r-9'} // {};

ok( ( $r9->{'mode'} // '' ) eq qw| size |
        && $r9->{'data'} =~ m{^missing : \Q$h1\E$}m
        && $r9->{'data'} !~ m{failed peers}
        && pending_lookups() == 0,
    'empty replies : anchor missing, no failed peers'
);

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,.,.,,,.,,.,,,,,,.,.,,.,,,,,,.,.,,..,,,,,.,.,...,.,.,,,.,,,.,.,,,..,,,,,,
#IEGMHBAX4MMTXBFMRSCSE5QBCRRRV7BVWMDNQP4VN7GRWWUHFRAEANUT6SNV3Q4HRJHRPZ6NBBGCS
#\\\|55AKSM6EEFYHKNAL2BOWU22IZQN2UD7L2CJTOKBF5UX4YZPR4LK \ / AMOS7 \ YOURUM ::
#\[7]GADC76RS6DNLYKTUQWWMTMTBAZ3D3YHST233ME7VEEMIEWMT6QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
