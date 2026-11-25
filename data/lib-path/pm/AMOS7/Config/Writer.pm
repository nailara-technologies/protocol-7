package AMOS7::Config::Writer;
our $VERSION = qw| AMOS7::Config::Writer-VERSION.NLHS43I |;

use v5.32;
use strict;
use warnings;
use English;
use Fcntl qw| O_WRONLY O_CREAT O_EXCL |;
use Errno qw| EEXIST |;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| write write_file |;

my $tmp_sequence = 0;

##[ native config writer ]####################################################
#
# write( \%config [, \%opts ] ) -> native text
# write_file( $path, \%config [, \%opts ] ) -> path, atomic tmp + rename
#
# flat `a.b.c => value` and nested hashes are accepted. keys are sorted, so
# equal prefixes stay together, and one assignment block shares its key width.
# opts : title  optional `   .:[ title ]:.` header
#        mode   write_file mode [ default 0644 ]
#
# values use the existing single-quote syntax only where normalization needs
# it. literal single quotes, tabs and multiline values have no lossless native
# representation yet and are refused instead of inventing another grammar.

sub write {
    my ( $config, $opts ) = @ARG;
    $opts //= {};
    die "AMOS7::Config::Writer::write : expected a hashref\n"
        if ref $config ne qw| HASH |;

    my $flat  = _flatten($config);
    my @keys  = sort keys $flat->%*;
    my $width = 0;
    foreach my $key (@keys) {
        $width = length $key if length $key > $width;
    }

    my @lines = ();
    if ( defined $opts->{'title'} ) {
        die "AMOS7::Config::Writer::write : multiline title\n"
            if $opts->{'title'} =~ m{[\r\n]};
        push @lines, "   .:[ $opts->{'title'} ]:.", '';
    }
    foreach my $key (@keys) {
        push @lines,
            sprintf '%-*s = %s', $width, $key, _value( $flat->{$key} );
    }
    return join '', map {"$_\n"} @lines;
}

sub write_file {
    my ( $path, $config, $opts ) = @ARG;
    $opts //= {};
    die "AMOS7::Config::Writer::write_file : path required\n"
        if not defined $path or not length $path;

    my $text = AMOS7::Config::Writer::write( $config, $opts );
    my $mode = $opts->{'mode'} // 0644;
    my $fh;
    my $tmp;
    for ( 1 .. 13 ) {
        $tmp = sprintf qw| %s.tmp.%d.%d |, $path, $PID, ++$tmp_sequence;
        last
            if CORE::sysopen( $fh, $tmp, O_WRONLY | O_CREAT | O_EXCL, $mode );
        die "AMOS7::Config::Writer::write_file : $tmp : $OS_ERROR\n"
            if $OS_ERROR != EEXIST;
    }
    die "AMOS7::Config::Writer::write_file : no temporary name for $path\n"
        if not defined $fh;

    my $ok = eval {
        CORE::chmod( $mode, $tmp )               or die "$OS_ERROR\n";
        CORE::binmode( $fh, ':encoding(UTF-8)' ) or die "$OS_ERROR\n";
        CORE::print {$fh} $text                  or die "$OS_ERROR\n";
        CORE::close($fh)                         or die "$OS_ERROR\n";
        undef $fh;
        CORE::rename( $tmp, $path ) or die "$OS_ERROR\n";
        1;
    };
    my $err = $EVAL_ERROR;
    if ( not $ok ) {
        CORE::close($fh) if defined $fh;
        CORE::unlink($tmp);
        chomp $err;
        die "AMOS7::Config::Writer::write_file : $path : $err\n";
    }
    return $path;
}

sub _flatten {
    my $config = shift;
    my $flat   = {};
    my $walk;
    $walk = sub {
        my ( $hash, $prefix ) = @ARG;
        die "AMOS7::Config::Writer : empty nested hash at '$prefix'\n"
            if length($prefix)
            and not keys $hash->%*;
        foreach my $part ( keys $hash->%* ) {
            my $key = length($prefix) ? "$prefix.$part" : $part;
            die "AMOS7::Config::Writer : invalid key '$key'\n"
                if $key !~ m{\A[\w<>][\w<>-]*(?:\.[\w<>][\w<>-]*)*\z};
            die "AMOS7::Config::Writer : duplicate key '$key'\n"
                if exists $flat->{$key};
            if ( ref $hash->{$part} eq qw| HASH | ) {
                $walk->( $hash->{$part}, $key );
            } else {
                die "AMOS7::Config::Writer : non-scalar value at '$key'\n"
                    if ref $hash->{$part};
                $flat->{$key} = $hash->{$part};
            }
        }
    };
    $walk->( $config, '' );
    return $flat;
}

sub _value {
    my $value = shift // '';
    die "AMOS7::Config::Writer : multiline or tabbed value '$value'\n"
        if $value =~ m{[\r\n\t]};
    die "AMOS7::Config::Writer : literal single quote in '$value'\n"
        if index( $value, qw| '| ) >= 0;
    return "'$value'"
        if $value =~ m{#}
        or $value =~ m{\A | \z}
        or $value =~ m{\\\z};
    return $value;
}

1;    ##  AMOS7::Config::Writer  ##

#,,,.,...,,..,.,.,,,.,...,,.,,...,..,,..,,,.,,..,,...,...,..,,.,,,,.,,,,,,...,
#IRSIJQYXQWH6W4P3UPYDGKZ7GBEH3IHILFL36KZXJ6Q75W3CKCARLRAVJH67PNZAW6DYHMI7DENMQ
#\\\|RCFQ7EFH5IMOQWS5VPQD6SQMB6ZYSZ54ALUS2YAPE7LEYGDPBYX \ / AMOS7 \ YOURUM ::
#\[7]IU6UZVBTUCZPBVCEN762Z6VLMSWJIUEBITKO3E5JZDGD7K3IMQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
