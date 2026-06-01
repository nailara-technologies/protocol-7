#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

use YAML::XS;
use File::Copy;
use File::Path qw(make_path);
use File::Basename;
use File::Spec;
use Text::ParseWords;
use HTML::TreeBuilder;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use List::Util qw(first);

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
my $IMPORT_DIR = '/data/projects/protocol-7/IMPORT';
my $JOBS_DIR   = '/var/protocol-7/jobsite/jobs';

my %STATUS_PRIORITY = (
    applied     => 6,
    interviewed => 5,
    apply       => 4,
    review      => 3,
    assessed    => 2,
    new         => 1,
    rejected    => 0,
);

# German / UI status -> canonical status
my %STATUS_MAP = (
    'Noch ausstehend'                  => 'applied',
    'Absage erhalten'                  => 'rejected',
    'Vorstellungsgespräch abgeschlossen' => 'interviewed',
    'beworben'   => 'applied',
    'absage'     => 'rejected',
    'applied'    => 'applied',
    'rejected'   => 'rejected',
    'responded'  => 'interviewed',
    'rückmeldung' => 'interviewed',
    'to_apply'   => 'apply',
    'skipped'    => undef,
    'übersp.'    => undef,
    'archived'   => undef,
    'archiv'     => undef,
);

# Ensure all target dirs exist
for my $sd (qw(new assessed review apply applied interviewed rejected blocked deleted)) {
    make_path("$JOBS_DIR/$sd") unless -d "$JOBS_DIR/$sd";
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
sub normalize {
    my ($s) = @_;
    return '' unless defined $s;
    $s = lc($s);
    $s =~ s/^\s+|\s+$//g;
    $s =~ s/\s+/ /g;
    $s;
}

sub extract_stepstone_id {
    my ($url) = @_;
    return undef unless defined $url;
    if ($url =~ /--(\d+)-inline\.html$/) {
        return $1;
    }
    return undef;
}

sub strip_bom {
    my ($s) = @_;
    $s =~ s/^\x{FEFF}// if defined $s;
    $s;
}

# ---------------------------------------------------------------------------
# Load existing jobs
# ---------------------------------------------------------------------------
my (%jobs_by_id, %jobs_by_key);

my @status_dirs;
if (opendir my $dh, $JOBS_DIR) {
    @status_dirs = grep { -d "$JOBS_DIR/$_" && !/^\./ } readdir($dh);
    closedir $dh;
}

my @all_yaml_files;
for my $dir (@status_dirs) {
    my $full = "$JOBS_DIR/$dir";
    my $sdh;
    next unless opendir $sdh, $full;
    while (my $f = readdir($sdh)) {
        push @all_yaml_files, "$full/$f" if $f =~ /\.yaml$/;
    }
    closedir $sdh;
}

print "Loading ", scalar(@all_yaml_files), " existing YAML files...\n";

for my $file (@all_yaml_files) {
    # YAML::XS expects raw bytes; do NOT use :encoding(UTF-8)
    open my $fh, '<', $file or do { warn "Cannot read $file: $!"; next; };
    local $/;
    my $raw = <$fh>;
    close $fh;
    my $data = eval { Load($raw) };
    if ($@) {
        warn "YAML parse error for $file: $@\n";
        next;
    }
    next if !$data || ref($data) ne 'HASH';

    my ($id, $title, $company, $url, $status, $dir);
    $id      = $data->{id} // '';
    $title   = $data->{title} // '';
    $company = $data->{company} // '';
    $url     = $data->{url} // '';
    $status  = $data->{status} // $data->{stage} // '';
    $dir     = dirname($file);
    $dir =~ s|^\Q$JOBS_DIR\E/||;

    my $rec = {
        data    => $data,
        file    => $file,
        status  => $status,
        dir     => $dir,
        title   => $title,
        company => $company,
        url     => $url,
        id      => $id,
    };

    if (defined $id && $id =~ /^\d+$/) {
        $jobs_by_id{$id} = $rec;
    }

    my $key = normalize($title) . '||' . normalize($company);
    $jobs_by_key{$key} = $rec;
}

print "Indexed by ID: ", scalar(keys %jobs_by_id), ", by title+company: ", scalar(keys %jobs_by_key), "\n";

# ---------------------------------------------------------------------------
# Parse CSVs
# ---------------------------------------------------------------------------
my @imported;

sub parse_csv_simple {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "Cannot read $path: $!";
    my $header = <$fh>;
    $header = strip_bom($header) if defined $header;
    while (<$fh>) {
        chomp;
        next unless /\S/;
        my @cols = split /;/, $_;
        next if @cols < 3;
        my ($date, $company, $title, $status) = @cols;
        for my $c (\$company, \$title, \$status, \$date) {
            next unless defined $$c;
            $$c =~ s/^"|"$//g;
            $$c =~ s/^\s+|\s+$//g;
        }
        my $mapped = $STATUS_MAP{$status};
        next unless defined $mapped;
        push @imported, {
            title   => $title,
            company => $company,
            url     => undef,
            status  => $mapped,
            date    => $date,
            source  => 'csv-import',
            origin  => $path,
        };
    }
    close $fh;
}

sub parse_csv_extended {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "Cannot read $path: $!";
    my $header = <$fh>;
    $header = strip_bom($header) if defined $header;
    while (<$fh>) {
        chomp;
        next unless /\S/;
        my @cols = parse_line(';', 0, $_);
        next if @cols < 7;
        my ($nr, $date, $company, $title, $city, $score, $status, $app_date, $note, $url) = @cols;
        for my $c (\$company, \$title, \$status, \$date, \$app_date, \$url) {
            next unless defined $$c;
            $$c =~ s/^"|"$//g;
            $$c =~ s/^\s+|\s+$//g;
        }
        my $mapped = $STATUS_MAP{$status};
        next unless defined $mapped;
        my $use_date = $app_date || $date;
        push @imported, {
            title   => $title,
            company => $company,
            url     => $url,
            status  => $mapped,
            date    => $use_date,
            source  => 'csv-import',
            origin  => $path,
            score   => $score,
        };
    }
    close $fh;
}

# Determine CSV format by header
for my $csv (glob "$IMPORT_DIR/*.csv") {
    open my $fh, '<:encoding(UTF-8)', $csv or next;
    my $header = <$fh>;
    close $fh;
    next unless defined $header;
    $header = strip_bom($header);
    chomp $header;
    if ($header =~ /\bLink\b/ || $header =~ /\bBewerbungsdatum\b/ || $header =~ /\bUnternehmen\b/) {
        parse_csv_extended($csv);
    } else {
        parse_csv_simple($csv);
    }
}

# ---------------------------------------------------------------------------
# Parse HTML backups
# ---------------------------------------------------------------------------
sub parse_html_backup {
    my ($path) = @_;
    # Read HTML as raw bytes; TreeBuilder handles encoding from meta tag
    open my $fh, '<', $path or die "Cannot read $path: $!";
    local $/;
    my $html = <$fh>;
    close $fh;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse($html);
    $tree->eof;

    my @cards = $tree->look_down(_tag => 'div', class => qr/job-card/);

    for my $card (@cards) {
        my $stage = $card->attr('data-stage') // '';
        my $id    = $card->attr('data-id')    // '';
        my $mapped = $STATUS_MAP{$stage};
        next unless defined $mapped;

        my $title_a = $card->look_down(_tag => 'a', class => qr/card-title/);
        my $title   = $title_a ? $title_a->as_text : '';
        my $url     = $title_a ? $title_a->attr('href') : '';

        my $company_span = $card->look_down(_tag => 'span', class => qr/company/);
        my $company      = $company_span ? $company_span->as_text : '';

        my $score_span = $card->look_down(_tag => 'span', class => qr/score-badge/);
        my $score      = $score_span ? $score_span->as_text : '';

        my $date_span = $card->look_down(_tag => 'span', class => qr/card-date/);
        my $date      = $date_span ? $date_span->as_text : '';

        push @imported, {
            title   => $title,
            company => $company,
            url     => $url,
            status  => $mapped,
            date    => $date,
            source  => 'html-import',
            origin  => $path,
            score   => $score,
            html_id => $id,
        };
    }

    $tree->delete;
}

for my $html (glob "$IMPORT_DIR/*.htm*") {
    parse_html_backup($html);
}

# ---------------------------------------------------------------------------
# Deduplicate imported records (prefer higher-priority status)
# ---------------------------------------------------------------------------
my %import_by_id;
my %import_by_key;

for my $rec (@imported) {
    my $sid = extract_stepstone_id($rec->{url});
    $sid = $rec->{html_id} if !$sid && defined $rec->{html_id} && $rec->{html_id} =~ /^\d+$/;

    my $key = normalize($rec->{title}) . '||' . normalize($rec->{company});

    if (defined $sid) {
        if (!exists $import_by_id{$sid}) {
            $import_by_id{$sid} = $rec;
        } else {
            my $existing = $import_by_id{$sid};
            if ($STATUS_PRIORITY{$rec->{status}} > $STATUS_PRIORITY{$existing->{status}}) {
                $import_by_id{$sid} = $rec;
            }
        }
    } else {
        if (!exists $import_by_key{$key}) {
            $import_by_key{$key} = $rec;
        } else {
            my $existing = $import_by_key{$key};
            if ($STATUS_PRIORITY{$rec->{status}} > $STATUS_PRIORITY{$existing->{status}}) {
                $import_by_key{$key} = $rec;
            }
        }
    }
}

my @unique_imported = (values %import_by_id, values %import_by_key);
print "Raw imported: ", scalar(@imported), ", unique: ", scalar(@unique_imported), "\n";

# ---------------------------------------------------------------------------
# Merge logic
# ---------------------------------------------------------------------------
my $matched_updated = 0;
my $matched_skipped = 0;
my $created         = 0;
my @stale_files;

for my $irec (@unique_imported) {
    my $sid = extract_stepstone_id($irec->{url});
    $sid = $irec->{html_id} if !$sid && defined $irec->{html_id} && $irec->{html_id} =~ /^\d+$/;

    my $key = normalize($irec->{title}) . '||' . normalize($irec->{company});

    my $existing;
    if (defined $sid && exists $jobs_by_id{$sid}) {
        $existing = $jobs_by_id{$sid};
    } elsif (exists $jobs_by_key{$key}) {
        $existing = $jobs_by_key{$key};
    }

    if ($existing) {
        my $local_priority  = $STATUS_PRIORITY{$existing->{status}} // -1;
        my $import_priority = $STATUS_PRIORITY{$irec->{status}}    // -1;

        if ($import_priority <= $local_priority) {
            $matched_skipped++;
            next;
        }

        # Update existing job
        my $data = $existing->{data};
        $data->{status} = $irec->{status};
        $data->{stage}  = $irec->{status};
        if ($irec->{status} eq 'applied' && $irec->{date}) {
            $data->{date_applied} = $irec->{date};
        }
        if (!$data->{url} && $irec->{url}) {
            $data->{url} = $irec->{url};
        }
        if (!$data->{company} && $irec->{company}) {
            $data->{company} = $irec->{company};
        }
        if (!$data->{title} && $irec->{title}) {
            $data->{title} = $irec->{title};
        }

        my $new_dir = "$JOBS_DIR/$irec->{status}";
        make_path($new_dir) unless -d $new_dir;
        my $base = basename($existing->{file});
        my $new_file = "$new_dir/$base";

        # Write raw bytes
        open my $out, '>', $new_file or die "Cannot write $new_file: $!";
        print $out Dump($data);
        close $out;

        if ($new_file ne $existing->{file} && -f $existing->{file}) {
            unless (unlink $existing->{file}) {
                push @stale_files, $existing->{file};
            }
        }

        $existing->{file}   = $new_file;
        $existing->{status} = $irec->{status};
        $existing->{dir}    = $irec->{status};
        $existing->{data}   = $data;

        $matched_updated++;
    } else {
        # Create new minimal entry
        my $target_status = $irec->{status};
        my $target_dir = "$JOBS_DIR/$target_status";
        make_path($target_dir) unless -d $target_dir;

        my $file_id;
        if (defined $sid) {
            $file_id = $sid;
        } else {
            my $md5 = md5_hex(encode_utf8(normalize($irec->{title}) . normalize($irec->{company})));
            $file_id = 'import-' . substr($md5, 0, 8);
        }

        my $out_file = "$target_dir/$file_id.yaml";
        if (-f $out_file) {
            my $counter = 1;
            while (-f "$target_dir/$file_id-$counter.yaml") {
                $counter++;
            }
            $out_file = "$target_dir/$file_id-$counter.yaml";
        }

        my %new_yaml = (
            id      => $file_id,
            title   => $irec->{title},
            company => $irec->{company},
            status  => $target_status,
            source  => 'csv-import',
        );
        $new_yaml{url} = $irec->{url} if $irec->{url};
        $new_yaml{date_applied} = $irec->{date} if $irec->{date} && $target_status eq 'applied';

        open my $out, '>', $out_file or die "Cannot write $out_file: $!";
        print $out Dump(\%new_yaml);
        close $out;

        # Register in index to prevent duplicates from later iterations
        my $new_rec = {
            data    => \%new_yaml,
            file    => $out_file,
            status  => $target_status,
            dir     => $target_status,
            title   => $irec->{title},
            company => $irec->{company},
            url     => $irec->{url},
            id      => $file_id,
        };
        if (defined $sid) {
            $jobs_by_id{$sid} = $new_rec;
        }
        $jobs_by_key{$key} = $new_rec;

        $created++;
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print "\n=== Import Summary ===\n";
print "Matched and updated: $matched_updated\n";
print "Matched and skipped: $matched_skipped\n";
print "New entries created: $created\n";
print "Total unique imported: ", scalar(@unique_imported), "\n";

if (@stale_files) {
    print "\n=== Stale files to remove manually ===\n";
    for my $f (@stale_files) {
        print "$f\n";
    }
    print "(Run: sudo rm -f ", join(' ', map { quotemeta } @stale_files), ")\n";
}

#,,.,,.,.,...,.,.,,,,,...,,..,.,.,..,,,.,,,..,..,,...,..,,,,.,,.,,...,...,,,,,
#SNAMZZE4VXHX35IE2NFRYLBFIHH62BSC2L4ISGBMAI2TUDFE3YKABTWB2UH34KK32HLCGGNXACWGE
#\\\|KFIRCLR6FN5WKMMETSFF7QEY3KMNYHAXDZ7BTPDM3UDZXJQ7LC3 \ / AMOS7 \ YOURUM ::
#\[7]GMCSQXFK6GUYE6ZGUS3Q4FH2MIRHVPV7T5V634EJ72TZMMSRIMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
