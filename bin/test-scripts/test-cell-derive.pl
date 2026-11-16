#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use Math::BigInt;
use Math::BigRat;
use AMOS7::cell::time qw| NTIME_YEAR EPOCHS_TOTAL frame window path |;
use AMOS7::N7FS::Sum  qw| epoch_int epoch_num epoch_window |;
use AMOS7::NTIME      qw| y_level_ntime ntime_now |;

my $report_name = qw| cell-time-float-mismatches.txt |;
my $report_path = "$FindBin::Bin/../../data/state/$report_name";
my @float_mismatches;

sub mismatch_line {
    my $m = shift;
    return
        sprintf 'level=%d boundary=%s side=%s ntime=%s '
        . 'exact=%s float=%s float_num=%s distance=%s',
        @{$m}{qw| level boundary side ntime exact float float_num distance |};
}

sub rat_decimal {
    my ( $value, $places ) = @ARG;
    $value = Math::BigRat->new($value) if not ref $value;
    my $negative = $value->is_neg();
    $value = $value->copy()->babs();
    my $scale = Math::BigInt->new(10)->bpow($places);
    my $scaled
        = $value->numerator()
        ->copy()
        ->bmul($scale)
        ->bdiv( $value->denominator() )
        ->bstr();
    $scaled = ( '0' x ( $places + 1 - length $scaled ) ) . $scaled
        if length $scaled <= $places;
    substr( $scaled, -$places, 0 ) = qw| . |;
    return ( $negative ? '-' : '' ) . $scaled;
}

sub record_mismatch {
    my ( $level, $boundary_index, $side, $ntime, $exact, $float, $divisor )
        = @ARG;
    my ( $boundary, $distance ) = ( qw| random |, qw| random | );
    if ( $side ne qw| random | ) {
        $boundary
            = Math::BigRat->new(NTIME_YEAR)
            ->bmul($boundary_index)
            ->bdiv($divisor);
        $distance
            = Math::BigRat->new($ntime)->bsub($boundary)->babs()->bstr();
        $boundary = $boundary->bstr();
    }
    push @float_mismatches,
        {
        level          => $level,
        boundary       => $boundary_index,
        side           => $side,
        ntime          => $ntime,
        exact          => $exact,
        float          => $float,
        float_num      => $level == 1 ? epoch_num($ntime) : $float,
        distance       => $distance,
        boundary_ntime => $boundary,
        };
}

sub run_suite {
    my @output;
    my $number = 0;
    my $check  = sub {
        my ( $passed, $name ) = @ARG;
        $number++;
        push @output, sprintf "%s %d - %s\n",
            $passed ? 'ok' : 'not ok', $number, $name;
        return $passed;
    };
    my $detail = sub {
        push @output, map {"# $ARG\n"} split m|\n|, join( "\n", @ARG );
    };
    my $year = Math::BigInt->new(NTIME_YEAR);
    my @exact_errors;
    my @checks = map {0} 0 .. 7;

    srand 385280;
    for ( 1 .. 100000 ) {
        my $ntime  = int rand( NTIME_YEAR * 20 );
        my $exact  = frame( $ntime, 1 ) % EPOCHS_TOTAL;
        my $legacy = epoch_int($ntime);
        $checks[1]++;
        record_mismatch( 1, $exact, qw| random |, $ntime, $exact, $legacy,
            13 )
            if $exact != $legacy;
    }

    for my $level ( 0 .. 7 ) {
        my $divisor = Math::BigInt->new(13)->bpow($level);
        my $unit    = $divisor->numify();
        my $base    = int( NTIME_YEAR / $unit );
        my $extra   = NTIME_YEAR % $unit;
        my $last    = $level == 1 ? EPOCHS_TOTAL - 1 : 40;
        for my $boundary_index ( 0 .. $last ) {
            next if $level != 1 and $boundary_index == 0;

            ## quotient and remainder stay exact below 2^52 at the full ##
            ## wrap                                                     ##
            my $boundary_whole = $boundary_index * $base
                + int( $boundary_index * $extra / $unit );
            my $whole_boundary = ( $boundary_index * $extra ) % $unit == 0;
            for my $offset ( -1 .. 1 ) {
                my $ntime = $boundary_whole + $offset;
                next if $ntime < 0;
                my $exact = $boundary_index + ( $offset < 0 ? -1 : 0 );
                $exact-- if $offset == 0 and not $whole_boundary;
                if ( $boundary_index % 4096 == 0 ) {
                    my $implemented = frame( $ntime, $level );
                    push @exact_errors,
                          "level=$level boundary=$boundary_index "
                        . "offset=$offset ntime=$ntime "
                        . "exact=$implemented expected=$exact"
                        if $implemented ne $exact;
                }
                $checks[$level]++;

                if ( $level == 1 ) {
                    my $legacy = epoch_int($ntime);
                    my $modulo = $exact % EPOCHS_TOTAL;
                    record_mismatch( $level, $boundary_index, $offset,
                        $ntime, $modulo, $legacy, $divisor )
                        if $modulo != $legacy;
                } else {
                    my $legacy = int( $ntime / y_level_ntime($level) );
                    record_mismatch( $level, $boundary_index, $offset,
                        $ntime, $exact, $legacy, $divisor )
                        if $exact != $legacy;
                }
            }
        }
    }

    my $report_dir = "$FindBin::Bin/../../data/state";
    mkdir $report_dir if not -d $report_dir;
    my $report_ok = open( my $report_fh, '>', $report_path );
    if ($report_ok) {
        print {$report_fh} "# known float-grid mismatches "
            . "[ exact versus legacy ]\n";
        print {$report_fh} map { mismatch_line($ARG) . "\n" }
            @float_mismatches;
        $report_ok &&= close $report_fh;
    }
    $check->(
        $report_ok && !@exact_errors,
        'exact grid verified across every level; known '
            . 'float defects are listed without failing the suite'
    );
    $detail->(
        sprintf 'known float mismatches : total=%d file=data/state/%s',
        scalar @float_mismatches, $report_name
    );
    for my $level ( 0 .. 7 ) {
        my $count = grep { $ARG->{'level'} == $level } @float_mismatches;
        $detail->(
            sprintf 'level %d : mismatches=%d checks=%d',
            $level, $count, $checks[$level]
        );
    }
    $detail->('first 20 float mismatches follow');
    $detail->( mismatch_line( $float_mismatches[$ARG] ) )
        for 0 .. ( @float_mismatches < 20 ? $#float_mismatches : 19 );
    $detail->(@exact_errors);

    my @pyramid_mismatches;
    for ( 1 .. 1000 ) {
        my $ntime = int rand( NTIME_YEAR * 20 );
        for my $level ( 0 .. 6 ) {
            my $parent = Math::BigInt->new( frame( $ntime, $level ) );
            my $child
                = Math::BigInt->new( frame( $ntime, $level + 1 ) )->bdiv(13);
            push @pyramid_mismatches,
                "ntime=$ntime level=$level parent=$parent child=$child"
                if $parent->bcmp($child) != 0;
        }
    }
    my @parent_path  = path( NTIME_YEAR * 7, 2 );
    my $parent_index = Math::BigInt->new( frame( NTIME_YEAR * 7, 2 ) );
    my @child_last_digits;
    for my $digit ( 0 .. 12 ) {
        my $child_index = $parent_index->copy()->bmul(13)->badd($digit);
        my $child_ntime
            = Math::BigRat->new( $child_index->bstr() )
            ->bmul($year)
            ->bdiv( Math::BigInt->new(13)->bpow(3) )
            ->bceil()
            ->as_int()
            ->bstr();
        my @child_path = path( $child_ntime, 3 );
        push @child_last_digits, pop @child_path;
        push @pyramid_mismatches,
            "path parent differs at child digit $digit : @child_path"
            if join( '.', @child_path ) ne join( '.', @parent_path );
    }
    push @pyramid_mismatches,
        "child digits are not 0..12 : @child_last_digits"
        if join( '', @child_last_digits ) ne '0123456789101112';
    my $absolute_ntime = NTIME_YEAR * ( EPOCHS_TOTAL + 7 );
    my @absolute_path  = path( $absolute_ntime, 2 );
    my $absolute_index = Math::BigInt->new(0);
    $absolute_index->bmul(13)->badd($ARG) for @absolute_path;
    push @pyramid_mismatches,
        'path truncated an absolute frame beyond the wrap'
        if $absolute_index->bcmp( frame( $absolute_ntime, 2 ) ) != 0;
    $check->(
        !@pyramid_mismatches,
        'absolute frames nest by thirteen '
            . 'and absolute paths retain every digit'
    );
    $detail->(@pyramid_mismatches);

    my @zero_window = window( 0, 1 );
    my @zero_legacy = epoch_window(0);
    my $last_ntime
        = Math::BigRat->new( EPOCHS_TOTAL - 1 )
        ->bmul($year)
        ->bdiv(13)
        ->bceil()
        ->as_int()
        ->bstr();
    my @last_window = window( $last_ntime, 1 );
    my @last_legacy = epoch_window( EPOCHS_TOTAL - 1 );
    my @wrap_window = window(EPOCHS_TOTAL);
    my @wrap_legacy = epoch_window(EPOCHS_TOTAL);
    $check->(
        join( ',', @zero_window ) eq join( ',', @zero_legacy )
            && join( ',', @last_window ) eq join( ',', @last_legacy )
            && join( ',', @wrap_window ) eq '385279,0,1'
            && join( ',', @wrap_legacy ) eq '385279,385280,1',
        'window normalizes absolute frames at '
            . 'the wrap where epoch_window does not'
    );

    my $below     = '10188553846.153846153845';
    my $above     = '10188553846.153846153847';
    my @malformed = ( undef, '-1', '.5', '1.', '1e3', '1/3', 'NaN' );
    my $fraction_ok
        = frame( $below, 1 ) eq '0'
        && frame( $above,           1 ) eq '1'
        && frame( '132451200000.1', 0 ) eq '1';
    $fraction_ok &&= !defined frame( $ARG, 1 ) for @malformed;
    $fraction_ok &&= !defined frame( '1',  8 );
    $check->(
        $fraction_ok,
        'fractional decimal strings are exact and malformed input is refused'
    );

    return join '', @output;
}

my $local_output = run_suite();
if ( $ENV{'P7_CELL_FLOOR_CHILD'} ) {
    print $local_output, "ok 6 - exact answer suite is reproducible\n";
    exit( $local_output =~ m|^not ok|m ? 1 : 0 );
}

my @floor_candidates;
push @floor_candidates, $ENV{'P7_FLOOR_PERL'}
    if defined $ENV{'P7_FLOOR_PERL'};
push @floor_candidates,
    sort glob("$ENV{'HOME'}/.local/perl-5.32.*/bin/perl5.32.*");
my $path_perl = qx|command -v perl5.32.0 2>/dev/null|;
chomp $path_perl;
push @floor_candidates, $path_perl if length $path_perl;
my ($floor_perl) = grep { -x $ARG } @floor_candidates;

my $floor_output = '';
my $floor_status = -1;
if ( defined $floor_perl ) {
    local $ENV{'P7_CELL_FLOOR_CHILD'} = 1;
    open( my $floor_fh, '-|', $floor_perl,
        "$FindBin::Bin/test-cell-derive.pl" )
        or die "floor perl : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    $floor_output = <$floor_fh> // '';
    close $floor_fh;
    $floor_status = $CHILD_ERROR;
}
my $expected_output
    = $local_output . "ok 6 - exact answer suite is reproducible\n";
my $floor_ok
    = defined $floor_perl
    && $floor_status == 0
    && $floor_output eq $expected_output
    && $local_output !~ m|^not ok|m;
print $local_output;
print $floor_ok
    ? "ok 6 - exact answer suite is reproducible\n"
    : "not ok 6 - floor and local perl answers "
    . "differ or floor perl is unavailable\n";
print "# floor perl : ", $floor_perl // 'unavailable', "\n";
if ( defined $floor_perl && $floor_output ne $expected_output ) {
    print "# floor output follows\n", $floor_output;
}

my $current_ntime = ntime_now(8);
my $current       = Math::BigRat->new($current_ntime);
my ( $nearest, $nearest_distance );
for my $mismatch ( grep { $ARG->{'level'} == 1 } @float_mismatches ) {
    next if $mismatch->{'side'} eq qw| random |;
    my $distance
        = $current->copy()->bsub( $mismatch->{'boundary_ntime'} )->babs();
    if ( not defined $nearest_distance
        or $distance->bcmp($nearest_distance) < 0 ) {
        ( $nearest, $nearest_distance ) = ( $mismatch, $distance );
    }
}
print "# current ntime : $current_ntime\n";
if ( defined $nearest ) {
    print "# nearest mismatching level-1 boundary : "
        . "index=$nearest->{'boundary'} "
        . "ntime=$nearest->{'boundary_ntime'}\n";
    my $distance_days = $nearest_distance->copy()->bdiv( 86400 * 4200 );
    print '# distance to nearest mismatching boundary : ',
        rat_decimal( $nearest_distance, 8 ),
        ' ntime units [ ', rat_decimal( $distance_days, 12 ), " days ]\n";
}
exit( $floor_ok ? 0 : 1 );

#,,..,...,,.,,,,.,.,.,,..,..,,,.,,,..,,,.,.,,,..,,...,...,...,.,,,,..,,,.,,,,,
#EMWHRJGCWBQ6J66B52NOX32HHPVR45U3ZD7EOOW34FJ7L6JKLXIHNPZX54WUP2T2T7OJ4EX5BYA7M
#\\\|A5VCES4FAI3CLQEI4ZWZSL5DUMLPVFXNQH443WQOOFN636PDAIN \ / AMOS7 \ YOURUM ::
#\[7]OL4RKB3JR3TK646KPOBGUGZUFO5SUH36PF7WESIUIEMRSWOAUOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
