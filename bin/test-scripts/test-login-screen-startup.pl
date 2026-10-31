#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use File::Spec;
use FindBin     qw| $RealBin |;
use Cwd         qw| abs_path |;
use POSIX       qw| WNOHANG |;
use Time::HiRes qw| sleep |;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    $main::root_path = $root;
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
}
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

our %data;
our %code;
our @ARG;

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $checks++;
    if ($cond) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

sub compile_module {
    my ($name) = @ARG;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open( my $fh, '<:raw', $path ) or die "cannot read $name";
    my $source = join( '', <$fh> );
    close($fh);
    my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
    die "$name compile : $EVAL_ERROR" if not $compiled;
    return $compiled;
}

my $execute = compile_module('base.execute_zenka_code');
my $watch   = compile_module('login-screen.handler.helper_watch');

$code{'base.list_matches'}        = sub { return FALSE };
$code{'base.check_cfg_cmd_alias'} = sub { return $ARG[0] };
$code{'base.sort'}                = sub {
    my ($arg) = @ARG;
    return ref($arg) eq 'HASH' ? sort keys %{$arg} : ();
};
$code{'base.logs'}         = sub { return TRUE };
$code{'base.log'}          = sub { return TRUE };
$code{'base.s_warn'}       = sub { return TRUE };
$code{'base.cnt_s'}        = sub { return 'lines' };
$code{'base.format_error'} = sub { return ( $ARG[0] // 'error' ) };
$code{'base.agent_code.handler.sig_warn.end_proc'} = sub { return TRUE };

my $exited = 0;
my $after  = 0;
$code{'base.exit'}     = sub { $exited++; die "fixture exit\n" };
$code{'fixture.fail'}  = sub { die "fixture failure\n" };
$code{'fixture.after'} = sub { $after++; return TRUE };

my $status = eval {
    $execute->(
        '$code{\'fixture.fail\'}->();',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $after == 1 && $exited == 0,
    'ordinary config exceptions retain existing nonfatal behavior' );
ok( !$status, 'ordinary exception still marks config execution failed' );

$after = 0;
eval {
    $execute->(
        '$code{\'fixture.fail\'}->() or $code{\'base.exit\'}->(1);',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $exited == 1 && $after == 0,
    'explicit base.exit makes a setup exception fatal' );

$code{'fixture.false'} = sub { return FALSE };
eval {
    $execute->(
        '$code{\'fixture.false\'}->() or $code{\'base.exit\'}->(1);',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $exited >= 2 && $after == 0,
    'explicit base.exit also handles a false setup return' );

{

    package Gtk3;
    sub main_quit { $main::gtk_quit++; return 5 }
}
$code{'base.logs'}                          = sub { return TRUE };
$data{'login-screen'}{'auth_helper'}{'pid'} = $PID;
$main::gtk_quit                             = 0;
my $alive = $watch->();
ok( $alive && !$main::gtk_quit,
    'negative waitpid on a live non-child is not helper death' );

my $child = fork();
die 'cannot fork helper fixture' if not defined $child;
POSIX::_exit(0)                  if $child == 0;
$data{'login-screen'}{'auth_helper'}{'pid'} = $child;
my $rounds = 0;
while ( !$main::gtk_quit && $rounds++ < 100 ) {
    $watch->();
    sleep(0.02) if !$main::gtk_quit;
}
ok( $main::gtk_quit == 1, 'actual helper exit still stops the greeter' );
ok( !defined $data{'login-screen'}{'auth_helper'}{'pid'},
    'actual helper exit clears the watched pid'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,.,,...,..,,,,.,,,,,,,.,,.,,..,,,.,,,,,,,..,..,,...,...,.,.,,,.,.,.,,,.,,,.,
#7WTCBKE34JYLMUPH2J45IG7BWSZGGCUJFOYI4EICQQAXCVI55OOJLDKWCZUAWA2VORFOXBCNKLEFK
#\\\|EKJ2VYBN5K3BJPSYMFJYAVBZYFZGUPJRBX5C7NMHFOBA4GHOYHQ \ / AMOS7 \ YOURUM ::
#\[7]FFURULQFMF5KFNBPZTRQN7MYB7ACWQB3DIHUG66PGJXE5TLNF4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
