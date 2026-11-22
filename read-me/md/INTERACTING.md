# Interacting with the Protocol-7 Network

the full detail behind the short section in the [readme](/read-me/md/README.md#interacting-with-the-system).
three primary methods : the nshell terminal interface, the command execution
binaries [ `p7c`, `p-7-r` and their short forms ], and the zenka alias symlinks.

## Contents

- [nshell : interactive terminal](#nshell--interactive-terminal)
- [Command execution binaries](#command-execution-binaries)
  - [p7c](#p7c)
  - [p-7-r](#p-7-r)
  - [Short forms](#short-forms)
  - [Authorizing a remote user](#authorizing-a-remote-user)
- [Common commands](#common-commands)
- [Command routing](#command-routing)
- [Zenka-specific command discovery](#zenka-specific-command-discovery)
- [Zenka alias symlinks](#zenka-alias-symlinks)

## nshell : interactive terminal

the recommended method [ fully refactored ].

```bash
p7-nshell
```

or equivalently:

```bash
./bin/Protocol-7 nshell
```

- Interactive shell for direct Protocol-7 network access
- Pure-Perl implementation with non-blocking I/O
- Full UTF-8 support with proper character buffering
- **Enhanced history navigation**: Session-based Page Up/Down with LIFO symmetry
- **Sequential arrow keys**: Up/Down navigate sequentially through history
- **Ctrl+R search**: Real-time history search with phosphor-colored search term display
- **Ctrl+O cycle**: Execute and advance through history sequence (cycling two entries)
- Strips protocol reply strings for cleaner output (similar to p7c and p-7-r)
- All navigation features fully tested and production-ready
- **Live coding-zenka session integration**: split-screen mode, `Tab` toggles between
  the coding-session view and normal Protocol-7 mode; auto-subscribes to a task and
  streams its output live
- **Round-based rewind/redo**: `Esc` (after first aborting) steps back one round,
  `F1`/`Shift+Esc` redo forward, `round-regen` forks a fresh-inference retry from any
  point, `restream` resyncs the view manually

See: [`NSHELL_REFACTORING_COMPLETED.md`](/data/md/documentation/NSHELL_REFACTORING_COMPLETED.md) for implementation details

**Legacy alternative:** `bin/nshell`

- Still available for compatibility
- Prints full protocol reply strings for debugging
- Use when you need to see complete protocol details

## Command execution binaries

### p7c

p7c [ protocol-7 command ] :

```bash
p7c <command> [args]
```

- Local command execution
- Automatically compiled and installed during v7-zenki startup
- Connects directly to the Protocol-7 network
- Uses current Unix user for authentication
- Installed at: `/usr/local/bin/p7c`

### p-7-r

p-7-r [ protocol-7 remote ] :

```bash
p-7-r [-v] [-strict] <hostname[:port]> <command> [args]
```

- Remote command execution over network [ default port 42 ]
- Automatically compiled and installed during v7-zenki startup
- Authenticates with the caller's key [ auth-keypair, `~/.n/user-keys/` ] ;
  the server has to authorize it first [ see *Authorizing a remote user* below ]
- The server proves its identity : its host-root is pinned on first
  contact in `~/.n/remote-keys/servers/<host>_<port>.public`, a different
  host-root later is refused. `-strict` refuses an unpinned server
- Installed at: `/usr/local/bin/p-7-r`

### Short forms

symlinks kept by v7-zenki :

```bash
:: <command> [args]            # = p7c, local
::: <alias> <command> [args]   # = p-7-r through 'ssh -W'
```

- `<alias>` is a `Host` of the caller's `~/.ssh/config` [ no dots ] with a
  `HostName` ; the link is `ssh -W 127.0.0.1:42 <alias>`, so a server
  only needs to expose ssh. a dotted word is never a host here : a
  slipped `::: zenka.cmd` fails before any lookup

  ```
  Host node-local
      HostName host.example.local
      User root
  ```

  then `::: node-local list sessions`, `::: node-local v7-zenki.list zenki`

### Authorizing a remote user

on the server, once per user :

```bash
USER=protocol-7 p7-keys add-incoming <user> <public key | file | -> cube
```

- writes the user's public key [ e.g. a copied `<user>.base.public` ] to
  the zenka user's `incoming/` and authorizes it for `cube` in one call
- cube watches its authorized keys [ inotify ] and re-reads them within a
  second -- no reload, no restart ; revoking with `p7-keys
  drop-authorized cube:<user>` applies the same way
- run as root, `p7-keys` works on root's own registry unless `USER`
  names the zenka user [ it prints a note then ] ; every directory it
  creates or finds root-owned is handed to the zenka user, so a repeated
  call also repairs a root-made registry
- related : `p7-keys incoming`, `list-authorized`, `authorize
  cube:<user>`, `re-pin cube:<user> <new key>` [ a rotated user key ]

## Common commands

- `p7c list sessions`: Display active network sessions

  ```
   : usid :.  : protocol :.  : type :.  : mode :.  : uname :.  : since :.
  ---------------------------------------------------------------------------
    3495297    protocol-7      unix      server       ---        16h 58'38"
    7310444    protocol-7     ip.tcp     server       ---        16h 58'38"
    5771202    protocol-7      unix      client    v7-zenki      16h 58'38"
    7091700    protocol-7      unix      client     system       16h 58'36"
    9079727    protocol-7      unix      client     p7-log       16h 58'35"
    ...
  ```

- `p7c commands`: List available commands for the current zenka

  - Returns a flat list of every command the zenka accepts, each with a
    one-line description and its argument form — session handling, network
    time, log buffers, routing overrides, cryptographic utilities and so on

## Command routing

### Command routing mechanism

- Local Context Commands:
  * `p7c commands`: Commands for the currently connected zenka (local cube)
  * `p7c <zenka>.commands`: Commands for specific zenki
  * Recursive routing possible: `p7c weather.child.commands`

### Routing principles

- No `.` in command: Routes to local context
- `.` in command: Routes to specified zenka or nested zenki
- Enables flexible, hierarchical command routing

### Command capabilities

- Discover and interact with any zenka
- Retrieve zenka-specific lists and information
- Manage network sessions
- Execute operations across different agents

## Zenka-specific command discovery

- `p7c v7-zenki.list`: Lists specific to the v7-zenki management zenka

  ```
   : list name :.    : description :.
  ------------------------------------------------------------------------------
    dependency         current zenka dependency status
     heartbeat         heartbeat latency per instance [ cube : v7 round trip ]
     available         available zenki \ descriptions
      subnames         'subnames' of registered zenki [ when available ]
      sessions         registered \ connected sessions
      children         PIDs of zenki and their children
       buffers         [log] ring buffers in use
        manual         zenki marked as 'manually stopped'
         zenki         currently running \ managed zenka instances
  ```

## Zenka alias symlinks

On startup, v7-zenki installs a `p7-<zenka>` symlink to
[bin/Protocol-7](/bin/Protocol-7) for every zenka that carries console
commands — `p7-keys`, `p7-nshell`, `p7-work`, `p7-sourcecode` and so on.
Invoking the symlink starts that zenka directly, so `p7-nshell` is
equivalent to `bin/Protocol-7 nshell`.

- Symlink directory: `v7-zenki.cfg.zenka_symlink_dir` [ `/usr/local/bin` ]
- Installation toggle: `v7-zenki.cfg.install_zenka_symlinks`
- The earlier `v7.<zenka>` symlink form is deprecated: `bin/Protocol-7`
  still recognizes it, but new installations get the `p7-` prefix only

#,,..,,.,,.,.,...,,,.,.,,,.,.,.,,,,.,,,,.,.,,,..,,...,...,...,,,.,,,,,..,,,.,,
#YJWMU7ZQHMFT4ARAP32C7FOJHBRCABDPXSE2VLDUG5UREX4JF5W3FFALJB4MBPSWAD4OSY2YMBKRS
#\\\|Q56W7SQ6G4Y4AFIJ4Q4O3GVGXM3D4H37KYVTVEA5SILIZ6LW53W \ / AMOS7 \ YOURUM ::
#\[7]XKSMVTFOQJ2AC6SID624MEHG7APHD45COR77HT3JY2THZXCUIYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
