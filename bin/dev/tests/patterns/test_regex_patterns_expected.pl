#!/usr/bin/perl
## Test file for regex style correction

use strict;
use warnings;

# These should be converted from s/// to s|||
$text   =~ s|^- \[ \]|- [x]|;
$path   =~ s|^$scan_dir||;
my $var =~ s|\n$||;

# These already use good styles
$cmd_string                      =~ s|\n| \\\n|mg;
$file_name                       =~ s|^.*\/||;
( my $power_str = $power_level ) =~ s|DPMSMode(\w+)|uc($1)|e;

# Mixed - some need fixing
$data  =~ s|old|new|;
$value =~ s|\s+||g;

# Return value corrections needed
sub validate_input {
    return TRUE if $input;
    return FALSE;
}

sub check_status {
    if ( $status eq 'ok' ) {
        return TRUE;
    }
    return FALSE;
}

#,,,,,..,,,,,,,..,..,,.,.,..,,,..,..,,.,.,,.,,..,,...,..,,,.,,.,.,.,,,...,,,.,
#PECEBHI2RVSSGG2JI2PFJ6URF274Z22HUMI76BYXKCKC7ZPGOGXX5MGMDMYFSYDSPUIWEUIJI5VX6
#\\\|L5L33IOTISEA3UP6VYYONPQJ32LWLP422EUQSOQSFVYTSWYUFYR \ / AMOS7 \ YOURUM ::
#\[7]2XWMN5WENCBH7FCB627UZFK2L52PUA3ENWVHK4LTDJVKWU55VGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
