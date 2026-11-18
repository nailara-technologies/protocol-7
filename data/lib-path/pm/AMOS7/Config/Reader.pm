package AMOS7::Config::Reader;
our $VERSION = qw| AMOS7::Config::Reader-VERSION.PQ2ELNY |;

use v5.32;
use strict;
use warnings;
use English;

use AMOS7::Config qw| normalize_lines |;
use AMOS7::Config::Source::Disk;

##[ standalone reader of the zenka config tree ]##############################
#
# reads the cfg/ tree the way a zenka does, without a zenka : collects the
# VALUES, never runs anything. kept apart from AMOS7::Config on purpose :
# AMOS7::Config is the small line grammar src/base.parser.config loads in
# every zenka, the reader [ layers, trust, disk access ] is for scripts only
#
#   my $cfg = AMOS7::Config::Reader->read( 'shared-params', {
#       'zenka'     => 'calc',            ## host overlay + <zenka> in paths ##
#       'overrides' => { 'a.b' => 1 },    ## applied last ##
#   } );
#   $cfg->get('system.local_config_dir');
#   $cfg->explain('buffer.zenka.max_size');   ## who set it, in apply order ##
#
# opts : zenka       name of the zenka : enables the host overlay, fills
#                    '<zenka>' in optional layer paths
#        overrides   hashref, applied last [ flat `a.b.c => value` ]
#        root        tree root [ default : the tree this module lives in ]
#        source      a source object [ default : the disk tree at root ]
#        etc_dir     what `cfg-dir:` means  [ /etc/protocol-7 ]
#        var_dir     what `var-dir:` means  [ /var/protocol-7 ]
#        zenka_user  account the tree owner may not be  [ protocol-7 ]
#        host_overlay  0 : skip the overlay even with a zenka name
#
# layers, later wins : tree [ the file asked for ] < include [ nested
# `[load_config_file:..]` ] < optional [ `[load_config_file_if_present:..]` ]
# < host [ overlay ] < override. an include inside an optional or host file
# keeps that layer. a layer outside the tree that fails the trust check is
# recorded in refused() and never applied
#
# value side of the zenka parser, mirrored :
#   `key = value` and `key : value`   split at the first '=' [ ':' is NOT a
#                                     separator in base.parser.config, see
#                                     the report ; only '=' here too ]
#   single quotes in a value are dropped, as the parser does
#   `<a.b>` in a value                replaced by the key read so far [ a
#                                     reference needs a dot, as there ]
#   `: name :` \ `- name` \ `.: name :.`  open namespaces : keys below them
#                                     are `name.key` [ base.load_section_conf ]
# not run, listed in calls() : lines with `[cmd:..]` or `<<net>>`

my %LAYER_KEEPS = ( 'optional' => 1, 'host' => 1 );
my $MAX_DEPTH   = 32;

sub read {
    my ( $class, $name, $opts ) = @ARG;
    $opts //= {};

    die "AMOS7::Config::Reader::read : expected a config name\n"
        if not defined $name or not length $name;

    my $source = $opts->{'source'};
    if ( not defined $source ) {
        my $root = $opts->{'root'} // _default_root();
        $source = AMOS7::Config::Source::Disk->new(
            'root'       => $root,
            'zenka_user' => $opts->{'zenka_user'},
        );
    }

    my $state = {
        'source'   => $source,
        'opts'     => $opts,
        'data'     => {},
        'explain'  => {},
        'calls'    => [],
        'refused'  => [],
        'warnings' => [],
        'stack'    => [],
        'etc_dir'  => $opts->{'etc_dir'} // '/etc/protocol-7',
        'var_dir'  => $opts->{'var_dir'} // '/var/protocol-7',
    };

    ## tree : a name under cfg/, or an absolute one [ a layer outside ] ##
    my $entry = _cfg_name($name);
    die "AMOS7::Config::Reader::read : '$name' not found\n"
        if not $source->exists($entry);
    my $top = _apply_file( $state, $entry, 'tree', 'start', 0, 1 );

    my $zenka = $opts->{'zenka'};
    if (    defined $zenka
        and length $zenka
        and ( $opts->{'host_overlay'} // 1 ) ) {
        if ( $zenka !~ m|^[\w.-]+$| or $zenka eq 'host-config' ) {
            _warn( $state, 'start', 0,
                "zenka name '$zenka' : no host overlay" );
        } else {
            my $overlay = "$state->{'etc_dir'}/host-config/$zenka.cfg";
            _apply_file( $state, $overlay, 'host', 'start', 0, 0 )
                if $source->exists($overlay);
        }
    }

    my $overrides = $opts->{'overrides'} // {};
    foreach my $key ( sort keys $overrides->%* ) {
        _set( $state, $key, $overrides->{$key}, '(overrides)', 0,
            'override' );
    }

    return bless $state, 'AMOS7::Config::Reader::Result';
}

sub _default_root {
    require File::Spec;
    require Cwd;
    ## .../data/lib-path/pm/AMOS7/Config/Reader.pm -> the tree root ##
    my $dir = Cwd::abs_path( ( File::Spec->splitpath(__FILE__) )[1] );
    $dir =~ s{/data/lib-path/pm/AMOS7/Config/?$}{};
    return $dir;
}

sub _cfg_name {
    my $name = shift;
    return index( $name, '/' ) == 0 ? $name : "cfg/$name";
}

sub _warn {
    my ( $state, $file, $line, $text ) = @ARG;
    push $state->{'warnings'}->@*,
        { 'file' => $file, 'line' => $line, 'text' => $text };
}

sub _set {
    my ( $state, $key, $value, $file, $line, $layer ) = @ARG;

    $state->{'data'}{$key} = $value;
    push $state->{'explain'}{$key}->@*,
        {
        'file'  => $file,
        'line'  => $line,
        'layer' => $layer,
        'value' => $value,
        };
}

## raw lines -> lines where the namespace markers survive normalize_lines ##
## [ it drops `: name :` as inline code ] : a marker becomes              ##
## \x01<level>\x01<name>                                                  ##
sub _mark_sections {
    my $raw = shift;

    my @re = (
        undef,
        qr{^\.: *([\w.-]+) *:\.$},    ## [ 1 ] .: name :. ##
        qr{^- *([\w.-]+)$},           ## [ 2 ] - name     ##
        qr{^: *([\w.\[\]-]+) *:$},    ## [ 3 ] : name :   ##
    );

    my @out  = ();
    my $cont = 0;
    foreach my $line ( $raw->@* ) {
        my $text = $line;
        $text =~ s{(?<!\\)#.*$}{};
        $text =~ s{^[ \t]+|[ \t\r\n]+$}{}g;

        if ( not $cont and length $text ) {
            my $found;
            foreach my $level ( 1 .. 3 ) {
                next if $text !~ $re[$level];
                $found = "\x01$level\x01" . ${^CAPTURE}[0];
                last;
            }
            if ( defined $found ) {
                push @out, $found;
                next;
            }
        }
        push @out, $line;

        ## same view as normalize_lines : is a continuation open ##
        if ( length $text ) {
            $cont = $text =~ m|\\ *$| ? 1 : 0;
        }
    }
    return \@out;
}

## is this normalised line code that the zenka would run ##
sub _is_call {
    my $text = shift;

    return 1 if $text =~ m|<<[\w-]+(?:\.[\w-]+)*>>|;

    ( my $masked = $text ) =~ s{'[^']*'}{''}g;
    while ( $masked =~ m{(?<![\w])\[([^\[|^\]]+)\]}g ) {
        return 1 if ${^CAPTURE}[0] =~ m|^[A-Za-z_][\w.-]*(?::.*)?$|;
    }
    return 0;
}

sub _apply_file {
    my ( $state, $name, $layer, $from, $from_line, $required ) = @ARG;

    my $source = $state->{'source'};

    if ( $state->{'stack'}->@* >= $MAX_DEPTH ) {
        _warn( $state, $from, $from_line,
            "include depth over $MAX_DEPTH : $name" );
        return 0;
    }
    if ( grep { $ARG eq $name } $state->{'stack'}->@* ) {
        _warn( $state, $from, $from_line, "include cycle : $name skipped" );
        return 0;
    }

    ## trust : the tree is trusted, anything else has to pass ##
    my ( $ok, $why ) = $source->trust($name);
    if ( not $ok ) {
        push $state->{'refused'}->@*,
            {
            'name'   => $name,
            'layer'  => $layer,
            'from'   => $from,
            'line'   => $from_line,
            'reason' => $why,
            };
        return 0;
    }

    my $raw = $source->lines($name);
    if ( not defined $raw ) {
        push $state->{'refused'}->@*,
            {
            'name'   => $name,
            'layer'  => $layer,
            'from'   => $from,
            'line'   => $from_line,
            'reason' => 'not readable',
            };
        return 0;
    }

    push $state->{'stack'}->@*, $name;

    my @section = ( undef, undef, undef, undef );
    foreach my $record (
        normalize_lines( _mark_sections($raw), { 'descr' => 0 } )->@* ) {
        my $text = $record->{'text'};
        next if not defined $text;
        my $line = $record->{'first'};

        if ( $text =~ m|^\x01(\d)\x01(.*)$| ) {
            my ( $level, $sect ) = ( ${^CAPTURE}[0], ${^CAPTURE}[1] );
            $section[$level] = $sect;
            @section[ $level + 1 .. 3 ] = (undef) x ( 3 - $level );
            next;
        }

        ## nested config files : applied here, in file order ##
        if ( $text
            =~ m|^\[(load_config_file(?:_if_present)?):\s*'?([^'\]]*?)'?\s*\]$|
        ) {
            my ( $cmd, $arg ) = ( ${^CAPTURE}[0], ${^CAPTURE}[1] );
            _include( $state, $cmd, $arg, $layer, $name, $line );
            next;
        }

        if ( _is_call($text) ) {
            push $state->{'calls'}->@*,
                { 'file' => $name, 'line' => $line, 'text' => $text };
            next;
        }

        next if index( $text, '=' ) < 0;
        my ( $key, $value ) = split m|=|, $text, 2;
        $key =~ s|[ \t\n]||g;
        next if not length $key;
        $value //= '';
        $value =~ s|'||g;

        ## `<a.b>` : the keys read so far ##
        $value =~ s{<([\w-]+(?:\.[\w-]+)+)>}{
            my $ref = ${^CAPTURE}[0];
            if ( exists $state->{'data'}{$ref} ) {
                $state->{'data'}{$ref} // '';
            } else {
                ## the zenka substitutes nothing here : empty + warning ##
                _warn( $state, $name, $line, "unresolved reference <$ref> in '$key'" );
                '';
            }
        }ge;

        my $prefix = join '.', grep {defined} @section[ 1 .. 3 ];
        $key = "$prefix.$key" if length $prefix;

        _set( $state, $key, $value, $name, $line, $layer );
    }

    pop $state->{'stack'}->@*;
    return 1;
}

sub _include {
    my ( $state, $cmd, $arg, $layer, $from, $line ) = @ARG;

    my $source = $state->{'source'};
    my ( $entry, $child_layer );

    if ( $cmd eq 'load_config_file' ) {
        $entry       = _cfg_name($arg);
        $child_layer = $LAYER_KEEPS{$layer} ? $layer : 'include';
        if ( not $source->exists($entry) ) {

            ## a required include is an error for a zenka : refused ##
            push $state->{'refused'}->@*,
                {
                'name'   => $entry,
                'layer'  => $child_layer,
                'from'   => $from,
                'line'   => $line,
                'reason' => 'required include not found',
                };
            return;
        }
    } else {
        ## mapping of base.load_config_file_if_present ##
        my $path  = $arg;
        my $zenka = $state->{'opts'}{'zenka'} // '';
        $path =~ s|<zenka>|$zenka|g;
        $path =~ s|^cfg-dir:|$state->{'etc_dir'}/|;
        $path =~ s|^var-dir:|$state->{'var_dir'}/|;
        return if index( $path, '/' ) != 0 or not $source->exists($path);
        $entry       = $path;
        $child_layer = 'optional';
    }

    _apply_file( $state, $entry, $child_layer, $from, $line, 1 );
}

##[ the result ]##############################################################

package AMOS7::Config::Reader::Result;

use v5.32;
use strict;
use warnings;

## get( $key ) : the value, undef when never set ##
sub get { return $_[0]->{'data'}{ $_[1] } }

## all() : the flat hash [ list context ] or a copy as hashref ##
sub all {
    my %copy = $_[0]->{'data'}->%*;
    return wantarray ? %copy : \%copy;
}

## explain( $key ) : { file, line, layer, value } per assignment, apply ##
## order [ the last one is the value get() returns ]                    ##
sub explain { return ( $_[0]->{'explain'}{ $_[1] } // [] )->@* }

## section( $prefix ) : the keys below `prefix.`, prefix cut off ##
sub section {
    my ( $self, $prefix ) = @_;
    my %part = ();
    foreach my $key ( keys $self->{'data'}->%* ) {
        next if index( $key, "$prefix." ) != 0;
        $part{ substr $key, length($prefix) + 1 } = $self->{'data'}{$key};
    }
    return wantarray ? %part : \%part;
}

## calls() : { file, line, text } of code that was NOT run ##
sub calls { return $_[0]->{'calls'}->@* }

## refused() : { name, layer, from, line, reason } of layers never applied ##
sub refused { return $_[0]->{'refused'}->@* }

## warnings() : { file, line, text } cycles, missing includes, open ##
## references                                                       ##
sub warnings { return $_[0]->{'warnings'}->@* }

1;    ##  AMOS7::Config::Reader  ##

#,,,,,.,.,..,,.,,,,,.,,,,,.,,,..,,.,.,,..,.,,,..,,...,...,.,,,.,.,..,,.,.,,.,,
#2WLPTNXGEDBYCEKZE4TIUCBYBYGCYR4EUNQYSNZRIUDOXWVMGB63O6HSQCD44KHRVRUVS4AD27RSO
#\\\|UHM6I4SHNEON4KO3WYFK2XRFRTP4WMMFNKDMX5Y5BIIX2A7QPE7 \ / AMOS7 \ YOURUM ::
#\[7]IVEGCZKOALFFLCGG4NU4Z2WVIZKHNJMRWV7YDAR7IT6CPW5XGECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
