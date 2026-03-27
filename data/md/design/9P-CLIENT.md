# 9P Client - Mount Remote Filesystems

The 9P client allows Protocol-7 to connect to remote 9P servers, such as:
- WSL Windows host filesystem (`/mnt/c`, etc.)
- QEMU VirtFS shares
- Plan 9 systems
- Other Protocol-7 instances

## Usage

### Connect to WSL Windows Host

```bash
# In amos-term
mount-9p-client 127.0.0.1 5640 wsl-host

# Or use default port
mount-9p-client 127.0.0.1
```

WSL exposes Windows drives via 9P on port 5640 by default.

### List Directory

```bash
p7c plan-9.client.list-dir wsl-host /mnt/c/Users
```

### Read File

```bash
p7c plan-9.client.read-file wsl-host /mnt/c/Users/YourName/Documents/file.txt
```

### Disconnect

```bash
p7c plan-9.client.disconnect wsl-host
```

## Architecture

### Low-Level Protocol Operations

| Module | Purpose |
|--------|---------|
| `plan-9.client` | Connect to server |
| `plan-9.client.version` | Version negotiation |
| `plan-9.client.attach` | Attach to filesystem |
| `plan-9.client.walk` | Walk directory path |
| `plan-9.client.open` | Open file |
| `plan-9.client.read` | Read file data |
| `plan-9.client.stat` | Get file info |
| `plan-9.client.clunk` | Close file |
| `plan-9.client.read-message` | Read server response |

### High-Level Operations

| Module | Purpose |
|--------|---------|
| `plan-9.client.read-file` | Read entire file |
| `plan-9.client.list-dir` | List directory contents |
| `plan-9.client.disconnect` | Close connection |

## Use Cases

### Windows File Assimilation

```bash
# Index Windows Documents
p7c plan-9.client.list-dir wsl-host /mnt/c/Users/$USER/Documents | \
    grep -E '\.(doc|pdf|txt)$' > windows-docs.txt
```

### Cross-Platform Downloads

```bash
# Download file to Windows Downloads folder
p7c plan-9.client.read-file p7-server /path/to/file > /mnt/c/Users/$USER/Downloads/file
```

### Backup Operations

```bash
# Backup Windows home directory
rsync -av /mnt/wsl-host/Users/$USER/Documents /backups/windows/
```

### PowerShell Integration

Combined with existing `socat.exe` + `powershell.exe` integration:

```bash
# Launch PowerShell command that saves to Windows filesystem
powershell.exe -Command "Get-Process | Export-Csv C:\\temp\\processes.csv"

# Then read via 9P
p7c plan-9.client.read-file wsl-host /mnt/c/temp/processes.csv
```

## Security Notes

- 9P client connects as specified user (default: root)
- No encryption by default (use SSH tunnel for remote servers)
- WSL 9P server is localhost-only by default (safe)

## Future Enhancements

- Write support (file upload)
- Directory creation
- File deletion
- Caching layer
- FUSE mount wrapper (mount 9P as local filesystem)
- SSH tunnel integration

#,,,.,..,,,.,,,.,,..,,,,.,,,.,..,,,..,...,,,,,..,,...,...,,,,,,..,.,,,...,..,,
#3WRLNJUGOQCBXAV6KJBHRECUIASFULJSHH65XMSIBQFEKL26EUHBYN5QPPF3YD3VB5CM4A7FQXXEW
#\\\|N5BKKKGGKRNNHGSQVGRTR5J6XF44JEASH63WTX6EX6X7OQ4DR4O \ / AMOS7 \ YOURUM ::
#\[7]RSV64FGY4TL4H6NK3M2JQFJFCE2KEF7ZEINRIK3GDNRDKX5I3GBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
