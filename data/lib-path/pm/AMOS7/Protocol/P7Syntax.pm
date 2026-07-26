
package AMOS7::Protocol::P7Syntax;   #########################################

use v5.24;
use strict;
use English;
use warnings;

our $VERSION = qw| AMOS-Protocol-P7Syntax-XKC91QZ |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

@EXPORT = qw[ ];

@EXPORT_OK = qw| $VERSION p7_syntax__translate |;

## deliberately dependency-free : no 'use AMOS7'/'use AMOS7::CHKSUM' --     ##
## this sub is also called from bin/Protocol-7's own bootstrap, before base ##
## is loaded, so nothing here may pull in a chain that could affect boot    ##
## order                                                                    ##

##[ P7 -> PERL SYNTAX TRANSLATION ]###########################################

## kept in lockstep with the inline copy in bin/Protocol-7 by hand -- see   ##
## the comment there. duplicated instead of shared because bin/Protocol-7   ##
## needs this before 'use lib' for data/lib-path/pm is safe to rely on that ##
## early in boot, and ptd/format-code need a real module they can 'use'     ##
sub p7_syntax__translate
{    ## p7 syntax -> perl [ becomes base.syntax.translate ]

    my $str = shift // '';

    # transform special syntax [non-destructive with /r flag]
    # preserve escaping with (?<!\\) negative lookbehind
    return $str =~ s|(?<!\\)<\[([\w\-\.]+)\]>\s*->\(|\$code{'$1'}->(|gr
        =~ s|(?<!\\)<\[([\w\-\.]+)\]>|\$code{'$1'}->()|gr
        =~ s|(?<!\\)<\[(\$\w+)\]>\s*->\(|\$code{$1}->(|gr
        =~ s|(?<!\\)<\[(\$\w+)\]>|\$code{$1}->()|gr
        =~ s|(?<!\\)<([\w\-:]+\.[\w\-\.:]+)>|
        do { my $k = "\$data{'$1'}";
             $k =~ s<\.><'}{'>g; $k }|reg;
}

return 5;  ###################################################################

#,,.,,,.,,,..,,,.,.,,,,,.,,,.,,,,,,,.,,.,,.,,,..,,...,...,,..,,,,,.,.,..,,,.,,
#TLP2BJQ42SRZ6BPV3WGYVU36WUPXLZC6AS2E6AXLXDJRYP6EWABIXVUYKDXTJOGWWYTHQIJGVVFKQ
#\\\|XSISJGEPDPU2XJLTLG74TSTPFAU735GKKN7GQCLIJMCIDRYOCEM \ / AMOS7 \ YOURUM ::
#\[7]C627KPNUNLBBPPMPUUNTMTNDMWB2GD6M7U2A7GCO3DMZLOMWBMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
