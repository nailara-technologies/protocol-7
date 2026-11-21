#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;
use JSON::XS   ();
use YAML::XS   ();

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

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

my $tmp
    = tempdir( 'p7-user-group-stage0-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my @timers;
my @replies;
my @sent;

$data{'form'}{'cube_sid'} = 42;
$code{'base.logs'}        = sub { return TRUE };
$code{'base.ntime'}       = sub { return 1_700_000_000 };
$code{'base.sort'}        = sub {
    my ($ref) = @ARG;
    return sort keys %{$ref} if ref $ref eq 'HASH';
    return sort @{$ref};
};
$code{'base.str.os_err'}            = sub { return $OS_ERROR };
$code{'base.prng.chars-anum'}       = sub { return 'temporary' };
$code{'base.path.resolve_keywords'} = sub {
    my $path = shift // '';
    $path =~ s|^\[VAR_P7\]|$tmp|;
    return $path;
};
$code{'format.json.encode'}
    = sub { return JSON::XS->new->pretty(1)->encode( $ARG[0] ) };
$code{'format.json.decode'} = sub { return JSON::XS->new->decode( $ARG[0] ) };
$code{'format.yaml.dump_str'} = sub { return YAML::XS::Dump( $ARG[0] ) };
$code{'format.yaml.load_str'} = sub {
    my $loaded = eval { YAML::XS::Load( $ARG[0] ) };
    return ( undef,   $EVAL_ERROR ) if $EVAL_ERROR;
    return ( $loaded, undef );
};
$code{'event.add_timer'} = sub {
    push @timers, $ARG[0];
    return TRUE;
};
$code{'test.reply'} = sub {
    push @replies, $ARG[0];
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub {
    my ($request) = @ARG;
    push @sent, $request;
    return TRUE;
};

sub deliver_timers {
    while ( my $timer = shift @timers ) {
        $timer->{'cb'}->();
    }
    return;
}

compile_module($ARG) for qw|
    host-edit.record.name_valid
    host-edit.record.path
    host-edit.record.read
    host-edit.record.write
    host-edit.record.field_names
    host-edit.record.name_is_host
    host-edit.record.default_fields
    host-edit.source.value_set
    host-edit.source.field_options
    user-edit.source.value_get
    user-edit.source.value_set
    user-edit.source.memberships_reply
    user-edit.source.groups_field
    |;

say ': host user bucket';
my $defaults = $code{'host-edit.record.default_fields'}->('record-one');
ok( ref $defaults->{'user_groups'} eq 'ARRAY'
        && !@{ $defaults->{'user_groups'} },
    'new host records start with an empty user bucket'
);

my $stored_fields = {
    'name'        => 'record-one',
    'user_groups' => [qw| bucket-one bucket.two+media |],
};
$code{'host-edit.source.value_set'}
    ->( 'record-one', JSON::XS->new->encode($stored_fields), 'test.reply' );
deliver_timers();
my $record_path = File::Spec->catfile( $tmp, qw| hosts record-one.json | );
my $stored      = -f $record_path
    ? JSON::XS->new->decode(
    do {
        open( my $fh, '<:raw', $record_path ) or die $OS_ERROR;
        local $INPUT_RECORD_SEPARATOR;
        <$fh>;
    }
    )
    : {};
ok( $replies[-1]{'cmd'} eq 'TRUE'
        && join( ',', @{ $stored->{'fields'}{'user_groups'} // [] } ) eq
        'bucket-one,bucket.two+media',
    'valid web group names are accepted and stored'
);

my $before_invalid = JSON::XS->new->canonical(1)->encode($stored);
$code{'host-edit.source.value_set'}->(
    'record-one',
    JSON::XS->new->encode(
        { 'name' => 'record-one', 'user_groups' => ['invalid/name'] }
    ),
    'test.reply'
);
deliver_timers();
my $after_invalid = JSON::XS->new->decode(
    do {
        open( my $fh, '<:raw', $record_path ) or die $OS_ERROR;
        local $INPUT_RECORD_SEPARATOR;
        <$fh>;
    }
);
ok( $replies[-1]{'cmd'} eq 'FALSE'
        && $replies[-1]{'data'} =~ m|invalid web group name|
        && JSON::XS->new->canonical(1)->encode($after_invalid) eq
        $before_invalid,
    'an invalid group name is refused without changing the record'
);

$code{'host-edit.source.field_options'}->('test.reply');
deliver_timers();
my %field_shapes = map { split m|\s+| }
    grep {length} split m|\n|, $replies[-1]{'data'};
ok( $field_shapes{'user_groups'} eq 'list',
    'the existing field vocabulary offers user_groups as a list' );

say ': read-only memberships';
@sent    = ();
@replies = ();
$code{'user-edit.source.value_get'}->( 'member-one', 'test.reply' );
ok( @sent == 1 && $sent[0]{'command'} eq '42.users.value-get',
    'the user record is fetched before its groups'
);
my $request = shift @sent;
my $params  = $request->{'reply'}{'params'};
$code{'user-edit.source.memberships_reply'}->(
    {   'cmd'    => 'SIZE',
        'params' => $params,
        'data'   => YAML::XS::Dump(
            { 'name' => 'member-one', 'fields' => { 'note' => 'kept' } }
        ),
    }
);
ok( @sent == 1
        && $sent[0]{'command'} eq '42.users.group-list'
        && $sent[0]{'call_args'}{'args'} eq ''
        && @replies == 0,
    'both namespaces are listed before the record is displayed'
);
$request = shift @sent;
$params  = $request->{'reply'}{'params'};
$code{'user-edit.source.memberships_reply'}->(
    {   'cmd'    => 'SIZE',
        'params' => $params,
        'data'   => "cube/ops\nweb/bucket-one\nweb/bucket-two",
    }
);

my %members = (
    'cube/ops'       => [qw| member-one |],
    'web/bucket-one' => [qw| member-one |],
    'web/bucket-two' => [qw| other-member |],
);
while (@sent) {
    $request = shift @sent;
    my $args = $request->{'call_args'}{'args'};
    my ( $group_name, $namespace ) = split m|\s+|, $args;
    my $qualified = "$namespace/$group_name";
    $code{'user-edit.source.memberships_reply'}->(
        {   'cmd'    => 'SIZE',
            'params' => $request->{'reply'}{'params'},
            'data'   => YAML::XS::Dump(
                { 'fields' => { 'members' => $members{$qualified} } }
            ),
        }
    );
}

my $shown = YAML::XS::Load( $replies[-1]{'data'} );
ok( join( ',', @{ $shown->{'fields'}{'group_memberships'} } ) eq
        'cube/ops,web/bucket-one' && $shown->{'fields'}{'note'} eq 'kept',
    'only matching memberships from both namespaces join the record view'
);
my $group_field = $code{'user-edit.source.groups_field'}->($shown)->[0];
ok( $group_field->{'readonly'}
        && $group_field->{'default'} eq 'cube/ops, web/bucket-one',
    'the synthesized membership row is read-only'
);

@sent = ();
$code{'user-edit.source.value_set'}->(
    'member-one',
    JSON::XS->new->encode(
        {   'note'              => 'changed',
            'group_memberships' => 'forged display value',
        }
    ),
    'test.reply'
);
my $write_args = $sent[0]{'call_args'}{'args'};
$write_args =~ s|^\S+\s+||;
my $write_fields = JSON::XS->new->decode($write_args);
ok( $write_fields->{'note'} eq 'changed'
        && !exists $write_fields->{'group_memberships'}
        && $write_args !~ m|\n|,
    'memberships are not stored and the write stays on one wire line'
);

say '';
if ($failed) {
    say sprintf '[ done ] %d checks, %d failed', $checks, $failed;
    exit 1;
}
say sprintf '[ done ] %d checks, all passed', $checks;
exit 0;

#,,.,,,,,.,,,,,,,.,,,,,.,,,.,.,..,,,..,,,,.,,,..,,.,,,.,,,..,.,,,.,,,,..,,,,

#,,,,,,,.,,.,,,,,,.,.,...,..,,...,..,,.,.,,.,,..,,...,..,,...,..,,,..,..,,...,
#CYEPQBNYPPGCQY6GMC7T6C4QRKGNIC32CGXJVG4AP2DPNOPZWGMP2YX2ZGHTH2R6RCHD6PGDTP2SO
#\\\|26KJ4VRTYMGYSGNZQET4LZHL2JCELXNOM7EGBMM3Q2SL5NCAXJI \ / AMOS7 \ YOURUM ::
#\[7]UGJFMNZKWNNSUDVLR7SKTBGBH6WZHES4ANEMAEPU56J75J46MOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
