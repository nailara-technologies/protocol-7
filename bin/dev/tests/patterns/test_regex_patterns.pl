#!/usr/bin/perl
## Test file for regex style correction

use strict;
use warnings;

# These should be converted from s/// to s|||
$text   =~ s/^- \[ \]/- [x]/;
$path   =~ s|^$scan_dir||;
my $var =~ s/\n$//;

# These already use good styles
$cmd_string                      =~ s|\n| \\\n|mg;
$file_name                       =~ s|^.*\/||;
( my $power_str = $power_level ) =~ s|DPMSMode(\w+)|uc($1)|e;

# Mixed - some need fixing
$data  =~ s/old/new/;
$value =~ s|\s+||g;

# Return value corrections needed
sub validate_input {
    return 1 if $input;
    return 0;
}

sub check_status {
    if ( $status eq 'ok' ) {
        return 1;
    }
    return 0;
}

#,,,,,.,.,,.,,...,...,...,..,,,,,,,..,.,.,..,,..,,...,...,,..,,,.,.,,,,,.,...,
#SBJV3PJEWUQWS4SZCGH5G2MMUZN77LYIHQAFUX45FGXUDFRA5YDCX6M6W4LVRZJNOTPZ4MQLXWVRO
#\\\|HGQ55XUCWXIMKO7BAAK5CCA5MBE7FBVGI77MMDF36IDLRTJISBW \ / AMOS7 \ YOURUM ::
#\[7]WFRQKEKLSILSOUG2UYZMYJ2GBJ5L5H333D3ET3RMF4ZCYPTEWMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
