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

my $full = $enc->('STR', 'byte-pack', 'partial test', {});
print "full length: ", length($full), " bytes\n";

my $buf = '';
for my $i (0 .. length($full)-1) {
    $buf .= substr($full, $i, 1);
    my @r = eval { $dec->(\$buf) };
    if ($@) { print "byte $i: died: $@"; }
    elsif (@r) { print "byte $i: got ", scalar(@r), " record(s), buf left: ", length($buf), "\n"; }
}
print "final buf length: ", length($buf), "\n";

#,,,.,.,.,,,,,...,...,,..,,..,..,,...,.,,,,,.,..,,...,...,,,.,.,,,,.,,,,,,,.,,
#J3QHCHHENSR4TSZEJEIXFOUUGPXVIHUT5LZRP3GQU47DNDTQ3HFK4RC52XREUXLIXPIOW5Z4EN6WO
#\\\|CJOSZR6EGN72XX2XRRB77XKXJDHPPOA3X343ISZZMEM7ZKKNTSX \ / AMOS7 \ YOURUM ::
#\[7]Z4J3OYXYGMGCESPJ24XUFXHWP4QLQK24G5TNIU7CKZLMOKMMP4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
