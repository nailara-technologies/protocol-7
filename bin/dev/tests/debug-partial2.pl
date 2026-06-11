#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;
use lib '/data/projects/protocol-7/data/lib-path/pm';
use AMOS7::STDIO::Tags;
use Crypt::Misc;

sub load_module {
    my $path = shift;
    open my $fh, '<', $path or die;
    local $/;
    my $src = <$fh>;
    close $fh;
    my $cref = eval "sub {\nuse v5.24;\nuse strict;\nuse warnings;\nuse English;\n$src\n}";
    die "compile error: $@" if $@;
    return $cref;
}

my $enc = load_module('/data/projects/protocol-7/modules/base.stdio.frame.encode');
my $dec = load_module('/data/projects/protocol-7/modules/base.stdio.frame.decode');

my $full_enc = $enc->('STR', 'byte-pack', 'partial test', {});
print "full_enc length: ", length($full_enc), "\n";

my @byte_at_a_time;
my $partial_buf = '';
for my $i (0 .. length($full_enc) - 1) {
    $partial_buf .= substr($full_enc, $i, 1);
    my @r = eval { $dec->(\$partial_buf) };
    if ($@) { print "byte $i: died: $@"; }
    push @byte_at_a_time, \@r;
    if (@r) { print "byte $i: got ", scalar(@r), " recs, buf=", length($partial_buf), "\n"; }
}

my @all = map { @$_ } @byte_at_a_time;
print "all_from_partial count: ", scalar(@all), "\n";

#,,,,,.,.,...,,,,,,,.,.,.,,,,,,,,,..,,.,,,,..,..,,...,...,,,,,..,,.,,,,,,,,..,
#57HOMHDBMTUZJ75HJ256SBUEONL46FG3RVNRW6Q5KFQ5DA3H25BN4553DGJNM7CWF2FTSGVNHFFYQ
#\\\|SOIR32KHXYCZOSQKWGLTW5TOW5T6YAJA3SRN4ID7F23W7OY3DWT \ / AMOS7 \ YOURUM ::
#\[7]IWORKT2BC3LKJGWPHXZZLZV526LAFVHDC2NAQP6JVGPS4CW4B6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
