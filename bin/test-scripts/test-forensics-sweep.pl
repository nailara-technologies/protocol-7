#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## forensics sweep : the window found by binary search                      ##
## [ few timestamp decodes, not one per line ], the sweep run in slices     ##
## over event loop turns, the same record as a full read, sweep-run replies ##
## when done.  REAL forensics.sweep.window_offset \ .step \                 ##
## event.nightly-sweep \ cmd.sweep-run compiled ; timers queued and run by  ##
## hand. no zenka.                                                          ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use File::Temp            qw| tempdir |;

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
use AMOS7::NTIME;
use File::stat ();

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

my $fail_count = 0;
my $test_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## no bytes : the harness's own 'use bytes' must not leak into the modules  ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- stubs ------------------------------------------------------------- ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
my $decodes = 0;
$code{'base.ntime.B32_2_unix'} = sub {
    $decodes++;
    my $unix = eval { AMOS7::NTIME::b32_to_unix( $ARG[0] ) };
    return defined $unix ? int $unix : undef;
};
$code{'file.make_path'} = sub {
    require File::Path;
    File::Path::make_path( $ARG[0] );
    return -d $ARG[0] ? TRUE : FALSE;
};
my @records;
$code{'format.yaml.write_file'} = sub {
    push @records, [@ARG];
    return (TRUE);
};
my @timers;
$code{'event.add_timer'} = sub { push @timers, $ARG[0]; return TRUE };
my @replies;
$code{'base.callback.cmd_reply'} = sub { push @replies, [@ARG]; return };

## run queued timers until none is left [ returns how many ran ] ##
sub run_timers {
    my $ran = 0;
    while ( my $timer = shift @timers ) {
        $code{ $timer->{'handler'} }->();
        $ran++;
        die 'runaway sweep' if $ran > 100000;
    }
    return $ran;
}

compile_module($ARG) for qw| forensics.sweep.window_offset
    forensics.sweep.step forensics.event.nightly-sweep |;
compile_module( 'forensics.cmd.sweep-run', 'my $call = shift // {};' );

## --- log files ---------------------------------------------------------- ##
my $tmp     = tempdir( CLEANUP => 1 );
my $log_dir = catfile( $tmp, 'log' );
mkdir $log_dir or die;
$data{'forensics'}{'cfg'}{'log_dir'}   = $log_dir;
$data{'forensics'}{'cfg'}{'sweep_dir'} = catfile( $tmp, 'sweeps' );
$data{'system'}{'node'}{'name'}        = 'host';
$data{'system'}{'zenka'}{'name'}       = 'forensics';

my $now    = time;
my $cutoff = $now - 86400;

sub ts_b32 {
    AMOS7::NTIME::ntime_to_b32( AMOS7::NTIME::unix_to_ntime(shift) );
}

## a big log : 10 days, one line every 3 s, a MISS line every 97 lines, a ##
## junk line every 1000 [ banner \ binary shaped ] ; utf-8 in some        ##
my ( %expected, $first_in_window_offset );
my $big = catfile( $log_dir, 'host.httpd.zenka.log' );
open( my $out, '>:raw', $big ) or die;
my $offset = 0;
my $n      = 0;
for ( my $t = $now - 10 * 86400; $t <= $now; $t += 3 ) {
    my $line;
    if ( ++$n % 1000 == 0 ) {
        $line = "  .:[ banner line, no timestamp ]:.\n";
    } else {
        my $msg
            = $n % 97 == 0
            ? sprintf( "[%d] MISS route %d gr\xc3\xbc\xc3\x9fe", $n, $n % 5 )
            : "[$n] ordinary line $n";
        $line = sprintf "%s 1234567 2 %s\n", ts_b32($t), $msg;
        if ( $t >= $cutoff ) {
            $first_in_window_offset //= $offset;
            $expected{
                "httpd\0" . sprintf "MISS route %d " . "gr\xc3\xbc\xc3\x9fe",
                $n % 5
                }++
                if $n % 97 == 0;
        }
    }
    print {$out} $line;
    $offset += length $line;
}
close($out);
my $big_size = -s $big;

## a small log inside the window, and an old one outside it ##
my $small = catfile( $log_dir, 'host.cube.zenka.log' );
open( $out, '>:raw', $small ) or die;
printf {$out} "%s 7654321 1 :::[ NOT FOUND ]::: some.sub\n",
    ts_b32( $now - 60 );
printf {$out} "%s 7654321 1 BAD signature x\n", ts_b32( $now - 30 );
close($out);
$expected{"cube\0:::[ NOT FOUND ]::: some.sub"} = 1;
$expected{"cube\0BAD signature x"}              = 1;

my $old = catfile( $log_dir, 'host.old.zenka.log' );
open( $out, '>:raw', $old ) or die;
printf {$out} "%s 1111111 1 MISS never counted\n", ts_b32( $now - 5 * 86400 );
close($out);
utime( $now - 5 * 86400, $now - 5 * 86400, $old ) or die;

say ':: forensics.sweep.window_offset';

open( my $big_fh, '<:raw', $big ) or die;
$decodes = 0;
my $found
    = $code{'forensics.sweep.window_offset'}->( $big_fh, $big_size, $cutoff );
ok( $found <= $first_in_window_offset
        && $first_in_window_offset - $found <= 65536 + 200,
    sprintf 'offset at most 64 KiB before the '
        . 'first in-window line [ %d .. %d ]',
    $found,
    $first_in_window_offset
);
ok( $decodes <= 40,
    sprintf '  :.. %d timestamp decodes for %d lines',
    $decodes, $n
);
ok( $code{'forensics.sweep.window_offset'}
        ->( $big_fh, $big_size, $now - 20 * 86400 ) == 0,
    'a cutoff before the log : offset 0'
);
close($big_fh);

say ':: sweep in slices';

$data{'forensics'}{'cfg'}{'sweep_slice_seconds'} = 0.002;
$decodes = 0;
ok( $code{'forensics.event.nightly-sweep'}->(), 'nightly-sweep : started' );
ok( ref $data{'forensics'}{'sweep'}{'state'} eq 'HASH' && @timers == 1,
    '  :.. state set, one step armed [ nothing read yet ]'
);
ok( $code{'forensics.event.nightly-sweep'}->() && @timers == 1,
    '  :.. a second start joins the running sweep'
);

my $call = { 'reply_id' => 4242 };
ok( $code{'forensics.cmd.sweep-run'}->($call)->{'mode'} eq 'deferred',
    'sweep-run while running : deferred' );

my $steps = run_timers();
ok( $steps > 1, "the sweep ran in $steps slices" );
ok( !exists $data{'forensics'}{'sweep'}{'state'}, '  :.. state cleared' );
ok( $decodes < 2000,
    "  :.. $decodes timestamp decodes [ not one per line ]" );

ok( @records == 1, 'one record written' );
my ( $path, $record ) = @{ $records[0] // [] };
my %got = map { ( "$ARG->{'zenka'}\0$ARG->{'message'}" => $ARG->{'count'} ) }
    @{ $record->{'entries'} // [] };
## the harness's use bytes : joined keys are the internal utf-8 bytes ##
my ($umlaut)
    = grep { $ARG->{'message'} =~ m|^MISS route| }
    @{ $record->{'entries'} // [] };
{
    no bytes;
    ok( defined $umlaut
            && utf8::is_utf8( $umlaut->{'message'} )
            && length( $umlaut->{'message'} ) == 18,
        'utf-8 message read raw, stored as decoded text'
    );
}
ok( join( ',', map {"$ARG=$expected{$ARG}"} sort keys %expected ) eq
        join( ',', map {"$ARG=$got{$ARG}"} sort keys %got ),
    sprintf '  :.. entries and counts as a full read [ %d unique ]',
    scalar keys %expected
);
ok( $record->{'sweep'}{'files_scanned'} == 2,
    '  :.. 2 files scanned [ the old one skipped ]'
);
ok( $path =~ m|/sweeps/\d{4}-\d\d-\d\d\.yaml\z|, '  :.. dated record path' );

ok( @replies == 1
        && $replies[0][0] == 4242
        && $replies[0][1]{'mode'} eq 'true',
    'sweep-run answered when the record was written'
);

## a sweep-run with no sweep running : starts one, deferred ##
@replies = ();
@records = ();
ok( $code{'forensics.cmd.sweep-run'}->( { 'reply_id' => 77 } )->{'mode'} eq
        'deferred',
    'sweep-run alone : starts a sweep, deferred'
);
run_timers();
ok( @records == 1 && @replies == 1 && $replies[0][0] == 77,
    '  :.. record written, answered' );

## a record write failure : sweep-run gets FALSE ##
@replies = ();
$code{'format.yaml.write_file'} = sub { return ( FALSE, 'disk full' ) };
$code{'forensics.cmd.sweep-run'}->( { 'reply_id' => 78 } );
run_timers();
ok( @replies == 1 && $replies[0][1]{'mode'} eq 'false',
    'record write failure : sweep-run answered FALSE'
);

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,,,.,,,.,...,...,.,,,,,,,...,.,.,.,,,,.,,..,,...,...,..,,,,.,,,,,.,.,,.,,
#7NETTPV2WVBZLZF5L4BB6UWCCSEX23UXHHJHCQEZMFDPM4GITFO2WQEPHQAUDAFKALNKOUFOQH5JO
#\\\|HKQ25MB7CXV6VG4436TFG4VLUJQUQLGC3W4UU2R2OEH4ILNN7PR \ / AMOS7 \ YOURUM ::
#\[7]N7I2TBHGUC74T4MGHK2M5MG3ULKWSNKEJLJJ25OLBZ7OZPSBQKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
