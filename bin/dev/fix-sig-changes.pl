#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp qw(read_file);

# Get list of conflicted files
my @conflicted_files = `git diff --name-only --diff-filter=U`;
chomp @conflicted_files;

print "Analyzing conflicted files for signature changes...\n";

my @signature_conflicts = ();
foreach my $file (@conflicted_files) {
    next unless -f $file;
    my $content = eval { read_file($file) };
    next unless $content;

    # Check if this file has signature conflicts anywhere
    if ( has_signature_conflict($content) ) {
        push @signature_conflicts, $file;
        print "SIGNATURE CONFLICT: $file\n";
        print_signature_conflict($content);
        print "\n" . "=" x 60 . "\n";
    }
}

if (@signature_conflicts) {
    print "Files with signature conflicts found: "
        . scalar(@signature_conflicts) . "\n";
    print "To resolve all signature conflicts with --theirs:\n";
    foreach my $file (@signature_conflicts) {
        print "git checkout --theirs '$file'\n";
    }
    print "\nOr run this script with --fix to auto-resolve:\n";
    print "$0 --fix\n";

    # Auto-fix option
    if ( $ARGV[0] && $ARGV[0] eq '--fix' ) {
        print "\nAuto-resolving signature conflicts...\n";
        foreach my $file (@signature_conflicts) {
            system("git checkout --theirs '$file'");
            print "Resolved: $file\n";
        }
        system( "git add " . join( " ", map {"'$_'"} @signature_conflicts ) );
        print "Added resolved files to index.\n";
    }
} else {
    print "No signature conflicts found.\n";
}

sub has_signature_conflict {
    my ($content) = @_;
    my @lines     = split /\n/, $content;

    my $in_conflict        = 0;
    my $contains_signature = 0;

    foreach my $line (@lines) {
        if ( $line =~ /^<{7}/ ) {    # Conflict start
            $in_conflict        = 1;
            $contains_signature = 0;
        } elsif ( $line =~ /^>{7}/ ) {    # Conflict end
            if ($contains_signature) {
                return 1;
            }
            $in_conflict = 0;
        } elsif ( $in_conflict && is_signature_line($line) ) {
            $contains_signature = 1;
        }
    }
    return 0;
}

sub is_signature_line {
    my ($line) = @_;
    return 1 if $line =~ /^\s*#\s*[A-Z0-9]{60,}/;  # Long hex-like signatures
    return 1 if $line =~ /AMOS7.*YOURUM/;          # AMOS7 markers
    return 1 if $line =~ /DATA\s+SIGNATURE/;       # Data signature markers
    return 1 if $line =~ /^#\s*[,.\\|]+\s*$/;      # Signature border patterns
    return 0;
}

sub print_signature_conflict {
    my ($content) = @_;
    my @lines     = split /\n/, $content;

    my $in_conflict        = 0;
    my $contains_signature = 0;
    my $conflict_start     = 0;

    for my $i ( 0 .. $#lines ) {
        if ( $lines[$i] =~ /^<{7}/ ) {
            $conflict_start     = $i;
            $in_conflict        = 1;
            $contains_signature = 0;
        } elsif ( $in_conflict && is_signature_line( $lines[$i] ) ) {
            $contains_signature = 1;
        } elsif ( $lines[$i] =~ /^>{7}/ && $in_conflict ) {
            if ($contains_signature) {

                # Print context around this conflict block
                my $start = $conflict_start > 5 ? $conflict_start - 5 : 0;
                my $end   = $i + 5 < @lines     ? $i + 5 : $#lines;

                print "  Conflict block (lines "
                    . ( $conflict_start + 1 ) . "-"
                    . ( $i + 1 ) . "):\n";
                for my $j ( $start .. $end ) {
                    my $marker = "";
                    $marker = " ← CONFLICT START" if $lines[$j] =~ /^<{7}/;
                    $marker = " ← SEPARATOR"      if $lines[$j] =~ /^={7}/;
                    $marker = " ← CONFLICT END"   if $lines[$j] =~ /^>{7}/;
                    $marker = " ← SIGNATURE"
                        if is_signature_line( $lines[$j] );

                    printf "    %3d: %s%s\n", $j + 1, $lines[$j], $marker;
                }
                print "\n";
            }
            $in_conflict = 0;
        }
    }
}

#,,,.,,,.,,,.,.,.,.,,,,,.,,.,,..,,,,,,...,.,.,...,...,...,..,,,..,...,,.,,,,.,
#ZAPPXGMB7WU2OEM4BVP6RB56DDQBXCEB5L5XW6WIRQM5YMPNYRH7VFZNFVEPYF2CEKOQT7EIAYJMO
#\\\|RIEY57TBATYZRHVHSGUNRF65CPKWCBHPHDRNHMT2EQ3NX7RPO36 \ / AMOS7 \ YOURUM ::
#\[7]TPXYJSXHOG356CR2JIUGAHRFR3EAYJBHLWX3GEKC25V7QQLDCWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
