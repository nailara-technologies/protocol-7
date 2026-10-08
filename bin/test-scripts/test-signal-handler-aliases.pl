#!/usr/bin/perl
## install_signal_handlers : one watcher per signal number -- regression   ##
###                                                                         ###

## two parts.                                                               ##
##                                                                          ##
## 1 : unit -- compiles the REAL                                            ##
## src/base.init_zenka.install_signal_handlers [ like the other harnesses : ##
## AMOS7::Protocol::P7Syntax  p7_syntax__translate + an eval'd wrapper ]    ##
## against stubbed base.sort / base.logs / base.perlmod.load /              ##
## event.add_signal. %SIG carries aliases [ CLD = CHLD, IOT = ABRT, POLL =  ##
## IO ] and Event.pm only calls sigaction when its per-signal watcher count ##
## goes 0 -> 1, so a second watcher on the same number silently defeats any ##
## later add_signal for that signal [ v7-zenki lost SIGCHLD after           ##
## v7-zenki.compile_bin_p7c restored $SIG{CHLD} : 07e19f5a2, 2026-10-07 ].  ##
## checks : one registration per sig_num, CHLD yes / CLD no, no IOT beside  ##
## ABRT and no POLL beside IO, and a stale CLD watcher from an earlier init ##
## is cancelled + deleted on reload.                                        ##
##                                                                          ##
## 2 : live mechanism -- real Event.pm in this process, /proc/$$/status     ##
## SigCgt bit 16 [ signal 17 = CHLD ] as ground truth : one watcher         ##
## catches, save/set-IGNORE/restore loses the kernel handler, cancel + new  ##
## watcher catches again, and -- the documented failure mode -- with a      ##
## second watcher on 'CLD' present the same sequence stays lost. ends by    ##
## forking a child and asserting the CHLD callback fires [ Event::sweep ].  ##
##                                                                          ##
## P7_TEST_SIG_SRC env override : compile another copy of the module [ eg a ##
## pre-fix one from `git show` ] instead of the current src file.           ##

use v5.24;
use strict;
use warnings;
use English;
use Config;
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
    $main::root_path = $root_path;
}

use lib File::Spec->catdir( $main::root_path, qw| data lib-path pm | );
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

## compile-time : Event's signal plumbing only wires up fully when the    ##
## module is loaded at compile time [ empirically : require+import leaves ##
## CHLD delivery dead in this process ]                                   ##
use Event;
use Time::HiRes qw| sleep |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $fail_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

our %data;
our %code;

##[ part 1 : unit -- compile the real module against stubs ]##################

my @signal_registrations;
my @cancelled_watchers;

$code{'base.sort'}
    = sub { my $hash_ref = shift; return sort keys %$hash_ref };
$code{'base.logs'}         = sub { return TRUE };
$code{'base.perlmod.load'} = sub {
    my $module = shift;
    eval "require $module";    ## Config : %Config::Config ##
    die "perlmod.load $module : $EVAL_ERROR" if $EVAL_ERROR;
    return TRUE;
};

{    ## fake watcher : cancel records, like the real event.add_signal store ##

    package FakeWatcher;
    sub new { return bless { 'name' => $_[1], 'cancelled' => 0 }, $_[0] }

    sub cancel {
        $_[0]->{'cancelled'} = 1;
        main::watcher_cancelled( $_[0] );
        return;
    }
}

sub watcher_cancelled { push @cancelled_watchers, $_[0]; return }

$code{'event.add_signal'} = sub {
    my $params = shift;
    push @signal_registrations, $params;
    my $sig     = $params->{'signal'};
    my $watcher = FakeWatcher->new($sig);
    $data{'watcher'}{'signal'}{$sig} = $watcher;
    return $watcher;
};

sub compile_signal_module {
    my $src_path = $ENV{'P7_TEST_SIG_SRC'}
        // File::Spec->catfile( $main::root_path, 'src',
        'base.init_zenka.install_signal_handlers' );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $OS_ERROR";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$src_path\"\n$translated\n}";
    die "compile failed for $src_path : $EVAL_ERROR"
        if not defined $cref;
    return $cref;
}

say ': 1. unit : install_signal_handlers registers one watcher per number';

my %sig_num;
@sig_num{ split( ' ', $Config::Config{'sig_name'} ) }
    = split( ' ', $Config::Config{'sig_num'} );

my %saved_sig = %SIG;    ## the module deletes entries : restore after    ##
my $install   = compile_signal_module();
$install->();
%SIG = %saved_sig;

my %seen_registration_num;
my $alias_collision = 0;
foreach my $params (@signal_registrations) {
    my $num = $sig_num{ $params->{'signal'} };
    $alias_collision++ if defined $num and $seen_registration_num{$num}++;
}
my %registered = map { $_->{'signal'} => 5 } @signal_registrations;

ok( $alias_collision == 0,
    'no two registered signals share one sig_num [ alias dedupe ]' );
ok( exists $registered{'CHLD'}, 'CHLD is registered' );
ok( !exists $registered{'CLD'}, 'CLD [ alias of CHLD ] is NOT registered' );
ok( !( exists $registered{'ABRT'} and exists $registered{'IOT'} ),
    'IOT not registered alongside ABRT [ same number ]'
);
ok( !( exists $registered{'IO'} and exists $registered{'POLL'} ),
    'POLL not registered alongside IO [ same number ]'
);
ok( defined $data{'watcher'}{'signal'}{'CHLD'},
    'CHLD watcher stored under <watcher.signal>'
);

say ': 1b. reload : a stale CLD watcher from an earlier init is dropped';

$data{'watcher'}{'signal'}{'CLD'} = FakeWatcher->new('CLD-seed');
my $seed_watcher = $data{'watcher'}{'signal'}{'CLD'};
@cancelled_watchers = ();

%saved_sig = %SIG;
$install->();
%SIG = %saved_sig;

ok( $seed_watcher->{'cancelled'}, 'stale CLD watcher cancelled on reload' );
ok( scalar(@cancelled_watchers) == 1
        && !exists $data{'watcher'}{'signal'}{'CLD'},
    'stale CLD watcher deleted from <watcher.signal>'
);

##[ part 2 : live mechanism -- real Event.pm, /proc SigCgt bit 16 ]###########

say ': 2. live mechanism : Event.pm + /proc/$$/status SigCgt bit 16';

my $chld_callback_count = 0;
sub chld_event_callback { $chld_callback_count++; return }

sub sigcgt_hex {
    open( my $fh, '<', "/proc/$$/status" ) or die "proc read : $OS_ERROR";
    while ( my $line = <$fh> ) {
        return $1 if $line =~ m|^SigCgt:\s+([0-9a-f]+)|;
    }
    die 'SigCgt line missing';
}
sub sigcgt_bit { return ( hex( sigcgt_hex() ) >> $_[0] ) & 1 }

## fork a child that exits immediately ; a caught CHLD fires our callback ##
## on the next Event::sweep after the disposition has had a moment        ##
sub probe_child_exit {
    $chld_callback_count = 0;
    my $pid = fork();
    die "fork : $OS_ERROR" if not defined $pid;
    exit 0                 if $pid == 0;
    sleep 0.3;
    Event::sweep();
    waitpid( $pid, 0 );
    return $chld_callback_count > 0 ? TRUE : FALSE;
}

my @live_watchers;

sub live_watch {
    my $sig = shift;
    my $w   = Event->signal( signal => $sig, cb => \&chld_event_callback );
    push @live_watchers, $w;
    Event::sweep();
    return $w;
}

my $saved_chld_sig = $SIG{'CHLD'};

ok( sigcgt_bit(16) == 0,
    'bit 16 [ signal 17 = CHLD ] not caught before any watcher' );

live_watch('CHLD');
ok( sigcgt_bit(16) == 1,
    'one CHLD watcher : kernel handler installed [ count 0 -> 1 ]' );

ok( probe_child_exit(),
    'forked child exit fires the CHLD callback [ Event::sweep ]' );

## the v7-zenki.compile_bin_p7c shape : something assigns $SIG{CHLD},  ##
## beneath Event, and the restore writes SIG_DFL back over the handler ##
$SIG{'CHLD'} = 'IGNORE';
$SIG{'CHLD'} = $saved_chld_sig;
ok( sigcgt_bit(16) == 0,
    'save / set IGNORE / restore loses the kernel handler beneath Event' );
ok( !probe_child_exit(), 'CHLD delivery lost after the restore' );

$live_watchers[-1]->cancel;
live_watch('CHLD');
ok( sigcgt_bit(16) == 1,
    'cancel + new watcher re-installs the handler [ count 0 -> 1 again ]' );
ok( probe_child_exit(), 'CHLD delivery restored' );

say ': 2b. the documented failure mode : alias watcher keeps the count up';

live_watch('CLD');             ## second watcher, same signal number 17 ##
$SIG{'CHLD'} = 'IGNORE';
$SIG{'CHLD'} = $saved_chld_sig;
$live_watchers[-2]->cancel;    ## the CHLD watcher, leaving CLD's ##
live_watch('CHLD');
ok( sigcgt_bit(16) == 0,
    'with a CLD alias watcher present the new CHLD watcher '
        . 'does NOT re-install [ v7-zenki 2026-10-07 failure mode ]'
);
ok( !probe_child_exit(),
    'CHLD stays lost -- why one watcher per number matters' );

foreach my $w (@live_watchers) { $w->cancel if $w }
$SIG{'CHLD'} = $saved_chld_sig;

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,,.,.,,,.,.,.,.,,,,,,,.,,.,,,,.,,.,,,,.,..,,...,...,.,.,.,.,.,,,,..,...,
#SVYMNSQQSAVMSTPD4LPQSHKFCSB2VHPKLZBSDDAUWKD5JUE5BOYOL5ILXF2VP4HEGLBEPBRP5TYQI
#\\\|FJ5VKMVF3PQ45EOPA4UDBHQA6ULAAPNEQRHWZX5H2EHLHM3XO2V \ / AMOS7 \ YOURUM ::
#\[7]OLDRIB6DNQ7PQKZQBAE5SPGET76RF2QN47X7QSLPMPDWF5EOVEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
