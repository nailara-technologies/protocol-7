#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;
use lib '/data/projects/protocol-7/data/lib-path/pm';
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

my $dec = load_module('/data/projects/protocol-7/modules/base.stdio.frame.decode');

my $good_buf = chr(0x82) . chr(0x56) . chr(0x38);
my @recs = eval { $dec->(\$good_buf) };
if ($@) { print "died: $@"; }
else {
    print "records: ", scalar(@recs), "\n";
    if (@recs) {
        print "tag: ", $recs[0]->{'tag'}, "\n";
        print "encoding: ", $recs[0]->{'encoding'}, "\n";
        print "buf left: ", length($good_buf), "\n";
    }
}

#,,..,,.,,.,.,.,,,.,,,...,,,.,...,...,,,,,.,.,..,,...,..,,.,.,,,,,...,.,,,,,,,
#3B5TGKGMHXSTDG2DL3L4IAMB4ZDD4OEJUXI4DK77ZMTJE6MY7IVCXYS6K7MWQUIA3GUNGIVO43AZM
#\\\|FA3VJSTWQ3JKXQZXTN5SH2GAM7S3LLQQFNP3CPHXDEXUCUAHA2R \ / AMOS7 \ YOURUM ::
#\[7]YCG77Q6LQS3YDZVHTTFBP7HMMUAASY73YECLEROXMJRX2ZQ3SSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
