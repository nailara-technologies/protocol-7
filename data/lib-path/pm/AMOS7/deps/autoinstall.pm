package AMOS7::deps::autoinstall;
our $VERSION = qw| AMOS7::deps::autoinstall-VERSION.LI3BCNQ |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

use File::Spec;
use File::Path qw| make_path |;
use File::stat qw| lstat |;

our @EXPORT_OK = qw| status enable disable trusted_chain |;

##[ auto-install opt-in management ]##########################################
##
## one implementation behind 'bin/p7-deps enable-auto-install' and the
## p7-install '-auto-install-deps' step. the opt-in itself is the host overlay
## line 'v7-zenki.cfg.auto_install_deps = yes' in
## /etc/protocol-7/host-config/v7-zenki.cfg [ applied by
## base.load_host_config ; gated root + host opt-in everywhere the strategic
## install fires ]. enabling CREATES the overlay when absent and merges the
## line into an existing one -- other host settings are never touched. every
## path component is verified against the  base.host.trusted_file rules
## [ root or tree owner, no group \ other write up to '/' ] -- verification
## reports, it never chmods what it did not create. all functions take an
## optional etc-root override [ testing \ P7_INSTALL_ROOT ] -- default
## /etc/protocol-7

my $CFG_KEY   = qw| v7-zenki.cfg.auto_install_deps |;
my $ZENKA     = qw| v7-zenki |;
my $FILE_MODE = 0644;
my $DIR_MODE  = 0755;

sub overlay_path {
    my $etc_root = shift // qw| /etc/protocol-7 |;
    return File::Spec->catfile(
        $etc_root,
        qw| host-config |,
        $ZENKA . qw| .cfg |
    );
}

sub _tree_owner {
    my $root_path = shift // '';
    return undef if not length $root_path or not -e $root_path;
    my $stat = lstat($root_path);
    return defined $stat ? $stat->uid : undef;
}

sub trusted_chain {
    my $path       = shift // '';
    my $tree_owner = shift;

    my %owner_ok = ( 0 => 1 );
    $owner_ok{$tree_owner} = 1
        if defined $tree_owner and $tree_owner != 0;

    return ( 0, 'not an absolute path' ) if index( $path, qw| / | ) != 0;
    return ( 0, 'symlink' )              if -l $path;
    return ( 0, 'missing' )              if not -e $path;

    my @check = ($path);
    ( my $dir = $path ) =~ s{/[^/]+$}{};
    while ( length $dir ) {
        push @check, $dir;
        $dir =~ s{/[^/]*$}{};
    }
    push @check, qw| / |;

    foreach my $entry (@check) {
        my $stat = lstat($entry);
        return ( 0, "$entry : cannot stat" ) if not defined $stat;
        return ( 0, "$entry : symlink" )     if -l $entry;
        return ( 0, sprintf '%s : owner uid %d not trusted',
            $entry, $stat->uid )
            if not $owner_ok{ $stat->uid };
        return ( 0, sprintf '%s : mode %#o, group \ other writable',
            $entry, $stat->mode & 07777 )
            if $stat->mode & 0022;
    }
    return ( 1, 'trusted' );
}

sub status {
    my $etc_root = shift;
    my $path     = overlay_path($etc_root);

    return ( 'absent',     $path, undef ) if not -e $path;
    return ( 'unreadable', $path, undef )
        if not -f $path or -l $path;

    open( my $fh, '<', $path ) or return ( 'unreadable', $path, undef );
    my $value;
    while ( my $line = <$fh> ) {
        next if $line =~ m{^\s*#};
        $value = $1 if $line =~ m{^\s*\Q$CFG_KEY\E\s*=\s*(\S+)};
    }
    close($fh);

    return ( defined $value ? $value : 'unset', $path, $value );
}

sub _merge_overlay {
    my ( $path, $value ) = @ARG;

    my @lines;
    if ( -e $path ) {
        open( my $fh, '<', $path ) or return undef;
        @lines = <$fh>;
        close($fh);
    }

    my $replaced = 0;
    foreach my $line (@lines) {
        next if $line =~ m{^\s*#};
        if ( $line =~ s{^(\s*\Q$CFG_KEY\E\s*=\s*)\S+}{$1$value} ) {
            $replaced = 1;
        }
    }
    if ( not $replaced ) {
        push @lines,
              sprintf "\n##  auto-install of missing dependencies  "
            . "##\n##  [ managed : bin/p7-deps "
            . "enable-auto-install ]  ##\n%s = "
            . "%s\n", $CFG_KEY, $value;
    }

    my $tmp_path = $path . '.tmp';
    open( my $out, '>', $tmp_path ) or return undef;
    print {$out} @lines;
    close($out);
    chmod $FILE_MODE, $tmp_path;
    return rename( $tmp_path, $path ) ? 1 : undef;
}

sub _write_enable {
    my ( $etc_root, $value, $tree_owner ) = @ARG;

    return ( 0, 'needs root' ) if $EUID != 0 and $UID != 0;

    my $dir  = File::Spec->catdir( $etc_root, qw| host-config | );
    my $path = overlay_path($etc_root);

    return ( 0, "refusing symlink [ $path ]" ) if -l $path;

    if ( not -d $dir ) {
        if ( not make_path( $dir, { mode => $DIR_MODE } ) ) {
            return ( 0, "cannot create [ $dir ] : $OS_ERROR" );
        }
        chmod $DIR_MODE, $dir;
        chown 0, 0, $dir;
    }

    my $existed  = -e $path ? 1                     : 0;
    my $prev_uid = $existed ? ( lstat($path) )->uid : undef;

    if ( not _merge_overlay( $path, $value ) ) {
        return ( 0, "cannot write [ $path ] : $OS_ERROR" );
    }

    ##  ownership : preserve a trusted existing owner, else root  ##
    my $owner_ok = defined $prev_uid
        && ( $prev_uid == 0
        || ( defined $tree_owner && $prev_uid == $tree_owner ) );
    if ( not $existed or not $owner_ok ) {
        chown 0, 0, $path;
    }

    return ( 1,
        sprintf '%s [ %s ]', $existed ? 'updated' : 'created', $path );
}

sub enable {
    my %param    = @ARG && ref $ARG[0] eq qw| HASH | ? %{ $ARG[0] } : ();
    my $etc_root = $param{'etc'} // qw| /etc/protocol-7 |;
    my ( $ok, $message )
        = _write_enable( $etc_root, qw| yes |,
        _tree_owner( $param{'tree'} // '' ) );
    return ( $ok, $message, overlay_path($etc_root) );
}

sub disable {
    my %param    = @ARG && ref $ARG[0] eq qw| HASH | ? %{ $ARG[0] } : ();
    my $etc_root = $param{'etc'} // qw| /etc/protocol-7 |;
    return ( 0, 'no host overlay present', overlay_path($etc_root) )
        if not -e overlay_path($etc_root);
    my ( $ok, $message )
        = _write_enable( $etc_root, qw| no |,
        _tree_owner( $param{'tree'} // '' ) );
    return ( $ok, $message, overlay_path($etc_root) );
}

1;

#,,..,.,.,,,,,...,...,..,,,..,,..,,..,...,,..,..,,...,...,,.,,.,.,,,.,..,,,,.,
#BPXKIR5E5EPPPMLUCX7SKXOK6GMEUVEGZELVDZEJP6V7EKWH3JZQTGPA4PBJVOXSQOB7DM2FI5DA4
#\\\|6IGFSK2EFBDQ4A2XH5IJ4HYCPRVFGZZHCEKPQLHHPTOEZIJIDZW \ / AMOS7 \ YOURUM ::
#\[7]62DFZTIVGHLZXZUMTWEMZMTR5DO7B5QZHQTRHMZFW6DFQ4FTBEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
