#!/usr/bin/perl
## format-code -r [ concat rejoin ] : standalone regression harness       ##
###                                                                          ###

##   exercises the REAL bin/format-code binary against tiny throwaway       ##
##   snippets in a File::Temp dir -- nothing in the repo is touched. step   ##
##   0 rejoins a '.'-concatenation of quoted strings and re-splits it       ##
##   only when needed. a chain on ONE physical line                         ##
##   [ a later reflow pulled a split back together ] is rejoined only       ##
##   when every joint sits at whitespace -- format-code's own split         ##
##   points. a joint inside a word or marker is deliberate and stays        ##
##   [ 2026-10-29 ]                                                         ##
##                                                                          ##
##   -n keeps perltidy out so exact-line comparison stays deterministic.    ##

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

##[ snippet template : strict + my [ $x, $src ] so a lost escape is a        ]##
##[ compile error in the output file                                        ]##
sub snippet {
    my $statement = shift;
    return join( "\n",
        '#!/usr/bin/perl', 'use strict;',
        'use warnings;',
        'my ( $x, $src ) = ( q!a!, q!b! );',
        $statement, '' );
}

##[ cases : [ name, statement, exact expected output line ] ]#################
my @cases = (
    [   'one line, joint at whitespace : rejoined',
        q!$x = 'issuer not ' . 'valid';!,
        q!$x = 'issuer not valid';!,
    ],
    [   'one line, joint at a leading space : rejoined',
        q!$x = 'cannot strip' . ' ./%s';!,
        q!$x = 'cannot strip ./%s';!,
    ],
    [   'one line, three fragments at whitespace : rejoined',
        q!$x = 'a ' . 'b ' . 'c';!,
        q!$x = 'a b c';!,
    ],
    [   'joint inside a marker : deliberate, unchanged',
        q!$x = 'pm-src.' . 'X';!,
        q!$x = 'pm-src.' . 'X';!,
    ],
    [   'joint inside the module header marker : deliberate, unchanged',
        q!$x = '## [' . ':< ##';!,
        q!$x = '## [' . ':< ##';!,
    ],
    [   'mixed quote chars : unchanged',
        q!$x = 'a ' . "b";!,
        q!$x = 'a ' . "b";!,
    ],
);

say ': format-code -r concat rejoin cases';

my $case_num = 0;
foreach my $case_ref (@cases) {
    my ( $name, $statement, $expected ) = @$case_ref;
    $case_num++;

    my $path
        = File::Spec->catfile( $work_dir, sprintf 'case-%d.pl', $case_num );
    open( my $write_fh, '>', $path )
        or die "cannot write $path : $OS_ERROR";
    print {$write_fh} snippet($statement);
    close($write_fh);

    my $run_log = `$format_code -r -n $path 2>&1`;
    my $run_rc  = $CHILD_ERROR >> 8;

    open( my $read_fh, '<', $path )
        or die "cannot read back $path : $OS_ERROR";
    my @out_lines = map { my $l = $_; $l =~ s|\s+$||; $l } <$read_fh>;
    close($read_fh);

    my ($got) = grep { index( $_, q!$x = ! ) == 0 } @out_lines;
    $got //= '<statement line not found>';

    ok( $run_rc == 0,                      "$name [ format-code exit 0 ]" );
    ok( defined $got && $got eq $expected, "$name [ got : $got ]" );

    my $compile_out = `perl -c $path 2>&1`;
    ok( $CHILD_ERROR == 0, "$name [ output compiles under strict ]" );
}

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,..,,,,,,.,.,,.,,..,,,,.,.,,,.,.,.,.,,,,,.,.,...,..,,.,.,,.,,,,.,,.,,,.,,
#PHCBAJQBMPPXL5NRWSKU45VVH22YVP2VU4K4UVJNLM3TXDQQDXH2FAENCF63SSXNBZ3JEPKARYHZA
#\\\|ROVNNZBPECIJUWNMCTSDLWKO3VA5EPCSAQDHFCCASOJCU6UCHT6 \ / AMOS7 \ YOURUM ::
#\[7]VMS6B7WKWDO3XESOL3E5HR42PNKBSJGRLEXQKHVBL3FPJ2O3FSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
