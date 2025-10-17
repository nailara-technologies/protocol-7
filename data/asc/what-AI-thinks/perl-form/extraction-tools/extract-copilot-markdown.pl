#!/usr/bin/perl
use strict;
use warnings;
use HTML::TreeBuilder;
use Getopt::Long;
use Pod::Usage;
use Encode qw(decode_utf8);

# Command line options
my $help = 0;
my $debug = 0;

GetOptions(
    'help|h' => \$help,
    'debug|d' => \$debug
) or pod2usage(1);

pod2usage(-exitval => 0, -verbose => 2) if $help;

# Get the filename from command line
my $filename = shift @ARGV or die "Usage: $0 [options] <filename>\nTry '$0 --help' for more information.\n";

# Read the HTML file
open my $fh, '<:encoding(UTF-8)', $filename or die "Cannot open $filename: $!";
my $html_content = do { local $/; <$fh> };
close $fh;

print STDERR "File loaded: $filename\n" if $debug;

# Parse the HTML
my $tree = HTML::TreeBuilder->new;
$tree->parse($html_content);
$tree->eof;

print STDERR "HTML parsed successfully\n" if $debug;

# Look for Copilot markdown content
my @copilot_elements = $tree->look_down(
    'data-copilot-markdown' => 'true'
);

if (@copilot_elements) {
    print STDERR "Found " . scalar(@copilot_elements) . " Copilot markdown elements\n" if $debug;

    foreach my $element (@copilot_elements) {
        # Get the HTML content of the element
        my $content = $element->as_HTML;

        # Extract just the inner HTML content
        if ($content =~ m{<div[^>]*data-copilot-markdown="true"[^>]*>(.*?)</div>}s) {
            my $inner_content = $1;

            # Clean up any HTML tags to get just the markdown
            $inner_content =~ s/<[^>]+>//g;

            # Decode HTML entities
            $inner_content =~ s/&lt;/</g;
            $inner_content =~ s/&gt;/>/g;
            $inner_content =~ s/&amp;/&/g;
            $inner_content =~ s/&quot;/"/g;
            $inner_content =~ s/&#39;/'/g;

            print "$inner_content\n";
        } else {
            # Fallback: if regex didn't work, just print the text content
            print $element->as_text, "\n";
        }
    }
} else {
    # Fallback method: try alternative class names
    print STDERR "No elements with data-copilot-markdown attribute found. Trying alternative selectors...\n" if $debug;

    my @alternative_elements = $tree->look_down(
        sub {
            my $e = shift;
            return 0 unless $e->tag eq 'div';
            my $class = $e->attr('class') || '';
            return $class =~ /markdown-body/ && $class =~ /MarkdownRenderer-module__container/;
        }
    );

    if (@alternative_elements) {
        print STDERR "Found " . scalar(@alternative_elements) . " alternative markdown elements\n" if $debug;

        foreach my $element (@alternative_elements) {
            print $element->as_text, "\n";
        }
    } else {
        die "Could not find any Copilot markdown content in the file.\n";
    }
}

# Clean up
$tree->delete;

__END__

=head1 NAME

extract-copilot-markdown.pl - Extract Copilot markdown content from saved HTML files

=head1 SYNOPSIS

extract-copilot-markdown.pl [options] <filename>

 Options:
   --help, -h     Show this help message
   --debug, -d    Enable debug output

=head1 DESCRIPTION

This script extracts Copilot-generated markdown content from HTML files saved from
the Copilot chat interface. It outputs the content to STDOUT, which can be redirected
to a file if needed.

=head1 EXAMPLES

  # Extract markdown to the terminal
  ./extract-copilot-markdown.pl chat.html

  # Save the extracted markdown to a file
  ./extract-copilot-markdown.pl chat.html > markdown.md

  # Enable debug output
  ./extract-copilot-markdown.pl --debug chat.html

=head1 DEPENDENCIES

Requires the following Perl modules:
  - HTML::TreeBuilder
  - Getopt::Long
  - Pod::Usage
  - Encode

=cut
