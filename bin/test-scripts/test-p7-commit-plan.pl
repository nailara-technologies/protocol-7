#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

##     Test bin/dev/p7-commit-plan -- the automatic requirement chain     ##
##                                                                        ##
##     1. <[call]> extraction + set-diff fixtures                         ##
##     2. footer-insensitive compare                                      ##
##     3. porcelain classification in a throwaway git repo                ##
##     4. build_steps : each rule maps to its step                        ##
##     5. read-only run on the REAL tree : parses, changes nothing        ##

use English;
use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;

my $up_dir    = File::Spec->updir;
my $root_path = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up_dir, $up_dir ) ) );
my $tool_path = abs_path(
    File::Spec->catdir( $root_path, qw| bin dev p7-commit-plan | ) );

##  the pure parts load without running main [ main() if not caller ]  ##
my $loaded = do $tool_path;
die sprintf ':: cannot load %s : %s', $tool_path,
    $EVAL_ERROR // $OS_ERROR // 'unknown'
    if not $loaded;

my $tests_run    = 0;
my $tests_passed = 0;
my @failures;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
    } else {
        push( @failures, $label );
        say sprintf '[ FAIL ] %s', $label;
    }
    return $condition;
}

sub git_in {
    my ( $dir, @args ) = @ARG;
    open( my $fh, '-|', qw| git -c color.ui=false -C |, $dir, @args )
        or return '';
    local $INPUT_RECORD_SEPARATOR;
    my $out = <$fh> // '';
    close $fh;
    return $out;
}

##[ 1 : <[call]> extraction + set diff ]######################################

my $src_before = <<'EOT';
## [:< ##
# name  = base.alpha
<[base.logs]>->( 0, 'message' );
my $result = <[base.chk-sum.bmw.ctx]>->();
call_twice <[base.logs]>;
EOT

my $src_after = <<'EOT';
## [:< ##
# name  = base.alpha
<[base.logs]>->( 0, 'message' );
my $result = <[base.chk-sum.elf.ctx]>->();
EOT

check( 'call_refs finds sorted unique names',
    join( ' ', call_refs($src_before) ) eq 'base.chk-sum.bmw.ctx base.logs' );
check( 'variable form <[$var]> is not a call ref',
    ( grep {m|^base\.|} call_refs('<[$dynamic]> <[base.static]>') ) == 1 );

check(
    'call set diff catches a swapped target',
    call_set_changed( $src_before, $src_after )
);
check(
    'text change without a call-set change is not a diff',
    not call_set_changed( $src_before, $src_before . "## comment edit ##\n" )
);

##[ 2 : footer-insensitive compare ]##########################################

my $signed   = "alpha\nbeta\n\n#,,,,,....\n#SIGLINE\n#:::::::::\n";
my $unsigned = "alpha\nbeta\n";

check( 'signed vs unsigned generator output is the same content',
    same_content( $signed, $unsigned ) );
check(
    'a real content change is still a change',
    not same_content( $signed, "alpha\ngamma\n" )
);
check(
    'a missing trailing newline alone is not a change',
    same_content( $unsigned, "alpha\nbeta" )
);

##[ 3 : porcelain classification in a throwaway repo ]########################

my $temp_root = tempdir(qw| CLEANUP 1 |);
git_in( $temp_root, qw| init -q | );
git_in( $temp_root, qw| config user.email |, 'test@example.org' );
git_in( $temp_root, qw| config user.name |,  'test' );

make_path( File::Spec->catdir( $temp_root, qw| src | ) );
make_path( File::Spec->catdir( $temp_root, qw| bin dev | ) );

my %fixture_file = (
    File::Spec->catfile( $temp_root, qw| src base.keep | ) =>
        "## [:< ##\n# name  = base.keep\n<[base.logs]>->();\n",
    File::Spec->catfile( $temp_root, qw| src base.gone | ) =>
        "## [:< ##\n# name  = base.gone\n<[base.logs]>->();\n",
    File::Spec->catfile( $temp_root, qw| bin tool.pl | ) =>
        "#!/usr/bin/perl\nuse strict;\n",
);

foreach my $path ( sort keys %fixture_file ) {
    open( my $fh, '>:raw', $path )
        or die sprintf ':: fixture write failed : %s', $OS_ERROR;
    print {$fh} $fixture_file{$path};
    close $fh;
}
git_in( $temp_root, qw| add -A | );
git_in( $temp_root, qw| commit -q -m |, 'fixtures' );

##  modify one src file, delete one, add one [ untracked ]  ##

my $keep_path = File::Spec->catfile( $temp_root, qw| src base.keep | );
open( my $keep_fh, '>>:raw', $keep_path )
    or die sprintf ':: %s', $OS_ERROR;
print {$keep_fh} "<[base.new.ref]>->();\n";
close $keep_fh;

unlink File::Spec->catfile( $temp_root, qw| src base.gone | )
    or die sprintf ':: unlink : %s', $OS_ERROR;

my $added_path = File::Spec->catfile( $temp_root, qw| src base.added | );
open( my $added_fh, '>:raw', $added_path )
    or die sprintf ':: %s', $OS_ERROR;
print {$added_fh} "## [:< ##\n# name  = base.added\n";
close $added_fh;

my $porcelain
    = git_in( $temp_root, qw| status --porcelain=v1 -z -uall --no-renames | );
my %status = classify_status( split m|\0|, $porcelain );

check( 'modified file classified M',
    ( $status{ join '/', qw| src base.keep | } // '' ) eq qw| M | );
check( 'deleted file classified D',
    ( $status{ join '/', qw| src base.gone | } // '' ) eq qw| D | );
check( 'untracked src module classified A',
    ( $status{ join '/', qw| src base.added | } // '' ) eq qw| A | );
check(
    'clean file absent from the change set',
    not exists $status{ join '/', qw| bin tool.pl | }
);

##[ 4 : build_steps maps each rule to its step ]##############################

my @perl_files = qw| src/base.keep bin/tool.pl |;
my %call_diff  = ( 'base.keep' => 1 );
my $affected   = [qw| cube p7-log |];

my @steps = build_steps( \%status, \%call_diff, \@perl_files, $affected );
my %step_files = map { $_->{'step'} => $_->{'files'} } @steps;

check(
    'changed perl source -> format-code step',
    exists $step_files{'format-code'}
);
check(
    'src add + delete -> update-sub-list on the sub list',
    ( $step_files{'update-sub-list'} // [] )->[0] eq
        'src/base.list.subroutines'
);
check(
    'src add + delete -> dep-graph doc files',
    grep( m|module-dependency-graph\.asc$|,
        @{ $step_files{'dep-graph'} // [] } )
);
check(
    'affected zenki -> one whitelist file per zenka',
    (   ( $step_files{'gen-sub-whitelist'} // [] )->[0] eq
            'cfg/zenki/cube/subroutines.load-early'
            and ( $step_files{'gen-sub-whitelist'} // [] )->[1] eq
            'cfg/zenki/p7-log/subroutines.load-early'
    )
);

##  an src/ M file with an unchanged call set drops the dep-graph step  ##
my %quiet_status = ( 'src/base.keep' => qw| M | );
my @quiet_steps  = build_steps( \%quiet_status, {}, \@perl_files, [] );
check( 'call set unchanged -> no dep-graph step',
    not exists { map { $_->{'step'} => 1 } @quiet_steps }->{'dep-graph'} );

##  a pm change maps to amos-versions  ##
my %pm_status = ( 'data/lib-path/pm/AMOS7/Util.pm' => qw| M | );
my @pm_steps  = build_steps( \%pm_status, {}, [], [] );
check( 'changed pm module -> amos-versions step',
    ( map { $_->{'step'} } @pm_steps )[0] eq qw| amos-versions | );

##[ 5 : read-only run on the real tree ]######################################

my $status_before
    = git_in( $root_path, qw| status --porcelain=v1 -z -uall | );

my $plan_out = qx| perl $tool_path -json 2>&1 |;
my $plan_rc  = $CHILD_ERROR >> 8;

my $status_after = git_in( $root_path, qw| status --porcelain=v1 -z -uall | );

check( 'read-only run exits clean',     $plan_rc == 0 );
check( 'read-only run changed nothing', $status_before eq $status_after );
my $plan = eval { JSON::PP->new->decode($plan_out) };
check( 'read-only run prints parseable json', ref $plan eq 'HASH' );
check(
    'plan has steps + rewritten keys',
    (           ref $plan->{'steps'} eq 'ARRAY'
            and ref $plan->{'rewritten'} eq 'ARRAY'
    )
) if ref $plan eq 'HASH';
check(
    'read-only run rewrites nothing',
    ( ref $plan->{'rewritten'} eq 'ARRAY' and not @{ $plan->{'rewritten'} } )
) if ref $plan eq 'HASH';

##[ SUMMARY ]#################################################################

say '';
if ( @failures == 0 ) {
    say sprintf '[ PASS ] %d of %d checks', $tests_passed, $tests_run;
    exit 0;
} else {
    say sprintf '[ FAIL ] %d of %d checks failed',
        scalar @failures, $tests_run;
    exit 1;
}

#,,.,,.,,,...,,.,,,,,,,.,,,.,,,,,,,.,,,,,,.,,,..,,...,...,.,,,...,,.,,,.,,.,,,
#GVSK5ZLBZVUCRVXG3JZBMVAJ7HED2VWSPC5UHOUO5RBXD4O3JOTWWUH2ISQ2K5D3TWBO66ZCSHDRW
#\\\|2T4KUJWBOY2FJOODGBEX5BFN7KDLOJMOBYBZMA746QCROBITQ5G \ / AMOS7 \ YOURUM ::
#\[7]4IXOJGQIBDRVBPI2IU4QLMTLAXPED5LNNVT6C5YNWR7HMYY2COAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
