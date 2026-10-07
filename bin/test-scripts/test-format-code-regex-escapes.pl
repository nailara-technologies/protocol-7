#!/usr/bin/perl
## format-code -r [ regex delimiter ] pass : standalone regression harness  ##
###                                                                          ###

##   exercises the REAL bin/format-code binary against tiny throwaway       ##
##   snippets in a File::Temp dir -- nothing in the repo is touched. the    ##
##   -r pass [ step9_normalize_regex_delimiters \ transform_regex_body,     ##
##   bin/format-code ~line 1898-2300 ] rewrites m/../ s/../../ =~ /../ to   ##
##   | or {} delimiters and drops escapes that only existed for the old     ##
##   '/'. the known regression : it also used to drop '\@' [ '@'            ##
##   interpolates -- fixed 2026-10-07 ] :                                   ##
##                                                                          ##
##   s/\@ARG/\@_/g  must become  s|\@ARG|\@_|g   [ NEVER s|@ARG|@_|g ]      ##
##                                                                          ##
##   every output file must also survive `perl -c` : the snippets use       ##
##   strict with my [ $x, $src ], so a dropped escape becomes a compile     ##
##   error.                                                                 ##
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
        'my ( $x, $src ) = ( q!a/b!, q!input! );',
        $statement, '' );
}

##[ cases : [ name, statement, exact expected output line ] ]#################
my @cases = (
    [   's/\@ARG/\@_/g keeps the \@ escape [ the regression ]',
        q!$src =~ s/\@ARG/\@_/g;!,
        q!$src =~ s|\@ARG|\@_|g;!,
    ],
    [   'm/a\/b/ : delimiter-only escape dropped under |',
        q!$x = m/a\/b/;!,
        q!$x = m|a/b|;!,
    ],
    [   'm/\$x\d+/ : \$ and \d survive the delimiter switch',
        q!$x = m/\$x\d+/;!,
        q!$x = m|\$x\d+|;!,
    ],
    [   'm/[\w\-_.]/ : \- inside a character class survives',
        q!$x = m/[\w\-_.]/;!,
        q!$x = m|[\w\-_.]|;!,
    ],
    [   'literal pipe escalates the delimiters to {} [ \| escape kept ]',
        q!$x = m/a\|b/;!,
        q!$x = m{a\|b};!,
    ],
    [   'm/a b/x : /x is skipped, line left unchanged',
        q!$x = m/a b/x;!,
        q!$x = m/a b/x;!,
    ],
);

say ': format-code -r regex-delimiter cases';

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

    my ($got)
        = grep { index( $_, '$x = m' ) == 0 or index( $_, '$src =~ s' ) == 0 }
        @out_lines;
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

#,,,,,,,.,...,,..,...,..,,.,,,...,..,,...,,,.,..,,...,...,.,,,.,,,,.,,,..,.,,,
#FJEHLUVBJDHBQEIS6C2DNPJCYUJDHULASJ4R4QR7ZFJ6ND7ALGRTNOJHWCGEQRLCIEK7XQYRTE4GI
#\\\|LFGKEBSYDBJRCM4YLK3IPV6GXWB3QFPCNPLNT5VGUTOQBCACGH4 \ / AMOS7 \ YOURUM ::
#\[7]5L6DKSF36AXDX6RK75L3KENOTK6DDBZ46CXOVIWFBVRAQN4LSIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
