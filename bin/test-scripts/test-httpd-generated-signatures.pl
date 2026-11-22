#!/usr/bin/perl
use v5.32;
use strict;
use warnings;
use English;

use Cwd qw| abs_path |;
use File::Spec;
use File::stat qw| stat |;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Fcntl;
use Test::More;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | );
    $main::root_path = $root_path;
}

use AMOS7;
use AMOS7::CHKSUM;
use AMOS7::B32 qw| encode_b32r decode_b32r |;
use AMOS7::Assert::Truth;
use AMOS7::Desktop::Theme     ();
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Ed25519            ();
use Digest::BMW               ();

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our %keys;

$data{'source'}{'chksum_bitsize'} = 384;
$data{'chk-sum'}{'bmw'} = { map { $ARG => undef } 224, 256, 384, 512 };
$data{'source'}{'C25519'}{'signature_key_name'} = 'proto-7.sourcecode';
$data{'source'}{'sign_template'}                = <<'EOT';
#..........,..........,..........,..........,..........,..........,..........,
#_____________________________________________________________________________
#\\\|___________________________________________________ \ / AMOS7 \ YOURUM ::
#\[7]____________________________________________________ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
EOT

%code = (
    'base.log'                   => sub { return TRUE },
    'base.logs'                  => sub { return TRUE },
    'base.cnt_s'                 => sub { return '' },
    'base.parser.ellipse_center' => sub { return shift },
    'base.s_warn'                => sub { return TRUE },
    'base.sleep'                 => sub { return TRUE },
    'event.once'                 => sub { return TRUE },
    'base.perlmod.autoload'      => sub { return TRUE },
    'base.file.put'              => sub { return TRUE },
    'crypt.C25519.key_vars'      => sub {
        my $requested = shift // 'proto-7.sourcecode';
        return { key_name => $requested };
    }
);

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

compile_module($_) foreach qw|
    source.extract_sig_body
    source.generated_envelope
    source.signature_valid
    source.verify_and_strip
    source.restore_payload_endline_state
    source.harmonize_payload_line_feed
    source.create_harmonic_footer
    source.fill_source_template
    source.sign_generated
    source.sign_data
    amos7.decode_octal_bit_header
    amos7.encode_octal_header
    base.chk-sum.from_substr
    crypt.C25519.verify_sign
    crypt.C25519.sign_data
    trust.chain
    trust.statement
    trust.key_id
    trust.verify
    httpd.generator_delegation
    httpd.generator_key_trust
    httpd.signature_cache_key
    httpd.signature_trust_context
    httpd.signature_persistent
    httpd.generate_theme_css
    sourcecode.signature_excluded
    sourcecode.console.update-signatures
    |;
compile_module( 'base.chk-sum.elf.inline', 'chk-sum.elf.inline' );
compile_module( 'base.chk-sum.elf',        'chk-sum.elf' );
compile_module( 'base.chk-sum.bmw.ctx',    'chk-sum.bmw.ctx' );
compile_module( 'base.chk-sum.bmw.strsum', 'chk-sum.bmw.strsum' );
compile_module( 'base.chk-sum.bmw.encode_digest',
    'chk-sum.bmw.encode_digest' );
compile_module( 'base.chk-sum.amos', 'chk-sum.amos' );

my @old_pair      = Crypt::Ed25519::generate_keypair( "\x21" x 32 );
my @new_pair      = Crypt::Ed25519::generate_keypair( "\x22" x 32 );
my @stranger_pair = Crypt::Ed25519::generate_keypair( "\x23" x 32 );
my @root_pair     = Crypt::Ed25519::generate_keypair( "\x24" x 32 );
$keys{'C25519'}{'generator-old'}
    = { public => $old_pair[0], private => $old_pair[1] };
$keys{'C25519'}{'generator-new'}
    = { public => $new_pair[0], private => $new_pair[1] };
$data{'system'}{'root_path'}                = $main::root_path;
$data{'system'}{'zenka'}{'name'}            = 'httpd';
$data{'httpd'}{'cfg'}{'generator_key_name'} = 'generator-old';
$data{'httpd'}{'cfg'}{'generator_host_roots'}
    = $code{'trust.key_id'}->( $root_pair[0] );

my %payload = (
    css  => ":root { --p7-test: 13px; }\n",
    html => "<html><body>generated</body></html>\n",
    js   => "const generated = 13;\n",
);
my %envelope = (
    css  => [ qr|/\* P7-GENERATED |,  qr|\*/\n\z| ],
    html => [ qr|<!-- P7-GENERATED |, qr|-->\n\z| ],
    js   => [ qr|/\* P7-GENERATED |,  qr|\*/\n\z| ],
);

foreach my $type (qw| css html js |) {
    my $signed = $code{'source.sign_generated'}
        ->( \$payload{$type}, 'generator-old', $type );
    ok( ref $signed eq 'SCALAR', "$type generated signature is created" );
    like( $signed->$*, $envelope{$type}[0], "$type comment opener is valid" );
    like( $signed->$*, $envelope{$type}[1], "$type comment closer is valid" );
    my $input = $signed->$*;
    my $result
        = $code{'source.verify_and_strip'}->( \$input, 'generator-old' );
    is( $result->{'status'}, 'valid', "$type comment footer verifies" );
    is( $result->{'body'}->$*,
        $payload{$type}, "$type comment footer strips to the exact payload" );
    is( $input, $payload{$type}, "$type input payload is restored" );
    ok( $result->{'generator_public_key'} eq $old_pair[0],
        "$type signer public key is returned for trust checking"
    );
}

my $theme_signed = $code{'httpd.generate_theme_css'}->();
ok( ref $theme_signed eq 'SCALAR', 'theme css uses the generator signer' );
my $theme_input = $theme_signed->$*;
my $theme_result
    = $code{'source.verify_and_strip'}->( \$theme_input, 'generator-old' );
is( $theme_result->{'status'}, 'valid', 'generated theme css verifies' );
like(
    $theme_result->{'body'}->$*,
    qr|--p7-font-size: 13px;|,
    'theme css still contains the configured theme tokens'
);

sub delegation {
    my ( $issuer, $private, $subject, $name ) = @ARG;
    my $now       = time;
    my $statement = $code{'trust.statement'}->(
        'build',
        {   issuer_pub  => $issuer,
            subject_pub => $subject,
            name        => $name,
            not_before  => $now - 13,
            not_after   => $now + 3600,
            scope       => '',
        }
    );
    my $signature = Crypt::Ed25519::sign( $statement, $issuer, $private );
    return $code{'trust.statement'}->( 'wire', $statement, $signature );
}

my $root_delegation
    = delegation( @root_pair[ 0, 1 ], $old_pair[0], 'test-host.zenka.httpd' );
my $record = $code{'httpd.generator_delegation'}->(
    {   vhost  => 'delegated-vhost',
        prefix => '/assets/',
        chain  => $root_delegation,
    }
);
ok( ref $record eq 'HASH', 'host-root delegated generator key is accepted' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'delegated-vhost',
        path       => '/assets/theme.css',
        public_key => $old_pair[0],
    }
);
ok( ref $record eq 'HASH', 'delegated key is trusted for its vhost prefix' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'delegated-vhost',
        path       => '/assets/theme.css',
        public_key => $stranger_pair[0],
    }
);
ok( !defined($record), 'unknown key is refused by a delegated prefix' );

$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'pinned-vhost',
        path       => '/theme.css',
        public_key => $old_pair[0],
    }
);
ok( ref $record eq 'HASH', 'first verified generator key is pinned' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'pinned-vhost',
        path       => '/theme.css',
        public_key => $stranger_pair[0],
    }
);
ok( !defined($record), 'unknown key is refused by a pinned prefix' );

my $old_rotation
    = delegation( @old_pair[ 0, 1 ], $new_pair[0], 'test-host.zenka.httpd' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'pinned-vhost',
        path       => '/theme.css',
        public_key => $new_pair[0],
        chain      => $old_rotation,
    }
);
ok( ref $record eq 'HASH', 'rotation signed by the old key is accepted' );

$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'root-rotate-vhost',
        path       => '/theme.css',
        public_key => $old_pair[0],
    }
);
ok( ref $record eq 'HASH', 'host-root rotation prefix starts pinned' );
my $root_rotation
    = delegation( @root_pair[ 0, 1 ], $new_pair[0], 'test-host.zenka.httpd' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'root-rotate-vhost',
        path       => '/theme.css',
        public_key => $new_pair[0],
        chain      => $root_rotation,
    }
);
ok( ref $record eq 'HASH' && $record->{'prefix'} eq '/',
    'host-root rotation keeps the configured path prefix'
);

$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'stranger-vhost',
        path       => '/theme.css',
        public_key => $old_pair[0],
    }
);
ok( ref $record eq 'HASH', 'separate prefix receives its own first-use pin' );
my $stranger_rotation = delegation( @stranger_pair[ 0, 1 ],
    $new_pair[0], 'test-host.zenka.httpd' );
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'stranger-vhost',
        path       => '/theme.css',
        public_key => $new_pair[0],
        chain      => $stranger_rotation,
    }
);
ok( !defined($record), 'rotation signed by a stranger is refused' );

$data{'sourcecode'}{'cfg'}{'signature_exclude'}
    = 'data/web-root/vhosts/jobsite.vhost/theme.css';
ok( $code{'sourcecode.signature_excluded'}
        ->('data/web-root/vhosts/jobsite.vhost/theme.css'),
    'configured generated theme is excluded from source signing'
);
ok( !$code{'sourcecode.signature_excluded'}
        ->('data/web-root/vhosts/jobsite.vhost/index.html'),
    'exclude list does not exclude neighbouring source files'
);

my $excluded_path = 'data/web-root/vhosts/jobsite.vhost/theme.css';
my $signer_called = 0;
my $exit_status;
$keys{'C25519'}{'proto-7.sourcecode'}
    = { public => 'public', private => 'private' };
$data{'sourcecode'}{'path'}{'work_tree'} = $main::root_path;
$code{'source.load_signature_key'}       = sub { return TRUE };
$code{'base.source.collect_file_list'}   = sub { return $excluded_path };
$code{'sourcecode.sign_file_list'}       = sub {
    $signer_called++;
    die 'excluded path reached the signer';
};
$code{'base.exit'} = sub {
    $exit_status = shift;
    die "expected excluded-path exit\n";
};
eval { $code{'sourcecode.console.update-signatures'}->($excluded_path) };
is( $signer_called, 0, 'update-signatures never signs an excluded path' );
is( $exit_status,   '0110', 'excluded explicit path leaves nothing to sign' );

my $delegated_payload = $payload{'html'};
my $delegated_signed  = $code{'source.sign_generated'}
    ->( \$delegated_payload, 'generator-old', 'html' );
my $delegated_input = $delegated_signed->$*;
$data{'httpd'}{'system'}{'user'}  = getpwuid($EUID);
$data{'httpd'}{'system'}{'group'} = getgrgid($GID);
$data{'httpd'}{'signature'}{'cache_dir'}
    = File::Spec->catdir( tempdir( CLEANUP => 1 ), 'persistent' );
my $cache_state = $code{'httpd.signature_persistent'}->('init');
ok( ref $cache_state eq 'HASH',
    'delegation cache test initializes persistence' );
my ($delegated_context) = $code{'httpd.signature_trust_context'}->(
    {   payload  => \$delegated_input,
        key_name => 'generator-old',
        vhost    => 'delegated-vhost',
        path     => '/assets/theme.html',
    }
);
ok( ref $delegated_context eq 'HASH',
    'trusted delegation produces a bound cache context' );
my $delegated_stored = $code{'httpd.signature_persistent'}->(
    'store',
    {   checksum          => $delegated_context->{'checksum'},
        status            => 'valid',
        key_name          => 'generator-old',
        trust_fingerprint => $delegated_context->{'trust_fingerprint'},
        public_b32        => $delegated_context->{'public_b32'},
        chain             => $delegated_context->{'chain'},
    }
);
my ( $delegated_hit, $delegated_lookup_error )
    = $code{'httpd.signature_persistent'}
    ->( 'lookup', { checksum => $delegated_context->{'checksum'} } );
ok( ( $delegated_hit->{'status'} // '' ) eq 'valid',
    'trusted delegation has a valid persistent entry before revocation [ '
        . ( ref $delegated_stored ? 'stored' : $delegated_stored // 'undef' )
        . ' : '
        . ( $delegated_lookup_error // 'no-error' ) . ' ]'
);
$data{'httpd'}{'generator'}{'delegations'}{'delegated-vhost'}{'/assets/'}
    {'not_after'} = time - 1;
my ( $revoked_context, $revoked_error )
    = $code{'httpd.signature_trust_context'}->(
    {   payload  => \$delegated_input,
        key_name => 'generator-old',
        vhost    => 'delegated-vhost',
        path     => '/assets/theme.html',
    }
    );
ok( !defined $revoked_context
        && $revoked_error eq 'generator-delegation-expired',
    'revoked delegation misses instead of using the old valid entry'
);
my ( $unpinned, $unpinned_error ) = $code{'httpd.generator_key_trust'}->(
    {   vhost       => 'lookup-only-vhost',
        path        => '/theme.css',
        public_key  => $old_pair[0],
        lookup_only => TRUE,
    }
);
ok( !defined $unpinned
        && !
        keys %{ $data{'httpd'}{'generator'}{'pins'}{'lookup-only-vhost'}
            // {} },
    'cache trust lookup never creates a first-use pin'
);
$record = $code{'httpd.generator_key_trust'}->(
    {   vhost      => 'lookup-reuse-vhost',
        path       => '/theme.css',
        public_key => $old_pair[0],
    }
);
ok( ref $record eq 'HASH'
        && $data{'httpd'}{'generator'}{'pins'}{'lookup-reuse-vhost'}{'/'},
    'lookup-only flag does not leak into the next call'
);

done_testing;

#,,.,,,.,,,,,,..,,,.,,,.,,,,.,,..,.,,,,.,,,,,,..,,...,..,,...,,.,,...,.,,,..,,
#FFBDFNJ2CSBJLL77O5MEFO7OP5WNZ3TXDNBMMADCG5ZEA5TVGRJA3G5VE476BRAKSWSDDHGEIUFEM
#\\\|EVTAE3D6PCC3DF77DIIB54TI3EBVTP4WEUKCCJDZHTAJSUIHZMP \ / AMOS7 \ YOURUM ::
#\[7]ACAHRLHL7OGB45B4UZLRJTFHC4FVBXJK6F267WBJBG3FKZNTP4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
