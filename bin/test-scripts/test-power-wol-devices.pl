#!/usr/bin/env perl
use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use File::Spec;
use FindBin qw| $RealBin |;
use Cwd     qw| abs_path |;

BEGIN {
    my $root
        = abs_path(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
        );
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our @ARG;
our $call;

my $checks = 0;
my $failed = 0;

sub check {
    my ( $label, $condition ) = @ARG;
    $checks++;
    if ($condition) {
        say "ok   : $label";
        return TRUE;
    }
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

$code{'base.log'}   = sub { return TRUE };
$code{'base.ntime'} = sub { return 123 };
my $saves = 0;
$code{'power.save_config'} = sub { $saves++; return TRUE };

compile_module($ARG) for qw|
    power.cmd.add-wol-device
    power.cmd.remove-wol-device
    power.cmd.show_all
    |;

sub run_cmd {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args // '' };
    return $code{$name}->($call);
}

my $reply = run_cmd( 'power.cmd.add-wol-device', '' );
check( 'usage required',
    $reply->{'mode'} eq qw| false | && $reply->{'data'} =~ m|^usage :| );

foreach my $case (
    [ 'bad name',  'bad.name aa:bb:cc:dd:ee:ff',   'invalid device name' ],
    [ 'bad mac',   'host aa-bb-cc-dd-ee-ff',       'invalid mac address' ],
    [ 'short mac', 'host aa:bb:cc:dd:ee',          'invalid mac address' ],
    [ 'bad iface', 'host aa:bb:cc:dd:ee:ff eth-0', 'invalid interface' ],
) {
    $reply = run_cmd( 'power.cmd.add-wol-device', $case->[1] );
    check(
        "validation : $case->[0]",
        $reply->{'mode'} eq qw| false |
            && index( $reply->{'data'}, $case->[2] ) >= 0
    );
}

$reply = run_cmd( 'power.cmd.add-wol-device',
    'build-host AA:BB:CC:DD:EE:FF enp1s0' );
check(
    'add stores lowercase mac, driver and iface',
    $reply->{'mode'} eq qw| true |
        && $data{'power'}{'cfg'}{'devices'}{'build-host'}{'mac'} eq
        'aa:bb:cc:dd:ee:ff'
        && $data{'power'}{'cfg'}{'devices'}{'build-host'}{'driver'} eq
        qw| wol |
        && $data{'power'}{'cfg'}{'devices'}{'build-host'}{'iface'} eq
        qw| enp1s0 |
        && $saves == 1
);

$reply = run_cmd( 'power.cmd.add-wol-device',
    'build-host aa:bb:cc:dd:ee:ff other0' );
check(
    'same name and mac is already present without saving',
    $reply->{'data'} eq 'already present' && $saves == 1
);

$reply = run_cmd( 'power.cmd.add-wol-device',
    'build-host 02:00:5e:10:00:01 enp1s0' );
check(
    'different mac requires replace',
    $reply->{'mode'} eq qw| false |
        && $reply->{'data'} =~ m|:replace:|
        && $saves == 1
);

$reply = run_cmd( 'power.cmd.add-wol-device',
    'build-host 02:00:5e:10:00:01 enp1s0 :replace:' );
check(
    'replace updates through the save path',
    $reply->{'mode'} eq qw| true |
        && $data{'power'}{'cfg'}{'devices'}{'build-host'}{'mac'} eq
        '02:00:5e:10:00:01'
        && $saves == 2
);

$code{'power.cmd.get_states'} = sub {
    return { 'mode' => qw| true |, 'data' => 'E' };
};
$reply = run_cmd( 'power.cmd.show_all', '' );
check( 'show_all lists the wol device',
    $reply->{'data'} =~ m|^build-host 02:00:5e:10:00:01 - E|m );

$reply = run_cmd( 'power.cmd.remove-wol-device', 'bad.name' );
check(
    'remove validates the name',
    $reply->{'mode'} eq qw| false |
        && $reply->{'data'} =~ m|invalid device name|
        && $saves == 2
);

$reply = run_cmd( 'power.cmd.remove-wol-device', 'missing' );
check(
    'remove refuses a missing device',
    $reply->{'mode'} eq qw| false |
        && $reply->{'data'} =~ m|does not exist|
        && $saves == 2
);

$reply = run_cmd( 'power.cmd.remove-wol-device', 'build-host' );
check(
    'remove saves once',
    $reply->{'mode'} eq qw| true |
        && !exists $data{'power'}{'cfg'}{'devices'}{'build-host'}
        && $saves == 3
);

say sprintf ':: %d passed, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,.,,.,,,...,.,.,...,...,..,,,..,.,.,,,,,,,.,..,,...,...,..,,.,,,..,,.,.,,.,,
#UTIYCKVLWQEPSIZLJUBYW67SIEX4WUZJLVPGHUDZWUUD762YWD6IELIJZIQM4H5S6ETREQB7XGDUS
#\\\|THOVKYYHS46QKRTNMDLFC5DZQISNJ3IPC5PP7XCZL5DEFNLGN2P \ / AMOS7 \ YOURUM ::
#\[7]6S6E4T3JJ3G33C6WNFQAC6C6LBMII6IIGU7LSBWCBWSXFPYM62CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
