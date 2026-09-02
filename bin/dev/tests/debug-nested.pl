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

my $scope_enter = $enc->('META', 'byte-pack', '', {
    'subtype' => 'scope-enter',
    'hop_id' => 42,
    'slot_addr' => 'v7-zenki.console',
    'origin' => 'weather'
});

my $eout_run = $enc->('EOUT', 'b32', 'loaded config', { 'fd' => 1 });

my $scope_leave = $enc->('META', 'byte-pack', '', {
    'subtype' => 'scope-leave',
    'origin' => 'weather'
});

print "scope_enter length: ", length($scope_enter), "\n";
print "eout_run length: ", length($eout_run), "\n";
print "scope_leave length: ", length($scope_leave), "\n";

my $nested_buf = $scope_enter . $eout_run . $scope_leave;
my @recs = eval { $dec->(\$nested_buf) };
if ($@) { print "died: $@"; }
print "records: ", scalar(@recs), "\n";
print "buf left: ", length($nested_buf), "\n";
for my $i (0..$#recs) {
    print "rec $i: tag=", $recs[$i]->{'tag'}, 
          " enc=", $recs[$i]->{'encoding'},
          " subtype=", ($recs[$i]->{'header'}->{'subtype'} // 'n/a'), "\n";
}

#,,..,,,.,,,,,.,,,...,,..,,,.,,,.,.,,,,,.,,,,,..,,...,...,.,,,,.,,,.,,.,,,.,,,
#RHS3IPTDAA6ZHV5HVXFDQ7Q2IHOOTTECFNVIMAHMY7AQWQGXSLXFHISGURRVQVFFM2LWM3B6YKQU6
#\\\|VC45PSK6AMUKCRSO2L6N3I2HFYJNBN5TKBRJQGUH33CGDXQLAB3 \ / AMOS7 \ YOURUM ::
#\[7]N2YL6NQJQZDRWCTZPGM7GY5KJQJXPZEMKC7U72VBBXEP2X5VU2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
