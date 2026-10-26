package AMOS7::deps::aptlog;
our $VERSION = qw| AMOS7::deps::aptlog-VERSION.ZJGCMVZ |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| condense |;

## pure condenser : raw apt-get \ dpkg output lines in, condensed lines out.
## one condensed line per package on its 'Setting up' line :  <pkg>  <old> ->
## <new>  <size>      [ 'new' as old for fresh installs ] 'The following ...
## :' package-name lists [ wrapped over several lines ] condense to one '.. N
## names : <what>' line. errors, warnings, conffile prompts and every unknown
## line pass through verbatim - routine progress lines are dropped and counted
## into a single summary line appended on the final chunk. the optional state
## hashref carries partial per-package state across calls for incremental
## stream use - pass final => 1 on the last chunk
## [ default when no state given ].
## [ logic shared with src/debian.log.condense -- keep the two in sync ]

sub condense {
    my $args  = shift            // {};
    my $lines = $args->{'lines'} // [];
    my $state = $args->{'state'};
    my $final = $args->{'final'};

    return { 'mode' => 'false', 'data' => 'lines arrayref required' }
        unless ref $lines eq qw| ARRAY |;

    $state = undef if defined $state and ref $state ne qw| HASH |;

    ## self-contained call without state : flush the summary line at the  ##
    ## end of this call - incremental callers pass final => 1 on the last ##
    ## chunk                                                              ##
    $final //= !defined $state;

    $state //= {
        'pkg'         => {},
        'order'       => [],
        'header'      => undef,
        'dropped'     => 0,
        'passthrough' => 0,
    };

    my @out;

    ## remember package fields, keeping earlier values unless overridden ##
    my $remember = sub {
        my $pkg    = shift;
        my $fields = shift // {};
        my $rec    = $state->{'pkg'}->{$pkg} //= {};
        push $state->{'order'}->@*, $pkg
            unless grep { $_ eq $pkg } $state->{'order'}->@*;
        while ( my ( $field, $value ) = each %$fields ) {
            $rec->{$field} = $value;
        }
        return $rec;
    };

    ## routine progress lines : dropped, counted into the final summary ##
    my $routine_re = qr{^(?:Reading\ package\ lists\.{3}
        |Building\ dependency\ tree\.{3}
        |Reading\ state\ information\.{3}
        |Solving\ dependencies\.{3}
        |Calculating\ upgrade\.{3}
        |Fetched\ \S
        |\(Reading\ database
        |Processing\ triggers\ for
        |Extracting\ templates\ from\ packages:
        |Selecting\ previously\ unselected\ package
        |Preparing\ to\ unpack)}x;

    ##[ per-line rules ]######################################################

    foreach my $raw_line (@$lines) {
        next unless defined $raw_line;
        my $line = $raw_line;
        $line =~ s|\r+$||;

        ## normalize the unicode ellipsis [ dpkg on utf-8 locales ] to the ##
        ## ascii dots every rule below expects -- byte-level, no decoding  ##
        $line =~ s|\xe2\x80\xa6|...|g;

        ## progress fragments [ percent-terminated ] : dropped         ##
        if ( $line =~ m{\d+%\s*\z} ) {
            $state->{'dropped'}++;
            next;
        }

        ## a wrapped package-name list closes on the first non-indented ##
        ## line : one '.. N names : <what>' line stands for the names   ##
        if ( defined $state->{'list'} and $line =~ m{^\S} ) {
            my $list = delete $state->{'list'};
            push @out,
                sprintf '.. %d names : %s', $list->{'count'},
                $list->{'what'};
        }

        ## 'The following ... :' opens the list ; the indented lines hold  ##
        ## package names [ lowercase name-shaped tokens, optional ':arch'  ##
        ## qualifier and a trailing '*' for removals ] -- counted, dropped ##
        ## ; other indented lines fall through                             ##
        if ( $line =~ m{^The following\s+(.+):$} ) {
            $state->{'list'} = { 'what' => $1, 'count' => 0 };
            $state->{'dropped'}++;
            next;
        }
        if (defined $state->{'list'}
            and $line =~ m{^\s+(
                (?:[a-z0-9][a-z0-9+.\-_]*(?::[a-z0-9-]+)?\*?)
                (?:\s+[a-z0-9][a-z0-9+.\-_]*(?::[a-z0-9-]+)?\*?)*
                )\s*$}x
        ) {
            my $count = () = $1 =~ m{\S+}g;
            $state->{'list'}->{'count'} += $count;
            $state->{'dropped'}++;
            next;
        }

        ## mirror fetch line : remember size per package, header once ##
        if ($line =~ m{^Get:(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+
                        (\S+)\s+\[([^\]]+)\]\s*$}x
        ) {
            my ( undef, $url, $suite, $arch, $pkg, undef, undef, $size )
                = @{^CAPTURE};
            $state->{'pkg'}->{$pkg}->{'size'} = $size;
            if ( not defined $state->{'header'} ) {
                my $mirror = $url;
                $mirror =~ s{^\w+://([^/]+).*}{$1};
                $state->{'header'}
                    = sprintf 'mirror %s  suite %s  arch %s',
                    $mirror, $suite, $arch;
            }
            $state->{'dropped'}++;
            next;
        }

        ## repo lines without suite \ arch components [ cuda-style ] : ##
        ## 'Get:7 <url>  <pkg> <version> [size]' -- size remembered    ##
        if ($line =~ m{^Get:(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+
                        \[([^\]]+)\]\s*$}x
        ) {
            my ( undef, undef, $pkg, undef, $size ) = @{^CAPTURE};
            $state->{'pkg'}->{$pkg}->{'size'} = $size;
            $state->{'dropped'}++;
            next;
        }

        ## remaining fetch lines : repo index files                   ##
        ## [ InRelease, Packages.diff/Index, Contents.* ] -- routine, ##
        ## dropped                                                    ##
        if ( $line =~ m{^Get:(\d+)\s+(.+\S)\s+\[[^\]]+\]\s*$} ) {
            $state->{'dropped'}++;
            next;
        }

        ## mirror cache lines : routine, dropped ##
        if ( $line =~ m{^(?:Hit|Ign):} ) {
            $state->{'dropped'}++;
            next;
        }

        ## package unpack with previous version : old -> new               ##
        ## [ the ellipsis may sit directly after ')' -- dpkg prints both ] ##
        if ($line =~ m{^Unpacking\s+(.+?)\s+\((\S+?)\)\s+over\s+\((\S+?)\)
                        \s*\.\.\.$}x
        ) {
            my ( $full, $new, $old ) = @{^CAPTURE};
            my $pkg = $full =~ s{:.*$}{}r;
            $remember->(
                $pkg, { 'old' => $old, 'new' => $new, 'status' => 'upgraded' }
            );
            next;
        }

        ## package unpack without previous version : fresh install ##
        if ( $line =~ m{^Unpacking\s+(.+?)\s+\((\S+?)\)\s*\.\.\.$} ) {
            my ( $full, $new ) = @{^CAPTURE};
            my $pkg = $full =~ s{:.*$}{}r;
            $remember->(
                $pkg,
                {   'old'    => 'new',
                    'new'    => $new,
                    'status' => 'installed'
                }
            );
            next;
        }

        ## package setup done : emit the single condensed line ##
        if ( $line =~ m{^Setting up\s+(.+?)\s+\((\S+?)\)\s*\.\.\.$} ) {
            my ( $full, $ver ) = @{^CAPTURE};
            my $pkg = $full =~ s{:.*$}{}r;
            my $rec = $state->{'pkg'}->{$pkg} // {};
            next if $rec->{'emitted'};  ## duplicate setup line : emit once ##
            my $old = $rec->{'old'} // 'new';
            my $new = $rec->{'new'} // $ver;
            my $size
                = defined $rec->{'size'} && length $rec->{'size'}
                ? $rec->{'size'}
                : '-';
            push @out, sprintf '%s  %s -> %s  %s', $pkg, $old, $new, $size;
            $remember->(
                $pkg,
                {   'new'    => $new,
                    'status' => $rec->{'status'} // 'installed'
                }
            );
            $state->{'pkg'}->{$pkg}->{'emitted'} = 1;
            next;
        }

        ## package removal : one line per package, like the setup line ##
        if ( $line =~ m{^Removing\s+(.+?)\s+\((\S+?)\)\s*\.\.\.$} ) {
            my ( $full, $ver ) = @{^CAPTURE};
            my $pkg = $full =~ s{:.*$}{}r;
            next if $state->{'pkg'}->{$pkg}->{'emitted'};
            push @out, sprintf '%s  removed  %s', $pkg, $ver;
            $remember->( $pkg, { 'new' => $ver, 'status' => 'removed' } );
            $state->{'pkg'}->{$pkg}->{'emitted'} = 1;
            next;
        }

        ## routine progress lines : dropped, counted ##
        if ( $line =~ $routine_re ) {
            $state->{'dropped'}++;
            next;
        }

        ## everything else passes through verbatim - errors, warnings, ##
        ## conffile prompts, held \ removed packages, unknown lines    ##
        $state->{'passthrough'}++;
        push @out, $line;
    }

    ##[ final chunk : open list + dropped routine lines, one line each ]###

    if ($final) {
        if ( defined $state->{'list'} ) {
            my $list = delete $state->{'list'};
            push @out,
                sprintf '.. %d names : %s', $list->{'count'},
                $list->{'what'};
        }
        if ( $state->{'dropped'} ) {
            push @out,
                sprintf '.. %d routine line%s condensed',
                $state->{'dropped'}, $state->{'dropped'} == 1 ? '' : 's';
            $state->{'dropped'} = 0;
        }
    }

    my @packages = map {
        my $rec = $state->{'pkg'}->{$_} // {};
        {   'pkg'    => $_,
            'old'    => $rec->{'old'},
            'new'    => $rec->{'new'},
            'size'   => $rec->{'size'},
            'status' => $rec->{'status'} // 'pending',
        }
    } $state->{'order'}->@*;

    return {
        'mode' => qw| true |,
        'data' => {
            'header'      => $state->{'header'},
            'lines'       => \@out,
            'packages'    => \@packages,
            'passthrough' => $state->{'passthrough'},
            'state'       => $state,
        }
    };
}

1;

#,,,,,..,,.,.,...,.,,,,.,,,,,,,.,,,,,,..,,.,,,.,.,...,...,,.,,,,.,,,,,,.,,,,.,
#2DHAQEWSXXLV7SPQRFLLPYA47WLYYMOUFEAA4HHGC5LNXVFZYLPVXKAPGGYTBB3HPKKF32TIWPOOI
#\\\|AHEN7WJTBOHCEXPAGEXEQZNXQKD7JSNOBHRNEMG7237XZDOF2DE \ / AMOS7 \ YOURUM ::
#\[7]JCJYZK7K6JSPSLKLLGZEB6VNYTWHBJOLBXHO6F62G3C3FOSN5YAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
