# Storage Mapping Plugins

Plugin-based storage mapping system for Protocol-7's data zenka.

## Overview

Storage mapping plugins translate between different address spaces:
- **Path-based**: Traditional filesystem paths
- **Checksum-based**: Content-addressed storage
- **9P-based**: Remote 9P filesystem references

## Architecture

```
plugin.storage.<type>.*
├── *.init_code          # Plugin initialization
├── *                    # Main dispatch module
└── *.<operation>        # Specific operations
```

## Existing Plugins

### plugin.storage.checksum

Maps files to content checksums for deduplication.

**Operations:**
- `map` - Compute/check file checksum
- `lookup` - Find files by checksum
- `verify` - Verify file integrity
- `cache-invalidate` - Clear cache entries

**Usage:**
```bash
# Map a file to its checksum
storage map-file checksum /path/to/file :algorithm: bmw

# Lookup files by checksum
storage lookup-checksum checksum AMOS7B32CHECKSUM
```

## Creating New Mapping Plugins

Template for `plugin.storage.<type>.init_code`:
```perl
## [:< ##
# name  = plugin.storage.<type>.init_code

$data{'storage'}{'mapping'}{'type'} = {
    'enabled' => 1,
    # Plugin-specific data structures
};

0;
```

Template for `plugin.storage.<type>`:
```perl
## [:< ##
# name  = plugin.storage.<type>

return sub {
    my ($args) = @_;
    my $operation = $args->{operation} // 'default';
    
    given ($operation) {
        when ('op1') { return <[plugin.storage.type.op1]>->($args); }
        default { return { 'mode' => 'false', 'data' => 'unknown operation' }; }
    }
};
```

## Reloading

Plugins are reloaded with `reload plugins`:
```bash
cube reload plugins
```

This reloads all `plugin.*` modules without affecting core storage code.

## Future Mapping Types

- **plugin.storage.9p** - 9P remote filesystem mapping
- **plugin.storage.segment** - AMOS7 segment mapping
- **plugin.storage.cloud** - Cloud storage abstraction
- **plugin.storage.deduplicated** - Deduplication-aware mapping

## Integration with 9P

The checksum mapping works seamlessly with 9P:
```bash
# Scan 9P mount and checksum all files
storage 9p-scan wsl-host /mnt/c/data :include: '\.pdf$'

# Map each found file to checksum
storage map-file checksum /mnt/wsl-host/data/file.pdf

# Now lookup finds both local and 9P-mounted instances
storage lookup-checksum checksum <checksum>
```

#,,,.,..,,..,,.,.,.,.,.,,,.,,,,,.,.,.,...,,.,,..,,...,...,.,,,.,,,...,,,,,,,,,
#ADUWVDTDZLSNHIWANI5Z5A6HHXGLJP6GL5B2QJVVS4H5MHSVMXBILXLLFUUTG7Z6F6G5XP2GQOLXC
#\\\|GSU36SZVOGIOZCQYN7CIMRIF52HQAMNJNBUY4HBMFKF3KO2RIBN \ / AMOS7 \ YOURUM ::
#\[7]FD3PTDPCPST7727HZDXVVKWHHQPNJMKEGEWNNFOB4HGN6PBKYABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
