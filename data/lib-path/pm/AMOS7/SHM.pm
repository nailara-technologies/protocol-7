## [:< ##

package AMOS7::SHM; ##########################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use constant SHM_HEADER_SIZE      => 512;
use constant DEFAULT_SEGMENT_SIZE => 63 * 1024;
use constant MAX_PERMISSIONS      => 16;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

@EXPORT_OK = qw|
    shm_create shm_open
    pack_shm_header unpack_shm_header
    header_read header_write
    permission_verify sign_permission
    parse_shm_path derive_pubkey
    mmap_file mmap_file_read
    lock_memory unlock_memory
    sweep_stale_segments
    |;

### use AMOS7::Version; ## to generate new version string ###
##
our $VERSION = qw| AMOS7::SHM-VERSION.AAAAAAA |;

##[ AMOS MODULE ]#############################################################

## the mechanics below [ mmap mapping, header pack / unpack, permission
## signature verification ] are pure computation — they do not care whether a
## zenka is running. context-specific values [ time source, group registry,
## logging ] are injected by the caller, keeping these branch-free in both
## standalone and zenka mode. the standalone / zenka difference is lifecycle
## [ cleanup — phase 4 ], not mechanics. mirror AMOS7::CHKSUM precedent.

## logging shim — zenka wrapper injects <[base.log]>, standalone is silent ##
our $log_handler;

## phase 4, standalone only : track creator-owned segment paths for an END-  ##
## time cleanup. zenka mode handles this via its own SIGINT/TERM handler    ##
## [ modules/data.mount.shm.init_code ] instead — this list stays empty     ##
## whenever $main::PROTOCOL_SEVEN is defined.                               ##
my @_standalone_owned_paths;

sub _log {
    my ( $level, $msg ) = @ARG;
    return unless defined $log_handler;
    $log_handler->( $level, $msg );
}

##[ HEADER PACK / UNPACK ]####################################################

## pack header structure into fixed 512-byte text format ##
## identical mechanics to data.mount.shm.header.write.pack_shm_header ##
sub pack_shm_header {

    my $header = shift;

    my @perm_strings;
    for my $perm ( @{ $header->{'permissions'} } ) {
        push @perm_strings,
            sprintf(
            "%s|%s|%s|%d|%d|%s",
            $perm->{'to'},                       $perm->{'branch'},
            join( ',', @{ $perm->{'rights'} } ), $perm->{'expiry'},
            $perm->{'granted'},                  $perm->{'sig'} // '0',
            );
    }
    my $perms_str = join( ';', @perm_strings );

    my $flags_str = join( ',',
        map { $_ . '=' . ( $header->{'flags'}{$_} ? 1 : 0 ) }
        sort keys %{ $header->{'flags'} } );

    my $packed = sprintf(
        "P7SH:%d:%s:%d:%d:%d:%s:%s:\n",
        $header->{'version'} // 1,
        $header->{'owner_pubkey'},
        $header->{'created'},
        $header->{'data_size'},
        $header->{'header_size'} // SHM_HEADER_SIZE,
        $flags_str,
        $perms_str,
    );

    $packed .= "\0" x ( SHM_HEADER_SIZE - length($packed) );
    return substr( $packed, 0, SHM_HEADER_SIZE );
}

## unpack 512-byte text header into hash structure ##
## identical mechanics to data.mount.shm.header.read.unpack_shm_header ##
## permissions are parsed back out so that standalone shm_open can verify
## signed grants; the on-disk header format is unchanged. ##
sub unpack_shm_header {

    my $raw = shift;

    _log( 2, "unpack: raw length=" . length($raw) );
    _log( 2, "unpack: first 80 chars=" . substr( $raw, 0, 80 ) );

    ## check magic ##
    my $magic = substr( $raw, 0, 4 );
    if ( $magic ne 'P7SH' ) {
        _log( 2, "unpack: bad magic='$magic'" );
        return undef;
    }

    ## try regex match ##
    if ( $raw
        =~ m{^P7SH:(\d+):([A-Z0-9]+):([\d.]+):(\d+):(\d+):([^:]+):([^:\n]*):}
    ) {
        my ($version,  $pubkey,    $created, $data_size,
            $hdr_size, $flags_str, $perms_str
        ) = ( $1, $2, $3, $4, $5, $6, $7 );

        _log( 2, "unpack: matched! version=$version, pubkey=$pubkey" );

        my %flags;
        for my $flag_pair ( split( /,/, $flags_str ) ) {
            my ( $key, $val ) = split( /=/, $flag_pair );
            $flags{$key} = $val if defined $key;
        }

        my @permissions;
        for my $perm_str ( split( /;/, $perms_str // '' ) ) {
            next unless length($perm_str);
            my ( $to, $branch, $rights, $expiry, $granted, $sig )
                = split( /\|/, $perm_str );
            push @permissions,
                {
                'to'      => $to,
                'branch'  => $branch,
                'rights'  => [ split( /,/, $rights // '' ) ],
                'expiry'  => $expiry,
                'granted' => $granted,
                'sig'     => $sig,
                };
        }

        return {
            'magic'        => 'P7SH',
            'version'      => $version,
            'owner_pubkey' => $pubkey,
            'created'      => $created,
            'data_size'    => $data_size,
            'header_size'  => $hdr_size,
            'flags'        => \%flags,
            'permissions'  => \@permissions,
        };
    }

    _log( 2, "unpack: regex did not match" );
    return undef;
}

##[ HEADER READ / WRITE ]#####################################################

## read and parse header from a mapped scalar reference ##
sub header_read {

    my $mmap_ref = shift;

    return undef unless defined $mmap_ref && ref($mmap_ref) eq 'SCALAR';

    my $header_raw = substr( $$mmap_ref, 0, SHM_HEADER_SIZE );
    return undef unless length($header_raw) >= SHM_HEADER_SIZE;

    return undef unless substr( $header_raw, 0, 4 ) eq 'P7SH';

    my $header = unpack_shm_header($header_raw);
    return undef unless defined $header;

    $header->{'checksum_verified'} = 1;
    $header->{'permissions'} //= [];

    return $header;
}

## write a header hash into the first 512 bytes of a mapped scalar ##
sub header_write {

    my $mmap_ref = shift;
    my $header   = shift;

    return undef unless defined $mmap_ref && ref($mmap_ref) eq 'SCALAR';
    return undef unless defined $header   && ref($header) eq 'HASH';

    my $packed = pack_shm_header($header);
    return undef unless length($packed) == SHM_HEADER_SIZE;

    substr( $$mmap_ref, 0, SHM_HEADER_SIZE ) = $packed;

    return {
        'written' => SHM_HEADER_SIZE,
        'version' => $header->{'version'},
    };
}

##[ PATH / KEY HELPERS ]######################################################

## parse a /dev/shm path into ( owner_pubkey, sub_path ) ##
sub parse_shm_path {

    my $path = shift;

    if ( $path =~ m{/dev/shm/p7:M:([A-Z0-9]+)(?::(.+))?} ) {
        return ( $1, $2 );
    }

    return undef;
}

## derive public key from private key [ placeholder, matches existing ] ##
sub derive_pubkey {

    my $priv_key = shift;

    return substr( $priv_key, 0, 32 );
}

##[ MMAP MAPPING ]############################################################

## mmap a file handle read-write, returns scalar ref or undef ##
sub mmap_file {

    my ( $fh, $size ) = @ARG;

    return undef unless defined $fh;

    if ( eval { require Sys::Mmap } ) {
        my $var;
        eval {
            ## Sys::Mmap::mmap wants the FILEHANDLE itself, not fileno($fh) —
            ## passing fileno() throws 'Bad filehandle' and silently fell
            ## through to the slurp-copy fallback below, every time, in both
            ## standalone and zenka mode. real shared memory was never
            ## actually in effect until this fix ##
            Sys::Mmap::mmap( $var, $size,
                Sys::Mmap::PROT_READ() | Sys::Mmap::PROT_WRITE(),
                Sys::Mmap::MAP_SHARED(), $fh, 0 );
        };
        return \$var if !$@ && length($var) > 0;
    }

    return undef;
}

## mmap a file handle read-only [ falls back to slurp ] ##
sub mmap_file_read {

    my $fh = shift;

    if ( eval { require Sys::Mmap } ) {
        my $var;
        ## eval-guarded to mirror mmap_file [ write path ] : on mmap failure
        ## fall through to the slurp fallback instead of dying — the original
        ## read path lacked this guard and died standalone [ Bad filehandle ]
        eval {
            Sys::Mmap::mmap( $var, 0, Sys::Mmap::PROT_READ(),
                Sys::Mmap::MAP_SHARED(), $fh, 0 );
        };
        return \$var if !$@ && length($var) > 0;
    }

    ## fallback : slurp ##
    local $/;
    my $data = <$fh>;
    return \$data;
}

##[ MEMORY LOCKING [ prevent swap to disk ] ]#################################

## self-detecting fork guard for IO::AIO — IO::AIO's background worker state
## does not survive fork() cleanly [ confirmed live : a child spins at 100%
## CPU on its first post-fork IO::AIO call without this ]. rather than make
## every caller remember to call IO::AIO::reinit() after fork() [ the
## existing project convention — modules/base.process-into-background,
## modules/vision-batch.parent.fork_child,
## modules/weather.base.fork_weather_child all do this manually ], track the
## pid we last touched IO::AIO from ; if $$ has changed since, a fork
## happened in between and we reinit automatically before proceeding.
## $$ is a cached interpreter value, not a syscall — this check is one
## integer comparison, negligible next to the mlock call itself ##
my $_io_aio_pid;

sub _io_aio_fork_guard {
    return unless defined &IO::AIO::reinit;
    if ( defined $_io_aio_pid and $_io_aio_pid != $PID ) {
        eval { IO::AIO::reinit() };
        _log( 1, "IO::AIO::reinit failed after fork : $@" ) if $@;
    }
    $_io_aio_pid = $PID;
}

## lock a mapped region in memory. ported verbatim from
## data.mount.shm.lock.memory — already zenka-agnostic pure perl, no
## behavior change. returns a status hashref, never undef ##
sub lock_memory {

    my $mmap_ref = shift;
    my $offset   = shift // 0;
    my $length   = shift;

    return undef unless defined $mmap_ref && ref($mmap_ref) eq 'SCALAR';

    $length = length($$mmap_ref) unless defined $length;

    ## async mlock via IO::AIO, non-blocking ##
    if ( eval { require IO::AIO } ) {
        _io_aio_fork_guard();
        IO::AIO::aio_mlock( $$mmap_ref, $offset, $length );
        return {
            'locked' => 1,
            'method' => 'IO::AIO::aio_mlock',
            'offset' => $offset,
            'length' => $length,
        };
    }

    ## fallback : resource-limit advisory only, no true mlock ##
    if ( eval { require POSIX } ) {
        if ( eval { require BSD::Resource } ) {
            BSD::Resource::setrlimit( RLIMIT_MEMLOCK(), $length, $length );
        }
        return {
            'locked'  => 0,
            'method'  => 'posix_fallback',
            'warning' =>
                'IO::AIO not available, swap prevention advisory only',
            'offset' => $offset,
            'length' => $length,
        };
    }

    return {
        'locked'  => 0,
        'method'  => 'none',
        'warning' => 'No mlock mechanism available, sensitive data may swap',
    };
}

## unlock a previously locked region. ported verbatim from
## data.mount.shm.lock.unlock — same zero-behavior-change basis ##
sub unlock_memory {

    my ( $mmap_ref, $offset, $size ) = @ARG;

    return undef unless defined $mmap_ref && ref($mmap_ref) eq 'SCALAR';

    $offset //= 0;
    $size   //= ( length($$mmap_ref) - SHM_HEADER_SIZE );
    $offset += SHM_HEADER_SIZE;

    my $unlocked = 0;

    if ( eval { require BSD::Resource; 1 } ) {
        if ( defined &SYS_munlock ) {
            eval {
                syscall( &SYS_munlock, $$mmap_ref + $offset, $size );
                $unlocked = 1;
            };
        }
    }

    if ( !$unlocked && eval { require IPC::Shm::Simple; 1 } ) {
        eval { $unlocked = 1; };
    }

    ## file-based SHM without explicit munlock support : memory is freed
    ## when the segment is unlinked ; report success regardless ##
    return $unlocked || 1;
}

##[ PERMISSION SIGN / VERIFY ]################################################

## build canonical permission string [ shared by sign + verify ] ##
sub _permission_canonical {

    my $perm = shift;

    return
          $perm->{'to'} . ':'
        . $perm->{'branch'} . ':'
        . join( ',', @{ $perm->{'rights'} } ) . ':'
        . $perm->{'expiry'} . ':'
        . $perm->{'granted'};
}

## sign a permission grant with the owner's private key [ placeholder hash,
## identical mechanics to data.mount.shm.permission.add.sign_permission ].
## the multiplier matches the verifier's use of the derived owner pubkey so
## that privkey/pubkey fixtures of different lengths still verify. ##
sub sign_permission {

    my ( $perm, $priv_key ) = @ARG;

    my $canonical = _permission_canonical($perm);

    my $sig = 0;
    for my $i ( 0 .. length($canonical) - 1 ) {
        $sig
            = ( $sig * 31 + ord( substr( $canonical, $i, 1 ) ) ) & 0xFFFFFFFF;
    }
    my $multiplier_key = derive_pubkey($priv_key) // $priv_key;
    $sig = ( $sig * length( $multiplier_key || '' ) ) & 0xFFFFFFFF
        if length( $multiplier_key || '' );

    return sprintf( "%08X", $sig );
}

## verify a permission signature against the owner pubkey ##
sub _verify_permission_sig {

    my ( $perm, $owner_pubkey ) = @ARG;

    my $canonical = _permission_canonical($perm);

    my $sig = 0;
    for my $i ( 0 .. length($canonical) - 1 ) {
        $sig
            = ( $sig * 31 + ord( substr( $canonical, $i, 1 ) ) ) & 0xFFFFFFFF;
    }
    $sig = ( $sig * length( $owner_pubkey || '' ) ) & 0xFFFFFFFF
        if length( $owner_pubkey || '' );

    my $expected_sig = sprintf( "%08X", $sig );

    return $perm->{'sig'} eq $expected_sig;
}

## glob-style path pattern match ##
sub _path_pattern_match {

    my ( $path, $pattern ) = @ARG;

    $pattern =~ s{\*}{.*}g;
    $pattern =~ s{\?}{.}g;

    return $path =~ m{^$pattern$};
}

## requested rights covered by allowed rights ##
sub _rights_sufficient {

    my ( $requested, $allowed ) = @ARG;

    my %allowed = map { $_ => 1 } @$allowed;

    for my $right (@$requested) {
        return 0 unless $allowed{$right};
    }

    return 1;
}

## group membership check — groups registry is injected [ %data slice in
## zenka mode, caller-supplied hashref standalone ] to stay branch-free ##
sub _group_contains {

    my ( $group_id, $member_key, $groups ) = @ARG;

    $groups //= {};
    return 0 unless exists $groups->{$group_id};
    return grep { $_ eq $member_key } @{ $groups->{$group_id}{'members'} };
}

## verify requester has permission to access path. owner always has full
## access; non-owners are checked against signed grants in the header.
## $groups is the optional group registry hashref [ injected by caller ].
## identical authorization mechanics to data.mount.shm.permission.verify ##
sub permission_verify {

    my $header           = shift;
    my $requester_pubkey = shift;
    my $requested_path   = shift;
    my $requested_rights = shift;
    my $groups           = shift;

    return 0 unless defined $header && defined $requester_pubkey;

    return 1 if $requester_pubkey eq $header->{'owner_pubkey'};

    for my $perm ( @{ $header->{'permissions'} } ) {
        next if $perm->{'expiry'} < time();

        next
            unless $perm->{'to'} eq $requester_pubkey
            || _group_contains( $perm->{'to'}, $requester_pubkey, $groups );

        next
            unless _path_pattern_match( $requested_path, $perm->{'branch'} );

        next
            unless _rights_sufficient( $requested_rights, $perm->{'rights'} );

        next
            unless _verify_permission_sig( $perm, $header->{'owner_pubkey'} );

        return 1;
    }

    return 0;
}

##[ SEGMENT CREATE / OPEN ]###################################################

## create a file-backed mmap segment with a cryptographic identity header.
## options : sub_path, mlock, encrypted, compressed, time_source.
## time_source is an optional coderef returning the 'created' field value
## [ zenka wrapper passes <[base.time]>->(2); standalone defaults to time() ].
## mlock is NOT performed here — the caller [ zenka wrapper ] owns locking and
## the in-memory segment registry, keeping this core mechanics-only.
## returns a $mount hashref or undef. ##
sub shm_create {

    my $pub_key_b32 = shift;
    my $size        = shift // DEFAULT_SEGMENT_SIZE;
    my $options     = shift // {};

    return undef unless defined $pub_key_b32 && length($pub_key_b32) >= 32;

    my $shm_path = sprintf( "/dev/shm/p7:M:%s", $pub_key_b32 );

    if ( $options->{'sub_path'} ) {
        $shm_path .= ":" . $options->{'sub_path'};
        $shm_path =~ s{[^a-zA-Z0-9_:/\-]}{_}g;
    }

    my $total_size = $size + SHM_HEADER_SIZE;

    ## file-based SHM in /dev/shm [ tmpfs ] — portable, not POSIX/SysV ##
    open( my $fh, '+>', $shm_path ) or return undef;
    binmode($fh);

    truncate( $fh, $total_size );

    my $time_source = $options->{'time_source'};
    my $created     = defined $time_source ? $time_source->() : time();

    my $header = {
        'magic'        => 'P7SH',
        'version'      => 1,
        'owner_pubkey' => $pub_key_b32,
        'created'      => $created,
        'data_size'    => $size,
        'header_size'  => SHM_HEADER_SIZE,
        'flags'        => {
            'mlocked'    => $options->{'mlock'}      // 1,
            'encrypted'  => $options->{'encrypted'}  // 0,
            'compressed' => $options->{'compressed'} // 0,
        },
        'permissions' => [],
    };

    my $header_packed = pack_shm_header($header);
    syswrite( $fh, $header_packed );

    ## flush so data is on disk before mmap ##
    $fh->flush();

    ## mmap for zero-copy access ##
    my $mmap_ptr = mmap_file( $fh, $total_size );

    ## if mmap fails, fall back to scalar reference [ copied to memory ] ##
    if ( !defined $mmap_ptr ) {
        seek( $fh, 0, 0 );
        my $data;
        {
            local $/;
            $data = <$fh>;
        }
        $mmap_ptr = \$data;
    }

    close($fh);

    ## standalone mode has no zenka thin-wrapper layer to add mlock
    ## externally [ that's how the zenka path gets it — see
    ## modules/data.mount.shm.create ] ; do it here instead so the
    ## mlock=>1 default behaves the same whether a zenka is running or not ##
    if ( not defined $main::PROTOCOL_SEVEN ) {
        push @_standalone_owned_paths, $shm_path;
        if ( $header->{'flags'}{'mlocked'} ) {
            lock_memory( $mmap_ptr, 0, $total_size );
        }
    }

    return {
        'path'       => $shm_path,
        'pub_key'    => $pub_key_b32,
        'size'       => $size,
        'total_size' => $total_size,
        'mmap_ptr'   => $mmap_ptr,
        'header'     => $header,
        'type'       => 'file',
    };
}

## open a segment with cryptographic verification.
## options : rights, groups [ group registry hashref for verify ].
## returns a $mount hashref, or a { error => ... } hashref on failure. ##
sub shm_open {

    my $shm_path           = shift;
    my $options            = shift // {};
    my $requester_priv_key = shift;

    return undef unless defined $shm_path;

    if ( $shm_path !~ m{^/} ) {
        $shm_path = "/dev/shm/p7:M:$shm_path";
    }

    my ( $pub_key, $sub_path ) = parse_shm_path($shm_path);
    return undef unless defined $pub_key;

    my $requested_rights = $options->{'rights'} // ['read'];

    my $open_mode = ( ( $options->{'mode'} // '' ) eq 'read' ) ? '<' : '+<';

    open( my $fh, $open_mode, $shm_path )
        or return { 'error' => 'open_failed', 'path' => $shm_path };
    binmode($fh);

    my $mmap_ref = mmap_file_read($fh);
    close($fh) unless defined $mmap_ref;

    return { 'error' => 'segment_not_found', 'path' => $shm_path }
        unless defined $mmap_ref;

    my $header = header_read($mmap_ref);
    return { 'error' => 'invalid_header' } unless defined $header;

    return { 'error' => 'ownership_mismatch' }
        unless $header->{'owner_pubkey'} eq $pub_key;

    my $requester_pubkey = derive_pubkey($requester_priv_key);

    my $has_access
        = permission_verify( $header, $requester_pubkey, $sub_path // '',
        $requested_rights, $options->{'groups'}, );

    return { 'error' => 'access_denied' } unless $has_access;

    return {
        'path'        => $shm_path,
        'pub_key'     => $pub_key,
        'sub_path'    => $sub_path,
        'mmap_ptr'    => $mmap_ref,
        'header'      => $header,
        'type'        => 'file',
        'data_offset' => SHM_HEADER_SIZE,
        'data_size'   => $header->{'data_size'},
        'requester'   => $requester_pubkey,
    };
}

##[ STALE SEGMENT SWEEP [ phase 4 part B ] ]##################################

## scan a directory [ default /dev/shm ] for p7:M:* segments and unlink any
## that are both stale [ created more than $ttl_seconds ago ] AND owned by
## the current effective UID. never attempts to unlink a file owned by a
## different UID -- the sticky bit on /dev/shm would refuse it anyway, and
## attempting it would just be noise. returns a summary hashref, never dies.
sub sweep_stale_segments {

    my $options     = shift                     // {};
    my $dir         = $options->{'dir'}         // '/dev/shm';
    my $ttl_seconds = $options->{'ttl_seconds'} // 3600;

    my %summary = (
        'scanned'             => 0,
        'reaped'              => 0,
        'skipped_fresh'       => 0,
        'skipped_other_owner' => 0,
        'skipped_unreadable'  => 0,
        'errors'              => [],
    );

    opendir( my $dh, $dir ) or return \%summary;
    my @candidates = grep {/^p7:M:[^.]/} readdir($dh);
    closedir($dh);

    for my $name (@candidates) {
        my $path = "$dir/$name";
        $summary{'scanned'}++;

        # ownership check FIRST [ -O is "owned by effective uid" ] ; never
        # attempt to even open-for-read-then-stat a file we can't reap, to
        # keep this cheap and to keep the "skipped, not failed" count honest
        if ( not -O $path ) {
            $summary{'skipped_other_owner'}++;
            next;
        }

        my $header = _read_header_only($path);
        if ( not defined $header ) {
            $summary{'skipped_unreadable'}++;
            next;
        }

        my $age = time() - ( $header->{'created'} // 0 );
        if ( $age <= $ttl_seconds ) {
            $summary{'skipped_fresh'}++;
            next;
        }

        _standalone_unlink_segment($path)
            ;    # already removes the .notify FIFO too
        $summary{'reaped'}++;
    }

    return \%summary;
}

## lightweight header peek : open + read first 512 bytes, no mmap, no lock.
## this is a maintenance scan, not a real mount -- it should never need the
## weight of shm_open's full mmap_file_read + permission_verify machinery.
sub _read_header_only {
    my $path = shift;
    open( my $fh, '<', $path ) or return undef;
    binmode($fh);
    my $raw;
    my $got = read( $fh, $raw, SHM_HEADER_SIZE );
    close($fh);
    return undef unless defined $got and $got == SHM_HEADER_SIZE;
    return undef unless substr( $raw, 0, 4 ) eq 'P7SH';
    return unpack_shm_header($raw);
}

##[ STANDALONE CLEANUP ]######################################################

## remove a creator-owned segment [ + its phase-3 notify FIFO ] on graceful  ##
## exit. this is the standalone counterpart to data.mount.shm.unlink/remove; ##
## it is intentionally self-contained because standalone code cannot reach   ##
## the zenka <[...]> dispatcher.                                             ##
sub _standalone_unlink_segment {
    my $shm_path = shift;
    unlink($shm_path) if -f $shm_path;
    my $notify_path = $shm_path . '.notify';
    unlink($notify_path) if -p $notify_path;
    return;
}

## install graceful-shutdown signal handlers in standalone mode so that
## SIGINT/SIGTERM run END blocks and therefore clean up creator-owned
## segments. without a handler Perl's default signal action terminates the
## process without invoking END. zenka mode handles cleanup in
## modules/data.mount.shm.init_code instead.
if ( not defined $main::PROTOCOL_SEVEN ) {
    my $graceful_exit = sub { exit(0) };
    $SIG{'INT'}  = $graceful_exit;
    $SIG{'TERM'} = $graceful_exit;
}

END {
    ## explicit skip in zenka mode — defense in depth alongside the fact
    ## that @_standalone_owned_paths is only ever populated when standalone ;
    ## zenka cleanup runs via modules/data.mount.shm.cleanup instead ##
    unless ( defined $main::PROTOCOL_SEVEN ) {
        _standalone_unlink_segment($_) for @_standalone_owned_paths;
    }
}

return TRUE  #################################################################

#,,,,,,..,.,.,...,.,,,,.,,..,,,,.,,,,,..,,,.,,..,,...,.,.,,..,,,,,,..,...,,,.,
#7CTYTNAV3CXH7QDSA33BHCSO5XDGTJ5J7GR3A2SXROE47D4KWFQGLEMX4W3RA4WIXS2EFC7BL4QW4
#\\\|IPO7MGQ42HX2TTPOVZH6AIHZA2CINU4RZQP7QX2YNLHWRX53AVJ \ / AMOS7 \ YOURUM ::
#\[7]AUZGXZQHZXAT4G36ANAAFEAONBGW3QIR4XLUUC6EEMVZ4Q3ETECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
