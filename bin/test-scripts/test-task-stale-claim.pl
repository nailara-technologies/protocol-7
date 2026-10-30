#!/usr/bin/perl
use v5.24;
use FindBin qw| $RealBin |;
use strict;
use warnings;
use English;

###                                        ###
## task stale claims : standalone regression ##
###                                        ###

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;

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

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module('thermal.window.in_range');
compile_module('thermal.window.current');
compile_module('thermal.window.tariff');
compile_module('thermal.window.weight');
compile_module('thermal.outdoor.poll');
compile_module('thermal.handler.outdoor-reply');
compile_module('thermal.outdoor.amp');
compile_module('thermal.gate.sample');
compile_module('thermal.gate.decide');
compile_module('thermal.feed.register');
compile_module('task.handler.gpu_power_update');
compile_module('task.handler.gpu_temp_update');
compile_module('thermal.mem.read');
compile_module('thermal.mem.decide');
compile_module('thermal.idle.sample');
compile_module('thermal.idle.held');
compile_module('thermal.idle.loadavg');
compile_module('thermal.start.ready');
compile_module('thermal.override.set');
compile_module('thermal.override.active');
compile_module('thermal.verdict');
compile_module('thermal.init_code');

$code{'base.cfg_bool'} = sub {
    my $value = shift // FALSE;
    return FALSE if $value =~ m{^(0|no?|false|off)$}i;
    return TRUE;
};

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

compile_module('task.handler.stale-claim-sweep');

## ages in seconds by updated_at stamp ; fail_task records its calls ##
my %age = (
    'OLDPROG' => 30000,
    'OLDCLAI' => 22000,
    'NEWPROG' => 600,
    'OLDDONE' => 90000,
    'OLDPEND' => 90000
);
my @failed;
$code{'base.ntime.delta_seconds'} = sub { return $age{ shift() } };
$code{'base.logs'}                = sub { return TRUE };
$code{'task.fail_task'}           = sub { push @failed, shift; return {} };

sub reset_queue {
    @failed = ();
    $data{'task'}{'queue'} = {
        map {
            my ( $id, $status ) = @{$ARG};
            (   $id => {
                    'status'     => $status,
                    'updated_at' => $id,
                    'agent'      => 'models'
                }
            )
        } [ 'OLDPROG', 'in_progress' ],
        [ 'OLDCLAI', 'claimed' ],
        [ 'NEWPROG', 'in_progress' ],
        [ 'OLDDONE', 'done' ],
        [ 'OLDPEND', 'pending' ]
    };
    $data{'task'}{'queue'}{'order'} = [qw| OLDPROG NEWPROG |];
    return;
}

say ': 1. only old claimed \ in_progress tasks are failed';
reset_queue();
$data{'task'}{'cfg'}{'stale_claim_secs'} = 21600;
$code{'task.handler.stale-claim-sweep'}->();
ok( join( ' ', sort @failed ) eq 'OLDCLAI OLDPROG',
    'stale in_progress and claimed fail, fresh \ done \ pending stay' );

say ': 2. the age limit is configurable and 0 turns the sweep off';
reset_queue();
$data{'task'}{'cfg'}{'stale_claim_secs'} = 25000;
$code{'task.handler.stale-claim-sweep'}->();
ok( join( ' ', @failed ) eq 'OLDPROG', 'a longer limit spares the claim' );
reset_queue();
$data{'task'}{'cfg'}{'stale_claim_secs'} = 0;
$code{'task.handler.stale-claim-sweep'}->();
ok( !@failed, 'stale_claim_secs 0 sweeps nothing' );

say ': 3. an undecodable stamp is left alone';
reset_queue();
$data{'task'}{'cfg'}{'stale_claim_secs'} = 21600;
$age{'OLDPROG'} = undef;
$code{'task.handler.stale-claim-sweep'}->();
ok( join( ' ', @failed ) eq 'OLDCLAI', 'no age, no fail' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,,,,,..,,.,.,,.,,,..,,.,,..,,.,,,.,.,.,.,..,,...,...,.,.,.,.,.,.,..,,,.,,
#D5NS4GBCFL6TJGA3SVJSAFUVHJ7QC6YJDH6CFDNQQR327ZJG4GZN46JM7YMAZ7VL227OL5PZJ5PZO
#\\\|CNIUPIO7OS7AASA6ZUKWHSTJPOS3P4KZLCTIAWN7RFCCQTSS2ZX \ / AMOS7 \ YOURUM ::
#\[7]TBYMNO7XTSR5MV2YTHOGPJVI7RSNLAI5MVIRQT5EFTIJEOCMCGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
