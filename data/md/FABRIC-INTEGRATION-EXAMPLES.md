# Protocol-7 Data Fabric: Integration Examples

Real-world examples of how different zenka integrate using the data synchronization fabric.

---

## Example 1: Menu System with Multiple Providers

**Goal**: Display a dynamic menu that aggregates items from multiple services.

### Architecture Diagram

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Weather    │  │    RSS       │  │   System     │
│   Provider   │  │   Ticker     │  │   Monitor    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ├─ push ──────────┼─ push ──────────┤
       │                 │                 │
       └──────┬──────────┴────────┬────────┘
              │                   │
              v                   v
    protocol-7-menu.menu-update
              │
              v
    menu-structure hash + watcher
              │
              v
    structure-changed handler (diff logic)
              │
              v
    GUI update (add/remove/modify items)
              │
              v
         ┌────────────────────────┐
         │   Display on Screen    │
         │  Weather  RSS  System  │
         │  ▼ Forecast ▼ Updates  │
         │  ▼ Alerts   ▼ Status   │
         └────────────────────────┘
```

### Implementation Flow

**Step 1: Initialize Menu Structure**

```perl
# protocol-7-menu.init_code

<protocol-7-menu.menu-structure> = {
    'last-changed' => <[base.cmd.timestamp]>,
    'providers' => {},
};

# Install watcher
<[event.add_var]>->({
    'var_path'   => 'protocol-7-menu.menu-structure',
    'var_key'    => 'last-changed',
    'event_type' => 'write',
    'callback'   => <[protocol-7-menu.structure-changed]>,
});
```

**Step 2: Weather Provider Registers**

```perl
# weather.zenka startup

my $menu_data = {
    'items' => {
        'forecast' => {
            'label'   => 'Weather: Loading...',
            'command' => 'weather.show_detail',
        },
        'alerts' => {
            'label' => 'No Alerts',
        },
    }
};

<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'protocol-7-menu.menu-update',
        'call_args' => {
            'args' => 'weather ' . JSON::encode_json($menu_data)
        }
    }
);

<[base.log]>->( 1, "registered with protocol-7-menu" );
```

**Step 3: Weather Data Changes**

```perl
# weather.zenka when fetch completes

my $new_forecast = fetch_weather_api();

# Update provider's menu representation
my $updated_menu = {
    'items' => {
        'forecast' => {
            'label'   => "Weather: $new_forecast->{temp}°C, $new_forecast->{condition}",
            'command' => 'weather.show_detail',
        },
        'alerts' => {
            'label' => $new_forecast->{alerts} > 0
                ? "Alerts ($new_forecast->{alerts})"
                : 'No Alerts',
        },
    }
};

# Push update to menu
<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'protocol-7-menu.menu-update',
        'call_args' => {
            'args' => 'weather ' . JSON::encode_json($updated_menu)
        }
    }
);
```

**Step 4: Menu Update Handler**

```perl
# protocol-7-menu.cmd.menu-update

return { 'mode' => qw| false |, 'data' => '...' }
    unless <protocol-7-menu.init-graphical>;

my ($provider, $data_json) = split(' ', $call->{'args'}, 2);

if (defined $data_json) {
    # Register or update provider
    my $data = JSON::decode_json($data_json);
    <protocol-7-menu.menu-structure>{'providers'}{$provider} = $data;
} else {
    # Unregister (empty update)
    delete <protocol-7-menu.menu-structure>{'providers'}{$provider};
}

# Mark changed - watcher fires
<protocol-7-menu.menu-structure>{'last-changed'} = <[base.cmd.timestamp]>;

return { 'mode' => qw| true |, 'data' => "menu updated for $provider" };
```

**Step 5: Watcher Fires, Handler Diffs**

```perl
# protocol-7-menu.structure-changed (fired by watcher)

my $prev = <protocol-7-menu.prev-structure> // { providers => {} };
my $curr = <protocol-7-menu.menu-structure>;

my %all_providers = (
    map { $_ => 1 }
    keys %{ $prev->{providers} },
    keys %{ $curr->{providers} },
);

foreach my $provider (sort keys %all_providers) {
    my $prev_data = $prev->{providers}{$provider};
    my $curr_data = $curr->{providers}{$provider};

    if (!defined $curr_data) {
        # Provider removed
        <[protocol-7-menu.remove-provider-items]>->($provider);
    } elsif (!defined $prev_data) {
        # Provider added
        <[protocol-7-menu.add-provider-items]>->($provider, $curr_data);
    } else {
        # Provider updated
        <[protocol-7-menu.update-provider-items]>->(
            $provider, $prev_data, $curr_data
        );
    }
}

<protocol-7-menu.prev-structure> = $curr;
```

**Step 6: GUI Updates**

```perl
# protocol-7-menu.update-provider-items (for weather example)

my ($provider, $prev_data, $curr_data) = @ARG;

my $submenu = <protocol-7-menu.gui-provider-items>{$provider}{submenu};

# Diff items
my @prev_keys = keys %{ $prev_data->{items} };
my @curr_keys = keys %{ $curr_data->{items} };

foreach my $key (@curr_keys) {
    my $prev_item = $prev_data->{items}{$key};
    my $curr_item = $curr_data->{items}{$key};

    if (!defined $prev_item) {
        # Add new item
        my $menu_item = Gtk3::MenuItem->new_with_label(
            $curr_item->{label}
        );
        $submenu->append($menu_item);
    } elsif ($prev_item->{label} ne $curr_item->{label}) {
        # Update label
        # Find and update the widget...
    }
}

$submenu->show_all;
```

### Result

User sees menu that updates in real-time as providers push changes. No polling, no stale data. Providers are completely decoupled—weather doesn't know about RSS, RSS doesn't know about system status.

---

## Example 2: Data Channels with Multi-Host Sync

**Goal**: Route data between providers and subscribers across multiple hosts, with automatic discovery.

### Architecture Diagram

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Host A      │     │   Host B         │     │  Host C      │
│              │     │                  │     │              │
│ Weather      │     │ Channels Router  │     │ Terminal UI  │
│ ├ temp       │────▶│ ├ weather.raw   │────▶│ ├ mount      │
│ └ updated    │     │ ├ weather.html  │     │ └ display    │
│              │     │ └ alerts        │     │              │
│              │     │                  │     │              │
│              │     │ Discover Service │     │              │
│              │     │ ├ announce       │     │              │
│              │     │ └ multicast      │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
       ↑                    ↑                        ↑
       └────────────────────┴────────────────────────┘
              All synced via timestamps
```

### Implementation Flow

**Step 1: Host A - Weather Provider Publishes**

```perl
# weather.zenka on Host A

# Fetch data and update local canonical state
my $new_obs = fetch_weather();

<weather.observations> = {
    'temperature'  => $new_obs->{temp},
    'humidity'     => $new_obs->{humidity},
    'condition'    => $new_obs->{condition},
    'timestamp'    => time(),
    'last-changed' => <[base.cmd.timestamp]>,
};

# Announce via discover (multicast on LAN)
<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'discover.cmd.announce',
        'call_args' => {
            'args' => 'weather weather.observations ' . <[base.cmd.timestamp]>
        }
    }
);
```

**Step 2: Host B - Channels Router Subscribes**

```perl
# channels.zenka on Host B

# Discover learns about weather on Host A (via multicast)
# Channels router mounts it

<[event.mount_remote_branch]>->(
    'weather.observations',     # From Host A
    'channels.topic.weather.raw',  # Local namespace
);

# Install watcher to track updates
<[event.add_var]>->({
    'var_path'   => 'channels.topic.weather.raw',
    'var_key'    => 'last-changed',
    'callback'   => sub { format_and_forward('weather') },
});

sub format_and_forward {
    my ($topic) = @_;

    my $raw = <channels.topic.weather.raw>;

    # Format for consumption
    my $html = format_as_html({
        'temp'      => $raw->{'temperature'},
        'condition' => $raw->{'condition'},
    });

    # Store formatted version
    <channels.topic.weather.formatted> = {
        'html'          => $html,
        'last-changed'  => <[base.cmd.timestamp]>,
    };

    # Announce to subscribers
    <[base.protocol-7.command.send.local]>->(
        {
            'command'   => 'discover.cmd.announce',
            'call_args' => {
                'args' => 'channels.weather channels.topic.weather.formatted'
            }
        }
    );
}
```

**Step 3: Host C - Terminal UI Subscribes**

```perl
# terminal-ui.zenka on Host C

# Discover learns about channels on Host B
# Mount the formatted channel

<[event.mount_remote_branch]>->(
    'channels.topic.weather.formatted',  # From Host B
    'terminal-ui.weather',
);

# Watch for updates
<[event.add_var]>->({
    'var_path'   => 'terminal-ui.weather',
    'var_key'    => 'last-changed',
    'callback'   => sub { render_weather_display() },
});

sub render_weather_display {
    my $weather = <terminal-ui.weather>;

    # Clear screen and render
    system('clear');
    print $weather->{html};
    print "\nUpdated: " . <terminal-ui.weather>{'last-changed'} . "\n";
}
```

### Data Flow

1. Weather on Host A publishes observation
2. Watcher fires → announces via multicast
3. Channels router on Host B detects announcement
4. Mounts remote data → watcher fires on mount
5. Formats data and announces to Host C
6. Terminal UI mounts from Host B → watcher fires
7. Terminal UI renders to screen
8. **All stay in sync** via timestamps and watchers
9. When Host C's network goes down → mount disconnect → cleanup automatic

### Benefits

- ✅ Multi-host synchronization without explicit network code
- ✅ Automatic discovery via multicast
- ✅ Data flows through layers (A → B → C)
- ✅ Each layer can transform/filter data
- ✅ Changes propagate instantly via watchers
- ✅ Cleanup automatic on disconnect (no stale subscriptions)

---

## Example 3: Real-Time Metrics with Hierarchical Aggregation

**Goal**: Collect metrics from servers, aggregate at regional level, visualize at central dashboard.

### Architecture

```
Servers (Leaf)
  server-1.metrics: cpu=45, mem=60
  server-2.metrics: cpu=52, mem=55
  ...
       ↓ (mount locally)
Regional Aggregator
  regional.summary:
    cpu_avg = 48.5
    mem_avg = 57.5
       ↓ (mount for central)
Central Dashboard
  dashboard.regional_summary:
    display "CPU: 48.5%, MEM: 57.5%"
```

### Implementation

**Step 1: Servers Report Metrics**

```perl
# Each server zenka

my $cpu = read_cpu_percent();
my $mem = read_mem_percent();

<server-1.metrics> = {
    'cpu'          => $cpu,
    'memory'       => $mem,
    'last-changed' => <[base.cmd.timestamp]>,
    'measured-at'  => time(),
};
```

**Step 2: Regional Aggregator Mounts All**

```perl
# regional-aggregator.zenka

foreach my $server (@servers) {
    <[event.mount_remote_branch]>->(
        "$server.metrics",
        "aggregator.servers.$server",
    );
}

# Watch all mounted servers
<[event.add_var]>->({
    'var_path'   => 'aggregator.servers',
    'var_key'    => 'last-changed',
    'callback'   => sub { compute_aggregates() },
});

sub compute_aggregates {
    my $servers = <aggregator.servers>;

    my ($cpu_sum, $mem_sum, $count) = (0, 0, 0);

    foreach my $server_name (keys %$servers) {
        next if $server_name eq 'last-changed';

        my $metrics = $servers->{$server_name};
        $cpu_sum += $metrics->{'cpu'} // 0;
        $mem_sum += $metrics->{'memory'} // 0;
        $count++;
    }

    if ($count > 0) {
        <aggregator.summary> = {
            'cpu_avg'       => $cpu_sum / $count,
            'mem_avg'       => $mem_sum / $count,
            'server_count'  => $count,
            'last-changed'  => <[base.cmd.timestamp]>,
        };
    }
}
```

**Step 3: Central Dashboard Displays**

```perl
# central-dashboard.zenka

<[event.mount_remote_branch]>->(
    'aggregator.summary',
    'dashboard.regional',
);

<[event.add_var]>->({
    'var_path'   => 'dashboard.regional',
    'var_key'    => 'last-changed',
    'callback'   => sub { update_display() },
});

sub update_display {
    my $summary = <dashboard.regional>;

    # Update dashboard GUI
    $window->{cpu_label}->set_text(
        sprintf "CPU: %.1f%%", $summary->{'cpu_avg'}
    );
    $window->{mem_label}->set_text(
        sprintf "Memory: %.1f%%", $summary->{'mem_avg'}
    );
}
```

### Cascading Updates

```
Server-1 measures 45% CPU
  → writes to server-1.metrics
  → watcher fires
  → aggregator.servers updated
  → compute_aggregates() runs
  → calculates new average (48.5%)
  → writes to aggregator.summary
  → watcher fires
  → dashboard.regional updated
  → update_display() runs
  → GUI updates to show "CPU: 48.5%"

Total latency: ~10-20ms (all local hash operations)
No polling, no delays, fully event-driven
```

### Scaling

With this pattern:
- 100 servers → 1 regional aggregator watching all
- 5 regional aggregators → 1 central watching all
- Each level computes efficient roll-ups
- Central dashboard stays responsive (just watches 5 aggregators, not 100 servers)

---

## Example 4: Log Aggregation

**Goal**: Collect logs from all services, centralize with filtering and alerting.

### Flow

**Step 1: Services Log Events**

```perl
# Any service

<[base.log]>->( 2, "CRITICAL: Database connection failed" );

# This internally writes to logs hash:
<logs.app.critical> = {
    '3OMY5G5IPO6VW' => {
        'message' => 'Database connection failed',
        'source'  => 'app.zenka',
        'host'    => 'server-1',
    },
    '3OMY5G5IPO6VT' => { ... },
    'last-changed' => '3OMY5G5IPO6VW',
};
```

**Step 2: Central Aggregator Mounts All**

```perl
# log-aggregator.zenka

foreach my $source (@all_sources) {
    <[event.mount_remote_branch]>->(
        "$source.logs",
        "aggregator.logs.$source",
    );
}

# Watch only critical/error events
<[event.add_var]>->({
    'var_path'   => 'aggregator.logs',
    'var_key'    => 'last-changed',
    'callback'   => sub { handle_critical_event() },
});

sub handle_critical_event {
    my $logs = <aggregator.logs>;

    foreach my $source (keys %$logs) {
        next if $source eq 'last-changed';

        my $critical = $logs->{$source}{critical} // {};
        foreach my $ts (keys %$critical) {
            next if $ts eq 'last-changed';

            my $event = $critical->{$ts};

            # Store to database
            store_to_db($event);

            # Alert operator
            send_alert($event->{message});
        }
    }
}
```

### Benefits

- ✅ Real-time aggregation
- ✅ Timestamp-indexed for range queries
- ✅ Scalable (watch only critical, ignore warnings)
- ✅ Persistent store can be asynchronous
- ✅ Same event visible in multiple contexts (critical, archive, search)

---

## Coupling Pattern: Dynamic Service Registry

**Idea**: Services register themselves, others discover them automatically.

```perl
# Service startup
<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'registry.cmd.register',
        'call_args' => {
            'args' => 'weather weather.observations'  # "I provide this data"
        }
    }
);

# Consumer discovers
<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'registry.cmd.lookup',
        'call_args' => {
            'args' => 'weather'  # "Where is weather data?"
        }
    }
);
# Response: "Available at weather.observations on host A"

# Consumer mounts
<[event.mount_remote_branch]>->(
    'weather.observations',
    'my-service.weather',
);

# Service shutdown
<[base.protocol-7.command.send.local]>->(
    {
        'command'   => 'registry.cmd.unregister',
        'call_args' => { 'args' => 'weather' }
    }
);
# All mounts automatically disconnect and clean up
```

---

## Key Insight: Composition Without Coordination

Each service is simple:
- Maintains its own hash structure
- Watches key points for changes
- Mounts upstream data it depends on
- Pushes downstream data others need

Result:
- **No central configuration** (services self-register)
- **No master/slave** (all peers)
- **No polling** (all push via watchers)
- **Automatic cleanup** (disconnect removes stale data)
- **Scales to 100+ services** without bottleneck

The infrastructure (watchers, timestamps, mounting) stays unchanged. Applications innovate on top by creating new hash structures and combining watchers in new ways.

---

**Next Steps**: Pick a pattern that matches your use case. See `FABRIC-PATTERNS-QUICK-REFERENCE.md` for code snippets.
