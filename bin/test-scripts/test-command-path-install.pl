#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;
use Test::More;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use Cwd        qw| abs_path |;
use FindBin;

BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }
use AMOS7::Perms qw| parse_rules |;

my $rules = parse_rules(<<'EOF');
# comment
RF 640 --> dir/#literal # trailing comment
CL --> .#editor --> dir/file
DC 750 u:root g:staff --> new-dir
EOF
is( scalar @{$rules},    3, 'rules stay ordered and comments are removed' );
is( $rules->[0]{'path'}, 'dir/#literal', 'hash in a path is preserved' );
is_deeply( $rules->[0]{'flags'}, ['RF'], 'flags are parsed' );
is( $rules->[0]{'mode'}, 0640,       'mode is parsed as octal' );
is( $rules->[1]{'path'}, '.#editor', 'editor lock link path is preserved' );
is( $rules->[1]{'link_target'}, 'dir/file', 'link target is parsed' );
is( $rules->[2]{'user'},        'root',     'user is parsed' );
is( $rules->[2]{'group'},       'staff',    'group is parsed' );

my $tmp       = tempdir( CLEANUP => 1 );
my $path_root = "$tmp/path";
make_path( "$path_root/all", "$path_root/admin" );
symlink( abs_path("$FindBin::RealBin/../..") . '/bin/n7fs',
    "$path_root/all/n7fs" )
    or die $OS_ERROR;
symlink( 'bin/other', "$path_root/admin/ncode" ) or die $OS_ERROR;

sub run_cli {
    my @args = @ARG;
    my $out  = "$tmp/out";
    my $err  = "$tmp/err";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>', $out ) or exit 98;
        open( STDERR, '>', $err ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::RealBin/../p7-deps", @args )
            or exit 99;
    }
    waitpid $pid, 0;
    my $status = $CHILD_ERROR >> 8;
    open( my $out_fh, '<', $out ) or die $OS_ERROR;
    open( my $err_fh, '<', $err ) or die $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR = undef;
    return ( $status, <$out_fh>, <$err_fh> );
}

local $ENV{'P7_DEPS_COMMAND_PATH_ROOT'} = $path_root;
my ( $rc, $out, $err ) = run_cli(qw| install-commands -dry-run |);
is( $rc, 0, 'dry-run succeeds' ) or diag $err;
like( $out, qr|DC 755 u:root g:root --> \Q$path_root\E/all|,
    'all role rule' );
like( $out, qr|bin/n7fs .* ok|,             'correct link reports ok' );
like( $out, qr|bin/ncode .* changed|,       'wrong link reports changed' );
like( $out, qr|restore-permissions .* set|, 'missing link reports set' );
like(
    $out,
    qr{bin/p7-vault .* (?:set|missing-dependency)},
    'dependency profile selects set or missing-dependency'
);

( $rc, $out, $err ) = run_cli('install-commands');
is( $rc, 1, 'stage 1 refuses a real install' );
like(
    ( $out // '' ) . ( $err // '' ),
    qr|stage 1 : dry-run only|,
    'refusal names the stage 1 limit'
);

done_testing();

#,,,,,,,,,,,.,,,,,..,,,.,,,.,,.,,,,,,,,.,,,,.,..,,...,...,,.,,,..,,,.,,.,,,,,,
#DH4AGZJGBDPNVCBZD6SVEY7HHHK5EFUYD5VXZJNXFJSYQCKNF375HYEJ6V4Y2B67625XUJMDYLZ2S
#\\\|FBG7NDQSDFPJJ3W6M52XR44E723BOXZWNGAFUV5A22JD6MISPRE \ / AMOS7 \ YOURUM ::
#\[7]TNDMXCRJKOGZTTBXQDFIRWIHUDG5W4HBI7Q5J4YRLL7KBX3INKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
