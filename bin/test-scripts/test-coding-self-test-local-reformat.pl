#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                        ###
## local-reformat short-circuit harness [ coding.self_test.evaluate ]      ##
###                                                                        ###

## exercises the real translated source of coding.self_test.evaluate +      ##
## coding.self_test.check_constraint directly [ both are transport- free,   ##
## no event/timer/http stubbing needed at all ]. covers the 2026-08-27 fix  ##
## : when the raw answer already contains every required token and the      ##
## constraint is word_count, evaluate returns outcome=final with            ##
## tier=local_reformat immediately instead of issuing a tier1 reformat      ##
## inference round-trip -- confirmed live the same day that round-trip can  ##
## independently fail [ model spends its whole reply on reasoning, emits no ##
## final content ] even when the original answer was already substantively  ##
## correct                                                                  ##

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

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;

%code = ( 'base.logs' => sub { return TRUE }, );

my $fail_count = 0;

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

compile_module('coding.self_test.check_constraint');
compile_module('coding.self_test.evaluate');

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub run_init {
    my $params = shift;
    return $code{'coding.self_test.evaluate'}
        ->( { step => qw| init |, %{$params} } );
}

##[ 1. sanity : tier0 exact match still passes directly, unaffected ]#########

say ': 1. tier0 exact match unaffected by the new branch';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'q',
            answer     => 'cat',
            expected   => 'cat',
            constraint => { type => qw| exact |, value => qw| cat | },
        }
    );
    ok( $r->{'outcome'} eq qw| final |,        'tier0 pass is final' );
    ok( $r->{'eval'}{'tier'} eq qw| literal |, 'tier reported as literal' );
}

##[ 2. the fix : word_count + content already correct -> local_reformat ]#####

say ': 2. word_count, content already '
    . 'correct : local reformat, no round-trip';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'What animal?',
            answer     => 'The cat. The mouse is now a snack.',
            expected   => 'cat',
            constraint => {
                type         => qw| word_count |,
                max_words    => 1,
                must_contain => qw| cat |
            },
        }
    );
    ok( $r->{'outcome'} eq qw| final |, 'resolved without a tier1 request' );
    ok( $r->{'eval'}{'tier'} eq qw| local_reformat |,
        'tier reported as local_reformat' );
    ok( $r->{'eval'}{'data'} eq qw| cat |, 'extracted answer is just "cat"' );
    ok( $r->{'eval'}{'original_answer'} eq
            'The cat. The mouse is now a snack.',
        'original answer preserved for the record'
    );
}

##[ 3. case preserved from the source text, not the lowercased needle ]#######

say ': 3. extraction preserves original casing from the answer';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'q',
            answer     => 'I think the Cat did it.',
            expected   => 'cat',
            constraint => {
                type         => qw| word_count |,
                max_words    => 1,
                must_contain => qw| cat |
            },
        }
    );
    ok( $r->{'outcome'} eq qw| final |, 'resolved locally' );
    ok( $r->{'eval'}{'data'} eq qw| Cat |,
        'kept the source capitalization "Cat", not "cat"' );
}

##[ 4. word_count, content NOT already correct -> normal tier1 path ]#########

say ': 4. word_count, token genuinely '
    . 'absent : falls through to tier1 request';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'What animal?',
            answer     => 'The dog barked loudly at the mailman.',
            expected   => 'cat',
            constraint => {
                type         => qw| word_count |,
                max_words    => 1,
                must_contain => qw| cat |
            },
        }
    );
    ok( $r->{'outcome'} eq qw| request |,
        'no local match available : issues a tier1 request as before' );
    ok( length $r->{'request_prompt'}, 'request prompt was built' );
}

##[ 5. whole-token boundary respected : substring match does not count ]######

say ': 5. "cat" inside "concatenate" is not a whole-token match';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'q',
            answer     => 'Please concatenate the strings.',
            expected   => 'cat',
            constraint => {
                type         => qw| word_count |,
                max_words    => 1,
                must_contain => qw| cat |
            },
        }
    );
    ok( $r->{'outcome'} eq qw| request |,
        'substring-only match does not short-circuit to local_reformat' );
}

##[ 6. non-word_count type : local-reformat gate never fires ]################

say ': 6. exact type : content-already-correct '
    . 'never takes the word_count-only shortcut';
{
    ## 'exact' type with must_contain set : content_already_correct can be ##
    ## true [ "The cat is here" contains "cat" ] while tier0 still fails [ ##
    ## the trimmed answer isn't exactly "cat" ] -- exercises the gate with ##
    ## a genuinely reachable non-word_count case, unlike numeric type [    ##
    ## numeric's own tier0 check has no brevity requirement, so a          ##
    ## content-correct numeric answer always already passes tier0 before   ##
    ## ever reaching this decision at all ]                                ##
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'What animal?',
            answer     => 'The cat is here.',
            expected   => 'cat',
            constraint => {
                type         => qw| exact |,
                value        => qw| cat |,
                must_contain => qw| cat |
            },
        }
    );
    ok( $r->{'outcome'} eq qw| request |,
        'exact type still goes through tier1, the '
            . 'word_count-only shortcut does not fire'
    );
    ok( length $r->{'request_prompt'}, 'request prompt was built' );
}

##[ 7. multi-word must_contain phrase extracted as one unit ]#################

say ': 7. multi-word must_contain phrase : extraction keeps it intact';
{
    my $r = run_init(
        {   model_id   => 'M1',
            prompt     => 'What did you see?',
            answer     => 'I definitely saw a black cat run past.',
            expected   => 'black cat',
            constraint => {
                type         => qw| word_count |,
                max_words    => 2,
                must_contain => 'black cat',
            },
        }
    );
    ok( $r->{'outcome'} eq qw| final |, 'resolved locally' );
    ok( $r->{'eval'}{'tier'} eq qw| local_reformat |,
        'tagged local_reformat' );
    ok( $r->{'eval'}{'data'} eq 'black cat',
        'the two-word phrase was extracted as one unit, not split' );
}

say '';
if ($fail_count) {
    say "$fail_count check(s) FAILED";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,..,...,,.,,,,.,,.,,,.,,...,,.,,..,,...,..,,...,...,,.,,,..,..,,,,,,..,,
#ESN72CXFPX4ETDJ7LMPI24BYUDH3CDBUHAIBR5DCOCXTDE4426PE2K2GISFIQEQGF2QDY5BXXTA6Y
#\\\|T5X3GYKN2LE3IOJKMV5ZQDIX27VJ5GAIC7MNK37DTMOAGOXORL3 \ / AMOS7 \ YOURUM ::
#\[7]GYDN7AP5PGNQFQ3XVEU65HGRA7JC2EYVSBB2L57L7XRUSIJRGEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
