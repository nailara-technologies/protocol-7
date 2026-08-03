#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );

# extracts job-application-related messages from a large mbox archive into
# a smaller, pre-filtered mbox file -- streaming, single pass, so it works
# fine against a multi-hundred-MB inbox without loading it all into memory.
#
# usage: extract-job-mail.pl <input-mbox> <output-mbox> [to-pattern]
#   default to-pattern: jobs@   (matched case-insensitively against
#   To/Cc/Bcc headers)
#
# a message is kept if either:
#   - a To/Cc/Bcc header matches <to-pattern>, or
#   - the Subject header contains the word "bewerbung"
#
# assumes mboxrd-style escaping (body lines starting with "From " are
# escaped as ">From ") -- same assumption jobsite.report.mail_split makes.

my ( $input, $output, $to_pattern ) = @ARGV;
$to_pattern //= 'jobs@';

if ( not defined $input or not defined $output ) {
    print STDERR "usage: $0 <input-mbox> <output-mbox> [to-pattern]\n";
    print STDERR "  default to-pattern: jobs\@\n";
    exit 1;
}

my $to_re = qr/\Q$to_pattern\E/i;

open( my $in_fh,  '<:raw', $input )  or die "cannot open $input: $!\n";
open( my $out_fh, '>:raw', $output ) or die "cannot open $output: $!\n";

my @buffer;
my $in_headers      = 0;
my $current_matched = 0;
## true at start of file counts as "after blank" ##
my $seen_blank = 1;
my ( $total_messages, $kept_messages, $line_count ) = ( 0, 0, 0 );

my $flush = sub {
    my ($keep) = @_;
    return if not @buffer;
    $total_messages++;
    if ($keep) {
        print {$out_fh} @buffer;
        $kept_messages++;
    }
    @buffer = ();
};

while ( my $line = <$in_fh> ) {
    $line_count++;

    if ( $line =~ /^From / and $seen_blank ) {
        $flush->($current_matched);
        $current_matched = 0;
        $in_headers      = 1;
    }

    if ($in_headers) {
        if ( $line =~ /^\s*$/ ) {
            $in_headers = 0;
        } elsif ( $line =~ /^(?:To|Cc|Bcc):\s*(.*)$/i ) {
            $current_matched = 1 if $1 =~ $to_re;
        } elsif ( $line =~ /^Subject:\s*(.*)$/i ) {
            $current_matched = 1 if $1 =~ /bewerbung/i;
        }
    }

    push @buffer, $line;
    $seen_blank = ( $line =~ /^\s*$/ ) ? 1 : 0;

    if ( $line_count % 200_000 == 0 ) {
        printf STDERR "..: %d lines, %d messages scanned, %d kept\n",
            $line_count, $total_messages, $kept_messages;
    }
}
$flush->($current_matched);

close($in_fh);
close($out_fh);

printf STDERR "done : %d messages scanned, %d kept [ pattern '%s' ] -> %s\n",
    $total_messages, $kept_messages, $to_pattern, $output;

#,,,,,..,,,.,,..,,.,.,,..,,.,,...,.,.,.,,,.,,,..,,...,...,,..,.,.,.,.,...,.,,,
#RFRZR4KMNW2W4A2X34C6PEBPWGP7A6QPH64AGE4TZ6XMSZ2ACUTN2FU5T32LYRAF4JWDOJTI7647W
#\\\|MKS6LJS4EOUN6F5WBMH2MQMTYPQLNBUPJSDRAUFXRKVWVWODK4P \ / AMOS7 \ YOURUM ::
#\[7]MMHSBPYATQM2MJZHMLW3JD6CMWB7JPPWTVBYEEHUM4FE4HQK2ODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
