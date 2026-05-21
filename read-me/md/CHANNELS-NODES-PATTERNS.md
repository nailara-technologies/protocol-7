# Channels and Nodes Zenka - Shared Patterns and Architecture

## Overview

The **channels** and **nodes** zenka implement patterns for distributed peer discovery, state synchronization, and pub/sub communication. This document extracts and documents the common patterns that can be applied to implement similar functionality across Protocol-7 infrastructure.

## Core Patterns

### 1. Lazy Activation Pattern

**Purpose**: Minimize network overhead by deferring resource allocation until actually needed.

**Implementation**:
- Subscriptions create entry-points but consume zero traffic when idle
- Resources (timers, file handles, network connections) allocated only on first use
- Automatic deactivation when idle thresholds exceeded

**Channels Example**:
```perl
##  Lazy creation - channel doesn't exist until first subscriber
<channels.subscriptions>->{$channel_path} //= {};

##  Deactivation - mark SUSPENDED when subscribers drop to zero
unless ( keys %{<channels.subscriptions>->{$channel_path}} ) {
    <channels.subscriptions>->{$channel_path}->{'status'} = 'SUSPENDED';
}
```

**Nodes Example**:
```perl
##  Node entries created only when discovered
<nodes.remote-nodes>->{$node_name} = {
    'status' => 'online'
};

##  Cleaned up after TTL expiration
if ( $time_offline > $inactive_timeout ) {
    delete <nodes.remote-nodes>->{$node_name};
}
```

**Applicability**: Any zenka managing distributed resources where overhead is proportional to active count.

### 2. Status Transition Pattern

**Purpose**: Track resource lifecycle with clear state machine ensuring consistent behavior.

**Status States**:
- **ACTIVE**: Resource actively in use
- **IDLE**: Resource inactive but retained during timeout
- **SUSPENDED**: Resource deactivated, pending cleanup
- **OFFLINE**: (Nodes) Remote resource no longer reachable

**Channels Implementation**:
```perl
## Transitions ##
ACTIVE    --(no heartbeat for $timeout)--> IDLE
IDLE      --(explicit unsubscribe)-------> SUSPENDED
SUSPENDED --(cleanup cycle)---------------> DELETED

## State tracking ##
<channels.subscriptions>->{$path}->{'status'} = 'IDLE';
<channels.subscriptions>->{$path}->{'idle_since'} = <[base.time]>->(2);
```

**Nodes Implementation**:
```perl
## Transitions ##
ONLINE   --(no heartbeat for $timeout)--> IDLE
IDLE     --(no contact for $extended)--> OFFLINE
OFFLINE  --(explicit removal)-----------> DELETED

## State tracking ##
<nodes.remote-nodes>->{$name}->{'status'} = 'offline';
<nodes.remote-nodes>->{$name}->{'last_seen'} = <[base.time]>->(2);
```

**Applicability**: Any resource with lifecycle (connections, subscriptions, peer relationships).

### 3. Timestamp as Low-Rate Heartbeat

**Purpose**: Detect stale resources and maintain health status with minimal overhead.

**Implementation**:
```perl
## Generate heartbeat even without data changes
my $heartbeat_interval = $config{'heartbeat_interval'} // 3600;  ## 1 hour ##
my $time_since_heartbeat = $current_time - $last_heartbeat;

if ( $time_since_heartbeat >= $heartbeat_interval ) {
    <resource.timestamps>->{$path} = encode_b32r(pack('Q>', $current_time));
    $entry->{'last_heartbeat'} = $current_time;
}

## Client detects staleness by checking timestamp age
my $age = $current_time - decode_timestamp($remote_timestamp);
if ( $age > $max_age ) {
    mark_resource_stale();
}
```

**Benefits**:
- Health detection without constant polling
- Base32-encoded timestamps work with existing infrastructure
- Compatible with Protocol-7's timeout-less design

**Applicability**: Any distributed system needing liveness detection.

### 4. Cleanup Cycle Pattern

**Purpose**: Efficiently reclaim resources using background maintenance routines.

**Implementation**:
```perl
my $cleanup_interval = $config{'cleanup_interval'} // 21600;  ## 6 hours ##
my $timeout = $config{'inactive_timeout'} // 86400;  ## 24 hours ##

foreach my $resource ( keys %{<active_resources>} ) {
    my $age = $current_time - $entry->{'created_at'};

    if ( $entry->{'status'} eq 'SUSPENDED' and $age > $timeout ) {
        delete <active_resources>->{$resource};
        delete <resource.data>->{$resource};
        delete <resource.timestamps>->{$resource};

        $removed_count++;
    }
}

return { 'removed' => $removed_count };
```

**Scheduling**:
- Cleanup can be:
  - Periodic via event system
  - Triggered on high memory usage
  - Manual via admin commands

**Applicability**: Any long-lived system accumulating disposable resources.

### 5. Data Structure Organization

**Pattern**: Parallel hash tables for related metadata.

**Channels Example**:
```perl
<channels.subscriptions>   ## { channel_path => { subscriber_id => metadata } } ##
<channels.data>            ## { channel_path => { field => value } } ##
<channels.timestamps>      ## { channel_path => base32_timestamp } ##
<channels.checksums>       ## { channel_path => base32_checksum } ##
<channels.blocking_clients> ## { request_id => { client_info } } ##
```

**Nodes Example**:
```perl
<nodes.remote-nodes>       ## { node_name => { status, addr, port, ... } } ##
<nodes.trunks>             ## { trunk_name => { connected, remote_nodes } } ##
<nodes.list.remote-nodes>  ## (integration with base.cmd.list) ##
```

**Benefits**:
- Separation of concerns (subscription tracking vs. data storage)
- Efficient single-table operations without nested traversal
- Easy to implement materialized views for admin commands

**Applicability**: Any system tracking multiple aspects of same entities.

### 6. Integration with base.cmd.list

**Purpose**: Provide admin visibility into distributed state via consistent interface.

**Implementation**:
```perl
## In init_code ##
<list.channels> = {
    'var'      => qw| data |,
    'key'      => qw| channels.subscriptions |,
    'sort_key' => 'alpha-len:channel_path',
    'descr'    => 'active channels with subscription status',
    'mask'     => 'channel:channel_path status:status updated:last_update',
    'align'    => { 'channel' => 'left+2', 'status' => 'center' },
    'filters'  => { 'status' => qw| base.parser.channel_status | }
};

<[base.list.init]>->({
    'name'         => qw| channels |,
    'key_ref'      => \$data{'channels'}{'subscriptions'},
    'max_elements' => <channels.cfg.max_subscriptions>
});
```

**Usage**:
```
p7 base.cmd.list channels
p7 base.cmd.list nodes remote-nodes
```

**Applicability**: Any system tracking collections that admins need to monitor.

### 7. Blocking Pattern (Long Polling)

**Purpose**: Push-style notifications without constant polling overhead.

**Implementation**:
```perl
## Client registers interest in future changes
my $request_id = <[base.gen_id]>->({});
<resource.blocking_clients>->{$request_id} = {
    'channel_path'  => $channel_path,
    'since_ts'      => $since_ts,
    'registered_at' => <[base.time]>->(2)
};

return {
    'mode' => qw| holding |,
    'data' => { 'request_id' => $request_id, 'message' => '...' }
};

## When data changes, notify all waiting clients
foreach my $request_id ( keys %{<resource.blocking_clients>} ) {
    my $client = <resource.blocking_clients>->{$request_id};
    if ( matches_client_interest($client) ) {
        delete <resource.blocking_clients>->{$request_id};
        send_response_to_client($request_id, $new_data);
    }
}
```

**Benefits**:
- Zero polling overhead
- Server-driven push notifications
- Compatible with Protocol-7's connection-held-open design

**Applicability**: Any system requiring efficient change notification.

### 8. TOFU Integration Pattern

**Purpose**: Secure distributed authentication without shared secrets.

**Implementation**:
```perl
## First connection: auto-pin key
unless ( -f $pinned_key_file ) {
    open my $fh, '>', $pinned_key_file or die;
    print $fh $incoming_key_b32 . "\n";
    close $fh;

    ##  Notify admin via channels for authorization
    <[channels.cmd.update]>->({
        'call' => {
            'args' => "security.tofu-requests $json_payload"
        }
    });

    return 1;  ## pinned, awaiting authorization ##
}

## Subsequent connections: validate
my $stored_key = <[file.slurp]>->($pinned_key_file)->$*;
if ( $stored_key ne $incoming_key ) {
    return 2;  ## MITM detected ##
}
```

**Integration with Channels**:
- TOFU pinning notifications → security channel
- Admin subscribes to security channel
- Async authorization workflow without blocking client

**Applicability**: Any distributed system requiring secure peer authentication.

### 9. Hierarchical Path Matching

**Purpose**: Support both exact matches and subtree subscriptions.

**Channels Example**:
```perl
## Exact match
/security.tofu-requests  ## single key only ##

## Implicit tree (includes subtree)
security.tofu-requests.pending  ## includes pending.user1, pending.user2, etc. ##

## Matching logic
if ( $watched_path eq $changed_path ) {
    ##  Exact match ##
} elsif ( $changed_path =~ m|^\Q$watched_path\E\.|  ) {
    ##  Subtree match ##
}
```

**Benefits**:
- Single subscription covers entire subdomain
- Efficient filtering by prefix
- Reduces subscription count in large systems

**Applicability**: Any hierarchical naming scheme (channels, config trees, metrics).

### 10. Conflict Resolution Pattern

**Purpose**: Handle concurrent modifications in distributed systems.

**Strategies**:
1. **Timestamp**: Most recent change wins
2. **Priority**: Higher priority value wins
3. **Local-wins**: Local copy always wins
4. **Remote-wins**: Remote copy always wins

**Implementation**:
```perl
my $strategy = <resource.cfg.conflict_resolution> // 'timestamp';

if ( $strategy eq 'timestamp' ) {
    return $local_ts >= $remote_ts ? $local : $remote;
} elsif ( $strategy eq 'priority' ) {
    return $local_priority >= $remote_priority ? $local : $remote;
}
```

**Applicability**: Memory-sync, distributed state management, multi-master replication.

## Pattern Combinations

### Discovery + TOFU + Channels
```
1. Nodes discovered via discover zenka (announce packets)
2. TOFU pins public keys on first connection
3. Channels notifies admins of new pinning requests
4. Admin authorizes by creating symlink
5. Subsequent connections validated against pinned key
```

### Memory-Sync + Conflict Resolution
```
1. Zenka register memory-sync watches on local %data paths
2. Changes trigger batch-send via channels
3. Remote zenka receive via memory-sync channel
4. Conflicts detected by concurrent timestamps
5. Resolution strategy applied to determine winner
6. Local copy updated with resolved value
```

### Lazy Activation + Cleanup Cycle
```
1. Resource created on first subscription
2. Remains active while subscribers exist
3. Marked SUSPENDED when last subscriber unsubscribes
4. Cleanup cycle removes SUSPENDED resources after timeout
5. Next subscription re-creates fresh resource
```

## Implementation Checklist

When implementing similar patterns in new zenka:

- [ ] Define status state machine (ACTIVE, IDLE, SUSPENDED, etc.)
- [ ] Create parallel data structure for subscriptions/resources
- [ ] Implement init_code with configuration defaults
- [ ] Create cleanup handler with TTL-based removal
- [ ] Integrate with base.cmd.list for admin visibility
- [ ] Add heartbeat mechanism for liveness detection
- [ ] Define blocking pattern for change notifications (if applicable)
- [ ] Document configuration options in comments
- [ ] Create integration point with events system for periodic tasks
- [ ] Add logging at appropriate levels (0=critical, 1=important, 2=debug)

## Performance Considerations

### Memory Usage
- Lazy activation prevents unbounded growth
- Cleanup cycles reclaim unused resources
- Status transitions minimize memory footprint

### Network Efficiency
- Batching reduces message count
- Base32 encoding standardizes wire format
- Blocking pattern eliminates polling overhead
- Heartbeats as low-rate health detection

### CPU Usage
- Cleanup runs periodically (not per-operation)
- Blocking clients registered efficiently as hash
- Timestamp comparison O(1) per change
- Conflict resolution follows O(log n) algorithms

## Integration Points

### With Events Zenka
- Periodic cleanup scheduling
- Variable watch triggering on %data changes
- Automatic memory-sync batching

### With Discover Zenka
- Announce presence via multicast
- Listen for peer announcements
- TOFU pinning on discovery

### With Nodes Zenka
- Track remote node connectivity
- Management of distributed peer relationships
- Integration with trunk-based communication

### With Base Infrastructure
- base.time: Consistent timestamp generation
- base.cmd.list: Admin visibility
- base.logs: Structured logging
- base.gen_id: Unique ID generation
- base.perlmod: Dynamic module loading

## Future Extensions

### Sharding
- Partition large datasets by hash(path) % N
- Each shard responsible for subset of channels
- Reduces memory per instance, enables horizontal scaling

### Replication
- Primary-replica synchronization of critical channels
- Automatic failover on primary unavailable
- Quorum-based conflict resolution

### Encryption
- End-to-end encryption of sensitive channel data
- TOFU-based key distribution
- Per-subscription encryption keys

### Rate Limiting
- Per-subscription message rate limits
- Per-channel aggregate rate limits
- Backpressure handling for slow subscribers

---

*This document describes patterns extracted from Protocol-7's nodes and channels zenka. Use these patterns as blueprints when implementing similar distributed infrastructure.*

```

#,,.,,..,,...,,..,..,,.,.,,..,.,,,,.,,.,.,,,,,...,...,...,..,,,.,,,,.,,..,.,.,
#RFXMVSHKTFNUSSM23D5GSVTOVATIMLUTA5CMQM43RSEYEWRZEVCPKGZJYORLA3Y2ACJGUHMN4LARI
#\\\|N7CRMOADXALK57FZKBWTPSTPTZEGBJHW2X4XSBUJMSEGNGTIND7 \ / AMOS7 \ YOURUM ::
#\[7]BT7X3LOD5FT7AR2AUUVRHRYUEQ53NKNNWYNF4RSXENZ7PIXIGSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
