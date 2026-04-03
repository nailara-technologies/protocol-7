## [:< ##

package AMOS7::Metadata;   ###################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw|
    parse_inline_metadata
    find_metadata_blocks
    build_command_registry
    search_registry
    filter_by_tag
    filter_by_zenka
    registry_to_json
    registry_to_yaml
    get_command_info
    $VERSION
    $METADATA_START
    $METADATA_END
    |;

our $VERSION = qw| AMOS7::Metadata-VERSION.YT9K8L2 |;

##[ METADATA CONSTANTS ]#######################################################

our $METADATA_START = qr/##\s*\[\:<\s*command-metadata/;
our $METADATA_END   = qr/##\s*\]/;

##[ GLOBAL REGISTRY ]#########################################################

our $command_registry //= {};    ## global command registry ##
our $metadata_cache   //= {};    ## cache for parsed metadata ##

##[ PARSE INLINE METADATA ]###################################################

sub parse_inline_metadata {
    my $source_code = shift;
    my $metadata    = {};

    return $metadata if not defined $source_code or not length $source_code;

    # Find metadata blocks marked by ## [:< command-metadata ... ## ]>
    my @lines       = split /\n/, $source_code;
    my $in_metadata = FALSE;
    my @metadata_lines;

    foreach my $line (@lines) {
        if ( $line =~ $METADATA_START ) {
            $in_metadata = TRUE;
            next;
        } elsif ( $line =~ $METADATA_END ) {
            $in_metadata = FALSE;
            last;
        }

        if ($in_metadata) {
            push @metadata_lines, $line;
        }
    }

    return $metadata if not @metadata_lines;

    # Parse metadata lines (format: #  key = value)
    foreach my $line (@metadata_lines) {

        # Match: # key = value
        if ( $line =~ m/^\s*#\s+(\w+)\s*=\s*(.*)/ ) {
            my $key   = $1;
            my $value = $2;

            $value =~ s/^\s+//;    # trim leading
            $value =~ s/\s+$//;    # trim trailing

            next if not length $value;

            if ( $key eq 'tag' ) {

                # tags can be comma-separated
                $metadata->{'tags'} = [ split /\s*,\s*/, $value ];
            } elsif ( $key eq 'examples' ) {

                # examples might span multiple lines, just store first
                if ( not exists $metadata->{'examples'} ) {
                    $metadata->{'examples'} = [$value];
                } else {
                    push @{ $metadata->{'examples'} }, $value;
                }
            } else {

                # single value fields
                $metadata->{$key} = $value;
            }
        }
    }

    return $metadata;
}

##[ FIND METADATA BLOCKS ]####################################################

sub find_metadata_blocks {
    my $source_code = shift;
    my @blocks      = ();

    return @blocks if not defined $source_code or not length $source_code;

    my @lines    = split /\n/, $source_code;
    my $in_block = FALSE;
    my @block_lines;
    my $block_start = 0;

    for ( my $i = 0; $i < @lines; $i++ ) {
        if ( $lines[$i] =~ $METADATA_START ) {
            $in_block    = TRUE;
            $block_start = $i;
            @block_lines = ();
            next;
        } elsif ( $lines[$i] =~ $METADATA_END ) {
            $in_block = FALSE;
            if (@block_lines) {
                push @blocks,
                    {
                    'start'  => $block_start,
                    'end'    => $i,
                    'lines'  => [@block_lines],
                    'source' => join( "\n", @block_lines )
                    };
            }
            next;
        }

        if ($in_block) {
            push @block_lines, $lines[$i];
        }
    }

    return @blocks;
}

##[ PARSE MODULE COMMAND FILES ]##############################################

sub parse_module_command {
    my $filepath = shift;
    my $metadata = {};

    open( my $FH, '<', $filepath ) or return $metadata;
    my $source_code = do { local $/; <$FH> };
    close($FH);

    # Extract name, param, and descr from comment lines
    # Format:
    # # name  = base.console.commands
    # # param = [pattern]
    # # descr = list [these] console commands and parameters
    my @lines = split /\n/, $source_code;
    foreach my $line (@lines) {
        if ( $line =~ /^\s*#\s+name\s*=\s*(.+)$/ ) {
            my $name = $1;
            $name =~ s/^\s+//;
            $name =~ s/\s+$//;
            $metadata->{'command'} = $name;
        } elsif ( $line =~ /^\s*#\s+param\s*=\s*(.+)$/ ) {
            my $param = $1;
            $param =~ s/^\s+//;
            $param =~ s/\s+$//;
            $metadata->{'param'} = $param;
        } elsif ( $line =~ /^\s*#\s+descr\s*=\s*(.+)$/ ) {
            my $descr = $1;
            $descr =~ s/^\s+//;
            $descr =~ s/\s+$//;
            $metadata->{'descr'} = $descr;
        }
    }

    return $metadata;
}

##[ BUILD COMMAND REGISTRY ]##################################################

sub build_command_registry {
    my $zenka_root = shift;    # path to configuration/zenki
    my $root_path  = shift;    # path to protocol-7 root (optional)
    my $registry   = {};

    return $registry if not defined $zenka_root or not -d $zenka_root;

    ## Scan zenka source directories for inline metadata
    opendir( my $ZENKA_DIR, $zenka_root ) or return $registry;
    my @zenka_names
        = grep { -d "$zenka_root/$_" and !/^\./ } readdir($ZENKA_DIR);
    closedir($ZENKA_DIR);

    foreach my $zenka_name (@zenka_names) {
        my $source_dir = "$zenka_root/$zenka_name/source";
        next if not -d $source_dir;

        opendir( my $SRC_DIR, $source_dir ) or next;
        my @files
            = grep { /\.(pl|pm)$/ and -f "$source_dir/$_" } readdir($SRC_DIR);
        closedir($SRC_DIR);

        foreach my $file (@files) {
            my $filepath = "$source_dir/$file";
            open( my $FH, '<', $filepath ) or next;
            my $source_code = do { local $/; <$FH> };
            close($FH);

            # Parse metadata from this file
            my $metadata = parse_inline_metadata($source_code);

            if ( exists $metadata->{'command'} ) {
                my $cmd = $metadata->{'command'};
                $registry->{$cmd} = {
                    %$metadata,
                    'zenka'    => $zenka_name,
                    'file'     => $file,
                    'filepath' => $filepath,
                    'source'   => 'zenka'
                };
            }
        }
    }

    ## Scan modules/*.console.* files for console commands
    ## These are Protocol-7 console commands with simple name/param/descr format
    if ( not defined $root_path ) {
        ## Try to infer root path from zenka_root
        ## zenka_root is typically configuration/zenki
        if ( $zenka_root =~ m{^(.+)/configuration/zenki$} ) {
            $root_path = $1;
        }
    }

    if ( defined $root_path and -d "$root_path/modules" ) {
        opendir( my $MOD_DIR, "$root_path/modules" ) or return $registry;
        my @module_files
            = grep { /\.console\./ and -f "$root_path/modules/$_" }
            readdir($MOD_DIR);
        closedir($MOD_DIR);

        foreach my $file (@module_files) {
            my $filepath = "$root_path/modules/$file";
            my $metadata = parse_module_command($filepath);

            if ( exists $metadata->{'command'} ) {
                my $cmd = $metadata->{'command'};
                $registry->{$cmd} = {
                    %$metadata,
                    'file'     => $file,
                    'filepath' => $filepath,
                    'source'   => 'console',
                    'tag'      => 'console-command'
                };
            }
        }
    }

    return $registry;
}

##[ SEARCH REGISTRY ]#########################################################

sub search_registry {
    my $registry = shift;
    my $pattern  = shift;
    my $results  = {};

    return $results if not defined $registry or not defined $pattern;

    foreach my $cmd ( keys %$registry ) {
        my $entry = $registry->{$cmd};

        # Search in command name
        if ( $cmd =~ /$pattern/i ) {
            $results->{$cmd} = $entry;
            next;
        }

        # Search in description
        if ( exists $entry->{'descr'} and $entry->{'descr'} =~ /$pattern/i ) {
            $results->{$cmd} = $entry;
            next;
        }

        # Search in usage
        if ( exists $entry->{'usage'} and $entry->{'usage'} =~ /$pattern/i ) {
            $results->{$cmd} = $entry;
            next;
        }
    }

    return $results;
}

##[ FILTER BY TAG ]###########################################################

sub filter_by_tag {
    my $registry = shift;
    my $tag      = shift;
    my $results  = {};

    return $results if not defined $registry or not defined $tag;

    foreach my $cmd ( keys %$registry ) {
        my $entry = $registry->{$cmd};

        next if not exists $entry->{'tags'};

        if ( grep { $_ eq $tag } @{ $entry->{'tags'} } ) {
            $results->{$cmd} = $entry;
        }
    }

    return $results;
}

##[ FILTER BY ZENKA ]#########################################################

sub filter_by_zenka {
    my $registry = shift;
    my $zenka    = shift;
    my $results  = {};

    return $results if not defined $registry or not defined $zenka;

    foreach my $cmd ( keys %$registry ) {
        my $entry = $registry->{$cmd};

        if ( exists $entry->{'zenka'} and $entry->{'zenka'} eq $zenka ) {
            $results->{$cmd} = $entry;
        }
    }

    return $results;
}

##[ REGISTRY TO JSON ]########################################################

sub registry_to_json {
    my $registry = shift;
    my $compact  = shift // FALSE;

    return '{}' if not defined $registry or not keys %$registry;

    my $json_parts = [];

    foreach my $cmd ( sort keys %$registry ) {
        my $entry = $registry->{$cmd};

        my $entry_json = "{\n";
        $entry_json .= qq|    "command": "$cmd",\n|;

        if ( exists $entry->{'descr'} ) {
            my $descr = $entry->{'descr'};
            $descr =~ s/\\/\\\\/g;    # escape backslashes first
            $descr =~ s/"/\\"/g;      # then escape quotes
            $entry_json .= qq|    "description": "$descr",\n|;
        }

        if ( exists $entry->{'usage'} ) {
            my $usage = $entry->{'usage'};
            $usage =~ s/\\/\\\\/g;    # escape backslashes first
            $usage =~ s/"/\\"/g;      # then escape quotes
            $entry_json .= qq|    "usage": "$usage",\n|;
        }

        if ( exists $entry->{'tags'} ) {
            my $tags_str = join( '", "', @{ $entry->{'tags'} } );
            $entry_json .= qq|    "tags": ["$tags_str"],\n|;
        }

        if ( exists $entry->{'zenka'} ) {
            $entry_json .= qq|    "zenka": "$entry->{'zenka'}"\n|;
        }

        $entry_json =~ s/,\n$/\n/;    # remove trailing comma
        $entry_json .= "  }";

        push @$json_parts, $entry_json;
    }

    return "[\n  " . join( ",\n  ", @$json_parts ) . "\n]";
}

##[ GET COMMAND INFO ]########################################################

sub get_command_info {
    my $registry = shift;
    my $cmd      = shift;

    return undef if not defined $registry or not defined $cmd;

    return $registry->{$cmd} if exists $registry->{$cmd};

    return undef;
}

##[ REGISTRY TO YAML (MINIMAL) ]##############################################

sub registry_to_yaml {
    my $registry = shift;

    return "commands: {}\n" if not defined $registry or not keys %$registry;

    my $yaml = "commands:\n";

    foreach my $cmd ( sort keys %$registry ) {
        my $entry = $registry->{$cmd};

        $yaml .= "  $cmd:\n";
        $yaml .= "    description: $entry->{'descr'}\n"
            if exists $entry->{'descr'};
        $yaml .= "    usage: $entry->{'usage'}\n"
            if exists $entry->{'usage'};

        if ( exists $entry->{'tags'} ) {
            my $tags_str = join( ', ', @{ $entry->{'tags'} } );
            $yaml .= "    tags: [$tags_str]\n";
        }

        $yaml .= "    zenka: $entry->{'zenka'}\n"
            if exists $entry->{'zenka'};
    }

    return $yaml;
}

##[ END OF MODULE ]###########################################################

1;

#,,.,,,.,,..,,,,,,,..,.,,,,,.,.,.,.,.,,,.,...,..,,...,...,,..,.,.,.,,,,,.,.,.,
#W6ESWUYUMCMXAGR4NYKWWCLT2VSUW37SDBD22IYWB6BJD55OQUJQR6IXJIHVF4XCJM3H3H6OROIX2
#\\\|6TBRAS7F7HUAI6M6PFSZ63EY3PTTEPA63JVBA5KGLA5NVONP22H \ / AMOS7 \ YOURUM ::
#\[7]6WPPPAZT3P36T6UNUDDCQXG74VZNVIFNMPDJMSX77BKNZHNT2SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
