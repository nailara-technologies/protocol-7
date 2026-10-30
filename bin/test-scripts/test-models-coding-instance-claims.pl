#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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

our %data;
our %code;
our $call = {};

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n$prefix\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my @logged;
my $rescans = 0;
$code{'base.logs'}          = sub { push @logged, [@ARG]; return TRUE };
$code{'models.task.rescan'} = sub { $rescans++;           return TRUE };

compile_module('models.task.claim-record');
compile_module('models.task.release-claim');
compile_module('models.task.release-previous-instance');
compile_module( 'models.cmd.coding-online', 'our $call;' );

$data{'models'}{'task'}{'coding_instance'} = '100';
my $record = $code{'models.task.claim-record'}->();
ok( $record->{'owner_zenka'} eq 'coding'
        && $record->{'owner_instance'} eq '100'
        && $record->{'at'} > 0,
    'new claims record the current coding instance'
);

my $now = time;
$data{'models'}{'task'}{'claimed'} = {
    'CLAIM-A' => {
        'at'             => $now - 42,
        'owner_zenka'    => 'coding',
        'owner_instance' => '100',
        'target_cmd'     => 'coding.ask-reply'
    },
    'OTHER-TARGET' => {
        'at'             => $now - 42,
        'owner_zenka'    => 'coding',
        'owner_instance' => '100',
        'target_cmd'     => 'llm.api-reply'
    },
    'CLAIM-B' => {
        'at'             => $now - 7,
        'owner_zenka'    => 'coding',
        'owner_instance' => '200',
        'target_cmd'     => 'coding.ask-reply'
    },
    'FOREIGN' => {
        'at'             => $now - 42,
        'owner_zenka'    => 'other-backend',
        'owner_instance' => '100'
    },
    'LEGACY-HASH' => { 'at' => $now - 42 },
    'LEGACY-TIME' => $now - 42
};
@logged  = ();
$rescans = 0;

$call = { 'args' => 'coding 31337 200' };
my $reply   = $code{'models.cmd.coding-online'}->();
my $claimed = $data{'models'}{'task'}{'claimed'};
ok( $reply->{'mode'} eq 'true', 'authenticated coding startup is accepted' );
ok( !exists $claimed->{'CLAIM-A'},
    'previous coding instance claim released' );
ok( exists $claimed->{'CLAIM-B'}, 'live coding instance claim kept' );
ok( exists $claimed->{'FOREIGN'}, 'foreign zenka claim kept' );
ok( exists $claimed->{'OTHER-TARGET'},
    'previous instance claim on a non-coding backend kept' );
ok( exists $claimed->{'LEGACY-HASH'} && exists $claimed->{'LEGACY-TIME'},
    'claims without an owner instance fall back to the ttl'
);
ok( $rescans == 1,
    'the existing release path re-scans once per dropped claim' );
my ($drop_log)
    = grep { $_->[1] =~ m{previous coding instance claim} } @logged;
ok( defined $drop_log
        && $drop_log->[2] eq 'CLAIM-A'
        && $drop_log->[3] eq 'CLAIM-A'
        && $drop_log->[4] >= 42,
    'the dropped claim log includes claim id, task id, and age'
);

$call  = { 'args' => 'other-backend 31338 100' };
$reply = $code{'models.cmd.coding-online'}->();
ok( $reply->{'mode'} eq 'false'
        && $data{'models'}{'task'}{'coding_instance'} eq '200'
        && exists $claimed->{'CLAIM-B'},
    'another authenticated zenka cannot select claims to release'
);

$call  = { 'args' => 'coding 31337 200' };
$reply = $code{'models.cmd.coding-online'}->();
ok( exists $claimed->{'CLAIM-B'} && $rescans == 1,
    'a repeated report from the live instance releases nothing' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say "all $pass_count checks passed";
exit 0;

#,,,.,.,,,,,.,,.,,,,.,,..,,.,,..,,,,.,,,.,,.,,..,,...,...,.,.,,.,,..,,,,,,,,,,
#65LQLJ7Q4NQ4Z6APWJU43KGFD4SW7YIKSL647MJTN7ILK46NYILGMULL3A6EZWTOKBJJPZDQJSMDQ
#\\\|4M2NDBDMAIAU73ZUGJAF52O42CDQXHN2LQYUKBSS3AQTLIQXFW4 \ / AMOS7 \ YOURUM ::
#\[7]ZR64QFFNXNTVKRDYTW7DCQ654WC47ETVHUNHHN4QBLR6JMJZI2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
