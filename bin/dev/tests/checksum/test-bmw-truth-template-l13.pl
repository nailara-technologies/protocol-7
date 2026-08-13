#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

## test base.chk-sum.bmw.truth_template_L13
## verifies AMOS7::TEMPLATE multi-template validation delegates
## correctly through the harmonize_L13 chokepoint

BEGIN {
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->catdir( $RealBin, $up_dir, $up_dir, $up_dir, $up_dir ) );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use AMOS7::Assert::Truth qw| is_true |;
use AMOS7::TEMPLATE;
use Crypt::Misc qw| encode_b32r |;
use Digest::BMW;
use Time::HiRes;

use constant TRUE => 5;

##[ new harmonize_L13 loaded from module file ]###############################

my $module_root
    = abs_path( File::Spec->catdir( $RealBin, ( File::Spec->updir ) x 4 ) );

my $helper_path = File::Spec->catfile( $module_root,
    qw| modules base.chk-sum.bmw.harmonize_L13 | );

open( my $HFH, qw| < |, $helper_path )
    or die "cannot read $helper_path : $!";
my $helper_src = do { local $/; <$HFH> };
close($HFH);

## strip header comments and signature footer ##
$helper_src =~ s|^\s*##\s*\[:<\s*##\s*\n||;
$helper_src =~ s|\n#,,.*\z||s;

## wrap in sub ##
my $harmonize_L13 = eval "sub {\n$helper_src\n}";
die "helper compile error: $@" if $@;

##[ new truth_template_L13 loaded from module file ]###########################

my $tt_path = File::Spec->catfile( $module_root,
    qw| modules base.chk-sum.bmw.truth_template_L13 | );

open( my $TTFH, qw| < |, $tt_path )
    or die "cannot read $tt_path : $!";
my $tt_src = do { local $/; <$TTFH> };
close($TTFH);

$tt_src =~ s|^\s*##\s*\[:<\s*##\s*\n||;
$tt_src =~ s|\n#,,.*\z||s;

## replace P7 call with direct helper call [ short alias form -- the actual  ##
## call site in the module, NOT the long <[base.chk-sum.bmw...]> form ]     ##
$tt_src =~ s|<\[chk-sum\.bmw\.harmonize_L13\]>->\(|\$harmonize_L13->(|g;

my $truth_template_L13 = eval "sub {\n$tt_src\n}";
die "truth_template_L13 compile error: $@" if $@;

##[ tests ]#####################################################################

my $tests_run    = 0;
my $tests_passed = 0;
my $tests_failed = 0;

sub ok {
    my ( $cond, $desc ) = @ARG;
    $tests_run++;
    if ($cond) {
        $tests_passed++;
        print "  ok - $desc\n";
    } else {
        $tests_failed++;
        print "  not ok - $desc\n";
    }
}

print "\n=== BMW L13 truth_template_L13 tests ===\n\n";

## [1] basic sprintf template ##

print "[1] basic sprintf template pass\n";

my $r1 = $truth_template_L13->( 'PFX:%s', 'data' );

## is_true returns ( TRUE, @assertion_modes ) in list context -- force  ##
## scalar context here so ok()'s argument list isn't spliced with extra ##
## trailing elements                                                    ##
my $r1_ok = defined $r1
    && length($r1) == 13
    && scalar is_true( sprintf( 'PFX:%s', $r1 ), 0, 1 );
ok( $r1_ok,
    "sprintf 'PFX:%s' result satisfies is_true( sprintf(...), 0, 1 )"
);

## [2] ARRAY of mixed sprintf + Regexp + CODE templates ##

print "\n[2] ARRAY of mixed sprintf + Regexp + CODE templates\n";

my $code_calls = 0;
my $r2         = $truth_template_L13->(
    [ 'X:%s', qr/^[2-9A-Z]{13}$/, sub { $code_calls++; return 1 } ],
    'mixed', 'templates'
);
ok( defined $r2 && length($r2) == 13 && $code_calls > 0,
    "ARRAY of sprintf+Regexp+CODE templates all satisfied" );

## [3] exclusion callback via configure_exclusive_type_callback ##

print "\n[3] exclusion-hashref via CALLBACK_exclusive_type\n";

AMOS7::TEMPLATE::template_timeout(10);    ## exclusion mode needs headroom ##
AMOS7::TEMPLATE::configure_exclusive_type_callback(
    ['ALPHA'], [qw| ALPHA BETA GAMMA |], ['excl:%%s:%s']
);
my $r3 = $truth_template_L13->(
    [ 'Q:%s', \&AMOS7::TEMPLATE::CALLBACK_exclusive_type ],
    'excl', 'test'
);
AMOS7::TEMPLATE::reset_temp_valid_timeout();
AMOS7::TEMPLATE::reset_all_callbacks();

my $r3_incl_ok = defined $r3 && is_true( sprintf( 'Q:%s', $r3 ), 0, 1 );
my $r3_excl_ok
    = defined $r3
    && !is_true( sprintf( 'excl:%s:BETA',  $r3 ), 0, 1 )
    && !is_true( sprintf( 'excl:%s:GAMMA', $r3 ), 0, 1 );
ok( $r3_incl_ok && $r3_excl_ok,
    "result satisfies inclusion template AND fails every inverted exclusion template"
);

## [4] unsatisfiable template times out ##

print "\n[4] unsatisfiable regex template (impossible length) times out\n";

AMOS7::TEMPLATE::template_timeout(0.5);
my $t0 = Time::HiRes::time;
my $r4 = $truth_template_L13->( qr/^.{20}$/, 'never', 'matches' );
my $elapsed = Time::HiRes::time - $t0;
AMOS7::TEMPLATE::reset_temp_valid_timeout();

ok( !defined $r4 && $elapsed < 2,
    "unsatisfiable template returns undef within template_timeout" );

## [5] invalid template param returns undef, no state leak ##

print "\n[5] invalid template param type returns undef, resets state\n";

my $r5 = $truth_template_L13->( { not => 'a valid template type' }, 'x' );
ok( !defined $r5 && AMOS7::TEMPLATE::template_count() == 0,
    "unsupported ref type returns undef, no leaked template state" );

## [6] empty-string template ('' -> zero templates) returns undef ##

print "\n[6] empty template param returns undef, resets state\n";

my $r6 = $truth_template_L13->( '', 'x' );
ok( !defined $r6 && AMOS7::TEMPLATE::template_count() == 0,
    "empty template param (zero templates assigned) returns undef" );

## [7] missing input params after valid template returns undef, resets state ##

print "\n[7] missing input params returns undef, resets state\n";

my $r7 = $truth_template_L13->('%s');
ok( !defined $r7 && AMOS7::TEMPLATE::template_count() == 0,
    "no input params returns undef, template state reset" );

## summary ##

print "\n" . "=" x 50 . "\n";
print "tests run:    $tests_run\n";
print "tests passed: $tests_passed\n";
print "tests failed: $tests_failed\n";
print "=" x 50 . "\n\n";

exit( $tests_failed > 0 ? 1 : 0 );

#,,.,,..,,.,.,.,,,.,,,.,.,,.,,,,,,,..,.,,,,,,,..,,...,...,..,,,,.,,,,,,,.,,,,,
#APUF4NXMKLIYYXMWUAURFXYAPMGXL2CO2PIWLKVPE3AUEMXEQK3EAXTDVCYFR6U5PJ26J3FHFUQSO
#\\\|C3Y7KZKJZDPENCZOLDCDWECM77SZ65IEVB4447P37VKIEUHFR3Z \ / AMOS7 \ YOURUM ::
#\[7]GYWCTTXPZUQN53ZBAF2AX5TMVOWKIFMN54JQSH63OUPAGOHPHWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
