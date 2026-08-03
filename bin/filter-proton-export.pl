#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Copy qw(copy);
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );

# filters a proton mail export tool dump [ pairs of <id>.eml + ##
# <id>.metadata.json ] down to job-application-related messages,      ##
# copying the matching .eml files into a destination directory.       ##
#
# usage: filter-proton-export.pl <export-dir> <dest-dir> [to-pattern]
#   default to-pattern: jobs@   (matched against To/Reply-To addresses)
#
# a message is kept if it isn't excluded, and either:
#   - a To/Reply-To address matches <to-pattern>, or
#   - the (already-decoded) Subject contains the word "bewerbung"
# excluded regardless of the above if Subject/Sender/To/Reply-To match
# the exclude pattern [ jobcenter / arbeitsagentur.de by default -- same
# exclusion jobsite.report.mail_evidence_collect uses ]

my ( $export_dir, $dest_dir, $to_pattern, $exclude_pattern ) = @ARGV;
$to_pattern      //= 'jobs@';
$exclude_pattern //= '\.jobcenter@|jobcenter|arbeitsagentur\.de';

if ( not defined $export_dir or not defined $dest_dir ) {
    print STDERR "usage: $0 <export-dir> <dest-dir> "
        . "[to-pattern] [exclude-pattern]\n";
    exit 1;
}

die "not a directory: $export_dir\n" if not -d $export_dir;
if ( not -d $dest_dir ) {
    mkdir($dest_dir) or die "cannot create $dest_dir: $!\n";
}

my $to_re      = qr/\Q$to_pattern\E/i;
my $exclude_re = qr/$exclude_pattern/i;

## metadata files are already utf-8 text ##
my $json = JSON::PP->new->utf8(0);

opendir( my $dh, $export_dir ) or die "cannot open $export_dir: $!\n";
my @meta_files = grep {/\.metadata\.json$/} readdir($dh);
closedir($dh);

my ( $scanned, $kept, $excluded ) = ( 0, 0, 0 );

for my $meta_file (@meta_files) {
    $scanned++;
    my $meta_path = "$export_dir/$meta_file";
    open( my $fh, '<:raw', $meta_path ) or next;
    local $/;
    my $raw_json = <$fh>;
    close($fh);

    my $data = eval { $json->decode($raw_json) };
    next if not $data or ref $data ne 'HASH';
    my $payload = $data->{'Payload'} // {};

    my $subject = $payload->{'Subject'} // '';
    my @to_addrs
        = map { $_->{'Address'} // '' } @{ $payload->{'ToList'} // [] };
    my @reply_addrs
        = map { $_->{'Address'} // '' } @{ $payload->{'ReplyTos'} // [] };
    my $sender_addr = $payload->{'Sender'}{'Address'} // '';

    my $haystack = join ' ', $subject, $sender_addr, @to_addrs, @reply_addrs;

    if ( $haystack =~ $exclude_re ) {
        $excluded++;
        next;
    }

    my $to_match = grep {/$to_re/} @to_addrs, @reply_addrs;
    next if not $to_match and $subject !~ /bewerbung/i;

    ( my $base = $meta_file ) =~ s/\.metadata\.json$//;
    my $eml_path = "$export_dir/$base.eml";
    next if not -f $eml_path;

    copy( $eml_path, "$dest_dir/$base.eml" )
        or warn "copy failed for $base.eml: $!\n";
    $kept++;
}

printf STDERR "done : %d scanned, %d kept, %d excluded -> %s\n",
    $scanned, $kept, $excluded, $dest_dir;

#,,,,,,..,,,,,,,.,,,.,,..,,,.,.,,,..,,,.,,,.,,..,,...,...,,..,.,.,,.,,,,,,,.,,
#IOYUNG6Z3ZSZCJIUSDGFEWYYPZ2CA2TD4HEHJQJ5NTNFDOKQUKHIXZ7QY36DEQ6DOXP4J3G5VEX4I
#\\\|KG67XUMQXAQGBFQ4VGO3NBNAQ3RDQAYNMHOTUMOIAFNVTZGBJYM \ / AMOS7 \ YOURUM ::
#\[7]BJKOOTG4ZRQFSDOWS2PRWMR2B764NTIVB5GLWSDWYBULUR2MTUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
