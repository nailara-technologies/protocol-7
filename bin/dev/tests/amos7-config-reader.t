#!/usr/bin/env perl

use v5.32;
use strict;
use warnings;
use English;

use File::Basename qw| dirname |;
use File::Path     qw| make_path remove_tree |;
use Test::More;

## tests of AMOS7::Config::Reader : real cfg/ files + a temp tree run : ##
## perl bin/dev/tests/amos7-config-reader.t                             ##

my $root;

BEGIN {
    $root = dirname( dirname( dirname( dirname(__FILE__) ) ) );
    $root = Cwd::abs_path($root) if eval { require Cwd; 1 };
    unshift @INC, "$root/data/lib-path/pm";
}

use AMOS7::Config::Reader;

##[ real files ]##############################################################

my $shared
    = AMOS7::Config::Reader->read( 'shared-params', { 'root' => $root } );
ok( scalar( keys $shared->all->%* ) > 20, 'shared-params : keys read' );
is( $shared->get('system.local_config_dir'),
    '/etc/protocol-7', 'shared-params : plain value' );
is( $shared->get('limits.client_sessions'),
    '77777', 'shared-params : trailing comment cut' );
my @ex = $shared->explain('limits.client_sessions');
is( scalar @ex,     1,                   'explain : one assignment' );
is( $ex[0]{'file'}, 'cfg/shared-params', 'explain : file' );
ok( $ex[0]{'line'} > 0, 'explain : line' );
is( $ex[0]{'layer'}, 'tree', 'explain : layer tree' );
ok(
    (   grep { $ARG->{'file'} =~ m|network/protocol-version| }
        map  { $shared->explain($ARG) } keys $shared->all->%*
    ),
    'shared-params : keys from a nested include'
);
is( scalar( () = $shared->refused ), 0, 'shared-params : nothing refused' );

my $calc = AMOS7::Config::Reader->read( 'zenki/calc/zenka.v7',
    { 'root' => $root } );
is( $calc->get('modules.load'),
    'auth.client net protocol io.unix ui calc',
    'calc zenka.v7 : modules.load'
);
is( $calc->get('buffer.session.max_size'), '795648', 'calc : own key' );
is( $calc->explain('system.access.wildcards.allow') ? 1 : 0,
    1, 'calc : key from shared-params include' );
my @calls = $calc->calls;
ok( ( grep { $ARG->{'text'} =~ m|^\[init_modules\]$| } @calls ),
    'calc : [init_modules] listed in calls, not run'
);
ok(
    (   grep { $ARG->{'text'} =~ m|^\[load_modules:<modules.load>\]$| }
            @calls
    ),
    'calc : [load_modules:..] listed in calls'
);
ok( !( grep { $ARG->{'text'} =~ m|load_config_file| } @calls ),
    'calc : includes are followed, not listed' );
ok(
    (   grep {
            $ARG->{'line'} > 0 and $ARG->{'file'} eq 'cfg/zenki/calc/zenka.v7'
        } @calls
    ),
    'calls carry file + line'
);

foreach my $zenka (qw| cube httpd v7-zenki coding |) {
    my $path = "cfg/zenki/$zenka/zenka.v7";
    next if not -f "$root/$path";
    my $cfg = AMOS7::Config::Reader->read( "zenki/$zenka/zenka.v7",
        { 'root' => $root } );
    ok( defined $cfg->get('modules.load'),
        "$zenka zenka.v7 : modules.load set"
    );
    is( scalar( () = $cfg->refused ), 0, "$zenka : nothing refused" );
}

## sections as namespaces [ section config style ] ##
my $frame = AMOS7::Config::Reader->read( 'ascii-frame', { 'root' => $root } );
is( $frame->get('ascii-frame.colors.fill.single'),
    'p7_fg_0000', 'ascii-frame : .: :. - : : namespaces' );
is( $frame->get('ascii-frame.colors.corner.anchor.bold'),
    '1', 'ascii-frame : dotted key below a section' );
is( $frame->get('ascii-frame.modes.expanded.border.only'),
    '0', 'ascii-frame : second sub-section reset' );

my $start = AMOS7::Config::Reader->read( 'zenki/cube/start.cfg',
    { 'root' => $root } );
is( $start->get('max_concurrency'),
    '1', 'cube start.cfg : key before sections' );
is( $start->get('v7-init.start_mode'),
    'stdin-zenka', 'cube start.cfg : `: v7-init :`' );
ok(
    (   grep {
                   $ARG->{'text'} =~ m|^cube.key = \[base.prng|
                or $ARG->{'text'} =~ m|base.auth.set_v7_key|
        } $start->calls
    ),
    'cube start.cfg : [call] lines go to calls'
);

##[ temp tree ]###############################################################

## beside the tree, not in /tmp : the trust check refuses a world-writable ##
## directory in the path, so the layers outside the tree need a clean one  ##
my $base = dirname($root) . "/.p7-config-reader-test-$PID";
remove_tree($base);
make_path(
    "$base/tree/cfg", "$base/etc/host-config",
    "$base/var", { 'mode' => 0755 }
);
END { remove_tree($base) if defined $base and -d $base }

sub put {
    my ( $path, $text, $mode ) = @ARG;
    make_path( dirname($path), { 'mode' => 0755 } );
    open( my $fh, '>:encoding(UTF-8)', $path ) or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh;
    chmod( $mode // 0644, $path );
}

my $tree = "$base/tree";
my %o    = (
    'root'    => $tree,
    'etc_dir' => "$base/etc",
    'var_dir' => "$base/var",
    'zenka'   => 'demo'
);

put( "$tree/cfg/main", <<'CFG' );
.:[ main file ]:.
a.one = 1
a.two = <a.one>-two   ## ref to a key read so far
a.long = first \
         second
b.quoted = 'x y'
[load_config_file:'sub/inc']
a.one = main-after-inc
[do.something:<a.one>]
net.val = <<some.net.key>>
[load_config_file_if_present:'cfg-dir:<zenka>-extra.cfg']
[load_config_file_if_present:'var-dir:detected.cfg']
[load_config_file_if_present:'cfg-dir:missing.cfg']
CFG
put( "$tree/cfg/sub/inc",
    "a.one = from-inc\ninc.only = yes\n[load_config_file:'sub/cyc']\n" );
put( "$tree/cfg/sub/cyc", "cyc.key = 1\n[load_config_file:'sub/inc']\n" );
put( "$base/etc/demo-extra.cfg",       "a.two = etc-layer\nextra.key = 1\n" );
put( "$base/var/detected.cfg",         "var.key = 1\na.one = var-layer\n" );
put( "$base/etc/host-config/demo.cfg", "host.key = 1\na.two = host-layer\n" );

my $r = AMOS7::Config::Reader->read( 'main', \%o );

is( $r->get('a.long'),   'first second', 'continuation joined' );
is( $r->get('b.quoted'), 'x y',          'single quotes dropped' );
is( $r->get('inc.only'), 'yes',          'nested include applied' );
is( $r->get('cyc.key'),  '1', 'cycle : second level still applied' );
ok( ( grep { $ARG->{'text'} =~ m|cycle| } $r->warnings ),
    'cycle : recorded in warnings, not looped'
);
is( $r->get('var.key'), '1', 'var-dir optional layer applied' );
is( $r->get('extra.key'),
    '1', 'cfg-dir optional layer, <zenka> substituted' );
is( $r->get('host.key'), '1',       'host overlay applied' );
is( $r->get('a.two'), 'host-layer', 'host overlay beats the optional layer' );
is( $r->get('a.one'), 'var-layer',
    'optional var layer beats the file [ last wins ]' );

## explain order : main '1', inc 'from-inc', main-after-inc, var layer ##
my @order = map {"$ARG->{'layer'}:$ARG->{'value'}"} $r->explain('a.one');
is_deeply(
    \@order,
    [   'tree:1',              'include:from-inc',
        'tree:main-after-inc', 'optional:var-layer'
    ],
    'explain : apply order with layers'
);
is( ( $r->explain('a.one') )[1]{'file'},
    'cfg/sub/inc', 'explain : include file' );
is( ( $r->explain('a.one') )[1]{'line'}, 1, 'explain : include line' );
is( ( $r->explain('a.long') )[0]{'line'},
    4, 'explain : continued line reports its first line' );
my @two = map { $ARG->{'layer'} } $r->explain('a.two');
is_deeply(
    \@two,
    [ 'tree', 'optional', 'host' ],
    'explain : tree < optional < host'
);

my @tcalls = $r->calls;
is( scalar @tcalls, 2, 'calls : [sub:..] and <<net>> line, nothing else' );
is( $tcalls[0]{'text'}, '[do.something:<a.one>]', 'calls : text' );
is( $tcalls[1]{'line'}, 10,                       'calls : line number' );
is( $r->get('net.val'), undef, '<<net>> line not applied as a value' );

## overrides last ##
my $ov = AMOS7::Config::Reader->read( 'main',
    { %o, 'overrides' => { 'a.two' => 'cli', 'new.key' => 'n' } } );
is( $ov->get('a.two'), 'cli', 'override beats the host overlay' );
is( ( $ov->explain('a.two') )[-1]{'layer'},
    'override', 'override layer in explain' );
is( $ov->get('new.key'), 'n', 'override adds a key' );

## no zenka name : no overlay, and the <zenka> path is empty ##
my $nz = AMOS7::Config::Reader->read( 'main', { %o, 'zenka' => undef } );
is( $nz->get('host.key'), undef, 'no zenka : no host overlay' );

## refused layers : group writable file, group writable directory ##
chmod 0664, "$base/etc/demo-extra.cfg";
my $ref = AMOS7::Config::Reader->read( 'main', \%o );
is( $ref->get('extra.key'), undef, 'group-writable layer : not applied' );
is( $ref->get('a.two'), 'host-layer',
    'refused layer leaves the other layers' );
my @refused = $ref->refused;
is( scalar @refused, 1, 'one layer refused' );
like(
    $refused[0]{'reason'},
    qr/mode 0664, group \\ other writable/,
    'refused : reason'
);
is( $refused[0]{'layer'}, 'optional', 'refused : layer' );
is( $refused[0]{'from'},  'cfg/main', 'refused : asked by' );
is( $refused[0]{'line'},  11,         'refused : line' );
chmod 0644, "$base/etc/demo-extra.cfg";

chmod 0666, "$base/etc/host-config/demo.cfg";
my $ref2 = AMOS7::Config::Reader->read( 'main', \%o );
is( $ref2->get('host.key'),
    undef, 'world-writable host overlay : not applied' );
is( ( $ref2->refused )[0]{'layer'}, 'host', 'host overlay refusal recorded' );
chmod 0644, "$base/etc/host-config/demo.cfg";

chmod 0775, "$base/var";
my $ref3 = AMOS7::Config::Reader->read( 'main', \%o );
is( $ref3->get('var.key'),
    undef, 'file under a group-writable directory : refused' );
like(
    ( $ref3->refused )[0]{'reason'},
    qr/\Q$base\E\/var : mode 0775/,
    'refused : names the directory'
);
chmod 0755, "$base/var";

## a symlinked layer is refused ##
symlink "$base/var/detected.cfg", "$base/etc/link.cfg";
put( "$tree/cfg/linked",
    "[load_config_file_if_prese" . "nt:'$base/etc/link.cfg']\n" );
my $lk = AMOS7::Config::Reader->read( 'linked', \%o );
is( ( $lk->refused )[0]{'reason'}, 'symlink', 'symlink layer refused' );

## unknown top file, include with .. ##
ok( !eval { AMOS7::Config::Reader->read( 'no/such/file', \%o ); 1 },
    'missing top file dies' );
put( "$tree/cfg/dots", "[load_config_file:'../../etc/x']\nok.key = 1\n" );
my $dots = AMOS7::Config::Reader->read( 'dots', \%o );
is( $dots->get('ok.key'), '1', 'path with .. : skipped, rest applied' );

## section() and a source of the same three calls ##
{

    package Mem::Source;
    sub new    { return bless { 'f' => $_[1] }, $_[0] }
    sub exists { return exists $_[0]{'f'}{ $_[1] } ? 1 : 0 }
    sub lines  { return $_[0]{'f'}{ $_[1] } }
    sub trust  { return wantarray ? ( 1, 'memory' ) : 1 }
}
my $mem = AMOS7::Config::Reader->read(
    'x',
    {   'source' => Mem::Source->new(
            {   'cfg/x' => [ "k.a = 1\n", "[load_config_file:'y']\n" ],
                'cfg/y' => [ "k.b = <k.a>2\n", ": s :\n", "  c = 3\n" ],
            }
        ),
    }
);
is_deeply(
    { $mem->section('k') },
    { 'a' => 1, 'b' => '12' },
    'custom source + section()'
);
is( $mem->get('s.c'), 3, 'custom source : namespace' );

## key : value , missing required include , unresolved reference ##
{
    my $mem2 = AMOS7::Config::Reader->read(
        'x',
        {   'source' => Mem::Source->new(
                {   'cfg/x' => [
                        "colon.key : 7\n",
                        "url.key = http://h:80/p\n",
                        "ref.key = a<no.such>b\n",
                        "[load_config_file:'gone']\n"
                    ],
                }
            ),
        }
    );
    is( $mem2->get('colon.key'), '7', 'key : value equals key = value' );
    is( $mem2->get('url.key'),
        'http://h:80/p', 'colon inside a value untouched' );
    is( $mem2->get('ref.key'), 'ab', 'unresolved reference : empty' );
    ok( ( grep { $ARG->{'reason'} =~ m|required include| } $mem2->refused ),
        'missing required include : refused' );
}

## a symlink inside the tree pointing outside it is not tree-trusted ##
{
    require File::Temp;
    my $outside = File::Temp::tempdir( CLEANUP => 1 );
    my $tree    = File::Temp::tempdir( CLEANUP => 1 );
    mkdir "$tree/cfg";
    open( my $fh, '>', "$outside/evil" ) or die $OS_ERROR;
    print $fh "evil.key = 1\n";
    close $fh;
    symlink( "$outside/evil", "$tree/cfg/evil" ) or die $OS_ERROR;
    require AMOS7::Config::Source::Disk;
    my $disk = AMOS7::Config::Source::Disk->new( 'root' => $tree );
    ok( !$disk->in_tree('cfg/evil'),
        'symlink escaping the tree : not in tree' );
}

done_testing();

#,,..,.,,,...,,,,,...,,.,,..,,.,.,..,,,.,,,..,..,,...,...,.,,,..,,,.,,,..,...,
#LQMIKWQOHVVBTL6BOHJ3QAHYZCG3UFEOENWMMMSHOVXCK5P5IASFTI6BQJCAMJRGEVPG6NFPSO3BM
#\\\|UX7SVMXJMH4MX5I2CK4AZBR4J77POKHQ7WKEWETUP2ZKUVYMAY2 \ / AMOS7 \ YOURUM ::
#\[7]TDMKAL6SS2NVJC6ZIAUUKINNXYWHTIPTMZ3HZJSWFX7CMMAPG2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
