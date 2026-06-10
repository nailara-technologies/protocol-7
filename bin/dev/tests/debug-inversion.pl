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

my $bad_buf = chr(0x00);
my @bad_recs = eval { $dec->(\$bad_buf) };
my $bad_err = $@;

print "bad_recs count: ", scalar(@bad_recs), "\n";
print "bad_err defined: ", defined($bad_err), "\n";
print "bad_err length: ", length($bad_err // ''), "\n";
print "bad_err content: [$bad_err]\n";
print "bad_recs[0] defined: ", defined($bad_recs[0]), "\n";

my $cond = !defined $bad_recs[0] && length $bad_err;
print "condition: ", ($cond ? "true" : "false"), "\n";

#,,,.,...,,,,,.,.,,.,,.,,,...,,,.,.,,,,,.,..,,..,,...,...,.,,,.,,,,..,...,,,,,
#7ZHSOO77W3FY7NN6UC2CGGKH4JSYVCA2GOMUZBGRIEV3IX4MJX2UUTVOXBMVTT5JINGYJAD6UDWA2
#\\\|OKMLIZFWRS6OSBZMBT3YFIAG4LBGALQG5AJTNUFB3753KETHRKL \ / AMOS7 \ YOURUM ::
#\[7]GWDYBB67CXPENR7THKOXH24TFC2LY5LOK4G7GC6I7EGLJMWIGGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
