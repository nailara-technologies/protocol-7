#!/usr/bin/perl
## format-code -m [ module call sugar ] pass : standalone regression ##
## harness                                                           ##
###                                                                          ###

##   exercises the REAL bin/format-code binary against tiny throwaway       ##
##   snippets in a File::Temp dir -- nothing in the repo is touched. the    ##
##   -m pass [ step7_compact_module_call_sugar , bin/format-code ]          ##
##   rewrites literal-key $code{'a.b'}->(...) to <[a.b]>->(...)             ##
##                                                                          ##
##   known regression [ fixed 2026-10-20 ] : the subscript scan used a      ##
##   recursive PPI find() for quote tokens and merely counted them --       ##
##   $code{ $on_done->{'handler'} } contains exactly ONE quote token ,      ##
##   nested inside $on_done's own subscript , and was misread as a          ##
##   literal key : the dynamic dispatch got rewritten to the hardcoded      ##
##   <[handler]> , silently dropping the vital variable part                ##
##                                                                          ##
##   every dynamic-key case below must come back byte-identical             ##
##                                                                          ##
##   -n keeps perltidy out so exact-line comparison stays deterministic.    ##
##   the snippets carry the real P7 module header [ '## [:< ##' ] : the    ##
##   -m pass is gated on is_p7_module_text and stays a no-op without it     ##

use v5.24;
use strict;
use warnings;
use English;
use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $main::root_path = $root_path;
}

my $format_code
    = File::Spec->catfile( $main::root_path, 'bin', 'format-code' );
my $work_dir   = tempdir( CLEANUP => 1 );
my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ snippet template : P7 module header so the -m gate engages ]##############
sub snippet {
    my $statement = shift;
    return join( "\n",
        '## [:< ##',
        'use v5.24;',
        'use strict;',
        'use warnings;',
        'my ( $call_params, $name, $p, $q, '
            . '$handler_name, $on_done, $done ) = ();',
        $statement,
        '' );
}

##[ cases : [ name, statement, exact expected output line ] ]#################
my @cases = (
    [   'dynamic key via nested subscript [ the regression ] stays untouched',
        q{$code{ $on_done->{'handler'} }->($call_params);},
        q{$code{ $on_done->{'handler'} }->($call_params);},
    ],
    [   'dynamic key with double-quoted inner key stays untouched',
        q{$code{ $done->{"handler"} }->( $done->{'params'} // {} );},
        q{$code{ $done->{"handler"} }->( $done->{'params'} // {} );},
    ],
    [   'plain scalar key stays untouched',
        q{$code{$handler_name}->($call_params);},
        q{$code{$handler_name}->($call_params);},
    ],
    [   'literal dotted module key gets the sugar',
        q|$code{'host-edit.flow.step'}->($name);|,
        q|<[host-edit.flow.step]>->($name);|,
    ],
    [   'literal key with an empty arg list drops ->()',
        q|$code{'a.b'}->();|, q|<[a.b]>;|,
    ],
    [   'literal key with args keeps the arg list verbatim',
        q|$code{'a.b'}->( $p, $q );|,
        q|<[a.b]>->( $p, $q );|,
    ],
);

say ': format-code -m module-sugar cases';

my $case_num = 0;
foreach my $case_ref (@cases) {
    my ( $name, $statement, $expected ) = @$case_ref;
    $case_num++;

    my $path = File::Spec->catfile( $work_dir, sprintf 'case-%d', $case_num );
    open( my $write_fh, '>', $path )
        or die "cannot write $path : $OS_ERROR";
    print {$write_fh} snippet($statement);
    close($write_fh);

    my $run_log = `$format_code -m -n $path 2>&1`;
    my $run_rc  = $CHILD_ERROR >> 8;

    open( my $read_fh, '<', $path )
        or die "cannot read back $path : $OS_ERROR";
    my @out_lines = map { my $l = $_; $l =~ s|\s+$||; $l } <$read_fh>;
    close($read_fh);

    my ($got)
        = grep { index( $_, q{$code} ) == 0 or index( $_, q{<[} ) == 0 }
        @out_lines;
    $got //= '<statement line not found>';

    ok( $run_rc == 0,                      "$name [ format-code exit 0 ]" );
    ok( defined $got && $got eq $expected, "$name [ got : $got ]" );
}

say '';
if ($fail_count) {
    say "RESULT : $fail_count failure(s)";
    exit 1;
}
say 'RESULT : all cases pass';
exit 0;

#,,,,,,..,.,.,..,,,.,,,,.,,,,,,,,,,.,,,,.,...,..,,...,..,,..,,...,,.,,,,,,.,.,
#MCE53I3KXRMI3OPYCFRA2QV6IILHTRKLK53G2VDQWULTTO426D3FSXSPK3ZWMPYZW3XRN52KRUKR4
#\\\|QBJWM4TLX4YGQPH2XJBP2EOLBF7RMO5PWLYMQYTMALZU6I7LFTF \ / AMOS7 \ YOURUM ::
#\[7]EHNKLLRQPRAIT4IXJQLLVVQNDBO2EPZT4XDPBYQXX6JRTVMSOYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
