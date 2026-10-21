#!/usr/bin/env perl

use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## v7-zenki optional dependencies + fail-fast on a disabled one :          ##
## 'optional_dependencies' count where the zenka is not disabled on the    ##
## host and are left out where it is ; a hard dependency that is disabled  ##
## refuses the start with the reason instead of a start that waits forever ##
## [ external on servers : discover is lan multicast, 2026-10-21 ] REAL    ##
## get_dependencies, is_disabled, cmd.start, cmd.start_once. no zenka      ##

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
    my ( $module_name, $prefix ) = @ARG;
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
$code{'base.logs'}              = sub { push @logged, [@ARG]; return };
$code{'base.log'}               = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}            = sub {return};
$code{'v7-zenki.start_count'}   = sub { return 0 };
$code{'zenka.instance.get_ids'} = sub { return [] };
$code{'zenka.is_enabled'}       = sub {
    my $enabled
        = $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'}{'enabled'}
        // return TRUE;
    return scalar grep { $ARG eq $_[0] } split m|\s+|, $enabled;
};

my $cmd_header = q{my $call = {}; if ( ref( $ARG[0] ) eq 'HASH' ) }
    . q{{ $call = $ARG[0] } else { $call->{'args'} = $ARG[0] }};

compile_module( 'v7-zenki.zenka.is_disabled', '' );
$code{'zenka.is_disabled'} = $code{'v7-zenki.zenka.is_disabled'};
compile_module( 'v7-zenki.zenka.get_dependencies', '' );
$code{'zenka.get_dependencies'} = $code{'v7-zenki.zenka.get_dependencies'};
compile_module( 'v7-zenki.zenka.cmd.start', $cmd_header );
$code{'zenka.cmd.start'} = $code{'v7-zenki.zenka.cmd.start'};
compile_module( 'v7-zenki.zenka.cmd.start_once', $cmd_header );
$code{'zenka.cmd.start_once'} = $code{'v7-zenki.zenka.cmd.start_once'};

$data{'regex'}{'base'}{'iid'}     = qr|^\d+$|;
$data{'regex'}{'base'}{'subname'} = qr|[\w.:-]|;
$data{'regex'}{'base'}{'usr_str'} = qr|[\w.-]|;

sub profile {
    my (%z) = @ARG;
    $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'} = {%z};
    $data{'v7-zenki'}{'cfg_data'}{'start_profile'} = 'remote-server';
    return;
}

sub start_cfg {
    my ( $zenka_name, %cfg ) = @ARG;
    $data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}{$zenka_name} = {%cfg};
    return;
}

start_cfg($ARG) for qw| cube nodes discover |;

say ':: get_dependencies';

start_cfg( 'external', 'dependencies' => 'cube nodes' );
profile();
ok( ( $code{'zenka.get_dependencies'}->('external') // '' ) eq 'cube nodes',
    'hard dependencies only : unchanged' );

start_cfg(
    'external',
    'dependencies'          => 'cube nodes',
    'optional_dependencies' => 'discover'
);
profile();    ## desktop : nothing disabled ##
ok( ( $code{'zenka.get_dependencies'}->('external') // '' ) eq
        'cube nodes discover',
    'optional, enabled on the host : counts like a dependency'
);

profile( 'disabled' => 'discover graphics-matrix' );    ## a server ##
ok( ( $code{'zenka.get_dependencies'}->('external') // '' ) eq 'cube nodes',
    'optional, disabled on the host : left out' );

start_cfg( 'external', 'optional_dependencies' => 'discover' );
ok( !defined $code{'zenka.get_dependencies'}->('external'),
    'only a disabled optional one : no dependencies [ undef ]'
);
start_cfg('lonely');
ok( !defined $code{'zenka.get_dependencies'}->('lonely'),
    'none configured : undef, as before' );

say ':: a disabled hard dependency refuses the start';

start_cfg( 'external', 'dependencies' => 'cube nodes discover' );
profile(
    'enabled'  => 'cube nodes',
    'disabled' => 'discover graphics-matrix'
);
@logged = ();
my $reply = eval {
    $code{'v7-zenki.zenka.cmd.start'}->( { 'args' => 'external' } );
};
ok( !length $EVAL_ERROR, 'cmd.start returns [ no die ]' )
    or say "    : $EVAL_ERROR";
ok( ref $reply eq 'HASH' && ( $reply->{'mode'} // '' ) eq 'false',
    'external : refused' );
ok( ( $reply->{'data'} // '' )
        =~ m|dependency 'discover' is disabled on this host|,
    '  :.. the reason names the dependency'
);
ok( scalar( grep { ( $ARG->[1] // '' ) =~ m|not started| } @logged ),
    '  :.. logged' );

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,.,,,.,,,,,.,.,,..,,,,,.,,,.,,,,.,,..,,...,..,,...,...,..,,,,.,...,.,.,,.,,
#ZS5UMO46LJGPQUPIZIWZO4QNYPPPSCRDU2SIL3ZNQ7PNIYKLK6X7CTK5PUO4PNABA5QU63YB23QAU
#\\\|O4PTKEYBUTE3AWKJIXSHKMM35BZJCQNNNNTZ47U2PQEUBVQ2IOF \ / AMOS7 \ YOURUM ::
#\[7]7PZWRLQM6GKBC4WD2K7L6D66XPLWZ7OCG4EJTYXEHESPLP6RM4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
