#!/usr/bin/env perl
## corpus_to_sft.pl -- convert a mined (before,after) corpus into the same
## literal-line SFT format train_lora.py already parses (matching data/
## control-vectors/dataset/positive-expanded.txt's shape). Real code stays
## real -- only a generic, category-agnostic instruction wrapper is
## synthesized, since git commits don't come with a matching natural- language
## instruction. Deliberately NOT category-specific ("fix the invoke idiom
## here") -- the actual goal is ambient idiomatic behavior by default, not the
## model learning to apply idiom X only when told to.
use strict;
use warnings;
use Getopt::Long;
use JSON::PP qw| decode_json |;

my $in_path  = 'data/idioms/corpus/mined.curated.jsonl';
my $out_path = 'data/idioms/corpus/mined.curated.sft.txt';

GetOptions( 'in=s' => \$in_path, 'out=s' => \$out_path )
    or die "usage error\n";

my @instructions = (
    'Rewrite this protocol-7 Perl snippet to '
        . 'follow the project\'s coding conventions.',
    'Bring this piece of protocol-7 code in '
        . 'line with the codebase\'s established style.',
    'Update this Perl fragment to match how the '
        . 'rest of protocol-7 writes this kind of code.',
);

sub escape_for_line {
    my ($text) = @_;
    $text =~ s|\\|\\\\|g;
    $text =~ s|\n|\\n|g;
    return $text;
}

open my $ifh, '<', $in_path  or die "cannot read $in_path: $!\n";
open my $ofh, '>', $out_path or die "cannot write $out_path: $!\n";

my $n = 0;
while ( my $line = <$ifh> ) {
    chomp $line;
    next unless length $line;
    my $row = decode_json($line);

    my $before = $row->{'before'} // '';
    my $after  = $row->{'after'}  // '';
    next unless length $before and length $after;

    my $instruction = $instructions[ $n % scalar @instructions ];
    my $user_text   = "$instruction\n\n" . $before;

    printf $ofh "<|im_start|>system\\nYou are a protocol-7 "
        . "developer.<|im_end|>\\n<|im_start|>user\\n%s<|im_end|>\\n<|im_"
        . "start|>assistant\\n%s\n",
        escape_for_line($user_text), escape_for_line($after);
    $n++;
}
close $ifh;
close $ofh;

printf STDERR "wrote %d SFT-format lines to %s\n", $n, $out_path;

#,,,,,...,,..,,.,,.,.,,,,,.,,,,,,,...,..,,,.,,..,,...,..,,,..,...,..,,,,.,.,.,
#ZKKGD6DQMCKHYPFCLBNLPJ2GGIRR6DZYEXJUAFMMCZCWTC55CFAMFQQE2HFUI2WKNVN5GFGLZF4U2
#\\\|CR6RRCQJA7ZVHSJ75XZ36VCWEJA4VSVNZRGGRRYTLVSAN3ZI3YF \ / AMOS7 \ YOURUM ::
#\[7]UP45OZNOXCUPEFKIN7CQHNJOIDU4BME2FZRTNYR4TVXSPWG77KDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
