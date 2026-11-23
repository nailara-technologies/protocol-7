#!/usr/bin/perl
## format-code : named unary operator before a dereferenced parenthesis     ##
###                                                                          ###

use v5.32;
use strict;
use warnings;
use English;
use B::Deparse;
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

sub deparse_source {
    my $source = shift;
    my $code   = eval "sub { $source }";
    die "cannot compile test source : $EVAL_ERROR" if $EVAL_ERROR;
    return B::Deparse->new->coderef2text($code);
}

my @operators = qw| not defined ref scalar exists |;
say ': format-code named unary dereference cases';

for my $operator (@operators) {
    my $declaration = 'my $ref = [ 1, 2, 3 ];';
    my $expression  = $operator eq 'exists' ? '$ref->[0]' : '$ref';
    my $statement   = "my \@values = $operator ( $expression )->\@*;";
    my $source      = "$declaration\n$statement";
    my $path        = File::Spec->catfile( $work_dir, "$operator.pl" );
    open( my $write_fh, '>', $path )
        or die "cannot write $path : $OS_ERROR";
    print {$write_fh} "#!/usr/bin/perl\nuse strict;\nuse "
        . "warnings;\n$declaration\n$statement\n";
    close $write_fh;

    my $before_deparse = deparse_source($source);
    my $run_log        = `$format_code $path 2>&1`;
    my $run_rc         = $CHILD_ERROR >> 8;
    ok( $run_rc == 0, "$operator [ format-code exit 0 ]" );

    open( my $read_fh, '<', $path )
        or die "cannot read back $path : $OS_ERROR";
    my $formatted = do { local $INPUT_RECORD_SEPARATOR = undef; <$read_fh> };
    close $read_fh;

    my $space_kept = $formatted =~ m{\Q$operator\E\s+\(};
    ok( $space_kept, "$operator [ semantic space preserved ]" );

    my $after_deparse = deparse_source($formatted);
    ok( $after_deparse eq $before_deparse,
        "$operator [ B::Deparse output unchanged ]"
    );

    my $second_log = `$format_code $path 2>&1`;
    ok( $CHILD_ERROR == 0, "$operator [ second format-code exit 0 ]" );
    open( my $second_fh, '<', $path )
        or die "cannot read back $path : $OS_ERROR";
    my $second = do { local $INPUT_RECORD_SEPARATOR = undef; <$second_fh> };
    close $second_fh;
    ok( $second eq $formatted, "$operator [ formatting is idempotent ]" );
}

my $tight_path = File::Spec->catfile( $work_dir, 'tight.pl' );
open( my $tight_fh, '>', $tight_path )
    or die "cannot write $tight_path : $OS_ERROR";
print {$tight_fh} "#!/usr/bin/perl\nuse strict;\nuse warnings;\nmy \$ref "
    . "= [ 1, 2, 3 ];\nmy \@values = not(\$ref)->\@*;\n";
close $tight_fh;
my $tight_log = `$format_code $tight_path 2>&1`;
ok( $CHILD_ERROR == 0, 'tight control [ format-code exit 0 ]' );
open( my $tight_read, '<', $tight_path )
    or die "cannot read back $tight_path : $OS_ERROR";
my $tight = do { local $INPUT_RECORD_SEPARATOR = undef; <$tight_read> };
close $tight_read;
ok( $tight =~ m{my \@values = not\(\$ref\)->\@\*},
    'tight control [ no semantic space introduced ]'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,...,,,.,.,.,.,.,..,,..,,,,.,...,.,.,...,..,,...,...,,..,..,,,..,...,.,,,
#BYWTPMRO3WJWFFPIPESVFXSFOYI2FGFZZ5INRVZDUOXV6XLWSV6IG6LYE2ZB2FOZ54D7JAJYRMPUY
#\\\|K4I4W4SH5KFALJJ7XITGHL2B2ONVD3ZNNP2OKUAEJAORYVZWONV \ / AMOS7 \ YOURUM ::
#\[7]FK7ITQ4C7WAGXVRZI4QW76MMWGH5LBMCWGAZ2B5AODRPPMRQTYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
