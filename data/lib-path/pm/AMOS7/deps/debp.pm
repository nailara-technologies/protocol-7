package AMOS7::deps::debp;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| probe_apt probe_apt_fresh install_apt |;

my $_apt_cache;

sub _apt_cache {
    unless ( defined $_apt_cache ) {
        eval { require AptPkg::Cache; $_apt_cache = AptPkg::Cache->new };
        $_apt_cache = undef if $@;
    }
    return $_apt_cache;
}

##[ probe_apt ]###############################################################

sub probe_apt {
    my ($pkg) = @_;

    return 0 unless defined $pkg && length $pkg;

    my $cache = _apt_cache();
    if ( defined $cache ) {
        my $p = $cache->{$pkg};
        return ( defined $p && $p->{CurrentState} eq 'Installed' ) ? 1 : 0;
    }

    ## fallback: dpkg-query if AptPkg unavailable ##
    my $out = `dpkg-query -W -f='\${Status}' "$pkg" 2>/dev/null`;
    return ( defined $out && $out =~ m|install ok installed| ) ? 1 : 0;
}

##[ probe_apt_fresh ]#########################################################

## dpkg-query per package [ ~3 ms ] : always the current state, no apt   ##
## cache in the process                                                  ##
## [ AptPkg::Cache : ~0.4 s, ~70 MB, never updated after an install ] -- ##
## for long-lived processes [ v7-zenki ]. no shell : the name goes to    ##
## dpkg-query as an argument                                             ##

sub probe_apt_fresh {
    my ($pkg) = @_;

    return 0 unless defined $pkg && $pkg =~ m|^[a-z0-9][a-z0-9.+\-~]*$|;

    my $pid = open( my $fh, '-|' );
    return 0 unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>', '/dev/null' );
        exec {'dpkg-query'} 'dpkg-query', '-W', '-f=${Status}', $pkg;
        exit 1;
    }
    my $out = do { local $/; <$fh> }
        // '';
    close($fh);

    return $out =~ m|install ok installed| ? 1 : 0;
}

##[ install_apt ]#############################################################

## optional leading CODE ref : an output sink, called once per apt-get      ##
## output line [ the root runner streams it to its parent ] -- package      ##
## names can never be code refs. no shell : apt-get and lslocks run         ##
## list-form, a name that could read as an option or holds whitespace fails ##
## before anything runs                                                     ##
sub install_apt {
    my $sink = ( @_ and ref $_[0] eq 'CODE' ) ? shift : undef;
    my (@pkgs) = @_;

    return { ok => [], failed => [] } unless @pkgs;

    return { ok => [], failed => [@pkgs] } if $EUID != 0;

    return { ok => [], failed => [@pkgs] }
        if grep { not defined $_ or $_ !~ m|\A[A-Za-z0-9][^\s]*\z| } @pkgs;

    local $ENV{'APT_LISTCHANGES_FRONTEND'} = 'none';
    local $ENV{'UCF_FORCE_CONFFOLD'}       = 'true';
    local $ENV{'UCF_FORCE_CONFMISS'}       = 'true';
    local $ENV{'DEBCONF_PRIORITY'}         = 'critical';
    local $ENV{'DEBIAN_FRONTEND'}          = 'noninteractive';
    local $ENV{'PAGER'}                    = '/bin/true';
    local $ENV{'LANG'}                     = 'en_US.UTF-8';

    my $max_fail = 5;
    my $ok       = 0;
    my @failed;
    my @installed;

    while ( !$ok and $max_fail-- ) {
        my $warned = 0;
        my $wait   = 2 + int( rand(5) );

        ## wait for dpkg lock ##
        while ( _dpkg_locked() and $wait = 11 or $wait-- ) {
            if ( $wait > 10 and !$warned++ ) {
                warn "auto_install: waiting for dpkg lock ...\n";
            }
            select( undef, undef, undef, 0.33 );
        }

        my ( $result, $output )
            = _run_output( $sink, qw| apt-get -fy install |, @pkgs );

        if ( not defined $result ) {
            warn "apt-get failed to execute: $!\n";
            push @failed, @pkgs;
            last;
        } elsif ( $result == 0 ) {
            push @installed, @pkgs;
            $ok = 1;
        } elsif ( $output =~ m|Unable to locate package| ) {
            warn "package not found — cannot continue\n";
            push @failed, @pkgs;
            last;
        } else {
            warn ": retrying automatic installation ..,\n";
            push @failed, @pkgs if $max_fail == 0;
        }
    }

    ## invalidate memoized apt package state cache ##
    $_apt_cache = undef;

    return { ok => \@installed, failed => \@failed };
}

## list-form command, stderr joined into stdout : ( $? , all output ) ##
## [ undef $? when the fork failed ], each line to $sink when given   ##
sub _run_output {
    my ( $sink, @cmd ) = @_;

    my $pid = open( my $fh, '-|' );
    return ( undef, '' ) unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        exec { $cmd[0] } @cmd;
        exit 127;
    }

    my $output = '';
    while ( my $line = <$fh> ) {
        $output .= $line;
        if ( defined $sink ) {
            chomp( my $text = $line );
            $sink->($text);
        }
    }
    close($fh);

    return ( $?, $output );
}

## a dpkg lock held [ lslocks list-form, a missing lslocks reads as ##
## unlocked -- as the former shell pipe did ]                       ##
sub _dpkg_locked {
    my $pid = open( my $fh, '-|' );
    return 0 unless defined $pid;
    if ( $pid == 0 ) {
        open( STDERR, '>', '/dev/null' );
        exec {'lslocks'} 'lslocks';
        exit 127;
    }
    my $locked = grep {m|^dpkg|} <$fh>;
    close($fh);

    return $locked ? 1 : 0;
}

1;

#,,..,,.,,...,.,.,..,,,,.,,,,,...,,.,,..,,...,..,,...,...,..,,,,.,.,,,...,.,.,
#MNHHCEBFVC6GNFRKC7G6B5NAJ5DB2IIJXCJUEBDZGY4I3QPRKUQIAHR2QT34PALQI7VOJDXU7CWXC
#\\\|7CFHJ7ATJXKGZNAIZEBSTZQ6GQZQOY27TVM7JLN5WDE2PGTFKOS \ / AMOS7 \ YOURUM ::
#\[7]GWRATMOXTKV3FFY3MAR2AYPRCQFP5KZG2RHQDNGT35NMT4K4PIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
