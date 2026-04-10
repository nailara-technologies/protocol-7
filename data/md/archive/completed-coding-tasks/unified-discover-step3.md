## task: unified adapter discover — step 3

extend models.registry.populate_from_discovery to use all active adapters
instead of the hardcoded lmstudio path. create one new module and update one
existing module.

p7 style: lowercase comments, [ brackets ], $ARG not $_, <[module]>->() syntax.
do NOT add #,,... stub lines. leave files clean for signing.


## read these files first

    modules/models.registry.populate_from_discovery   (existing — to be updated)
    modules/models.storage.adapter.invoke.discover    (returns invoke records)
    modules/models.storage.adapter.lmstudio.discover  (returns lmstudio records)
    modules/models.registry.create_entry              (how entries are built)


## record format differences to normalize

invoke adapter returns:
    { name, type, base, format, path, size, source, source_type }
    path = bare uuid OR uuid/filename (relative, no root prefix)

lmstudio adapter returns:
    { name, type, base, format, path, size, quant, source, source_type }
    path = author/model-dir/file.gguf (relative, no root prefix)

registry expects (from populate_from_discovery):
    { name, path, size_gb, quantization, tier, is_vision, mmproj_path }
    path = absolute on-disk path (or relative — check existing usage)


## module to create

### modules/models.storage.adapter.discover_all

    # name  = models.storage.adapter.discover_all
    # descr = call all active adapters and return merged model record list

    input:  $ARG = optional hashref { adapters => ['invoke','lmstudio'] }
            defaults to both adapters if not specified

    output: arrayref of normalized model hashrefs, ready for populate_from_discovery

    logic:
        my @adapters = @{ $ARG->{'adapters'} // [qw( invoke lmstudio )] };
        my @all;

        for my $adapter (@adapters) {
            my $records;
            if ( $adapter eq 'invoke' ) {
                $records = <[models.storage.adapter.invoke.discover]>->() // [];
            } elsif ( $adapter eq 'lmstudio' ) {
                $records = <[models.storage.adapter.lmstudio.discover]>->() // [];
            } else {
                <[base.logs]>->( 1, "discover_all: unknown adapter [ %s ]", $adapter );
                next;
            }

            ## normalize each record to registry format ##
            for my $rec (@$records) {
                ## resolve to absolute path ##
                my $abs_path;
                if ( $adapter eq 'invoke' ) {
                    $abs_path = <[models.storage.adapter.invoke.resolve]>->($rec);
                } elsif ( $adapter eq 'lmstudio' ) {
                    $abs_path = <[models.storage.adapter.lmstudio.resolve]>->($rec);
                }
                next unless defined $abs_path;   ## skip if not on disk ##

                my $size_bytes = $rec->{'size'} // 0;
                my $size_gb    = $size_bytes > 0
                    ? sprintf( "%.2f", $size_bytes / 1_073_741_824 )
                    : 0;

                push @all, {
                    'name'         => $rec->{'name'}   // '',
                    'path'         => $abs_path,
                    'size_gb'      => $size_gb,
                    'quantization' => $rec->{'quant'}  // 'unknown',
                    'format'       => $rec->{'format'} // '',
                    'base'         => $rec->{'base'}   // 'unknown',
                    'type'         => $rec->{'type'}   // 'main',
                    'adapter'      => $adapter,
                    'source'       => $rec->{'source'} // '',
                    'source_type'  => $rec->{'source_type'} // '',
                    'tier'         => $adapter,    ## use adapter name as tier ##
                    'is_vision'    => 0,
                    'mmproj_path'  => '',
                };
            }
        }

        <[base.logs]>->( 2, "discover_all: %d models across %d adapters",
            scalar @all, scalar @adapters );

        return \@all;


## module to update

### modules/models.registry.populate_from_discovery

    current fallback (when no arrayref passed) is:
        $discovered = <[models.storage.discover_directory]>->(
            qw| /mnt/ext-xfs-data/models-lmstudio |, TRUE    ## [LLL] fix path
        ) // [];

    replace that entire block with:
        $discovered = <[models.storage.adapter.discover_all]>->() // [];

    that is the only change needed — the rest of the module (dedup by path,
    checksum, registry insertion) stays exactly as-is.

    use replace_in_file or edit_file to make this targeted change only.
    do not rewrite the whole module.


## verification

    ptd -c modules/models.storage.adapter.discover_all
    ptd -c modules/models.registry.populate_from_discovery

    then test via p7c:
        p7c models.adapter-discover        ## should list invoke models
        p7c models.adapter-lmstudio-discover  ## should list lmstudio models

report when done.

#,,,,,.,.,.,,,..,,...,..,,,,,,...,,.,,,..,.,.,..,,...,...,.,.,.,.,...,.,,,.,.,
#HQACA3BVUJSRPTMWDZ626QQLQUKMI5N66K4KF3KGGGJFPZA6XZ3UNV4LOO76NJTTZ66J7GZULIG6Q
#\\\|XMNBEMCDKAUSPT54WIPOTI63QWIJJDXOWRESUBTCMYHWHSJW57P \ / AMOS7 \ YOURUM ::
#\[7]TSNT2CS6JE2VZH7XJNSSHUQAPSFNPOXVSYYTPOLC5TBJQOEI24DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
