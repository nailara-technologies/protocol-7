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

use AMOS7::B32                qw| encode_b32r |;
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

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
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open my $fh, '<', $src_path or die "cannot read $src_path : $OS_ERROR";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
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
        $keys{'C25519'}{ $_[0] }{'public'} = TRUE;
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
        return "STATUS:$status\nLENGTH:$header->{'Content-Length'}\n\n";
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
    foreach qw| source.verify_and_strip httpd.parse_range_header |;

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
    }
    $data{'httpd'}{'signature'}{'cache'}{$path} = $entry;
    $data{'httpd'}{'signature'}{'verify_count'}++;
    return $code{'httpd.serve_static'}
        ->( $id, { path => $data{'session'}{$id}{'test_path'} } );
};

compile_module('httpd.serve_static');

$data{'httpd'}{'cfg'}{'hostnames'}{'test-vhost'} = $site_dir;
$data{'httpd'}{'cfg'}{'require_signature_html'} = {};

sub request {
    my ( $name, $range ) = @ARG;
    my $id = 13;
    $data{'session'}{$id} = {
        http_host => 'test-vhost',
        http      => {
            request => { headers => {}, uri => $name },
            close   => TRUE
        },
        response  => { params => {} },
        buffer    => { output => '' },
        test_path => $name
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

say $fail_count ? ": FAIL [ $fail_count ]" : ': all tests passed';
exit( $fail_count ? 1 : 0 );

#,,.,,...,...,,,.,...,.,.,,..,..,,.,.,,,.,,.,,..,,...,...,..,,,.,,...,,.,,..,,
#HVH7RZB2MM7VM7XUSJROKSTHVABWMD6SZFO4THMFDWV4XF2MIMXKOH5SI2QXMP7E3DRMHK7VEXKYC
#\\\|VBHGMYU7T7UCG63WVO5BZRKJ23QVYB2SO466V5JZK4IB2363F3S \ / AMOS7 \ YOURUM ::
#\[7]UUNRR7DBUNMUWH7GOLRQNFH5OYLWXPWMNFY6ONXK26NCZP4TRECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
