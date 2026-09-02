# Remote Sync Tunnel - Auto-Mounting Remote Protocol-7 Systems

Quick setup for mounting remote Protocol-7 code, content, and logs with automatic SSH tunneling and crash recovery.

## Purpose

Allows local development/testing against a remote Protocol-7 deployment without requiring full link-level encryption setup. Useful for:

- Testing letsencrypt chain on remote before production deployment
- Iterative development on remote infrastructure
- Monitoring remote logs and content in real-time
- Automatic recovery if remote server crashes

## Setup

### 1. Install SSH Key Authentication

The remote user account must allow SSH key-based login:

```bash
# Generate local SSH key if needed
ssh-keygen -t ed25519 -f ~/.ssh/id_p7_remote

# Copy public key to remote
ssh-copy-id -i ~/.ssh/id_p7_remote taeki@atom.local

# Configure SSH to use this key
cat >> ~/.ssh/config <<'EOF'
Host atom.local
    User taeki
    IdentityFile ~/.ssh/id_p7_remote
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
```

### 2. Install Dependencies on Local System

```bash
# Perl modules (usually already available)
sudo cpan Net::Ping

# SSHFS for mounting
sudo apt-get install sshfs   # Debian/Ubuntu
sudo brew install sshfs      # macOS
```

### 3. Install Service Files

```bash
# Copy script to /usr/local/bin
sudo cp bin/admin/remote-sync-tunnel /usr/local/bin/
sudo chmod +x /usr/local/bin/remote-sync-tunnel

# Copy systemd service
sudo cp bin/admin/remote-sync-tunnel.service /usr/lib/systemd/system/
sudo systemctl daemon-reload
```

### 4. Configure for Your Environment

Edit `/usr/lib/systemd/system/remote-sync-tunnel.service`:

```ini
Environment="REMOTE_P7_HOST=atom.local"      # Your remote hostname
Environment="REMOTE_P7_USER=taeki"           # Remote username
```

### 5. Create protocol-7 System User (if needed)

```bash
# Create user for SSH key access
sudo useradd -r -s /bin/false protocol-7
sudo mkdir -p /home/protocol-7/.ssh
sudo cp ~/.ssh/id_p7_remote /home/protocol-7/.ssh/
sudo chown -R protocol-7:protocol-7 /home/protocol-7/.ssh
sudo chmod 700 /home/protocol-7/.ssh
```

## Usage

### Start Service

```bash
sudo systemctl start remote-sync-tunnel
```

### Enable on Boot

```bash
sudo systemctl enable remote-sync-tunnel
```

### Check Status

```bash
sudo systemctl status remote-sync-tunnel
# or
/usr/local/bin/remote-sync-tunnel status
```

### View Logs

```bash
sudo journalctl -u remote-sync-tunnel -f
# or
tail -f /var/log/autossh-atom.local.log
```

### Manual Operations

```bash
# Start manually
/usr/local/bin/remote-sync-tunnel start

# Stop
/usr/local/bin/remote-sync-tunnel stop

# Monitor with auto-recovery
/usr/local/bin/remote-sync-tunnel monitor

# Check current status
/usr/local/bin/remote-sync-tunnel status
```

## What Gets Mounted

| Local Path | Remote Path | Purpose |
|-----------|-----------|---------|
| `/usr/local/protocol-7` | `/data/projects/protocol-7` | Code & modules |
| `/var/httpd` | `/var/www` | HTTP content |
| `/var/log/protocol-7` | `/var/log/protocol-7` | Log files |

## SSH Tunnels Created

| Service | Local Port | Remote Port | Purpose |
|---------|-----------|-----------|---------|
| p7c | 7777 | 7777 | Client command access |
| p7r | 7778 | 7778 | Remote operations |

## Auto-Recovery Behavior

The `monitor` mode continuously checks if the remote server is alive:

1. **Server down**: Automatically unmounts directories, closes tunnels
2. **Server returns**: Automatically re-establishes tunnels, remounts directories
3. **Check interval**: 30 seconds (configurable in script)

## Troubleshooting

### Mount Fails: "Permission denied"

```bash
# Ensure SSH key is working
ssh -i ~/.ssh/id_p7_remote taeki@atom.local echo "OK"

# Check SSH agent has key
ssh-add ~/.ssh/id_p7_remote
```

### SSHFS "Connection refused"

```bash
# Verify autossh tunnel is active
ps aux | grep autossh

# Check tunnel logs
tail -f /var/log/autossh-atom.local.log
```

### Unmount Fails on Stop

```bash
# Force unmount with:
sudo fusermount -uz /usr/local/protocol-7
sudo fusermount -uz /var/httpd
sudo fusermount -uz /var/log/protocol-7
```

### Server Offline but Mounts Still Show

```bash
# Check if mounts are actually accessible
ls /usr/local/protocol-7

# Force unmount and recovery
sudo systemctl restart remote-sync-tunnel
```

## Security Considerations

⚠️ **This setup uses SSH tunnels over plain TCP - suitable for local/LAN testing only**

For production or internet-exposed testing:
1. Use SSH keys without passwords
2. Restrict SSH access via firewalls
3. Consider implementing link-level encryption layer when ready
4. Use SSH tunnels from restricted network segments only

## Next Steps

Once remote mounts and tunnels are working:

1. Test letsencrypt provisioning chain
2. Verify ACME challenge responses
3. Monitor httpsd certificate integration
4. Test certificate renewal process
5. After validation, move to production deployment

## Related Files

- `bin/admin/remote-sync-tunnel` - Main script
- `bin/admin/remote-sync-tunnel.service` - Systemd integration
- `cfg/zenki/v7-zenki/start-set-up.remote-server` - Remote deployment profile

#,,.,,,.,,.,,,,..,,.,,...,,,,,..,,...,...,,,.,..,,...,...,..,,,,.,,,.,..,,..,,
#POAIB3AEBNZKCWUTJOYAPKHZDSY5W2L3F25L3WE24RMJZYCOH4A7OBEYEB2OS7GW56KWMMM5AHFG6
#\\\|ZJH35MTROWPYC2LROKUDW6ZUSIAVVKNJ6CXCY7JVT4KM6NHFXO3 \ / AMOS7 \ YOURUM ::
#\[7]CGR2HBNJTFWNY2YUEP4MWQILXQDNGOU4QN46GSQ4KZGJ6AGHXIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
