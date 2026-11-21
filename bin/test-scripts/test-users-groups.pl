#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use bytes;
use File::Spec;
use File::Path qw| make_path |;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;
use YAML::XS   ();

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use AMOS7::CHKSUM             ();

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our @ARG;
our $call;

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $condition, $label ) = @ARG;
    $checks++;
    if ($condition) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

sub compile_module {
    my ($name) = @ARG;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open( my $fh, '<:raw', $path ) or die "cannot read $name : $OS_ERROR";
    my $source = join( '', <$fh> );
    close($fh);
    my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
    die "$name compile : $EVAL_ERROR" if not $compiled;
    $code{$name} = $compiled;
    return $compiled;
}

my $tmp = tempdir( 'p7-users-groups-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $records_dir = File::Spec->catdir( $tmp, 'records' );
make_path($records_dir);

$code{'base.logs'}  = sub { return TRUE };
$code{'base.ntime'} = sub { return 1_700_000_000 };
$code{'base.sort'}  = sub {
    my ($ref) = @ARG;
    return sort keys %{$ref} if ref $ref eq 'HASH';
    return sort @{$ref};
};
$code{'chk-sum.amos'} = sub {
    return AMOS7::CHKSUM::amos_chksum( \$ARG[0] );
};
$code{'base.path.resolve_keywords'} = sub {
    my $path = shift // '';
    $path =~ s|^\[USERS_HOST\]|$records_dir|;
    return $path;
};
$code{'file.make_path'} = sub {
    my ($path) = @ARG;
    make_path($path);
    return -d $path ? TRUE : FALSE;
};
$code{'file.match_dirs'} = sub {
    my ( $path, $pattern ) = @ARG;
    return grep { -d $ARG } glob( File::Spec->catdir( $path, $pattern ) );
};
$code{'format.yaml.load_keyword_path'} = sub {
    my $path = $code{'base.path.resolve_keywords'}->( shift // '' );
    return undef if not -f $path;
    return YAML::XS::LoadFile($path);
};
$code{'format.yaml.write_file'} = sub {
    my ( $path, $record ) = @ARG;
    YAML::XS::DumpFile( $path, $record );
    return ( TRUE, undef );
};
$code{'format.yaml.dump_str'} = sub { return YAML::XS::Dump( $ARG[0] ) };

$code{'base.access.special-user-map'} = sub {
    my $template = shift // '';
    my %map      = (
        '<admin-user>' => 'test-admin',
        '<unix-admin>' => 'unix-test-admin',
        '<AMOS-user>'  => 'test-admin'
    );
    return sort keys %map if not length $template;
    return $map{$template} // $template;
};
$data{'users'}{'cfg'}{'group'}{'web_level_max'} = 20;
$code{'base.load_config_file'} = sub {
    my ($name) = @ARG;
    if ( $name =~ m|access\.zenki$| ) {
        $data{'access'}{'cmd'}{'usr'}{'media-operators'} = 'status list';
    } else {
        $data{'access'}{'cmd'}{'usr'}{'<admin-user>'} = '** status';
        $data{'access'}{'cmd'}{'usr'}{'<AMOS-user>'}  = 'status';
    }
    return TRUE;
};

compile_module($ARG) for qw|
    users.group.path
    users.group.ensure_dir
    users.group.build
    users.group.validate
    users.group.read
    users.group.cube_records
    users.group.cube_admin_level
    users.cmd.group-list
    users.cmd.group-get
    users.cmd.group-create
    users.cmd.group-add
    users.cmd.group-remove
    |;

sub run_cmd {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args // '' };
    return $code{"users.cmd.$name"}->();
}

say ': resolved cube groups';
my $cube_groups = $code{'users.group.cube_records'}->();
ok( $cube_groups->{'<admin-user>'}{'fields'}{'members'}[0] eq 'test-admin',
    'cube membership uses the existing special-user resolver'
);
ok( $cube_groups->{'<admin-user>'}{'fields'}{'security_level'} == 1_000_000,
    'cube wildcard admin keeps its unbounded level' );
my $reply = run_cmd( 'group-get', '<admin-user> cube' );
ok( $reply->{'mode'} eq 'size' && $reply->{'data'} =~ m|namespace:\s+cube|,
    'group-get returns a resolved cube record' );

say ': web create, add and remove';
$reply = run_cmd( 'group-create',
    'media-readers namespace=web level=20 scopes=media:read,ui ttl=3600' );
ok( $reply->{'mode'} eq 'true', 'web group creation succeeds' );
my $record_path = File::Spec->catfile( $records_dir,
    qw| groups web media-readers details.yaml | );
ok( -f $record_path && index( $record_path, $tmp ) == 0,
    'record is written only below the temporary store'
);
my $stored = YAML::XS::LoadFile($record_path);
ok( $stored->{'fields'}{'namespace'} eq 'web'
        && $stored->{'fields'}{'ttl'} == 3600
        && $stored->{'fields'}{'security_level'} == 20,
    'namespace, level and ttl round-trip through yaml'
);
ok( $stored->{'checksum'} eq substr(
        AMOS7::CHKSUM::amos_chksum( \'group:web:media-readers' ),
        0, 7
    ),
    'record carries the users-style AMOS identity checksum'
);

$reply = run_cmd( 'group-add', 'media-readers reader-one' );
ok( $reply->{'mode'} eq 'true', 'group-add stores a member' );
$stored = YAML::XS::LoadFile($record_path);
ok( join( ',', @{ $stored->{'fields'}{'members'} } ) eq 'reader-one',
    'added member is present in the stored list' );
my $created_timestamp = $stored->{'timestamp'};
$reply  = run_cmd( 'group-remove', 'media-readers reader-one' );
$stored = YAML::XS::LoadFile($record_path);
ok( $reply->{'mode'} eq 'true' && !@{ $stored->{'fields'}{'members'} },
    'group-remove deletes the member' );
ok( $stored->{'timestamp'} == $created_timestamp,
    'updates preserve the creation timestamp'
);

say ': namespace and level refusals';
for my $command (qw| group-add group-remove |) {
    $reply = run_cmd( $command, '<admin-user> reader-one' );
    ok( $reply->{'mode'} eq 'false'
            && $reply->{'data'} eq 'cube groups : read-only in stage 0',
        "$command refuses cube writes"
    );
}
$reply = run_cmd( 'group-create', 'media-readers namespace=cube' );
ok( $reply->{'mode'} eq 'false'
        && $reply->{'data'} eq 'cube groups : read-only in stage 0',
    'group-create refuses the cube namespace'
);
$reply = run_cmd( 'group-create',
    'elevated-readers namespace=web level=1000000' );
ok( $reply->{'mode'} eq 'false'
        && $reply->{'data'} =~ m|below the cube admin|,
    'web group level cannot reach the cube admin level'
);
$reply = run_cmd( 'group-create', 'over-ceiling namespace=web level=21' );
ok( $reply->{'mode'} eq 'false' && $reply->{'data'} =~ m|web ceiling|,
    'web group level cannot pass the configured ceiling'
);
delete $data{'users'}{'cfg'}{'group'}{'web_level_max'};
$reply = run_cmd( 'group-create', 'unset-ceiling namespace=web level=1' );
ok( $reply->{'mode'} eq 'false',
    'an unset ceiling allows level 0 only [ fail closed ]' );
ok( $code{'users.group.cube_admin_level'}->() == 1,
    'without a ceiling only level 0 stays below the limit'
);
$data{'users'}{'cfg'}{'group'}{'web_level_max'} = 20;

say ': list filter and validation';
$reply = run_cmd( 'group-list', 'web' );
ok( $reply->{'mode'} eq 'size' && $reply->{'data'} eq 'web/media-readers',
    'web list filter returns only the web record' );
$reply = run_cmd( 'group-list', 'cube' );
ok( $reply->{'data'}        =~ m|cube/<admin-user>|
        && $reply->{'data'} =~ m|cube/media-operators|
        && $reply->{'data'} !~ m|web/|,
    'cube list filter returns resolved cube groups only'
);
$reply = run_cmd( 'group-list', 'other' );
ok( $reply->{'mode'} eq 'false', 'unknown namespace filter is refused' );
my ( $valid, $err )
    = $code{'users.group.validate'}->( $stored, 'media-readers', 'web' );
ok( defined $valid && !defined $err, 'stored web record validates' );
my $tampered = YAML::XS::LoadFile($record_path);
$tampered->{'checksum'} = 'INVALID';
( $valid, $err )
    = $code{'users.group.validate'}->( $tampered, 'media-readers', 'web' );
ok( !defined $valid && $err eq 'group checksum mismatch',
    'validation rejects a changed identity checksum'
);

say '';
if ($failed) {
    say sprintf '[ done ] %d checks, %d failed', $checks, $failed;
    exit 1;
}
say sprintf '[ done ] %d checks, all passed', $checks;
exit 0;

#,,.,,...,,,,,.,,,..,,,.,,.,.,,.,,,..,.,.,,,.,..,,...,...,,.,,,.,,..,,.,.,,,.,
#EMCKUFYVTNQ4RGS3SL3TNB6ANCUDAXCSPXPAR5756FHSO65RDA3A7BGZWFAOEQCBV4O5Y6V476GM4
#\\\|MCKQAW4DUKPZNZYXFBJPFLG6AEBBLRZHDA57RGN7GJ6SL46J6VB \ / AMOS7 \ YOURUM ::
#\[7]ETDSL427FQYHF3XRDVFYN4W2AH4CZLOWGRY37KIFKONSF6EXWGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
