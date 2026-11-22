package AMOS7::Config::Source::Disk;
our $VERSION = qw| AMOS7::Config::Source::Disk-VERSION.IP3LPLI |;

use v5.32;
use strict;
use warnings;
use English;
use Cwd ();

##[ config source : the disk tree ]###########################################
#
# one of the sources of AMOS7::Config::Reader. a source answers three calls :
#
#   exists( $name )  -> true when the entry is there
#   lines( $name )   -> arrayref of raw lines, undef when it cannot be read
#   trust( $name )   -> ( ok, reason ) : may the entry be applied
#
# names are relative to the tree root [ `cfg/shared-params` ] or absolute
# [ a layer outside the tree : /etc/protocol-7/.. ]. an inline or remote
# source answers the same three calls for the same names
#
# trust : an entry inside the tree is trusted [ the tree is the code ]. an
# entry outside it follows src/base.host.trusted_file : regular file, no
# symlink, and the file and every directory up to '/' owned by root or by
# the tree owner [ never the zenka user ] with no group \ other write

sub new {
    my ( $class, %opts ) = @ARG;

    my $root = $opts{'root'} // '';
    $root =~ s{/+$}{};
    die "AMOS7::Config::Source::Disk : root is not a directory\n"
        if not length $root or not -d $root;

    my %owner_ok = ( 0 => 1 );
    my @tree     = CORE::stat $root;
    if (@tree) {
        my $zenka_uid
            = ( CORE::getpwnam( $opts{'zenka_user'} // 'protocol-7' ) )[2]
            // -1;
        $owner_ok{ $tree[4] } = 1 if $tree[4] != $zenka_uid;
    }

    return bless { 'root' => $root, 'owner_ok' => \%owner_ok }, $class;
}

sub root { return $ARG[0]->{'root'} }

## the file behind a name, undef when the name is not usable ##
sub path {
    my ( $self, $name ) = @ARG;

    return undef if not defined $name or not length $name;
    return undef if $name =~ m{(?:^|/)\.\.?(?:/|$)};    ## no . \ .. parts ##
    return undef if $name =~ m{\x00};
    return $name if index( $name, '/' ) == 0;
    return "$self->{'root'}/$name";
}

sub in_tree {
    my ( $self, $name ) = @ARG;

    my $path = $self->path($name) // return 0;
    return 0 if index( $path, "$self->{'root'}/" ) != 0;

    ## a symlink inside the tree may point outside it : resolved path has ##
    ## to stay under the resolved root                                    ##
    my $real_root = Cwd::realpath( $self->{'root'} ) // return 0;
    ## missing : no escape ##
    my $real_path = Cwd::realpath($path) // return 1;
    return index( $real_path, "$real_root/" ) == 0 ? 1 : 0;
}

sub exists {
    my ( $self, $name ) = @ARG;

    my $path = $self->path($name) // return 0;
    return -f $path ? 1 : 0;
}

sub lines {
    my ( $self, $name ) = @ARG;

    my $path = $self->path($name) // return undef;
    open( my $fh, '<:encoding(UTF-8)', $path ) or return undef;
    my @lines = <$fh>;
    close $fh;
    return \@lines;
}

sub trust {
    my ( $self, $name ) = @ARG;

    my $refuse = sub { return wantarray ? ( 0, shift ) : 0 };
    my $path   = $self->path($name);

    return $refuse->('path not valid')   if not defined $path;
    return wantarray ? ( 1, 'tree' ) : 1 if $self->in_tree($name);

    return $refuse->('missing')            if not -e $path and not -l $path;
    return $refuse->('symlink')            if -l $path;
    return $refuse->('not a regular file') if not -f $path;

    my @check = ($path);
    ( my $dir = $path ) =~ s{/[^/]+$}{};
    while ( length $dir ) {
        push @check, $dir;
        $dir =~ s{/[^/]*$}{};
    }
    push @check, '/';

    foreach my $entry (@check) {
        my @stat = CORE::lstat $entry;
        return $refuse->("$entry : cannot stat") if not @stat;
        return $refuse->("$entry : symlink")     if -l $entry;
        return $refuse->( sprintf '%s : owner uid %d', $entry, $stat[4] )
            if not $self->{'owner_ok'}{ $stat[4] };
        return $refuse->(
            sprintf '%s : mode %#o, group \ other writable',
            $entry, $stat[2] & 07777
        ) if $stat[2] & 0022;
    }

    return wantarray ? ( 1, 'outside the tree, trusted' ) : 1;
}

1;    ##  AMOS7::Config::Source::Disk  ##

#,,..,..,,,..,,..,,..,,,,,.,.,.,.,,..,..,,..,,..,,...,...,...,.,.,,,.,,.,,..,,
#IDTJZNWZVDMUSSMHGHBBJPZTT265Y5MN44HBIGGBNSJKEK2FLP7F3WRVSFDYVVZOHTTS7A7ALBXU6
#\\\|E5YHJ2AVYH465XMFYGUQSOZHXQPCHIVFPBF5CP2S5VOO6C6LDOS \ / AMOS7 \ YOURUM ::
#\[7]O6FS6SFITQOVEFAQILHNLXGHK6PUF77SGJCIZJ56EZW2LTGGNWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
