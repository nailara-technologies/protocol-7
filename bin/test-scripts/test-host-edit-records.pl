#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

# test script for host-edit's local record source [ lane B1 of
# data/md/design/HOST-SETUP.md ] : compiles the real host-edit.record.*
# and host-edit.source.* modules and drives them with stubs -- the record
# store is a File::Temp dir behind a stubbed base.path.resolve_keywords,
# the pin store a second temp dir behind a stubbed crypt.C25519.key_vars,
# and event.add_timer is a stub queue that PROVES the deferred-reply
# contract [ a 0 s timer, never an inline call ].  no zenka started, no
# network, no real record dirs touched.

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use JSON::XS;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ module loader ]###########################################################

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

my $runtime_pragmas
    = q{no bytes; use File::stat; use File::Spec::Functions qw| canonpath catfile catdir |;}
    . q{ use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
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

sub register_stub {
    my ( $name, $cref ) = @ARG;
    $code{$name} = $cref;
    return;
}

##[ stubbed environment ]#####################################################

my $var_dir
    = tempdir( 'host-edit-var-XXXXXXXX', TMPDIR => TRUE, CLEANUP => 1 );
my $n_dir = tempdir( 'host-edit-n-XXXXXXXX', TMPDIR => TRUE, CLEANUP => 1 );
my $hosts_dir   = File::Spec->catdir( $var_dir, qw| hosts | );
my $servers_dir = File::Spec->catdir( $n_dir,   qw| remote-keys servers | );
my $owners_dir  = File::Spec->catdir( $n_dir,   qw| remote-keys owners | );

register_stub( 'base.logs',            sub { return TRUE } );
register_stub( 'base.str.os_err',      sub { return $OS_ERROR } );
register_stub( 'base.str.eval_error',  sub { return $EVAL_ERROR } );
register_stub( 'base.buffer.add_line', sub { return TRUE } );
register_stub( 'base.ntime',           sub { return time } );
register_stub( 'base.sort',            sub { return sort @_ } );
register_stub(
    'base.prng.chars-anum',
    sub {
        my $len = shift;
        join '', map { chr( 97 + int rand 26 ) } 1 .. $len;
    }
);
register_stub(
    'base.path.resolve_keywords',
    sub {
        my $path = shift // '';
        $path =~ s|^\[VAR_P7\]|$var_dir|;
        return $path;
    }
);
register_stub( 'crypt.C25519.key_vars',
    sub { return { qw| known_hosts_dir |, $servers_dir } } );

## the deferred-reply proof : senders must register a 0 s timer whose callback
## alone delivers the reply -- an inline call would defeat the engine's async
## contract and would be visible here as a delivery made before the drain
my @timer_queue;

register_stub(
    'event.add_timer',
    sub {
        my $params = shift;
        push @timer_queue, $params;
        return bless {}, 'FakeTimer';
    }
);

sub drain_timers {
    my @replies;
    while ( my $params = shift @timer_queue ) {
        die 'deferred reply is not a 0 s timer'
            if not defined $params->{'after'}
            or $params->{'after'} != 0;
        push @replies, $params;
    }
    return @replies;
}

sub deliver_timers {
    my @queue = @_ ? @_ : drain_timers();
    my @fired;
    foreach my $params (@queue) {
        die 'deferred reply is not a 0 s timer'
            if not defined $params->{'after'}
            or $params->{'after'} != 0;
        push @fired, $params->{'cb'}->();
    }
    return @fired;
}

## reply handlers : plain subs registered under their engine names
my @reply_log;

sub make_collector {
    my $label = shift;
    register_stub(
        $label,
        sub {
            my ($info) = @ARG;
            push @reply_log, [ $label, $info ];
            return TRUE;
        }
    );
    return $label;
}

my $collector = make_collector('test.reply_handler');

$data{'form'}{'source'}   = { qw| not_found_fmt |, q{host '%s' not found} };
$data{'form'}{'cube_sid'} = 42;

compile_module('host-edit.record.name_valid');
compile_module('host-edit.record.path');
compile_module('host-edit.record.read');
compile_module('host-edit.record.write');
compile_module('host-edit.record.field_names');
compile_module('host-edit.record.default_fields');
compile_module('host-edit.trust.pin_state');
compile_module('base.file.all_files');
$code{'file.all_files'} = $code{'base.file.all_files'};
compile_module('format.json.encode');
compile_module('format.json.decode');
compile_module('format.yaml.dump_str');
register_stub(
    'format.yaml.dump_str_fn',
    sub {
        my ($payload) = @ARG;
        ## capture the payload for shape assertions, emit a marker the reply
        ## handler sees as data
        $data{'test'}{'yaml_payload'} = $payload;
        return "YAML_STUB\n";
    }
);
$data{'format'}{'yaml'}{'dump_str_fn'} = $code{'format.yaml.dump_str_fn'};
compile_module('host-edit.source.value_get');
compile_module('host-edit.source.value_all');
compile_module('host-edit.source.value_set');
compile_module('host-edit.source.create_default');
compile_module('host-edit.source.field_options');
compile_module('host-edit.source.secret_hold');
compile_module('host-edit.source.secret_release');

##[ the name rule ]###########################################################

say ': name rule';

my $name_valid = $code{'host-edit.record.name_valid'};

ok( $name_valid->('zz-test'),   'zz-test is a valid host name' );
ok( $name_valid->('a'),         'single char name is valid' );
ok( $name_valid->( 'a' x 63 ),  '63 chars is valid [ the {0,62} ceiling ]' );
ok( !$name_valid->(''),         'empty name is invalid' );
ok( !$name_valid->('Abc'),      'uppercase is invalid' );
ok( !$name_valid->('-lead'),    'leading dash is invalid' );
ok( !$name_valid->('.lead'),    'leading dot is invalid' );
ok( !$name_valid->('x/y'),      'path separator is invalid' );
ok( !$name_valid->( 'a' x 64 ), '64 chars is invalid' );
ok( !defined $code{'host-edit.record.path'}->('x/y'),
    'path returns undef for an invalid name'
);

##[ create_default : deferred reply + on-disk shape ]#########################

say ': create_default';

$code{'host-edit.source.create_default'}->( 'zz-test', $collector );

my @pending = drain_timers();
ok( scalar @pending == 1,
    'create_default registered exactly one deferred reply' );
ok( scalar @reply_log == 0, 'no reply was delivered inline' );

deliver_timers(@pending);
ok( scalar @reply_log == 1, 'the reply arrived through the timer' );
my $info = $reply_log[0][1];
ok( uc( $info->{'cmd'} ) eq qw| TRUE |, 'create_default replied TRUE' );

my $record_path = File::Spec->catfile( $hosts_dir, qw| zz-test.json | );
ok( -f $record_path, 'zz-test.json exists under the hosts dir' );
ok( ( File::stat::stat($record_path)->mode & 07777 ) == 0600,
    'record file mode is 0600' );
my @leftover_tmp
    = ( glob("$hosts_dir/.*.tmp.*"), glob("$hosts_dir/*.tmp.*") );
ok( scalar @leftover_tmp == 0,
    'no temp file left behind [ temp + rename completed ]' );

my $json = do {
    open( my $fh, '<', $record_path ) or die $!;
    local $INPUT_RECORD_SEPARATOR = undef;
    <$fh>;
};
my $envelope = JSON::XS->new->decode($json);
ok( ( ref $envelope eq qw| HASH | and $envelope->{'name'} eq 'zz-test' ),
    'envelope carries the record name' );
ok(
    (           $envelope->{'fields'}{'name'} eq 'zz-test'
            and $envelope->{'fields'}{'transports'}->[0] eq 'tcp'
    ),
    'default fields seeded [ name + tcp transport ]'
);
my $created = $envelope->{'created'};

## refuses to overwrite an existing record
$code{'host-edit.source.create_default'}->( 'zz-test', $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok(
    (   uc( $info->{'cmd'} ) eq qw| FALSE |
            and $info->{'call_args'}{'args'} eq
            "host 'zz-test' record exists already"
    ),
    'create_default refuses an existing record'
);

##[ value_get : not-found wording + trust columns never stored ]##############

say ': value_get';

$code{'host-edit.source.value_get'}->( 'no-such', $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok(
    (   uc( $info->{'cmd'} ) eq qw| FALSE |
            and $info->{'call_args'}{'args'} eq "host 'no-such' not found"
    ),
    'missing record replies the source not_found_fmt wording'
);

$code{'host-edit.source.value_get'}->( 'zz-test', $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok(
    (   uc( $info->{'cmd'} ) eq qw| SIZE |
            and $info->{'data'} eq "YAML_STUB\n"
    ),
    'value_get replied SIZE with the yaml payload in data'
);
my $payload = $data{'test'}{'yaml_payload'};
ok( ( ref $payload eq qw| HASH | and ref $payload->{'fields'} eq qw| HASH | ),
    'payload is the record envelope the engine parses'
);
ok(
    (           $payload->{'fields'}{'trust'} eq q{not yet contacted}
            and $payload->{'fields'}{'owner_trust'} eq q{no owner configured}
    ),
    'no pin + no owner renders not-yet-contacted columns'
);

$json = do {
    open( my $fh, '<', $record_path ) or die $!;
    local $INPUT_RECORD_SEPARATOR = undef;
    <$fh>;
};
$envelope = JSON::XS->new->decode($json);
ok(
    (           not exists $envelope->{'fields'}{'trust'}
            and not exists $envelope->{'fields'}{'owner_trust'}
    ),
    'trust columns were display-only : nothing extra stored'
);

##[ value_set : re-filter + created preserved + deferred reply ]##############

say ': value_set';

my $fields_in = {
    qw| name |       => 'ignored-label',
    qw| addresses |  => ['127.0.0.1:42'],
    qw| ssh |        => 'test@127.0.0.1',
    qw| ssh_port |   => '42',
    qw| transports | => [qw| tcp ssh:plain |],
    qw| owner |      => 'test-owner',
    qw| roles |      => [qw| peer |],
    qw| trust |      => 'forged display column',
    qw| extra |      => 'not in the vocabulary',
};
my $json_in = JSON::XS->new->encode($fields_in);

$code{'host-edit.source.value_set'}->( 'zz-test', $json_in, $collector );
@pending = drain_timers();
ok( scalar @pending == 1, 'value_set registered one deferred reply' );
deliver_timers(@pending);
$info = $reply_log[-1][1];
ok(
    (   uc( $info->{'cmd'} ) eq qw| TRUE |
            and $info->{'call_args'}{'args'} eq "host 'zz-test' stored"
    ),
    'value_set replied TRUE with the stored wording'
);

$json = do {
    open( my $fh, '<', $record_path ) or die $!;
    local $INPUT_RECORD_SEPARATOR = undef;
    <$fh>;
};
$envelope = JSON::XS->new->decode($json);
ok(
    (           $envelope->{'fields'}{'addresses'}->[0] eq '127.0.0.1:42'
            and $envelope->{'fields'}{'transports'}->[1] eq 'ssh:plain'
    ),
    'lists round-tripped through the write'
);
ok(
    (           not exists $envelope->{'fields'}{'trust'}
            and not exists $envelope->{'fields'}{'extra'}
    ),
    'value_set re-filtered unknown + trust keys out'
);
ok( $envelope->{'fields'}{'name'} eq 'zz-test',
    'the record name stayed authoritative'
);
ok( $envelope->{'created'} == $created,
    'created timestamp preserved across the update' );
ok( ( File::stat::stat($record_path)->mode & 07777 ) == 0600,
    'update kept the 0600 mode' );
my @leftover_upd = glob("$hosts_dir/*.tmp.*");
ok( scalar @leftover_upd == 0, 'no temp file left behind after the update' );

$code{'host-edit.source.value_set'}->( 'Bad Name', $json_in, $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok( uc( $info->{'cmd'} ) eq qw| FALSE |,
    'value_set rejects an invalid name' );

##[ trust columns read the client pin store ]#################################

say ': trust columns';

File::Path::make_path( $servers_dir, $owners_dir );
my $key_id = 'A' x 77;
{
    my $pin_path
        = File::Spec->catfile( $servers_dir, qw| 127.0.0.1_42.public | );
    open( my $fh, '>', $pin_path ) or die $!;
    print {$fh} join( qq|\n|, $key_id, 'test-leaf.cube', '424242' );
    close($fh);
}
my $owner_pin_path
    = File::Spec->catfile( $owners_dir, qw| test-owner.public | );
{
    open( my $ofh, '>', $owner_pin_path ) or die $!;
    close($ofh);
}

$code{'host-edit.source.value_get'}->( 'zz-test', $collector );
deliver_timers();
$payload = $data{'test'}{'yaml_payload'};

ok( $payload->{'fields'}{'trust'} eq sprintf(
        q{key %s · %s · since %s},
        'AAAAAAA', 'test-leaf.cube', '424242'
    ),
    'trust column shows label + leaf + since from the pin'
);
ok( $payload->{'fields'}{'owner_trust'} eq 'owner pin test-owner present',
    'owner pin presence detected' );

## the RECORD's pin wins over another host's pin at the same address [ ##
## p-7-r -host names a tunnelled pin after the record ]                ##
{
    my $record_pin
        = File::Spec->catfile( $servers_dir, qw| zz-test_42.public | );
    open( my $fh, '>', $record_pin ) or die $!;
    print {$fh} join( qq|\n|, 'B' x 77, 'zz-test.cube', '7' );
    close($fh);
    $code{'host-edit.source.value_get'}->( 'zz-test', $collector );
    deliver_timers();
    $payload = $data{'test'}{'yaml_payload'};
    ok( $payload->{'fields'}{'trust'} eq sprintf(
            q{key %s · %s · since %s},
            'BBBBBBB', 'zz-test.cube', '7'
        ),
        'record pin [ zz-test_42 ] wins over the address pin [ 127.0.0.1_42 ]'
    );
    unlink $record_pin;
}

unlink File::Spec->catfile( $servers_dir, qw| 127.0.0.1_42.public | );
$code{'host-edit.source.value_get'}->( 'zz-test', $collector );
deliver_timers();
$payload = $data{'test'}{'yaml_payload'};
ok( $payload->{'fields'}{'trust'} eq q{not yet contacted},
    'pin removed -> not yet contacted again' );

##[ value_all : newline-joined listing ]######################################

say ': value_all';

$code{'host-edit.source.create_default'}->( 'aa-second', $collector );
deliver_timers();
$code{'host-edit.source.value_all'}->($collector);
@pending = drain_timers();
ok( scalar @pending == 1, 'value_all registered one deferred reply' );
deliver_timers(@pending);
$info = $reply_log[-1][1];
ok(
    (   uc( $info->{'cmd'} ) eq qw| SIZE |
            and $info->{'data'} eq "aa-second\nzz-test"
    ),
    'value_all returns the sorted newline-joined names'
);

##[ field_options + secret senders ]##########################################

say ': field_options + secrets';

$code{'host-edit.source.field_options'}->($collector);
deliver_timers();
$info = $reply_log[-1][1];
my %vocabulary = map { split m|\s+| }
    grep {length} split m|\n|, $info->{'data'};
ok(
    (           uc( $info->{'cmd'} ) eq qw| SIZE |
            and $vocabulary{'addresses'} eq qw| list |
            and $vocabulary{'ssh'} eq qw| line |
            and not exists $vocabulary{'trust'}
    ),
    'vocabulary advertises shapes and never the trust columns'
);

$code{'host-edit.source.secret_hold'}->( 'n', 'AAAA', $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok( $info->{'data'} =~ m|^\s*<<|,
    'secret hold replies the engine-detected not-supported failure shape' );

$code{'host-edit.source.secret_release'}->( 'n', $collector );
deliver_timers();
$info = $reply_log[-1][1];
ok( $info->{'data'} =~ m|^\s*<<|,
    'secret release replies the same failure shape' );

##[ summary ]#################################################################

say '';
if ( $fail_count == 0 ) {
    say sprintf '[ done ] %d checks, all passed', $pass_count;
    exit 0;
}
say sprintf '[ done ] %d passed, %d FAILED', $pass_count, $fail_count;
exit 1;

#,,,.,..,,,..,,,.,,.,,,..,.,,,...,...,,,.,...,..,,...,...,.,,,.,.,,,.,.,.,,..,
#6AT5L3BLTGDNVUMZ2QCTY5QBY4WGE2CMXPN3FL75ZO7AJTSIBHG35CCZBY7HBLIYUUGBLESNLD5RS
#\\\|PDEDGGDED5XIYTI2B542WUOYOYVQ2Y5UIKFWMKDRT6QTJWZMM64 \ / AMOS7 \ YOURUM ::
#\[7]6PHUPVVWIHHL5BU7SJRURFFFANADJX7JDCPZCAEOUXG4V4II2IAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
