# Alternative Mounting Options (No FUSE Required)

## The Problem

FUSE 2.x (required by Perl `Fuse` module) is incompatible with modern Linux:
- FUSE 2.9.9 (2016) conflicts with modern glibc (`closefrom` function)
- Modern distros only ship FUSE 3.x
- Perl `Fuse` module is unmaintained (last release 2011)

## Alternatives

### Option 1: 9P (Plan 9 Protocol) - RECOMMENDED

```
9P Protocol:
  ✓ Native Linux kernel support (since 2.6.14)
  ✓ No userspace FUSE daemon needed
  ✓ Network-transparent
  ✓ Simple protocol, easy to implement
  ✓ Mount with: mount -t 9p ...
  
Implementation:
  ┌─────────────────────────────────────────┐
  │  amos-term 9P server (Perl)             │
  │  ├── Exports buffer as 9P filesystem    │
  │  └── Runs as user daemon                │
  └─────────────────────────────────────────┘
              │
              │ 9P protocol over Unix socket
              │
  ┌─────────────────────────────────────────┐
  │  Kernel 9P client                       │
  │  └── mount -t 9p 127.0.0.1 /mnt/buffer  │
  └─────────────────────────────────────────┘

Perl modules:
  - Dancer::Plugin::Nine (heavy)
  - Net::DFC::Protocol::Nine (lighter)
  - Custom implementation (simplest)
```

### Option 2: bindfs / bind mounts

```
Simple bind approach:
  # Instead of FUSE filesystem, use:
  mount --bind /proc/amos-term/buffer /mnt/buffer
  
Limitations:
  • Read-only without complex kernel module
  • Doesn't provide the "filesystem view" we want
  • Hacky
```

### Option 3: WebDAV

```
WebDAV server:
  ✓ HTTP-based, mountable via davfs2
  ✓ Cross-platform
  ✓ No kernel module needed for server
  
Implementation:
  - amos-term runs WebDAV server on localhost
  - User mounts: mount -t davfs http://localhost:PORT /mnt/buffer
  
Perl modules:
  - HTTP::DAV::Server
  - Net::DAV::Server
```

### Option 4: SSHFS-compatible (SFTP)

```
SFTP subsystem:
  - amos-term provides SFTP server on Unix socket
  - Mount via: sshfs -o ssh_command=amos-sftp-bridge ...
  
Complexity: High
Benefit: Standard tools work
```

### Option 5: Custom Socket Protocol

```
Simplest implementation:
  # amos-term exports buffers via Unix socket
  # Custom client library (Perl/Python) mounts
  
Protocol:
  GET /buffer/amos:XYZ789/z-0
  PUT /buffer/amos:XYZ789/z-0
  LIST /buffer/amos:XYZ789/
  
No kernel mount - just client library.
This is NOT a filesystem mount, but API access.
```

## Recommendation: 9P

### Why 9P?

```
1. Native kernel support
   mount -t 9p 127.0.0.1 /mnt/amos-term -o trans=tcp,port=PORT

2. Simple protocol
   - 9 message types (version, auth, attach, walk, open, read, write, clunk, remove)
   - Text-based where possible
   - Easy to debug

3. No FUSE dependency
   - Kernel handles filesystem operations
   - User daemon just responds to 9P messages

4. Modern usage
   - Used by QEMU (virtio-9p)
   - Used by containers (rootless containers)
   - Active kernel development

5. Perl implementation exists
   - Can adapt from existing code
   - Or write minimal implementation (~500 lines)
```

### 9P Implementation Sketch

```perl
## amos-term.9p.server ##

use IO::Socket::INET;
use constant {
    Tversion => 100,
    Rversion => 101,
    Tattach  => 104,
    Rattach  => 105,
    Twalk    => 110,
    Rwalk    => 111,
    Topen    => 112,
    Ropen    => 113,
    Tread    => 116,
    Rread    => 117,
    Twrite   => 118,
    Rwrite   => 119,
    Tclunk   => 120,
    Rclunk   => 121,
};

sub serve_9p {
    my ($port) = @_;
    
    my $server = IO::Socket::INET->new(
        LocalPort => $port,
        Listen    => 5,
        Reuse     => 1,
    ) or die "Cannot create 9P server: $!";
    
    while (my $client = $server->accept()) {
        while (my $msg = read_9p_message($client)) {
            my $response = handle_9p_request($msg);
            send_9p_message($client, $response);
        }
    }
}

sub handle_9p_request {
    my ($msg) = @_;
    my ($type, $tag, $data) = unpack_9p($msg);
    
    given ($type) {
        when (Tversion) { return handle_version($tag, $data) }
        when (Tattach)  { return handle_attach($tag, $data) }
        when (Twalk)    { return handle_walk($tag, $data) }    # path traversal
        when (Topen)    { return handle_open($tag, $data) }
        when (Tread)    { return handle_read($tag, $data) }    # read buffer layer
        when (Twrite)   { return handle_write($tag, $data) }   # write buffer layer
        default         { return error_response($tag, "unknown type") }
    }
}

sub handle_read {
    my ($tag, $data) = @_;
    my ($fid, $offset, $count) = unpack_9p_read($data);
    
    # Map 9P fid to buffer location
    my $buffer = $fid_to_buffer{$fid};
    my $layer = $buffer->get_layer($fid->{z});
    
    # Read from buffer at offset
    my $content = substr($layer->{data}, $offset, $count);
    
    return pack_9p_read_response($tag, $content);
}
```

### Usage

```bash
# 1. Start amos-term 9P server
amos-term 9p-server --port 5640 --buffer amos:XYZ789

# 2. Mount via kernel 9P
sudo mount -t 9p 127.0.0.1 /mnt/amos-term \
    -o trans=tcp,port=5640,uname=$USER

# 3. Access buffer as filesystem
cat /mnt/amos-term/z-0        # Read layer 0
echo "data" > /mnt/amos-term/z-1  # Write layer 1
cat /mnt/amos-term/metadata   # Buffer metadata
```

## Option 6: Port Fuse.pm to FUSE 3

```
Effort estimate: 2-4 weeks full-time

FUSE 2 → 3 API changes:
- Different initialization (fuse_main → fuse_session)
- Different file operation structs
- Low-level vs high-level API split
- Inode-based operations required

Would require:
1. Fork Fuse.pm on CPAN
2. Rewrite XS bindings for FUSE 3
3. Maintain compatibility layer
4. Release as Fuse3

Benefit: Clean, native FUSE 3 support
Cost: Significant development effort
```

## Conclusion

> **Recommendation: Implement 9P server for amos-term.**
> 
> - No kernel module development needed
> - No FUSE compatibility issues
> - Modern, supported protocol
> - Simpler than WebDAV/SSHFS
> - Can be implemented incrementally

FUSE 2.x is effectively dead on modern Linux. Let's move forward with 9P.

#,,.,,.,,.,,.,,.,.,.,.,.,,.,.,.,,.,.,.,,.,,.,.,.,,.,.,.,,.,.,.,,.,.,.,,.,.,.,,

#,,..,,..,,,,,.,.,..,,,..,,.,,,.,,,,.,..,,...,..,,...,...,,..,,..,,.,,,..,.,,,
#IG3P46QELBYDVOCXOU6GSXH5BZIOE3OGJY2NTDSQCJUPIH4TXWAVEIZKAP6N6OG4PBTKDEDQ5VVCM
#\\\|7N4TDZVNUWYG7BKBU4RWCS7AZTQWM2B3EE4L263WSRHH3LTMS36 \ / AMOS7 \ YOURUM ::
#\[7]FXQY6WM57IAJXXHNLJZYRC4VUGKYO6S3BLNT3X5CJTDNJ5N33GDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
