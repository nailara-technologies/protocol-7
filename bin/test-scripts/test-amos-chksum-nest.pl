#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

## Test amos-chksum -nest truth harmonization  Tests: bracketed [child:parent]
## notation passes is_true on the full string, bare child:parent form [
## brackets stripped, e.g. terminal  double-click copy-paste ] passes is_true
## independently,  verify_nesting round-trip, parse_nested, reconstruct_chain

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use English;
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use English;
use AMOS7;
use AMOS7::CHKSUM;
use AMOS7::CHKSUM::Nested;
use AMOS7::Assert::Truth;

my $tests_run    = 0;
my $tests_passed = 0;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
        say sprintf( '[ ok ] %s', $label );
    } else {
        say sprintf( '[ FAIL ] %s', $label );
    }
    return $condition;
}

say '';
say '=== testing amos-chksum -nest truth harmonization ===';
say '';

##[ arbitrary parent \ child pairs ]##
##
my @input_pairs = (
    [qw| LOVES SWEETIE   |], [qw| PROTOCOL SEVEN  |],
    [qw| AMOS TRUTH      |], [qw| alpha beta      |],
    [qw| gamma delta     |],
);

foreach my $pair (@input_pairs) {
    my ( $parent_in, $child_in ) = $pair->@*;

    my $parent_chksum = amos_chksum($parent_in);
    my $child_name    = amos_chksum( join( ' ', $parent_in, $child_in ) );

    my $child_chksum = child_chksum( $parent_chksum, $child_name );
    my $notation     = format_nested( $child_chksum, $parent_chksum );

    check( sprintf( '%s : full notation is_true', $notation ),
        is_true( $notation, 0, 1, 4, 7 ) );
    check(
        sprintf( '%s : bare notation is_true [ brackets stripped ]',
            $notation ),
        is_true(
            sprintf( '%s:%s', $child_chksum, $parent_chksum ),
            0, 1, 4, 7
        )
    );
    check( sprintf( '%s : child alone is_true', $notation ),
        is_true( $child_chksum, 0, 1, 4, 7 ) );
    check(
        sprintf( '%s : verify_nesting round-trip', $notation ),
        verify_nesting( $notation, $parent_chksum, $child_name )
    );

    my $parsed = parse_nested($notation);
    check(
        sprintf( '%s : parse_nested', $notation ),
        (           defined $parsed
                and $parsed->{'child'} eq $child_chksum
                and $parsed->{'parent'} eq $parent_chksum
        )
    );

    my $chain = reconstruct_chain($notation);
    check(
        sprintf( '%s : reconstruct_chain', $notation ),
        ( defined $chain and $chain->@* == 1 )
    );
}

##[ invalid input handling ]##
##
check( 'empty parent returns undef',
    not defined child_chksum( '', qw| child | ) );
check( 'empty child name returns undef',
    not defined child_chksum( qw| PKHKHVA |, '' ) );
check( 'malformed notation rejected',
    not defined parse_nested(qw| [not-valid] |) );
check(
    'verify_nesting false on wrong child name',
    not verify_nesting(
        qw| [NUFY2TI:PKHKHVA] |,
        qw| PKHKHVA |, qw| OTHERNAME |
    )
);

say '';
say sprintf( '=== %d of %d tests passed ===', $tests_passed, $tests_run );
say '';

exit( $tests_passed == $tests_run ? 0 : 1 );

#,,,.,,,,,,,,.,,,.,,,,,,.,,,,,,,,,,,,,,,,,,.,,,,,,,,,.,,,,,,,,,,,,,,,,,.,,,,,,,,
#AMOS7-TEST-SCRIPT-SIGNATURE-PLACEHOLDER-REGENERATED-BY-VC-COMMIT-TOOLING-000000
#\\\|TESTAMOSCHKSUMNESTTRUTHHARMONIZATIONREGRESSIONSCRIPT \ / AMOS7 \ YOURUM ::
#\[7]TESTAMOSCHKSUMNESTTRUTHHARMONIZATIONREGRESSIONSCRIPT0 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#,,.,,.,,,.,.,,.,,...,.,,,.,.,,.,,..,,.,.,.,.,..,,...,...,..,,,,,,.,.,,.,,,,,,
#7YV5ETFZWF6ETG5TOZ6FJRA3B57EMVZQJZS5IR3KNKVUH3XBHD6SGJS4MWGUOXLPV6OOP4BXCX2EI
#\\\|X6FU4O7TYKJSLLCGMIUYV34MRYQBTZDGYZ5WXFTEKHJNNO3UOA6 \ / AMOS7 \ YOURUM ::
#\[7]7JXW4GLJ4XK5VZCZ54NTYEUUDC6MSP6PPDG4KHASSUH4UMYW4SBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
