# Protocol-7: Zenki Startup and Management Guide

## Core Components Startup Flow

### 1. Starting the Core Stack

The basic Protocol-7 stack starts with three essential components:

1. **cube** - The message routing and session management zenka
2. **v7** - The zenka management and control system
3. **p7-log** - The logging system zenka

### 2. The v7 Zenka: System Manager

The v7 zenka acts as the primary control system. It:
- Manages zenki lifecycle (start, stop, restart)
- Handles job queues
- Manages authentication
- Controls system state

Key configuration from v7's start file:
```perl
system.zenka.name = v7
modules.load = v7 jobqueue net protocol io.unix io.ip crypt.C25519 auth.zenka
```

### 3. Zenki Start Modes

Zenki can be started in several modes:

#### stdin-zenka Mode
Used when a zenka receives its configuration through standard input.
```perl
: v7-init :
  start_mode = stdin-zenka
  cube.key = [base.prng.chars-anum:44]
```

#### exec-external Mode
For running external programs as zenki:
```perl
: v7-init :
  start_mode = exec-external
  exec_bin = /path/to/binary
  exec_usr = username
```

### 4. X11 Integration

The X11 zenka provides display server integration and can run in multiple modes:
- host (connects to existing X server)
- xorg (starts new X server)
- xephyr (nested X server)
- nxagent
- xnest
- xvfb (virtual framebuffer)

Configuration example:
```perl
X-11.mode = host
X-11.display.xorg = :13
X-11.params.xorg = -quiet
```

## Managing Zenki Through v7

### Interacting with Protocol-7

### Using nshell and p7c

Protocol-7 provides two main ways to interact with the system:

1. **nshell** - An interactive shell for Protocol-7
2. **p7c** - A command-line tool for single commands

Example session showing system status and interaction:

```bash
# Check Protocol-7 service status
$ systemctl status Protocol-7
● Protocol-7.service - [AMOS7] PROTOCOL 7 [ v7-zenka ]
     Active: active (running) since Sun 2025-02-23 06:23:10 CET; 7s ago
     CGroup: /system.slice/Protocol-7.service
             ├─22017 atom.v7
             ├─22019 atom.cube
             ├─22021 atom.httpd
             ├─22022 atom.p7-log
             ├─22023 atom.system
             ├─22024 atom.events
             └─22027 "system--'term'-child"

# Check current session identity
$ p7c whoami
unix-root 7079779

# List active sessions
$ p7c list sessions
 : usid :.  : protocol :.  : type :.  : mode :.  : uname :.  : since :.
------------------------------------------------------------------------
  5920713     protocol-7     unix      client       v7            1'30"
  7701530     protocol-7     unix      client      httpd          1'26"
  7717703     protocol-7     unix      client     p7-log          1'26"
  7347529     protocol-7     unix      client     system          1'26"
  7927047     protocol-7     unix      client     events          1'26"

# List running zenki
$ p7c v7.list zenki
 : instance :.  : job id :.  : name :.  : zenka id :.  : status :.
-------------------------------------------------------------------
   7749157        1577953      httpd       1270477       online
   7202773        3770954      system      5799295       online
   7077792        1942777      p7-log      7201797       online
   4912770        4770771      events      4252007       online
   4427527        3920291      cube        5413514       online
```

### Basic Commands

1. Starting a zenka:
```
v7.start zenka_name
```

2. Stopping a zenka:
```
v7.stop zenka_name
```

3. Restarting a zenka:
```
v7.restart zenka_name
```

### Startup Configuration

Zenki startup configurations are defined in files like `start-set-up.base`:

```perl
.: zenki :.

- dist-upgrade
    max_concurrency = 1
    restart.disabled = 1
    : v7-init :
      start_mode = exec-external
      exec_bin = debian_dist_upgrade.sh
      exec_usr = root
```

### Authentication and Security

1. C25519 Key-based Authentication
- Uses curve25519 for secure communication
- Supports key generation and management
- Enables secure zenki authentication

2. Multiple Auth Methods
```perl
auth.supported_methods = zenka unix twofish pwd
```

### Dependency Management

Zenki can specify dependencies:
```perl
dependencies = cube
max_concurrency = 1
```

## Monitoring and Control

### Heartbeat System
Zenki maintain connection status through heartbeat messages:
```perl
heartbeat.timeout = 7
```

### Status Tracking
The v7 zenka tracks:
- Running zenki
- Startup status
- Dependencies
- Error states

## Advanced Features

### Job Queues
The v7 zenka includes a job queue system for:
- Scheduled tasks
- Dependency resolution
- Task prioritization

### Event System
- Zenki can subscribe to events
- Event-based triggers for actions
- Inter-zenka communication

## Development and Debugging

### Logging
The p7-log zenka provides:
- Centralized logging
- Log levels
- Log routing

### Debug Modes
```perl
system.verbosity.console = 2
system.verbosity.zenka_buffer = 1
```

## Available Commands

The Protocol-7 system provides a rich set of commands for interaction and management. Here are some key categories:

### System Information
- `whoami` - Return current user name and session id
- `commands` - List available commands
- `src-ver` - Show running source code version
- `rel-ver` - Show release version
- `ptl-ver` - Display protocol version

### Session Management
- `list sessions` - Show active sessions
- `present <name>` - Check if user/zenka is connected
- `when-present <command>` - Queue command for when zenka connects
- `set-initialized` - Mark zenka as initialized

### Authentication
- `get-session-key` - Get public session key (BASE32)
- `get-session-sig` - Get session key signature
- `set-client-key` - Set client public key
- `clear-zenka-key` - Securely erase zenka key

### Zenki Management
- `v7.list zenki` - List running zenki
- `dependencies` - Show zenka dependencies
- `ondemand-zenka` - Manage on-demand zenki

### Logging and Buffers
- `show-buffer` - Display buffer content
- `buffer-erase` - Clear buffer content
- `verbosity` - Show/set log levels

### Time and Timestamps
- `timestamp` - Get network time
- `localtime` - Get local time
- `epoch_v7` - Get V7 epoch timestamp

### System Control
- `reload` - Reload configurations
- `term-all` - Close user sessions
- `exit` - Close current session

## Common Patterns

1. **Basic Zenka Startup Flow**:
   - Initialize modules
   - Set up authentication
   - Connect to cube
   - Begin normal operation

2. **Configuration Loading**:
   ```perl
   [load_config_file:'shared-params']
   [load_config_file:'specific-config']
   ```

3. **Module Loading**:
   ```perl
   modules.load = base_modules plugin_modules specific_modules
   [load_modules:<modules.load>]
   [init_modules]
   ```

## Troubleshooting

Common issues and solutions:

1. Authentication Failures
   - Check key permissions
   - Verify authentication method availability
   - Check zenka startup messages

2. Dependency Issues
   - Ensure required zenki are running
   - Check startup order
   - Verify configuration

3. Connection Problems
   - Check cube zenka status
   - Verify network configuration
   - Check authentication status

## Best Practices

1. **Zenka Design**
   - Keep zenki focused on specific tasks
   - Use clear dependency chains
   - Implement proper error handling

2. **Configuration**
   - Use shared configuration where appropriate
   - Document custom settings
   - Follow naming conventions

3. **Security**
   - Use appropriate authentication methods
   - Manage keys securely
   - Follow principle of least privilege

## Next Steps

1. Study the example configurations
2. Experiment with basic zenki
3. Learn the v7 command set
4. Understand the messaging system
5. Explore advanced features

The Protocol-7 system is designed to be flexible and extensible. Understanding these basics will provide a foundation for working with more complex configurations and use cases.