#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## base.interval.* : the shared non-linear interval helper -- growth, cap, ##
## jitter bounds, reset, pairs, the division-by-13 filter                  ##
## [ applied and bounded ], golden-blink alternation, no round 600 s.      ##
## compiles the real src modules ; the 13 filter calls the real            ##
## AMOS7::Assert::Truth ::is_true [ swapped for the bounded tests ],       ##
## base.cfg_bool is the real module.  no zenka started.                    ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $root = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root;
    unshift @INC, "$root/data/lib-path/pm";
}

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

our %data;
our %code;
my $warned = 0;
use subs qw| warn |;
sub warn { $warned++; return FALSE }
## refusals log, never die ##
$code{'base.log'} = sub { $warned++; return TRUE };

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
}

sub translate_code {
    my $code = shift;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>(?=->)|"\$code{$1}"|eg;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>|"\$code{$1}->()"|eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    open my $fh, '<', File::Spec->catfile( $root_path, 'src', $name )
        or die "cannot read $name : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    my $sub        = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

## stubs ##

my $real_truth    = eval { require AMOS7::Assert::Truth; 1 };
my $harmony_calls = 0;
my $real_is_true  = $real_truth ? \&AMOS7::Assert::Truth::is_true : undef;
my $harmony = sub { my $s = shift; return $real_is_true->( \$s, 1, 1 ) };

sub set_is_true {    ## swap the function the module calls ##
    no warnings qw| redefine |;
    *AMOS7::Assert::Truth::is_true = shift;
}
if ( not $real_truth ) {
    say "# AMOS7::Assert::Truth not loadable : filter tests skipped";
}

load_module($ARG) for qw|
    base.cfg_bool
    base.interval.next
    base.interval.rhythm.non-linear
    base.interval.rhythm.golden-blink
    |;

my $next = sub { $code{'base.interval.next'}->(@ARG) };

## cfg per type ##
$data{'base'}{'interval'}{'cfg'}{'type'} = {
    qw| plain |  => { qw| harmonic | => 0 },
    qw| fast |   => { qw| harmonic | => 0, qw| start | => 0.07 },
    qw| capped | => {
        qw| harmonic |   => 0,
        qw| start |      => 1,
        qw| cap |        => 10,
        qw| cap_jitter | => 2
    },
    qw| pairs | => {
        qw| harmonic |   => 0,
        qw| send_count | => 2,
        qw| distance |   => 0.13,
        qw| start |      => 0.19,
        qw| factor |     => 1.13
    },
    qw| harm |   => {},
    qw| blink |  => { qw| rhythm | => qw| golden-blink | },
    qw| blink2 | => {
        qw| rhythm | => qw| golden-blink |,
        qw| on |     => 1.274,
        qw| off |    => 0.769
    },
    qw| blink3 | => {
        qw| rhythm | => qw| golden-blink |,
        qw| on |     => 0.5
    },
    qw| idle10 | => { qw| minutes | => 10 },
    qw| idle13 | => { qw| minutes | => 13 },
    qw| nosuch | =>
        { qw| rhythm | => qw| does-not-exist |, qw| harmonic | => 0 },
};

sub near { abs( $_[0] - $_[1] ) < 1e-9 }

## defaults : start 0.77, factor 1.2 ##
{
    my %st;
    my $a = $next->( { type => 'plain', state => \%st } );
    my $b = $next->( { type => 'plain', state => \%st } );
    my $c = $next->( { type => 'plain', state => \%st } );
    ok( near( $a, 0.77 ),        'default start 0.77' );
    ok( near( $b, 0.77 * 1.2 ),  'grows x1.2' );
    ok( near( $c, 0.77 * 1.44 ), 'grows x1.2 again' );
    ok( $st{'type'} eq 'plain', 'state keeps the type' );
}
{
    my %st;
    ok( near( $next->( { type => 'fast', state => \%st } ), 0.07 ),
        'per type start 0.07' );
}

## cap : jittered, bounded, reached, never exceeded ##
{
    my ( @caps, $bad );
    for ( 1 .. 25 ) {
        my %st;
        my $last = 0;
        my $v;
        $v = $next->( { type => 'capped', state => \%st } ) for 1 .. 60;
        push @caps, $v;
        $bad++ if $v < 10 or $v > 12.0000001;
    }
    ok( !$bad, 'cap within [ cap, cap + jitter ]' );
    my %u = map { $_ => 1 } @caps;
    ok( keys %u > 5, 'cap jitter varies between timers' );
    my %st;
    my @s    = map { $next->( { type => 'capped', state => \%st } ) } 1 .. 60;
    my $mono = 1;
    $s[$_] < $s[ $_ - 1 ] - 1e-9 and $mono = 0 for 1 .. $#s;
    ok( $mono,                  'never shrinks while growing' );
    ok( near( $s[-1], $s[-2] ), 'holds at the cap' );
}

## reset ##
{
    my %st;
    $next->( { type => 'plain', state => \%st } ) for 1 .. 8;
    my $grown = $st{'last'};
    my $v     = $next->( { type => 'plain', state => \%st, reset => TRUE } );
    ok( $grown > 0.77 * 2, 'grown before reset' );
    ok( near( $v, 0.77 ),  'reset returns to start' );
}

## pairs ##
{
    my %st;
    my @s = map { $next->( { type => 'pairs', state => \%st } ) } 1 .. 6;
    ok( near( $s[0], 0.19 ) && near( $s[1], 0.13 ),
        'pair : interval, then distance' );
    ok( near( $s[2], 0.19 * 1.13 ) && near( $s[3], 0.13 ),
        'pair : interval grows per group' );
    ok( near( $s[4], 0.19 * 1.13**2 ) && near( $s[5], 0.13 ),
        'pair : third group' );
}

## 13 filter ##
SKIP: {
    if ( not $real_truth ) {
        ok( 1, 'filter tests skipped [ no Truth module ]' );
        last SKIP;
    }
    my ( $nudged, $passing, $total ) = ( 0, 0, 0 );
    for my $round ( 1 .. 200 ) {
        my %st;
        for ( 1 .. 12 ) {
            my $v = $next->( { type => 'harm', state => \%st } );
            $total++;
            my $ms = sprintf '%d', $v * 1000 + 0.5;
            $passing++ if $harmony->($ms);
        }
    }
    ok( $passing > $total * 0.96,
        "produced values pass the filter [ $passing / $total ]" );

    ## bounded : a harmony that always fails costs at most 14 calls ##
    my $n = 0;
    set_is_true( sub { $n++; return FALSE } );
    my %st;
    my $v = $next->( { type => 'harm', state => \%st } );
    ok( $n <= 27 && $n > 1,
        "always failing filter stays bounded [ $n calls ]" );
    ok( near( $v, 0.77 ), 'unfiltered value used when nothing passes' );
    set_is_true($real_is_true);

    ## nudge is small : failing value moves up a few steps ##
    my $first = 0;
    set_is_true( sub { return ++$first > 3 ? TRUE : FALSE } );
    my %st2;
    my $w = $next->( { type => 'harm', state => \%st2 } );
    ok( abs( $w - 0.77 ) < 0.77 * 0.13 + 0.001, "nudge is small [ $w ]" );
    set_is_true($real_is_true);
}

## golden-blink ##
{
    my %st;
    my @s = map { $next->( { type => 'blink', state => \%st } ) } 1 .. 6;
    ok( near( $s[0], 1.274 ) && near( $s[2], 1.274 ), 'blink : on delays' );
    ok( near( $s[1], 1.274 / ( ( 1 + sqrt 5 ) / 2 ) ),
        'blink : off = on / phi' );
    ok( $s[1] > 0.78         && $s[1] < 0.79, 'blink : off about 787 ms' );
    ok( near( $s[1], $s[3] ) && near( $s[4], $s[0] ), 'blink : alternates' );
    my $r = $next->( { type => 'blink', state => \%st, reset => TRUE } );
    ok( near( $r, 1.274 ), 'blink : reset starts with on' );
    my %st2;
    my @o = map { $next->( { type => 'blink2', state => \%st2 } ) } 1 .. 2;
    ok( near( $o[0], 1.274 ) && near( $o[1], 0.769 ),
        'blink : explicit on \ off' );
    my %st3;
    my @p = map { $next->( { type => 'blink3', state => \%st3 } ) } 1 .. 2;
    ok( near( $p[0], 0.5 ) && near( $p[1], 0.5 / ( ( 1 + sqrt 5 ) / 2 ) ),
        'blink : explicit on only derives off' );
}

## human scale : never 600 s ##
{
    my ( $bad, $min, $max ) = ( 0, 1e9, 0 );
    for ( 1 .. 300 ) {
        my %st;
        my $v = $next->( { type => 'idle10', state => \%st } );
        $bad++ if abs( $v - 600 ) < 0.0005;
        $min = $v if $v < $min;
        $max = $v if $v > $max;
    }
    ok( !$bad,      'minutes = 10 never produces 600 s' );
    ok( $min > 630, 'minutes = 10 is treated as 13 minutes' );
    my %st;
    my $v = $next->( { type => 'idle13', state => \%st } );
    ok( $v > 780 * 0.94 && $v < 780 * 1.06, "13 minutes with jitter [ $v ]" );
    ok( $v != 780,                          '13 minutes not exactly round' );
    ## the guard itself : a rhythm that returns 600 ##
    $code{'base.interval.rhythm.fixed600'} = sub {600};
    $data{'base'}{'interval'}{'cfg'}{'type'}{'six'}
        = { rhythm => 'fixed600' };
    my %st6;
    ok( $next->( { type => 'six', state => \%st6 } ) != 600,
        'a rhythm returning 600 s is guarded' );
}

## fallback + bad input ##
{
    my %st;
    ok( near( $next->( { type => 'nosuch', state => \%st } ), 0.77 ),
        'unknown rhythm falls back to non-linear' );
    ok( abs( $next->( { type => 'unconfigured', state => {} } ) - 0.77 )
            < 0.1,
        'unconfigured type uses defaults'
    );
    my $before = $warned;
    ok( !$next->( { type => 'plain' } ), 'missing state refused' );
    ok( !$next->('x'),                   'non hash refused' );
    ok( $warned >= $before + 2,          'refusals are logged' );
}

say "# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,.,,,.,,,...,,,.,,..,.,.,..,,,.,,,..,,,,,..,,...,...,...,.,.,,.,,,.,,,,.,
#VXSJWO45YAMLP5KVOM6TZGOEBWTU2DUJMZE3SWDHYEXOYVGYNKJLDGL5V7HZM3KO4KFAZLYQZCW7E
#\\\|2RVDTZRJ2BYDWOFRVI6DMRQW7HKHVMTGRYSL5TBUJZUD2GYNR5D \ / AMOS7 \ YOURUM ::
#\[7]TRMD357BK2WKRCDIFDQA4ZYGZXJU6JSAX2UQHIT6T34IJ3QKSIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
