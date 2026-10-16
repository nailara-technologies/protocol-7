package AMOS7::deps::backend::debian;

use strict;
use warnings;
use English;

## debian-family backend : the interface AMOS7::deps::os_package dispatches ##
## to by family name. AMOS7::deps::debp stays the implementation            ##
## [ bin/p7-deps and bin/os-pkg import from it directly ] and is called     ##
## FULLY QUALIFIED -- compile-time sub imports break when Module::Refresh   ##
## wipes the shared CV during a live v7 reload [ %DB::sub active ], see the ##
## comment at AMOS7::deps::os_package                                       ##

use AMOS7::deps::debp;

sub name       { return qw| debian | }
sub needs_root { return 1 }

##[ probe ]###################################################################

## $fresh : the current dpkg state per call, no in-process apt cache  ##
## [ long-lived processes -- see AMOS7::deps::debp::probe_apt_fresh ] ##
sub probe {
    my ( $pkg, $fresh ) = @_;

    return AMOS7::deps::debp::probe_apt_fresh($pkg) if $fresh;
    return AMOS7::deps::debp::probe_apt($pkg);
}

##[ install ]#################################################################

## pass-through : the { ok, failed } hashref contract of  debp::install_apt ##
## IS the debian-family contract and stays unchanged -- 'manual' is empty   ##
## by definition on debian                                                  ##
## [ no admin-side action needed beyond apt itself ]. an optional leading   ##
## CODE ref is the output sink of the interface                             ##
## [ one call per output line, used by AMOS7::deps::root_runner ] and       ##
## passes through as well                                                   ##
sub install {
    my (@args) = @_;

    return AMOS7::deps::debp::install_apt(@args);
}

##[ refresh ]#################################################################

## documented no-op : debp offers no apt cache refresh [ apt-get update ] ##
## -- the AptPkg cache lives and dies inside the probing process and      ##
## debp::install_apt already invalidates it after a successful install    ##
sub refresh { return 1 }

1;

#,,..,..,,..,,.,.,,,.,,..,...,...,.,,,,,.,,,,,..,,...,...,,..,.,,,,,.,,,,,,,,,
#HHKXVCGDWKZCSTS57GC3NHKY2UG7MIBQTPWEXHYB3HSVVCDF6A23BBRDCLTR7Z4MVRMYFMJAJPS2C
#\\\|6FV5ECP4DGZWHOLJGVVIWEIL2AN25HFOS2Y5IPFQCG4C5AUDX6H \ / AMOS7 \ YOURUM ::
#\[7]VBOWVI7VVKGHXKLRKIHLV36Z5BLKHYMB2DCMLLC3FYVTFOPZCKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
