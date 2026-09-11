#!/usr/bin/env perl
## mine_git_history.pl -- mine this repo's own commit history for real (before
## -> after) P7 idiom corrections, instead of another synthetic instruction
## dataset. see data/tasks/coding-git-history-idiom-mining.md for the full
## context, dry-run numbers, and open hazards.
##
## the rubric regexes below are a direct, unmodified port of data/control-
## vectors/score.py's frozen RUBRIC/ANTI tables -- keep them in sync by hand
## if score.py ever changes; this script measures the same thing the
## validation harness measures, deliberately, so a future training run's "did
## idiom density improve" question uses one consistent ruler.
##
## the code directory has been renamed three times in this repo's history
## (src/ -> base-code/ -> modules/ -> src/, see the task file's "mining
## approach" section) -- rather than tracking exact date boundaries, every git
## show call below passes ALL historical names as pathspecs; a name that
## didn't exist in a given commit's tree simply contributes no diff output for
## it, which is harmless and confirmed correct against the validated python
## dry-run.
##
## usage:
##   mine_git_history.pl --tier1              [ default -- 122 commits,
##                                               subject-line "style" ]
##   mine_git_history.pl --tier2               [ 586 commits, subject
##                                               +body keyword match ]
##   mine_git_history.pl --all [--max N]       [ full pool, 6381 commits,
##                                               newest-first, cap with
##                                               --max for a bounded run ]
##   mine_git_history.pl --dry-run             [ counts only, no jsonl
##                                               written -- matches the
##                                               2026-09-10 python dry-run ]
##   ... --out data/idioms/corpus/mined.jsonl  [ default output path ]

use strict;
use warnings;
use Getopt::Long;
use JSON::PP qw| encode_json |;

my $tier     = 'tier1';
my $max_n    = 0;                                  ## 0 = no cap ##
my $dry_run  = 0;
my $out_path = 'data/idioms/corpus/mined.jsonl';

GetOptions(
    'tier1'   => sub { $tier = 'tier1' },
    'tier2'   => sub { $tier = 'tier2' },
    'all'     => sub { $tier = 'all' },
    'max=i'   => \$max_n,
    'dry-run' => \$dry_run,
    'out=s'   => \$out_path,
) or die "usage error\n";

## direct port of score.py's RUBRIC / ANTI -- keep in sync by hand ##
my %RUBRIC = (
    invoke    => qr/<\[[\w.]+\]>->\(/,
    cfgaccess => qr/<(?!\[)[a-z][\w.]+>/,
    truefalse => qr/\b(?:TRUE|FALSE)\b/,
    comment   => qr/## [a-z\[]/,
    bracket   => qr/\[ [\w][^\]\n]{0,60}? \]/,
    colonflag => qr/:[a-z][a-z0-9-]*:/,
    dotmodule => qr/\b[a-z][a-z0-9_]*(?:\.[a-z0-9_]+){2,}\b/,
);
my %ANTI = (
    dashflag   => qr/--[a-z][a-z-]+/,
    coloncolon => qr/\b[A-Z][\w]*(?:::[\w]+)+/,
    capcomment => qr/^\s*# [A-Z]/m,
    barebool   => qr/\breturn [01]\b/,
    successkey => qr/\b(?:success|error)\s*=>/,
);

sub score_text {
    my ($text) = @_;
    my %s;
    for my $k ( keys %RUBRIC ) {
        my @hits = $text =~ m|$RUBRIC{$k}|g;
        $s{$k} = scalar @hits;
    }
    $s{'modedata'} = ( $text =~ m|'mode'| && $text =~ m|'data'| ) ? 1 : 0;
    return \%s;
}

sub sum_scores { my ($h) = @_; my $t = 0; $t += $_ for values %$h; return $t }

## code-directory names across all three eras -- always pass all of them ##
my @CODE_DIRS = qw| src/ modules/ base-code/ bin/ |;

sub sh {
    my (@cmd) = @_;
    open my $fh, '-|', 'git', '-c', 'color.ui=never', @cmd
        or die "failed to run git @cmd: $!\n";
    local $/;
    my $out = <$fh>;
    close $fh;
    return $out // '';
}

## build the commit hash list per the requested tier ##
my @hashes;
{
    my $raw = sh( 'log', '--format=%H%x00%s' );
    for my $line ( split m|\n|, $raw ) {
        next unless length $line;
        my ( $h, $s ) = split m|\x00|, $line, 2;
        next unless defined $h && defined $s;
        if ( $tier eq 'tier1' ) {
            push @hashes, $h if lc($s) =~ m|style|;
        } elsif ( $tier eq 'tier2' ) {
            push @hashes, $h
                if lc($s)
                =~ m{style|cleanup|idiom|convention|refactor.*to use|swap.*to|normalize};
        } else {    ## all ##
            push @hashes, $h;
        }
    }
}
@hashes = @hashes[ 0 .. $max_n - 1 ] if $max_n && @hashes > $max_n;
printf STDERR "commits in scope [%s]: %d\n", $tier, scalar @hashes;

## per-commit diff -> hunks -> score both sides ##
sub parse_hunks {
    my ($diff) = @_;
    my @hunks;
    my ( @before, @after );
    my $in_hunk = 0;
    for my $line ( split m|\n|, $diff ) {
        if ( $line =~ m|^@@| ) {
            if ( $in_hunk && ( @before || @after ) ) {
                push @hunks, [ join( "\n", @before ), join( "\n", @after ) ];
            }
            @before  = ();
            @after   = ();
            $in_hunk = 1;
            next;
        }
        next unless $in_hunk;
        if ( $line =~ m|^-(?!--)| ) {
            push @before, substr( $line, 1 );
        } elsif ( $line =~ m|^\+(?!\+\+)| ) {
            push @after, substr( $line, 1 );
        }
    }
    push @hunks, [ join( "\n", @before ), join( "\n", @after ) ]
        if $in_hunk && ( @before || @after );
    return @hunks;
}

my $total_hunks     = 0;
my $real_correction = 0;
my $qualifying      = 0;
my @out_lines;

for my $h (@hashes) {
    my $diff = sh( 'show', $h, '--unified=0', '--', @CODE_DIRS );
    next unless length $diff;

    my ( $subject, $ts ) = split m|\x00|,
        sh( 'show', '-s', '--format=%s%x00%at', $h );
    chomp $ts if defined $ts;

    for my $pair ( parse_hunks($diff) ) {
        my ( $before, $after ) = @$pair;
        $total_hunks++;

        ## skip pure additions/deletions -- not a real correction, just new ##
        ## code that trivially scores higher "after" than an empty "before" ##
        ## without representing any actual fix                              ##
        next
            if length( $before =~ s{^\s+|\s+$}{}gr ) < 5
            || length( $after  =~ s{^\s+|\s+$}{}gr ) < 5;
        $real_correction++;

        my $sb    = score_text($before);
        my $sa    = score_text($after);
        my $delta = sum_scores($sa) - sum_scores($sb);
        next unless $delta > 0;
        $qualifying++;

        ## dominant category = the rubric key with the largest positive ##
        ## per-key delta, ties broken by key name for determinism       ##
        my ( $best_cat, $best_delta ) = ( 'unknown', 0 );
        for my $k ( sort keys %RUBRIC, 'modedata' ) {
            my $kd = ( $sa->{$k} // 0 ) - ( $sb->{$k} // 0 );
            if ( $kd > $best_delta ) {
                $best_delta = $kd;
                $best_cat   = $k;
            }
        }

        push @out_lines,
            encode_json(
            {   'before'   => $before,
                'after'    => $after,
                'category' => $best_cat,
                'delta'    => $delta,
                'kind'     => 'mined',
                'source'   => 'git-history',
                'commit'   => $h,
                'subject'  => $subject,
                'ts'       => $ts + 0,
            }
            );
    }
}

printf STDERR "total hunks: %d\n",                   $total_hunks;
printf STDERR "real correction-shaped hunks: %d\n",  $real_correction;
printf STDERR "qualifying (idiom density up): %d\n", $qualifying;

if ($dry_run) {
    print STDERR "dry-run -- nothing written\n";
    exit 0;
}

open my $ofh, '>', $out_path or die "cannot write $out_path: $!\n";
print $ofh "$_\n" for @out_lines;
close $ofh;
printf STDERR "wrote %d lines to %s\n", scalar(@out_lines), $out_path;

#,,,.,,,,,,..,,..,.,,,.,,,,,.,.,,,,,.,...,,..,..,,...,...,,,.,..,,.,,,,,,,,..,
#BO7XA5ZL6KTGWJZHG4GPNTXO2OPH7JTQFPBFINY2FW675NQW7VN6JYMIMW5VHQTMUGEI2FYCR6BB4
#\\\|6YBNOFXJMVZKGJIIODT5K3LK5LOIEF4SEVVIJQGXCHJ5BBZPO4O \ / AMOS7 \ YOURUM ::
#\[7]TVOKAZYIG2IIUUTI246THZXP2CXKTVWBPUM7UFM2UMUP7UI4SQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
