#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## log send-buffer created before Event exists                             ##
## [ a bootstrap start : v7-zenki.pre_init installs Event during init ] :  ##
## init must not die half-way, the buffer queues, and the first line after ##
## Event is loaded sets up the watchers -- nothing queued is lost. before, ##
## init died at event.add_var and the buffer never sent a line             ##
## [ 2026-10-15 ]. REAL base.log.send-buffer.init \ .watchers \ .add-queue ##
## ; Event and the idle callback stubbed. no zenka.                        ##

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

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- stubs ------------------------------------------------------------- ##
my $event_loaded = FALSE;
my ( @var_watchers, @idle_sets );
$code{'base.s_warn'}         = sub {return};
$code{'base.logs'}           = sub {return};
$code{'base.perlmod.loaded'} = sub { return $event_loaded };
$code{'event.add_var'}       = sub {
    die "cannot locate object method 'var' via package 'Event'\n"
        if not $event_loaded;
    push @var_watchers, $ARG[0];
    return { 'watcher' => scalar @var_watchers };
};
$code{'base.log.send-buffer.idle-callback-set'} = sub {
    die "cannot locate object method 'idle' via package 'Event'\n"
        if not $event_loaded;
    push @idle_sets, $ARG[0];
    return TRUE;
};

compile_module($ARG) for qw| base.log.send-buffer.watchers
    base.log.send-buffer.init base.log.send-buffer.add-queue |;

delete $INC{'Event.pm'};    ## the test must not see a real Event ##

$data{'buffer'}{'zenka'}
    = { 'log_cmd' => 'p7-log.append', 'max_size' => 1000 };
$data{'system'}{'zenka'}{'name'}        = 'v7-zenki';
$data{'system'}{'zenka'}{'initialized'} = FALSE;

say ':: before Event';

my $init = eval { $code{'base.log.send-buffer.init'}->('zenka') };
ok( !length $EVAL_ERROR && $init, 'init without Event : no die, TRUE' );
my $b_ref = $data{'log'}{'send-buffer'}{'zenka'};
ok( ref $b_ref eq 'HASH' && $b_ref->{'watchers_pending'},
    '  :.. buffer created, watchers pending' );
ok( !@var_watchers && !@idle_sets, '  :.. no watcher, no idle callback' );

for my $n ( 1 .. 3 ) {
    my $line = "early line $n";
    $code{'base.log.send-buffer.add-queue'}->( 'zenka', \$line );
}
ok( scalar @{ $b_ref->{'data'} } == 3 && $b_ref->{'lines-added'} == 3,
    'lines before Event : queued [ 3 ]' );
ok( $b_ref->{'watchers_pending'}, '  :.. still pending' );

say ':: Event installed [ bootstrap ]';

$event_loaded = TRUE;
my $line4 = 'first line after Event';
$code{'base.log.send-buffer.add-queue'}->( 'zenka', \$line4 );
ok( !$b_ref->{'watchers_pending'}, 'next line : watchers set up' );
ok( scalar @var_watchers == 2
        && $var_watchers[0]{'var'} == \$b_ref->{'lines-added'}
        && $var_watchers[1]{'var'} == \$b_ref->{'sent-lines'},
    '  :.. watchers on the buffer\'s lines-added + sent-lines counters'
);
ok( scalar @idle_sets == 1 && $idle_sets[0] eq 'zenka',
    '  :.. idle send callback armed' );
ok( scalar @{ $b_ref->{'data'} } == 4, '  :.. nothing lost [ 4 queued ]' );

my $line5 = 'later line';
$code{'base.log.send-buffer.add-queue'}->( 'zenka', \$line5 );
ok( scalar @var_watchers == 2, 'later lines : no second watcher set' );

say ':: Event present from the start';

delete $data{'log'};
@var_watchers = @idle_sets = ();
$code{'base.log.send-buffer.init'}->('zenka');
ok( !$data{'log'}{'send-buffer'}{'zenka'}{'watchers_pending'}
        && scalar @var_watchers == 2
        && scalar @idle_sets == 1,
    'init with Event : watchers at once, nothing pending [ as before ]'
);

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,,.,,,.,,..,,.,,.,.,...,.,.,,,.,...,,,,,..,,...,...,,..,,,.,,..,,..,...,
#3GXJWBNMPYGRBNBPYGZQFK5VWB2DOSVXUBYJNBY3MDWDFJDEGE3SW7NOM43QR3S52L5INGMQFXTXE
#\\\|3JEYDARJR4V53EQH63TKU4KF5UKUZ7L76BJAMJ77BEC26TZX5K6 \ / AMOS7 \ YOURUM ::
#\[7]XPNQI5KFUFSVQY2O4TLID4NQGXU65BNCWT6UZUW2Q35XUCBKYIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
