#!/usr/bin/perl
use v5.32;
use strict;
use warnings;
use English;

use Cwd        qw| abs_path |;
use File::Copy qw| copy |;
use File::Spec;
use File::stat  qw| stat |;
use File::Temp  qw| tempdir |;
use FindBin     qw| $RealBin |;
use HTTP::Date  qw| time2str |;
use MIME::Types ();
use URI;

my $mime_types = MIME::Types->new;

sub mimetype {
    my ($path) = @ARG;
    my $type = $mime_types->mimeTypeOf($path);
    return defined $type ? $type->type : undef;
}

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
    unshift @INC, $local_lib_path;
    $main::root_path = $root_path;
}

use AMOS7;
use AMOS7::CHKSUM;
use AMOS7::B32                qw| encode_b32r |;
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Digest::BMW               ();

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our %keys;

my $fail_count = 0;
my @logs;
my $valid_payload;
my $temp_dir = tempdir( CLEANUP => 1 );
my $site_dir = File::Spec->catdir( $temp_dir, 'site' );
mkdir $site_dir or die "mkdir $site_dir : $OS_ERROR";

sub ok ($;$) {
    my ( $condition, $label ) = @ARG;
    if ($condition) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
}

sub compile_module {
    my ( $module_name, $code_name ) = @ARG;
    $code_name //= $module_name;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open my $fh, '<', $src_path or die "cannot read $src_path : $OS_ERROR";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$code_name} = $cref;
}

sub write_file {
    my ( $path, $content ) = @ARG;
    open my $fh, '>', $path or die "write $path : $OS_ERROR";
    binmode $fh;
    print $fh $content;
    close $fh;
}

sub read_file {
    my $path = shift;
    open my $fh, '<', $path or die "read $path : $OS_ERROR";
    binmode $fh;
    my $content = join '', <$fh>;
    close $fh;
    return $content;
}

sub catfile {
    return File::Spec->catfile(@ARG);
}

sub fixture_body {
    my $content = shift;
    $content =~ s|\n?#[\.,]{70,}\n(?:#[^\n]+\n)+$|\n|s;
    return $content;
}

{

    package TestSignatureWatcher;
    sub new    { return bless { fd => $_[1], data => $_[2] }, $_[0] }
    sub fd     { return $_[0]{'fd'} }
    sub data   { return $_[0]{'data'} }
    sub cancel { $_[0]{'cancelled'} = 1; return 5 }
}

{

    package TestSignatureEvent;
    sub new { return bless { w => $_[1] }, $_[0] }
    sub w   { return $_[0]{'w'} }
}

%code = (
    'base.log'  => sub { return TRUE },
    'base.fork' => sub { return fork },
    'file.temp' => sub {
        my ( $fh, $path ) = File::Temp::tempfile(
            'signed-body-XXXXXXXXXXXXX',
            DIR    => $temp_dir,
            UNLINK => 0
        );
        return ( $fh, $path );
    },
    'httpd.base.file.nonblocking'   => sub { return TRUE },
    'crypt.C25519.load_from_string' => sub {
        $keys{'C25519'}{ $_[0] }{'public'} = "\x13" x 32;
        return TRUE;
    },
    'protocol-7.source-key' => sub { return 'test-public-key' },
    'event.add_io'          => sub {
        my $params = shift;
        return TestSignatureWatcher->new( $params->{'fd'},
            $params->{'data'} );
    },
    'base.logs' => sub {
        my $level = shift;
        push @logs, sprintf shift, @ARG;
        return TRUE;
    },
    'base.s_warn'                => sub { return TRUE },
    'base.str.os_err'            => sub { return "$OS_ERROR" },
    'base.parser.ellipse_center' => sub { return shift },
    'base.cnt_s'                 => sub { return '' },
    'chk-sum.elf.vax-BASE32'     => sub { return 'test-etag' },
    'chk-sum.bmw.strsum'         => sub { return 'test-signed-bmw' },
    'file.slurp'                 => sub {
        my ( $path, $target ) = @ARG;
        my $content = eval { read_file($path) };
        return undef if not defined $content;
        if ( ref $target ) { $target->$* = $content; return TRUE }
        return \$content;
    },
    'httpd.new_header' => sub {
        my ( $status, $header ) = @ARG;
        return "STATUS:$status\nLENGTH:$header->{'Content-Length'}"
            . "\nTYPE:$header->{'Content-Type'}\n\n";
    },
    'httpd.send_error_page' => sub {
        my ( $id, $status ) = @ARG;
        $data{'session'}{$id}{'test_error'} = $status;
        return $status;
    },
    'httpd.download_init' => sub {
        my $params = shift;
        my $id     = $params->{'sid'};
        my $range  = $data{'session'}{$id}{'http'}{'request'}{'range'};
        if ( defined $range ) {
            $params->{'header'}{'Content-Range'} = sprintf 'bytes %d-%d/%d',
                $range->[0]{'start'}, $range->[0]{'end'},
                $params->{'header'}{'Content-Length'};
            $params->{'header'}{'Content-Length'}
                = 1 + $range->[0]{'end'} - $range->[0]{'start'};
        }
        $data{'session'}{$id}{'test_download'} = $params;
        return 0;
    },
    'source.extract_sig_body' => sub {
        my $body     = shift;
        my $original = $body->$*;
        my $stripped = fixture_body($original);
        if ( $stripped eq $original ) {
            return {
                'was-present' => $original =~ m{AMOS7|DATA SIGNATURE}
                ? TRUE
                : FALSE,
                'structure-was-valid' => FALSE,
                'encountered-error'   => 'footer-structure'
            };
        }
        $body->$* = $stripped;
        return {
            'was-present'             => TRUE,
            'structure-was-valid'     => TRUE,
            'encountered-error'       => undef,
            'needs_separator_endline' => FALSE
        };
    },
    'source.signature_valid' => sub {
        my ( $body, $footer ) = @ARG;
        my $valid = $body->$* eq $valid_payload;
        return (
            $valid,
            {   'AMOS-chksum-matches' => $valid,
                'bmw-chksum-matches'  => $valid,
                'signature-is-valid'  => $valid
            }
        );
    }
);

compile_module($_)
    foreach qw| source.generated_envelope source.verify_and_strip
    httpd.parse_range_header |;
compile_module( 'base.chk-sum.bmw.ctx',    'chk-sum.bmw.ctx' );
compile_module( 'base.chk-sum.bmw.strsum', 'chk-sum.bmw.strsum' );
compile_module($_) foreach qw|
    httpd.signature_policy
    httpd.signature_persistent
    httpd.signature_cache_key
    httpd.signature_trust_context
    httpd.signature_cache_init
    httpd.signature_memory_invalidate
    httpd.signature_memory_pressure
    httpd.signature_memory_store
    |;
$code{'httpd.signature_watch'}         = sub { return TRUE };
$code{'httpd.json.encode'}             = sub { return '{}' };
$code{'base.ntime.b32'}                = sub { return 13 };
$code{'protocol-7.command.send.local'} = sub { return TRUE };
$code{'httpd.determine_host'}          = sub { return 'test-vhost' };
$code{'httpd.vhost_template_resolver'} = sub { return undef };
$data{'chk-sum'}{'bmw'} = { map { $ARG => undef } 224, 256, 384, 512 };
$data{'system'}{'zenka'}{'name'}         = 'httpd-test';
$data{'system'}{'zenka-user'}{'current'} = getpwuid($EUID);
$data{'httpd'}{'system'}{'user'}         = getpwuid($EUID);
$data{'httpd'}{'system'}{'group'}        = getgrgid($GID);
$data{'httpd'}{'signature'}{'cache_dir'}
    = File::Spec->catdir( $temp_dir, 'persistent' );
$data{'httpd'}{'signature'}{'pressure_next_check'} = time + 3600;
my ( $persistent_state, $persistent_error )
    = $code{'httpd.signature_persistent'}->('init');
die "persistent test cache : " . ( $persistent_error // 'unknown' )
    if not defined $persistent_state;

$code{'httpd.signature_verify_start'} = sub {
    my ( $id, $path, $identity ) = @ARG;
    my $content = read_file($path);
    my $result  = $code{'source.verify_and_strip'}->( \$content );
    my $entry   = {
        identity => $identity,
        status   => $result->{'status'},
        error    => $result->{'error'},
        hits     => 0
    };
    if ( $result->{'status'} eq 'valid' ) {
        my $body_path = File::Spec->catfile( $temp_dir, "body-$id" );
        write_file( $body_path, $result->{'body'}->$* );
        $entry->{'body_path'} = $body_path;
        $entry->{'body_size'} = -s $body_path;
        $entry->{'body_ref'}  = $result->{'body'};
    }
    $code{'httpd.signature_memory_store'}->( $path, $entry );
    $data{'httpd'}{'signature'}{'verify_count'}++;
    return $code{'httpd.serve_static'}
        ->( $id, { path => $data{'session'}{$id}{'test_path'} } );
};

compile_module($_) foreach qw|
    httpd.get_mime_type
    httpd.serve_static
    httpd.process_template
    httpd.route_dispatcher
    httpd.http_get
    httpd.http_head
    httpsd.route_template_request
    |;

$data{'httpd'}{'cfg'}{'hostnames'}{'test-vhost'} = $site_dir;
$data{'httpd'}{'cfg'}{'require_signature_html'}  = {};
$data{'httpd'}{'site_dir'}                       = $site_dir;

sub request {
    my ( $name, $range ) = @ARG;
    my $id = 13;
    $data{'session'}{$id} = {
        http_host => 'test-vhost',
        http      => {
            request => { headers => {}, uri => $name, host => 'test-vhost' },
            close   => TRUE
        },
        response   => { params => {} },
        buffer     => { output => '' },
        start_time => time,
        test_path  => $name
    };
    $data{'session'}{$id}{'http'}{'request'}{'headers'}{'range'} = $range
        if defined $range;
    $code{'httpd.serve_static'}->( $id, { path => $name } );
    return $data{'session'}{$id};
}

my $fixture_path = File::Spec->catfile( $main::root_path,
    qw| src httpd.parse_range_header | );
my $signed_content = read_file($fixture_path);
$valid_payload = fixture_body($signed_content);
my $signed_path = File::Spec->catfile( $site_dir, 'valid.html' );
write_file( $signed_path, $signed_content );

my $session = request('/valid.html');
ok( !defined $session->{'test_error'}, 'valid signed html is served' );
ok( $session->{'buffer'}{'output'} =~ m{^STATUS:200\nLENGTH:}m,
    'valid signed html has a successful length header'
);
my ($declared_length)
    = $session->{'buffer'}{'output'} =~ m{^LENGTH:(\d+)$}m;
my ($served_body) = $session->{'buffer'}{'output'} =~ m{\n\n(.*)$}s;
ok( $declared_length == length($valid_payload),
    'content-length uses stripped size'
);
ok( $served_body eq $valid_payload,    'valid signed html body is stripped' );
ok( $served_body !~ m{DATA SIGNATURE}, 'signature footer is absent' );

my $verify_count = $data{'httpd'}{'signature'}{'verify_count'};
$session = request('/valid.html');
ok( $data{'httpd'}{'signature'}{'verify_count'} == $verify_count,
    'unchanged identity uses verification cache' );
ok( $data{'httpd'}{'signature'}{'cache_hits'} > 0, 'cache hit is recorded' );

write_file( $signed_path, $signed_content . "<!-- tampered -->\n" );
$session = request('/valid.html');
ok( ( $session->{'test_error'} // 0 ) == 403,
    'tampered signed html is refused'
);
ok( $data{'httpd'}{'signature'}{'verify_count'} == $verify_count + 1,
    'changed identity is verified again' );
ok( ( grep {m{signed-file refused : /valid.html :}} @logs ) == 1,
    'refusal logs one path and failed-check line' );

write_file( $signed_path, $signed_content );
$session = request( '/valid.html', 'bytes=0-4' );
my $download = $session->{'test_download'};
ok( defined $download, 'range request enters download path' );
ok( ( $download->{'header'}{'Content-Range'} // '' ) eq 'bytes 0-4/'
        . length($valid_payload),
    'range header uses stripped size'
) if defined $download;
ok( ( $download->{'session'} // '' ) eq '',
    'range test uses transfer parameters'
) if 0;

my $request_range = $session->{'http'}{'request'}{'range'};
ok( $request_range
        && $request_range->[0]{'start'} == 0
        && $request_range->[0]{'end'} == 4,
    'range offsets target stripped payload'
);

my $unsigned_path = File::Spec->catfile( $site_dir, 'plain.html' );
my $unsigned_body = "<html><body>unsigned</body></html>\n";
write_file( $unsigned_path, $unsigned_body );
$session = request('/plain.html');
ok( !defined $session->{'test_error'}, 'unsigned html served by default' );
($served_body) = $session->{'buffer'}{'output'} =~ m{\n\n(.*)$}s;
ok( $served_body eq $unsigned_body, 'unsigned html body is unchanged' );

$data{'httpd'}{'cfg'}{'require_signature_html'}{'test-vhost'} = 1;
$session = request('/plain.html');
ok( ( $session->{'test_error'} // 0 ) == 403,
    'per-vhost option refuses unsigned html'
);

$data{'httpd'}{'cfg'}{'require_signature_html'} = {};
$session = request('/valid.html');
ok( !defined $session->{'test_error'},
    'valid html still served when signature option is available' );

my $policy = $code{'httpd.signature_policy'}->( 'test-vhost', 'text/css' );
ok( $policy->{'selected'} && $policy->{'mode'} eq 'verify',
    'default policy verifies css signatures' );
$policy = $code{'httpd.signature_policy'}
    ->( 'test-vhost', 'application/javascript' );
ok( $policy->{'selected'}, 'default policy verifies javascript signatures' );
$data{'httpd'}{'cfg'}{'signature_types'} = 'html';
$policy = $code{'httpd.signature_policy'}->( 'test-vhost', 'text/css' );
ok( !$policy->{'selected'}, 'configured types exclude css' );
$data{'httpd'}{'cfg'}{'signature_types'} = 'html css js';

$data{'httpd'}{'cfg'}{'signature_mode'} = 'off';
$session = request('/valid.html');
($served_body) = $session->{'buffer'}{'output'} =~ m{\n\n(.*)$}s;
ok( $served_body =~ m{DATA SIGNATURE},
    'off mode serves signed bytes unchecked'
);
$data{'httpd'}{'cfg'}{'signature_mode'} = 'require';
$session = request('/plain.html');
ok( ( $session->{'test_error'} // 0 ) == 403,
    'global require mode refuses unsigned html'
);
$data{'httpd'}{'cfg'}{'signature_mode'}
    = { default => 'require', 'test-vhost' => 'off' };
$session = request('/plain.html');
ok( !defined $session->{'test_error'},
    'per-vhost off overrides global require'
);
$data{'httpd'}{'cfg'}{'require_signature_html'}{'test-vhost'} = 1;
$policy = $code{'httpd.signature_policy'}->( 'test-vhost', 'text/html' );
ok( $policy->{'mode'} eq 'off',
    'explicit vhost mode overrides legacy alias' );
$data{'httpd'}{'cfg'}{'require_signature_html'} = {};
$data{'httpd'}{'cfg'}{'signature_mode'}         = 'verify';
$data{'httpd'}{'cfg'}{'signature_types'}        = 'html css js tmpl';

$policy = $code{'httpd.signature_policy'}
    ->( 'test-vhost', 'application/octet-stream', '/site/example.tmpl' );
ok( $policy->{'selected'} && $policy->{'type'} eq 'tmpl',
    'default policy selects templates by filename'
);
my $signed_template_path = File::Spec->catfile( $site_dir, 'valid.tmpl' );
write_file( $signed_template_path, $signed_content );
$session = request('/valid.tmpl');
ok( defined $session->{'content'}{'template_path'},
    'valid signed template is processed'
);
ok( read_file( $session->{'content'}{'template_path'} ) eq $valid_payload,
    'template processor receives the stripped body' );
write_file( $signed_template_path, $signed_content . "<!-- tampered -->\n" );
$session = request('/valid.tmpl');
ok( ( $session->{'test_error'} // 0 ) == 403
        && !defined $session->{'content'}{'template_path'},
    'invalid template is refused before processing'
);
my $unsigned_template_path = File::Spec->catfile( $site_dir, 'plain.tmpl' );
write_file( $unsigned_template_path, $unsigned_body );
$session = request('/plain.tmpl');
ok( !defined $session->{'test_error'}
        && read_file( $session->{'content'}{'template_path'} ) eq
        $unsigned_body,
    'unsigned template is processed in verify mode'
);
$data{'httpd'}{'cfg'}{'signature_mode'} = 'require';
$session = request('/plain.tmpl');
ok( ( $session->{'test_error'} // 0 ) == 403
        && !defined $session->{'content'}{'template_path'},
    'unsigned template is refused in require mode'
);
$data{'httpd'}{'cfg'}{'signature_mode'} = 'verify';
my $fallback_template_path
    = File::Spec->catfile( $site_dir, 'fallback.tmpl' );
write_file( $fallback_template_path, $unsigned_body );
$session = request('/fallback');
ok( !defined $session->{'test_error'}
        && $session->{'content'}{'template_path'} eq $fallback_template_path,
    'template fallback is checked before processing'
);
ok( $session->{'content'}{'type'} eq 'text/html; charset=UTF-8',
    'extensionless template fallback keeps html content type'
);
my $index_dir = File::Spec->catdir( $site_dir, 'dir' );
mkdir $index_dir or die "mkdir $index_dir : $OS_ERROR";
my $index_template_path = File::Spec->catfile( $index_dir, 'index.tmpl' );
write_file( $index_template_path, $unsigned_body );
$session = request('/dir/');
ok( !defined $session->{'test_error'}
        && $session->{'content'}{'template_path'} eq $index_template_path,
    'directory index template is checked before processing'
);
ok( $session->{'content'}{'type'} eq 'text/html; charset=UTF-8',
    'directory index template keeps html content type'
);

sub template_type_case {
    my ( $name, $expected ) = @ARG;
    my $path = File::Spec->catfile( $site_dir, $name );
    write_file( $path, $unsigned_body );
    my $before = $data{'httpd'}{'signature'}{'verify_count'};
    my $result = request("/$name");
    ok( $result->{'content'}{'type'} eq $expected,
        "$name output uses its own content type"
    );
    ok( $data{'httpd'}{'signature'}{'verify_count'} == $before + 1,
        "$name is verified as type tmpl before processing"
    );
}
template_type_case( 'post.html.tmpl', 'text/html; charset=UTF-8' );
template_type_case( 'app.js.tmpl',    'text/javascript; charset=UTF-8' );
template_type_case( 'style.css.tmpl', 'text/css; charset=UTF-8' );
template_type_case( 'data.asc.tmpl',  'text/plain; charset=UTF-8' );
template_type_case( 'page.tmpl',      'text/html; charset=UTF-8' );

sub static_type_case {
    my $name = shift;
    my $path = File::Spec->catfile( $site_dir, $name );
    write_file( $path, $unsigned_body );
    my $result = request("/$name");
    my ($type) = $result->{'buffer'}{'output'} =~ m{^TYPE:([^\n]+)}m;
    ok( ( $type // '' ) eq 'text/plain; charset=UTF-8',
        "static $name uses the asc text content type"
    );
}
static_type_case('README');
static_type_case('data.asc');
static_type_case('.html');

$code{'httpd.vhost_template_resolver'}
    = sub { return $unsigned_template_path };
$data{'route_cache'} = {};
my $template_route
    = $code{'httpd.route_dispatcher'}->( 'GET', '/routed', 'test-vhost', 13 );
ok( $template_route->{'handler'} eq 'httpd.serve_static'
        && $template_route->{'handler_args'}{'template_path'} eq
        $unsigned_template_path,
    'route dispatcher selects verified template handler'
);
$data{'httpd'}{'cfg'}{'signature_mode'} = 'require';
$data{'route_cache'}                    = {};
$session                                = request('/routed');
$code{'httpd.http_get'}->(13);
ok( ( $session->{'test_error'} // 0 ) == 403
        && !defined $session->{'content'}{'template_path'},
    'GET route refuses unsigned template in require mode'
);
$session = request('/plain.tmpl');
$code{'httpd.http_head'}->(13);
ok( ( $session->{'test_error'} // 0 ) == 403
        && !defined $session->{'content'}{'template_path'},
    'HEAD route refuses unsigned template in require mode'
);
$data{'httpsd'}{'route_cache'} = {};
my $https_template_route = $code{'httpsd.route_template_request'}
    ->( 'GET', '/routed', 'test-vhost', 13 );
ok( $https_template_route->{'handler'} eq 'httpd.serve_static',
    'HTTPS route selects verified template handler'
);
$session = request('/routed');
$code{'httpd.serve_static'}->( 13, $https_template_route->{'handler_args'} );
ok( ( $session->{'test_error'} // 0 ) == 403
        && !defined $session->{'content'}{'template_path'},
    'HTTPS route refuses unsigned template in require mode'
);
$data{'httpd'}{'cfg'}{'signature_mode'} = 'verify';
$code{'httpd.vhost_template_resolver'} = sub { return undef };

my $persistent_payload = $signed_content . 'persistent test fixture';
my $cache_checksum
    = $code{'chk-sum.bmw.strsum'}->( \$persistent_payload, 384 );
my $stored = $code{'httpd.signature_persistent'}->(
    'store',
    {   checksum          => $cache_checksum,
        status            => 'valid',
        key_name          => 'proto-7.sourcecode',
        trust_fingerprint => 'C' x 77
    }
);
ok( ref $stored eq 'HASH',
    'persistent verification result is stored [ '
        . ( ref $stored ? 'ok' : $stored // 'undef' ) . ' : '
        . length( $cache_checksum // '' ) . ' ]'
);
my ( $persistent_hit, $persistent_lookup_error )
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => $cache_checksum } );
ok( ( $persistent_hit->{'status'} // '' ) eq 'valid',
    'persistent cache returns valid result and key'
);
ok( ( $persistent_hit->{'key_name'} // '' ) eq 'proto-7.sourcecode',
    'persistent cache retains verification key name' );
delete $data{'httpd'}{'signature'}{'persistent_state'};
( $persistent_hit, $persistent_lookup_error )
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => $cache_checksum } );
ok( ( $persistent_hit->{'status'} // '' ) eq 'valid',
    'persistent result survives cache state restart'
);
my $persistent_path
    = File::Spec->catfile( $data{'httpd'}{'signature'}{'cache_dir'},
    'verification.cache' );
my $persistent_content = read_file($persistent_path);
my $planted            = join( ' ',
    'B' x 77, 'valid', '-', 'proto-7.sourcecode', 'C' x 77, '-', '-', time )
    . "\n";
$persistent_content =~ s{^P7-SIGNATURE-CACHE 2\n}{$&$planted}m;
write_file( $persistent_path, $persistent_content );
chmod 0600, $persistent_path;
( $persistent_hit, $persistent_lookup_error )
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => 'B' x 77 } );
ok( !defined $persistent_hit
        && ( $persistent_lookup_error // '' ) eq 'cache-authentication',
    'planted valid entry is refused by authentication'
);
$stored = $code{'httpd.signature_persistent'}->(
    'store',
    {   checksum          => $cache_checksum,
        status            => 'valid',
        key_name          => 'proto-7.sourcecode',
        trust_fingerprint => 'C' x 77
    }
);
ok( ref $stored eq 'HASH' && $stored->{'recovered'} eq 'cache-authentication',
    'full verification can replace a tampered persistent cache'
);

my $trusted_v1 = "\x11" x 32;
my $trusted_v2 = "\x22" x 32;
my $bound_v1   = $code{'httpd.signature_cache_key'}->(
    {   payload            => \$persistent_payload,
        key_name           => 'proto-7.sourcecode',
        trusted_public_key => $trusted_v1,
    }
);
my $bound_rotated = $code{'httpd.signature_cache_key'}->(
    {   payload            => \$persistent_payload,
        key_name           => 'proto-7.sourcecode',
        trusted_public_key => $trusted_v2,
    }
);
my $bound_other_name = $code{'httpd.signature_cache_key'}->(
    {   payload            => \$persistent_payload,
        key_name           => 'other.key',
        trusted_public_key => $trusted_v1,
    }
);
ok( $bound_v1->{'checksum'} ne $bound_rotated->{'checksum'},
    'trusted key rotation changes the persistent cache key'
);
ok( $bound_v1->{'checksum'} ne $bound_other_name->{'checksum'},
    'different key name changes the persistent cache key'
);
$stored = $code{'httpd.signature_persistent'}->(
    'store',
    {   checksum          => $bound_v1->{'checksum'},
        status            => 'valid',
        key_name          => 'proto-7.sourcecode',
        trust_fingerprint => $bound_v1->{'trust_fingerprint'},
    }
);
my ($rotation_hit)
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => $bound_rotated->{'checksum'} } );
my ($other_name_hit)
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => $bound_other_name->{'checksum'} } );
ok( !defined $rotation_hit,
    'rotated trusted key misses the old valid entry' );
ok( !defined $other_name_hit,
    'different key name misses the old valid entry' );

my $valid_cache_dir = $data{'httpd'}{'signature'}{'cache_dir'};
my $bad_cache_path
    = File::Spec->catfile( $temp_dir, 'cache-not-a-directory' );
write_file( $bad_cache_path, 'not a directory' );
$data{'httpd'}{'signature'}{'cache_dir'} = $bad_cache_path;
delete $data{'httpd'}{'signature'}{'persistent_state'};
my $init_result;
my $init_error = do {
    local $EVAL_ERROR;
    eval { $init_result = $code{'httpd.signature_cache_init'}->() };
    $EVAL_ERROR;
};
ok( !$init_error
        && !$init_result
        && $data{'httpd'}{'signature'}{'persistent_disabled'},
    'cache initialization failure continues without persistence'
);
ok(
    (   grep {m{signed-file persistent cache disabled .* full verification}}
            @logs
    ) >= 1,
    'disabled persistent cache logs a full-verification warning'
);
$data{'httpd'}{'signature'}{'cache_dir'} = $valid_cache_dir;
delete $data{'httpd'}{'signature'}{'persistent_state'};
$code{'httpd.signature_cache_init'}->();

my $lru_body  = '12345678';
my $lru_path  = File::Spec->catfile( $site_dir, 'lru-a.html' );
my $lru_file  = File::Spec->catfile( $temp_dir, 'lru-body-a' );
my $lru_file2 = File::Spec->catfile( $temp_dir, 'lru-body-b' );
write_file( $lru_file,  $lru_body );
write_file( $lru_file2, $lru_body );
$data{'httpd'}{'cfg'}{'signature_memory_bytes'}    = 10;
$data{'httpd'}{'cfg'}{'signature_memory_file_max'} = 100;
$code{'httpd.signature_memory_store'}->(
    $lru_path,
    {   status    => 'valid',
        body_ref  => \$lru_body,
        body_size => 8,
        body_path => $lru_file
    }
);
my $lru_body2 = 'abcdefgh';
$code{'httpd.signature_memory_store'}->(
    "$lru_path-b",
    {   status    => 'valid',
        body_ref  => \$lru_body2,
        body_size => 8,
        body_path => $lru_file2
    }
);
ok( !exists $data{'httpd'}{'signature'}{'cache'}{$lru_path}
        && $data{'httpd'}{'signature'}{'memory_bytes'} <= 10,
    'memory LRU evicts oldest body at its byte limit'
);
ok( !-e $lru_file && -e $lru_file2,
    'LRU eviction removes only the evicted temporary body' );
$code{'httpd.signature_memory_invalidate'}->("$lru_path-b");
ok( !exists $data{'httpd'}{'signature'}{'cache'}{"$lru_path-b"}
        && !-e $lru_file2,
    'explicit invalidation removes result and temporary body'
);
$data{'httpd'}{'cfg'}{'signature_memory_bytes'}    = 8 * 1024 * 1024;
$data{'httpd'}{'cfg'}{'signature_memory_file_max'} = 256 * 1024;

compile_module($_)
    foreach qw| httpd.signature_verify_start httpd.handler.signature_verify |;
ok( ( grep {m{signed-file debug :}} @logs ) == 0,
    'signature diagnostics are off by default'
);
$data{'httpd'}{'cfg'}{'signature_debug'} = 1;
my $async_path = File::Spec->catfile( $site_dir, 'async.html' );
write_file( $async_path, $signed_content );
$session = request('/async.html');
my $poll_rounds = 0;

while ( exists $session->{'signature_pending'} and $poll_rounds++ < 200 ) {
    my $watcher = $session->{'watcher'}{'signature_handler'};
    my $readset = '';
    vec( $readset, fileno( $watcher->fd ), 1 ) = 1;
    next if not select( $readset, undef, undef, 0.05 );
    $code{'httpd.handler.signature_verify'}
        ->( TestSignatureEvent->new($watcher) );
}
ok( !exists $session->{'signature_pending'},
    'asynchronous child verification completes'
);
ok( !defined $session->{'test_error'}
        && $session->{'buffer'}{'output'} =~ m{^STATUS:200}m,
    'asynchronously verified html is served'
);
($served_body) = $session->{'buffer'}{'output'} =~ m{\n\n(.*)$}s;
ok( $served_body eq $valid_payload,
    'asynchronous path serves the child-written stripped body' );
ok( ( grep {m{signed-file debug : /async.html : .*status=valid}} @logs ) == 1,
    'enabled diagnostics identify the verified file and status'
);
ok( ( grep {m{signature=1;signature-unverifiable=na}} @logs ) == 1,
    'enabled diagnostics report individual signature checks'
);

my $full_verifications = $data{'httpd'}{'signature'}{'verify_count'};
$code{'httpd.signature_memory_invalidate'}->($async_path);
utime time, time + 13, $async_path;
$session     = request('/async.html');
$poll_rounds = 0;
while ( exists $session->{'signature_pending'} and $poll_rounds++ < 200 ) {
    my $watcher = $session->{'watcher'}{'signature_handler'};
    my $readset = '';
    vec( $readset, fileno( $watcher->fd ), 1 ) = 1;
    next if not select( $readset, undef, undef, 0.05 );
    $code{'httpd.handler.signature_verify'}
        ->( TestSignatureEvent->new($watcher) );
}
ok( !defined $session->{'test_error'}
        && ( $data{'httpd'}{'signature'}{'persistent_hits'} // 0 ) == 1,
    'mtime-only change reuses authenticated persistent verification'
);
ok( $data{'httpd'}{'signature'}{'verify_count'} == $full_verifications,
    'persistent cache hit skips full verification' );
($served_body) = $session->{'buffer'}{'output'} =~ m{\n\n(.*)$}s;
ok( $served_body eq $valid_payload,
    'persistent cache hit still returns the stripped body' );

$data{'httpd'}{'signature'}{'persistent_disabled'} = TRUE;
$code{'httpd.signature_memory_invalidate'}->($async_path);
$session     = request('/async.html');
$poll_rounds = 0;
while ( exists $session->{'signature_pending'} and $poll_rounds++ < 200 ) {
    my $watcher = $session->{'watcher'}{'signature_handler'};
    my $readset = '';
    vec( $readset, fileno( $watcher->fd ), 1 ) = 1;
    next if not select( $readset, undef, undef, 0.05 );
    $code{'httpd.handler.signature_verify'}
        ->( TestSignatureEvent->new($watcher) );
}
ok( $data{'httpd'}{'signature'}{'verify_count'} == $full_verifications + 1
        && $data{'httpd'}{'signature'}{'persistent_hits'} == 1,
    'disabled persistence performs full verification without a lookup'
);
$data{'httpd'}{'signature'}{'persistent_disabled'} = FALSE;

say $fail_count ? ": FAIL [ $fail_count ]" : ': all tests passed';
exit( $fail_count ? 1 : 0 );

#,,,.,..,,,,.,..,,.,.,,,,,...,,,.,,.,,.,,,.,,,..,,...,...,...,...,..,,.,,,,.,,
#5OCELGWO2ZMZAZ2MRWZMDKJV7L7RC3F2CXHHVD7FPJQMVU6O3SZKLZQA6WD5BDEJTMZIS7OKHUSE4
#\\\|6RSP4TJLIJNHQLP53UTDM5XLUSRLDKIHHTSNL3PY2XYWX2KWDIK \ / AMOS7 \ YOURUM ::
#\[7]K7I4QNUCODF4I7ECBYXMKYCDK65S6LPUN6BB2TQ6ON624L6VSGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
