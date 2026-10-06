#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## base.prng seeding : OS entropy + machine data [ 2026-10-06 ]             ##
## Crypt::PRNG::Fortuna->new( $seed ) uses ONLY the given seed -- before    ##
## this fix the seed was a function of PID + ms time alone. checks that the ##
## entropy pool carries OS entropy, differs per call, tolerates missing     ##
## machine sources, and that identical harmonic input no longer gives       ##
## identical streams. no live zenka required.                               ##

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
use Crypt::PRNG::Fortuna;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

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

## stubs for what reseed \ entropy_pool call ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
## fixed : worst case ##
$code{'base.ntime'} = sub { return '3225760654008' };
## leave the loop at once ##
$code{'base.assert.harmony'} = sub { return 1 };
$code{'base.sleep'}          = sub {return};
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'} = sub { return '[ test ]' };
$code{'base.time'}
    = sub { require Time::HiRes; return sprintf '%.9f', Time::HiRes::time() };

compile_module('base.prng.entropy_pool');
compile_module('base.prng.reseed');
compile_module('base.prng.add_entropy');

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @ARG };

say ': entropy pool';

my $pool_a = $code{'base.prng.entropy_pool'}->('42');
my $pool_b = $code{'base.prng.entropy_pool'}->('42');

ok( length($pool_a) == 64, 'pool is a 64-byte BMW-512 digest' );
ok( $pool_a ne $pool_b, 'same harmonic input, two calls : different pools' );
require AMOS7::Assert::Truth;
ok( scalar( AMOS7::Assert::Truth::is_true( \$pool_a, FALSE, TRUE ) )
        && scalar( AMOS7::Assert::Truth::is_true( \$pool_b, FALSE, TRUE ) ),
    'pools pass the truth assertion [ harmonic, new source ]'
);
ok( ( $data{'base'}{'prng'}{'os_entropy'} // 0 ) == TRUE,
    'os entropy present and flagged' );
ok( !grep( { ( $ARG->[1] // '' ) =~ m{WITHOUT os entropy} } @logged ),
    'no weak-pool warning on a host with os entropy' );
ok( !@warnings,
    'no perl warnings while optional machine sources are missing' );
say "         $ARG" for @warnings;

say ': reseed';

## the old weakness : PID + time identical -> identical fortuna stream ##
$code{'base.prng.reseed'}->();
my $stream_a = $data{'base'}{'prng'}{'fortuna'}->bytes_hex(32);
$code{'base.prng.reseed'}->();
my $stream_b = $data{'base'}{'prng'}{'fortuna'}->bytes_hex(32);

ok( $stream_a ne $stream_b,
    'same PID + same time, two reseeds : different streams' );

say ': add_entropy';

my $before = $data{'base'}{'prng'}{'fortuna'};
ok( ( $code{'base.prng.add_entropy'}->('test-data') // 0 ) == TRUE
        && length( $before->bytes(32) ) == 32,
    'add_entropy on a live prng : TRUE, prng keeps producing'
);
ok( !@complaints, 'add_entropy with data : no complaint' );
{
    local $data{'base'}{'prng'}{'fortuna'} = undef;
    ok( ( $code{'base.prng.add_entropy'}->('x') // 1 ) == FALSE,
        'add_entropy without a prng yet : FALSE, no die'
    );
}
@complaints = ();
$code{'base.prng.add_entropy'}->($ARG) for ( undef, '' );
ok( scalar(@complaints) == 2
        && !grep( { !m{no entropy data given} } @complaints ),
    'add_entropy complains for undef and for empty data'
);

## additive : the same OS-seeded start, entropy added to one of them ##
{
    my $x = Crypt::PRNG::Fortuna->new('fixed');
    my $y = Crypt::PRNG::Fortuna->new('fixed');
    local $data{'base'}{'prng'}{'fortuna'} = $y;
    $code{'base.prng.add_entropy'}->('more');
    ok( $x->bytes_hex(16) ne $y->bytes_hex(16),
        'add_entropy changes the stream [ additive reseed ]' );
}

## the pre-fix behaviour, for contrast : a bare seed is deterministic ##
ok( Crypt::PRNG::Fortuna->new('3225760654008')->bytes_hex(16) eq
        Crypt::PRNG::Fortuna->new('3225760654008')->bytes_hex(16),
    'reference : fortuna with only a bare seed IS deterministic'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,..,,,.,,...,.,,,,,.,.,.,.,.,.,,,.,.,..,,..,,...,...,,,,,,,,,,..,,,,,,..,
#TUBKCLTAFNRKHZOVU33EBJRJZDYHQ4AVREIL247EVACZXJDUR2SG5YHS3L6CJ2KMBDYZDSHEXG2KS
#\\\|NXWSZIMVOUDU3BUI4CRYWJNK2NBGDKDNUS5IILXTKAJWMK3YPHP \ / AMOS7 \ YOURUM ::
#\[7]W5A6P65BPSN6NOLMA5WSMAWLQJRUZ2BGJYE6FTZJYKIEUHZ6RKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
