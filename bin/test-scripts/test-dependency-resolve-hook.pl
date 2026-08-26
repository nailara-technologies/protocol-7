#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                ###
##  generic dependency resolve-hook : standalone acceptance harness ##
###                                                                ###

## exercises the real translated module sources [ base.dependency.setup,    ##
## .add_object, .add, .install_callbacks, .ok, and v7.resolve.object.zenka  ##
## ] against an in-process %data / %code stub environment -- no live v7     ##
## required. covers:                                                        ##
## - install_callbacks discovers callback+resolve per type [ dotted types,  ##
## callback-only types unaffected -- regression guard for the 4 real        ##
## pre-existing callback-only consumers ]                                   ##
## - dependency.ok still returns FALSE/TRUE exactly as before, unchanged    ##
## control flow, when a resolve hook is present                             ##
## - resolve hook fires on a failed check, is debounced per chain-object id ##
## [ guards the duplicate-start bug a naive un-debounced hook would cause   ##
## -- jobqueue.check_dependencies sweeps 'depending' synchronously every    ##
## tick, and v7.start_count can't see a job sitting in 'queued' ]           ##
## - a resolve hook that dies never propagates out of dependency.ok         ##
## - v7.resolve.object.zenka resolves object_id -> zenka_id -> zenka_name   ##
## and cascade-starts via zenka.cmd.start_once with the correct args        ##

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

##[ p7 runtime environment stubs ]############################################

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

## controllable fake clock : advanced explicitly by the test, not real time ##
my $FAKE_NOW = 1000;

## simple sequential id generator -- real base.gen_id does harmonic/mod-13 ##
## id shaping, irrelevant to what this hook actually needs to verify       ##
my $NEXT_ID = 1;

my @start_once_calls;

%code = (
    'base.log'    => sub { return TRUE },
    'base.logs'   => sub { return TRUE },
    'base.gen_id' => sub {
        my $href = shift;
        my $id;
        do { $id = $NEXT_ID++ } while exists $href->{$id};
        return $id;
    },
    'base.ntime'           => sub { return $FAKE_NOW },
    'base.str.eval_error'  => sub { return "$EVAL_ERROR" },
    'zenka.cmd.start_once' => sub {
        my $args = shift;
        push @start_once_calls, $args;
        return { 'mode' => qw| true |, 'data' => 'job queued [ID=1]' };
    },
);

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

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

compile_module($_) foreach qw|
    base.dependency.setup
    base.dependency.add_object
    base.dependency.add
    base.dependency.install_callbacks
    base.dependency.ok
    v7.resolve.object.zenka
    |;

## real runtime aliases base.X -> X via base.swap_subs [ base.pre_init ] : ##
## install_callbacks calls the short form internally, so mirror that here  ##
$code{'dependency.setup'} = $code{'base.dependency.setup'};

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ 1 : install_callbacks -- discovers callback+resolve, dotted types,  ]#####
##[     leaves callback-only types alone [ regression guard ]           ]#####

say ': install_callbacks';

my ( @thing_cb_calls, @thing_resolve_calls );
$code{'test.callback.object.thing'} = sub {
    push @thing_cb_calls, [@_];
    return FALSE;    ## always unresolved, to exercise the resolve path ##
};
$code{'test.resolve.object.thing'} = sub {
    push @thing_resolve_calls, [@_];
    return TRUE;
};
$code{'test.callback.object.only_cb'}   = sub { return TRUE };
$code{'test.callback.object.deep.type'} = sub { return TRUE };

my $registered = $code{'base.dependency.install_callbacks'}->('test');
ok( $registered == 3,
    "install_callbacks registered " . "3 types [ got $registered ]" );

ok( ref( $data{'dependency'}{'setup'}{'type'}->{'thing'}->{'callback'} ) eq
        'CODE',
    "'thing' type got a callback"
);
ok( ref( $data{'dependency'}{'setup'}{'type'}->{'thing'}->{'resolve'} ) eq
        'CODE',
    "'thing' type got a resolve hook"
);
ok( ref( $data{'dependency'}{'setup'}{'type'}->{'only_cb'}->{'callback'} ) eq
        'CODE',
    "'only_cb' type got a callback"
);
ok(
    (   not exists $data{'dependency'}{'setup'}{'type'}->{'only_cb'}
            ->{'resolve'}
    ),
    "'only_cb' type has NO resolve key at all [ callback-only untouched ]"
);
ok( ref( $data{'dependency'}{'setup'}{'type'}->{'deep.type'}->{'callback'} )
        eq 'CODE',
    'dotted type name still discovered correctly'
);

##[ 2 : dependency.ok -- unchanged return value, resolve fires + debounces ]##

say ': dependency.ok + resolve debounce';

my $obj_a = $code{'base.dependency.add_object'}->( { 'type' => 'thing' } );
my $obj_b = $code{'base.dependency.add_object'}->( { 'type' => 'thing' } );
$code{'base.dependency.add'}->( $obj_a, $obj_b );

my $result1 = $code{'base.dependency.ok'}->($obj_a);
ok( ( not $result1 ), 'dependency.ok returns FALSE exactly as before' );
ok( scalar(@thing_resolve_calls) == 1,
    'resolve hook fired once on first failed check' );

## burst of checks within the same tick / same debounce window : must NOT   ##
## fire resolve again -- this is the check that guards the duplicate- start ##
## bug (queue_counter/check_dependencies both re-check every tick)          ##
$code{'base.dependency.ok'}->($obj_a) foreach 1 .. 20;
ok( scalar(@thing_resolve_calls) == 1,
    'resolve NOT re-fired during a burst inside the debounce window [ '
        . scalar(@thing_resolve_calls)
        . ' total calls ]'
);

##  advance the fake clock past the default 5s min_interval : must fire again
$FAKE_NOW += 6;
$code{'base.dependency.ok'}->($obj_a);
ok( scalar(@thing_resolve_calls) == 2,
    'resolve fires again once the debounce interval has elapsed' );

##[ 3 : a resolve hook that dies must never propagate out of dependency.ok ]#

say ': resolve hook error safety';

$code{'test.callback.object.dying'} = sub { return FALSE };
$code{'test.resolve.object.dying'}  = sub { die "boom\n" };
$code{'base.dependency.install_callbacks'}->('test');

my $obj_c = $code{'base.dependency.add_object'}->( { 'type' => 'dying' } );
my $obj_d = $code{'base.dependency.add_object'}->( { 'type' => 'dying' } );
$code{'base.dependency.add'}->( $obj_c, $obj_d );

my $result2 = eval { $code{'base.dependency.ok'}->($obj_c) };
ok( ( not $EVAL_ERROR ),
    'a dying resolve hook does ' . 'not propagate an exception' );
ok( ( not $result2 ),
    'dependency.ok still returns ' . 'FALSE despite resolve dying' );

##[ 4 : v7.resolve.object.zenka -- id resolution + cascade-start call ]#######

say ': v7.resolve.object.zenka';

$data{'dependency'}{'object'}->{99} = { 'type' => 'zenka', 'zenka_id' => 42 };
$data{'v7'}{'zenka'}{'setup'}->{42} = { 'name' => 'models' };

my $reply = $code{'v7.resolve.object.zenka'}->(99);
ok( scalar(@start_once_calls) == 1, 'zenka.cmd.start_once called once' );
ok( ( $start_once_calls[0]->{'args'} // '' ) eq 'models',
    'start_once called with the resolved zenka name'
);
ok( ( $start_once_calls[0]->{'recursion'} // -1 ) == 1,
    'start_once called with recursion => 1 [ forces implicit start-mode ]' );
ok( ( $reply->{'mode'} // '' ) eq 'true',
    'resolve hook returns ' . 'start_once reply'
);

##  wrong object type / unknown id : safe undef, no cascade attempt  ##
$data{'dependency'}{'object'}->{100} = { 'type' => 'not-zenka' };
my $wrong_type = $code{'v7.resolve.object.zenka'}->(100);
ok( ( not defined $wrong_type ), 'wrong object type returns undef' );
ok( scalar(@start_once_calls) == 1,
    'wrong object type ' . 'does not cascade-start' );

my $unknown_id = $code{'v7.resolve.object.zenka'}->(999999);
ok( ( not defined $unknown_id ), 'unknown object id returns undef' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,.,,...,...,,,,,,,.,...,..,,,..,,,.,...,..,,...,..,,...,,,.,.,.,,..,..,,
#HV6AFHVSSEXXJIKOGXPP6Y6Q5JNBE6KW37KY2DJ3CRHDVTYA3LVM6IZTG3ZY5AIVRKUQAI4FC4PES
#\\\|R2ZAFVNMJWKZCFBQGGXOAMLIC2QZM575FY7WHJDU4IIGS3PW6ZC \ / AMOS7 \ YOURUM ::
#\[7]7LCNBDDXUICWGXQZB46OQCQZP3SWIGYAP5JSURTN3MRODUMXQECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
