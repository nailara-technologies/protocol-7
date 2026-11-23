#!/usr/bin/env perl
use v5.32.0;
use strict;
use warnings;
use English;

use Test::More;
use FindBin qw| $RealBin |;

use constant { TRUE => 5, FALSE => 0 };

our %data;
our %code;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $now        = 100;
my $free       = 900;
my $files_free = 900;
my @events;
$data{'disk'}{'warn_free'}                  = 13;
$data{'disk'}{'critical_free'}              = 5;
$data{'disk'}{'warn_min_free_gb'}           = 13;
$data{'disk'}{'critical_min_free_gb'}       = 5;
$data{'disk'}{'absolute_floor_min_size_gb'} = 64;
$data{'disk'}{'history_samples'}            = 13;
$code{'base.time'}                          = sub { return $now };
$code{'system.disk.mounts'}                 = sub {
    return [ { device => '/dev/fake', path => '/fake', type => 'ext4' } ];
};
$code{'system.disk.statvfs'} = sub {
    return {
        block_size  => 1,
        blocks      => 1000,
        blocks_free => $free,
        files       => 1000,
        files_free  => $files_free,
    };
};
$code{'base.logs'}             = sub { return TRUE };
$code{'protocol-7.route-send'} = sub { push @events, shift; return TRUE };

load_src('system.disk.poll');
load_src('system.disk.cmd.disk-status');
load_src('base.interval.rhythm.disk');

$code{'system.disk.poll'}->();
$now  = 200;
$free = 700;
$code{'system.disk.poll'}->();
is scalar @events, 0, 'healthy polls emit no events';
my $mount = $data{'system'}{'disk'}{'mounts'}{'/fake'};
cmp_ok abs( $mount->{'rate'} - -2 ), '<', 0.00001,
    'trend derives byte loss per second';
is $mount->{'eta'}, 350, 'eta uses current free bytes and trend';

$free = 120;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events,        1, 'warning emits once while below threshold';
is $events[0]{'command'}, 'notify.warn', 'warning uses notify path';

$free = 40;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events, 2, 'critical emits once while below threshold';

$free = 900;
$code{'system.disk.poll'}->();
$code{'system.disk.poll'}->();
is scalar @events,        3,             'recovery emits once';
is $events[2]{'command'}, 'notify.info', 'recovery uses notify path';
like $events[2]{'call_args'}{'args'}, qr|recovered|, 'recovery is named';

$files_free = 40;
$code{'system.disk.poll'}->();
is scalar @events, 4, 'inode critical threshold is watched';
$files_free = 900;
$code{'system.disk.poll'}->();
is scalar @events, 5, 'inode recovery emits once';

$data{'disk'}{'mount'}{'/fake'}{warn_free}     = 1;
$data{'disk'}{'mount'}{'/fake'}{critical_free} = 0.5;
$code{'system.disk.poll'}->();
is scalar @events, 5, 'per-mount thresholds override defaults';
delete $data{'disk'}{'mount'};

my $status = $code{'system.disk.cmd.disk-status'}->();
like $status->{'data'}, qr|/fake .* 1000 B|s,
    'disk-status reports mount and bytes';
like $status->{'data'}, qr|\d+/\d+ \d+ : .*B/s|,
    'disk-status reports inode counts and trend';

my $rhythm = $code{'base.interval.rhythm.disk'};
my @delays = map {
    $rhythm->(
        {   state     => { pressure => $ARG },
            cfg       => { start    => 377, cap => 13 },
            harmonize => sub { return shift },
        }
    )
} 0, 0.5, 1;
ok $delays[0] > $delays[1] && $delays[1] > $delays[2],
    'disk rhythm accelerates as free space falls';
is $delays[2], 13, 'critical pressure reaches configured floor';

done_testing();

#,,.,,..,,..,,...,,,.,..,,...,,,,,,,.,,.,,,,,,..,,...,...,..,,,.,,.,.,,,.,,,.,
#M6ASUZVBZ2BZANNOSTDMXNMGHNGOMVFM5COTRLJ357CAV5ZPGLQYN2W2OSMA2EJJGPKXOUCNM3OUG
#\\\|32QXBRZGCGDEWYZYZ44KWAGBXR66V5BDETV2MY3AKDDEUVMWZHH \ / AMOS7 \ YOURUM ::
#\[7]2GWO3QIE3HUGU56MPXUZGOLVEK7OLDUFBKBX5AVIQ25RFCOSRQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
