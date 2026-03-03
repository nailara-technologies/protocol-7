# Protocol-7 Data Fabric: Patterns Quick Reference

A quick lookup for common patterns when building zenka with the data synchronization fabric.

## Pattern: Simple Timestamped Value

**When to use**: A single monitored value (temperature, price, status).

```perl
# Define structure
<my-service.data> = {
    'value'        => 42,
    'last-changed' => <[base.cmd.timestamp]>,
    'unit'         => 'celsius',
    'source'       => 'sensor-1',
};

# Install watcher
<[event.add_var]>->({
    'var_path'   => 'my-service.data',
    'var_key'    => 'last-changed',
    'event_type' => 'write',
    'callback'   => sub { on_value_changed(@_) },
});

# On each measurement
<my-service.data>{'value'} = read_temperature();
<my-service.data>{'last-changed'} = <[base.cmd.timestamp]>;

# Consumer (optional)
<[event.mount_remote_branch]>->(
    'my-service.data',
    'consumer.upstream-data',
);
```

**Consumers see**: Latest value instantly via watcher or mounted hash.

---

## Pattern: Provider Registry with Dynamic Items

**When to use**: Multiple providers registering/unregistering items (menu aggregation, plugin system).

```perl
# Initialize structure
<registry.menu> = {
    'last-changed' => <[base.cmd.timestamp]>,
    'providers' => {},
};

# Install watcher
<[event.add_var]>->({
    'var_path'   => 'registry.menu',
    'var_key'    => 'last-changed',
    'callback'   => sub { handle_menu_change(@_) },
});

# Provider registers
sub register_provider {
    my ($provider_name, $items) = @_;

    <registry.menu>{'providers'}{$provider_name} = {
        'items' => $items,
        'registered' => <[base.cmd.timestamp]>,
    };

    <registry.menu>{'last-changed'} = <[base.cmd.timestamp]>;
}

# Handler: Diff and update consumers
sub handle_menu_change {
    my ($old_structure, $new_structure) = @_;

    # Find added/removed/changed providers
    # Update UI accordingly
}

# Provider unregisters
sub unregister_provider {
    my ($provider_name) = @_;

    delete <registry.menu>{'providers'}{$provider_name};
    <registry.menu>{'last-changed'} = <[base.cmd.timestamp]>;
}
```

**Renderers see**: Structure changes instantly, can diff and update incrementally.

---

## Pattern: Push Update from Provider

**When to use**: Zenka needs to notify others of data changes (reverse route).

```perl
# Provider (e.g., weather zenka)
sub fetch_and_announce {
    my $new_data = fetch_weather();

    # Update own canonical data
    <weather.observations> = $new_data;
    <weather.observations>{'last-changed'} = <[base.cmd.timestamp]>;

    # Push to interested parties (reverse route)
    <[base.protocol-7.command.send.local]>->(
        {
            'command'   => 'protocol-7-menu.menu-update',
            'call_args' => {
                'args' => 'weather ' . JSON::encode_json({
                    'items' => {
                        'forecast' => {
                            'label' => "Temp: $new_data->{temp}°C",
                        }
                    }
                }),
            }
        }
    );
}

# Recipient (e.g., protocol-7-menu)
<[protocol-7-menu.cmd.menu-update]> = sub {
    my ($call) = @_;

    my ($provider, $data_json) = split(' ', $call->{'args'}, 2);
    my $data = JSON::decode_json($data_json);

    # Update menu structure
    <protocol-7-menu.menu-structure>{'providers'}{$provider} = $data;
    <protocol-7-menu.menu-structure>{'last-changed'} = <[base.cmd.timestamp]>;

    # Watcher fires automatically
    return { 'mode' => qw| true |, 'data' => "updated $provider" };
};
```

**Benefits**: No polling, decoupled (provider doesn't know consumer), works across hosts.

---

## Pattern: Remote Mounting (Subscribe)

**When to use**: You need real-time access to another service's data.

```perl
# Consumer zenka
sub subscribe_to_upstream {
    # Mount remote data locally
    <[event.mount_remote_branch]>->(
        'weather.observations',           # Remote path
        'my-service.weather',             # Local path
    );

    # Now <my-service.weather> is synchronized automatically
    # Install local watcher
    <[event.add_var]>->({
        'var_path'   => 'my-service.weather',
        'var_key'    => 'last-changed',
        'callback'   => sub { on_weather_change(@_) },
    });
}

# Handler fires when remote data changes
sub on_weather_change {
    my $weather = <my-service.weather>;

    <[base.log]>->( 1, "weather updated to %s",
        JSON::encode_json($weather) );
}
```

**Benefits**: Automatic sync, looks like local hash, watchers fire on remote changes, works across hosts.

---

## Pattern: Timestamp-Based Status Query

**When to use**: Optional status checks before fetching (bandwidth optimization).

```perl
# Consumer queries upstream
sub check_for_updates {
    my $cached_ts = <my-service.weather-cache-ts> // '';

    # Ask: "What's your current timestamp?"
    my $response = <[base.protocol-7.command.send.local]>->(
        { 'command' => 'weather.cmd.updated' }
    );

    if ($response =~ /^TRUE\s+(\S+)/) {
        my $remote_ts = $1;

        if ($remote_ts ne $cached_ts) {
            # Something changed, fetch new data
            my $new_data = <[base.protocol-7.command.send.local]>->(
                { 'command' => 'weather.cmd.get-data' }
            );

            <my-service.weather-cache> = $new_data;
            <my-service.weather-cache-ts> = $remote_ts;
        }
    }
}

# Provider implements .updated query
<[weather.cmd.updated]> = sub {
    my ($call) = @_;
    my $param = $call->{'args'};

    if (!defined $param) {
        # Current status
        return {
            'mode' => qw| true |,
            'data' => <[base.cmd.timestamp]>,
        };
    } elsif ($param =~ /^\d/) {
        # Delta query - what changed since timestamp?
        return compute_delta_tree($param);
    } elsif ($param =~ /^weather\./) {
        # Branch query - status of specific branch?
        return query_branch_timestamp($param);
    }
};
```

**Benefits**: Early abort (check before fetching), caching-friendly, still push-driven.

---

## Pattern: Hierarchical Topics

**When to use**: Organizing related data in a tree structure (pub/sub channels).

```perl
# Publisher (e.g., channels router)
sub publish_to_topic {
    my ($topic, $data) = @_;

    my @path = split('\.', $topic);

    # Navigate/create path
    my $node = <channels.topic>;
    foreach my $segment (@path) {
        $node->{$segment} //= {};
        $node = $node->{$segment};
    }

    # Write data
    $node->{'data'} = $data;
    $node->{'last-changed'} = <[base.cmd.timestamp]>;

    # Mark root as changed (triggers subscribers)
    <channels.topic>{'last-changed'} = <[base.cmd.timestamp]>;
}

# Subscriber discovers topics
sub discover_topics {
    my $response = <[base.protocol-7.command.send.local]>->(
        { 'command' => 'channels.cmd.updated' }
    );

    # Response shows all topics and their timestamps
    # Can drill down: channels.updated weather.raw
}

# Subscriber mounts specific topic
sub subscribe_to_topic {
    my ($topic) = @_;

    <[event.mount_remote_branch]>->(
        "channels.topic.$topic",
        "my-service.topics.$topic",
    );

    # Now <my-service.topics.$topic> stays in sync
}
```

**Benefits**: Hierarchical discovery, selective subscription, efficient quarantine of updates.

---

## Pattern: Time-Series Data

**When to use**: Historical data indexed by timestamp (metrics, logs, sensor data).

```perl
# Collector
sub record_metric {
    my ($metric_name, $value) = @_;

    my $ts = <[base.cmd.timestamp]>;

    my $metric_hash = <system.metrics>{$metric_name} //= {
        'last-changed' => $ts,
    };

    # Store value indexed by timestamp
    $metric_hash->{$ts} = {
        'value' => $value,
        'host'  => <system.hostname>,
    };

    # Mark changed
    $metric_hash->{'last-changed'} = $ts;
    <system.metrics>{'last-changed'} = $ts;
}

# Analyzer retrieves time-range
sub get_metric_range {
    my ($metric, $start_ts, $end_ts) = @_;

    my $metric_hash = <system.metrics>{$metric} // {};

    my @values = grep {
        $_ ge $start_ts && $_ le $end_ts && $_ !~ /^(last-changed|host)$/
    } keys %$metric_hash;

    return sort @values;  # Timestamps sort lexicographically
}

# Analyzer can watch for new measurements
<[event.add_var]>->({
    'var_path'   => "system.metrics.$metric_name",
    'var_key'    => 'last-changed',
    'callback'   => sub { on_new_measurement(@_) },
});
```

**Benefits**: Natural time ordering, queryable by range, watchers fire on new data.

---

## Pattern: Multi-Level Aggregation

**When to use**: Leaf nodes → regional aggregators → central dashboard.

```perl
# Leaf (server metrics collector)
sub report_metric {
    my ($metric, $value) = @_;

    <leaf.metrics>{$metric} = {
        'value'        => $value,
        'last-changed' => <[base.cmd.timestamp]>,
    };
}

# Regional Aggregator
sub aggregate {
    # Mount all leaf metrics
    foreach my $leaf (@leaf_servers) {
        <[event.mount_remote_branch]>->(
            "$leaf.metrics",
            "aggregator.leaves.$leaf",
        );
    }

    # Compute roll-ups
    <[event.add_var]>->({
        'var_path'   => 'aggregator.leaves',
        'var_key'    => 'last-changed',
        'callback'   => sub { compute_regional_summary() },
    });
}

sub compute_regional_summary {
    my $leaves = <aggregator.leaves>;

    my $cpu_total = 0;
    my $count = 0;

    foreach my $leaf_name (keys %$leaves) {
        next if $leaf_name eq 'last-changed';
        my $leaf = $leaves->{$leaf_name};
        my $metrics = $leaf->{'metrics'} // {};
        $cpu_total += $metrics->{'cpu'}{'value'} // 0;
        $count++;
    }

    my $cpu_avg = $count > 0 ? $cpu_total / $count : 0;

    <aggregator.summary>{'cpu'} = $cpu_avg;
    <aggregator.summary>{'last-changed'} = <[base.cmd.timestamp]>;

    # Now central dashboard mounts aggregator.summary
}

# Central Dashboard
sub initialize {
    <[event.mount_remote_branch]>->(
        'aggregator.summary',
        'dashboard.regional',
    );

    <[event.add_var]>->({
        'var_path'   => 'dashboard.regional',
        'var_key'    => 'last-changed',
        'callback'   => sub { render_dashboard() },
    });
}
```

**Benefits**: Hierarchical efficiency, each level computes roll-ups, changes propagate up automatically.

---

## Pattern: Initialization with Catch-Up

**When to use**: On startup, catch up with existing data before entering event loop.

```perl
# Consumer startup
sub initialize {
    # 1. Optional: Catch up with initial data
    catch_up_with_remote_data();

    # 2. Mount remote data
    <[event.mount_remote_branch]>->(
        'upstream.data',
        'my-service.upstream',
    );

    # 3. Install watchers for ongoing updates
    <[event.add_var]>->({
        'var_path'   => 'my-service.upstream',
        'var_key'    => 'last-changed',
        'callback'   => sub { on_upstream_change(@_) },
    });

    # 4. Enter event loop
    <[zenka.loop]>;
}

sub catch_up_with_remote_data {
    # Query .updated to get current state
    my $response = <[base.protocol-7.command.send.local]>->(
        { 'command' => 'upstream.cmd.updated' }
    );

    if ($response =~ /^TRUE\s+(\S+)/) {
        my $current_ts = $1;

        # Query full data
        my $data = <[base.protocol-7.command.send.local]>->(
            { 'command' => 'upstream.cmd.get-data' }
        );

        <my-service.upstream> = $data;
        <my-service.cached-ts> = $current_ts;

        <[base.log]>->( 1, "initialized with data from $current_ts" );
    }
}
```

**Benefits**: Fresh data on startup, then watchers keep updated, combines pull and push elegantly.

---

## Common Mistakes & Solutions

### ❌ Mistake: Forgetting to update timestamp

```perl
# WRONG - watcher won't fire
<service.data>{'value'} = new_value();

# RIGHT - watcher fires on timestamp change
<service.data>{'value'} = new_value();
<service.data>{'last-changed'} = <[base.cmd.timestamp]>;
```

### ❌ Mistake: Watching the wrong key

```perl
# WRONG - watches the value, not the change marker
<[event.add_var]>->({
    'var_path'   => 'service.data',
    'var_key'    => 'value',  # Changes too often
});

# RIGHT - watch the timestamp
<[event.add_var]>->({
    'var_path'   => 'service.data',
    'var_key'    => 'last-changed',
});
```

### ❌ Mistake: Comparing timestamps as numbers

```perl
# WRONG - string comparison of base32 timestamps
if ($ts1 > $ts2) { ... }

# RIGHT - timestamps compare lexicographically
if ($ts1 gt $ts2) { ... }

# EVEN BETTER - use spaceship operator for clarity
my $cmp = ($ts1 cmp $ts2);  # -1, 0, or 1
```

### ❌ Mistake: Not handling missing mounted data

```perl
# WRONG - crashes if mount not ready yet
my $upstream = <my-service.upstream>;
my $value = $upstream->{'value'};  # May be undef

# RIGHT - check before access
my $upstream = <my-service.upstream> // {};
my $value = $upstream->{'value'} // 0;
```

### ❌ Mistake: Modifying mounted data directly

```perl
# WRONG - changes don't propagate to remote
<my-service.upstream>{'value'} = 99;

# RIGHT - request changes from upstream or
# unmount if you need local copy
my $copy = { %{ <my-service.upstream> } };
$copy->{'value'} = 99;  # Local change only
```

---

## Debugging Tips

### Check current timestamp
```perl
<[base.log]>->( 2, "current time: %s", <[base.cmd.timestamp]> );
```

### Verify watcher is installed
```perl
<[base.log]>->( 2, "data changed: %s", Dumper(<my-service.data>) );
```

### Check mounted data exists
```perl
if ( defined <my-service.upstream> ) {
    <[base.log]>->( 1, "upstream mounted successfully" );
} else {
    <[base.log]>->( 2, "upstream mount failed or not ready" );
}
```

### Track timestamp comparisons
```perl
my $old_ts = '3OMY5G3ABCDE1';
my $new_ts = '3OMY5G5IPO6VW';
<[base.log]>->( 2, "is newer? %d", $new_ts gt $old_ts ? 1 : 0 );
```

### Dump hash structure (for debugging)
```perl
<[base.log]>->( 2, "structure: %s", Dumper(<my-service.data>) );
```

---

## Performance Considerations

- **Watchers are cheap**: O(1) per mutation, use generously
- **Timestamps are tiny**: 13 chars, can embed in queries
- **Remote mounting overhead**: Initial sync is full copy, then only deltas
- **Query patterns save bandwidth**: Check timestamp before fetching large data

---

## Where to Learn More

- **Architecture Overview**: `GENERIC-DATA-SYNCHRONIZATION-FABRIC.md`
- **Reference Architecture**: `data/yaml/fabric-reference-architecture.yaml`
- **Protocol-7-Menu Example**: `modules/protocol-7-menu.*`
- **Event System**: `modules/base.event.*`

---

**Key Takeaway**: Watch for `last-changed` key, mount remote data for sync, push updates for others, and let the infrastructure handle the rest. Simple pattern, powerful system. ✨

#,,,,,,,,,,..,.,,,,,.,,,.,,,.,.,.,.,.,,,,,,,.,..,,...,...,.,.,,,.,...,,,,,.,,,
#STMUJ5BKWYQZK3U7ZWDYT7AWHAM527O2CZPW7QTZHN5QQMK4PHJCEW5HOTI5BEM66OMXIDM555VJI
#\\\|WWIXYIA7JR6NPH2TIMX4S7CI44RJKCFRJBLOUCBQKXDHPKJJ5QN \ / AMOS7 \ YOURUM ::
#\[7]HRQ5HWWP7G2EEI3JJLCTD7L7WMR5OA5QC62MSEWHWKTR7NARHOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
