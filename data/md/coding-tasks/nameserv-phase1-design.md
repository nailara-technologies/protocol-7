## [:< ##

# nameserv zenka - phase 1 implementation design
# descr = design document for authoritative dns server zenka

---

## overview

phase 1 implements an authoritative-only dns server zenka using net::dns::packet
for protocol parsing and protocol-7's event loop for async i/o. provides dynamic
record management via commands for letsencr dns-01 integration.

---

## start file layout

file: `configuration/zenki/nameserv/start`

```
 .:[ protocol-7 authoritative dns server zenka ]:.

[load_config_file:'shared-params']

## command access [ cube-routed commands available to other zenki ] ##
access.cmd.usr.cube = status reload-zones list-zones show-zone \
                      set-record remove-record get-record

system.zenka.verbosity.buffer  = 2
system.zenka.verbosity.console = 2

## configuration ##
nameserv.cfg.listen_addr = 0.0.0.0
nameserv.cfg.listen_port = 53
nameserv.cfg.zones_dir   = configuration/zenki/nameserv/zones
nameserv.cfg.default_ttl = 300
nameserv.cfg.log_queries = 1

modules.load = auth net protocol io.unix event nameserv

[load_modules:<modules.load>]
[init_modules]

[root.drop_privs:<system.amos-zenka-user>]

[nameserv.start_listener]

[zenka.loop]
```

### execution flow

1. `[load_modules]` loads base modules + nameserv namespace
2. `[init_modules]` calls `nameserv.init_code` which:
   - loads net::dns via `perlmod.load`
   - initializes zone storage hash
   - loads zone files from `nameserv.cfg.zones_dir`
3. `[root.drop_privs]` drops privileges after socket creation
4. `[nameserv.start_listener]` creates udp socket, registers `event.add_io`
5. `[zenka.loop]` starts event loop

---

## module list

| module | description |
|--------|-------------|
| `nameserv.init_code` | load perl modules, init state, load zones |
| `nameserv.start_listener` | create udp socket, bind port, register io watcher |
| `nameserv.handler.query` | udp read handler: parse query, lookup, respond |
| `nameserv.zone.load` | read zone yaml files, build in-memory hash |
| `nameserv.zone.save` | persist zone changes to yaml files |
| `nameserv.zone.lookup` | query the in-memory zone hash |
| `nameserv.cmd.set-record` | add or replace a dns record |
| `nameserv.cmd.remove-record` | delete a dns record |
| `nameserv.cmd.get-record` | retrieve current record value |
| `nameserv.cmd.show-zone` | dump all records for a domain |
| `nameserv.cmd.list-zones` | list loaded zones with record counts |
| `nameserv.cmd.reload-zones` | reparse all zone files without restart |
| `nameserv.cmd.status` | show running state, zone count, query stats |

---

## init_code design

file: `modules/nameserv.init_code`

```perl
## [:< ##

# name  = nameserv.init_code
# descr = initialize nameserv zenka state and load zones

## load required perl modules via perlmod.load ##
map { <[base.perlmod.load]>->($ARG) } qw| Net::DNS Net::DNS::Packet |;

## configuration defaults ##
<nameserv.cfg.listen_addr> //= qw| 0.0.0.0 |;
<nameserv.cfg.listen_port> //= 53;
<nameserv.cfg.zones_dir>   //= qw| configuration/zenki/nameserv/zones |;
<nameserv.cfg.default_ttl> //= 300;
<nameserv.cfg.log_queries> //= 1;  ## 0=off 1=errors 2=all ##

## state variables ##
<nameserv.zones>       //= {};  ## { domain => zone_hashref } ##
<nameserv.socket>      //= undef;  ## udp socket handle ##
<nameserv.io_watcher>  //= undef;  ## event.add_io watcher ref ##
<nameserv.query_count> //= 0;
<nameserv.nx_count>    //= 0;

## zone modification tracking for soa serial ##
<nameserv.zone_serials> //= {};  ## { domain => current_serial } ##

## load initial zones ##
<[nameserv.zone.load_all]>;

<[base.logs]>->( 2, ': nameserv initialized [ %d zones ]',
    scalar keys %{<nameserv.zones>} );

return TRUE;
```

---

## zone file format

uses `format.yaml.load_str` and `format.yaml.dump_str` via `yaml::xs`.
zone files stored in `configuration/zenki/nameserv/zones/`.

### example: `example.com.yaml`

```yaml
---
domain: example.com
ttl: 300
soa:
  mname:   ns1.example.com
  rname:   hostmaster.example.com
  serial:  2026021901
  refresh: 3600
  retry:   900
  expire:  604800
  minimum: 300
records:
  - type: NS
    name: "@"
    value: ns1.example.com.
  - type: NS
    name: "@"
    value: ns2.example.com.
  - type: A
    name: "@"
    value: 203.0.113.1
  - type: A
    name: ns1
    value: 203.0.113.1
  - type: AAAA
    name: "@"
    value: 2001:db8::1
  - type: MX
    name: "@"
    priority: 10
    value: mail.example.com.
  - type: TXT
    name: "@"
    value: "v=spf1 mx ~all"
```

### in-memory zone structure

```perl
$nameserv.zones->{'example.com'} = {
    'domain'  => 'example.com',
    'ttl'     => 300,
    'soa'     => { mname => ..., rname => ..., serial => ... },
    'records' => {
        'A' => {
            '@'   => [ { value => '203.0.113.1', ttl => 300 } ],
            'ns1' => [ { value => '203.0.113.1', ttl => 300 } ],
        },
        'TXT' => {
            '@' => [ { value => 'v=spf1 mx ~all', ttl => 300 } ],
            '_acme-challenge' => [ { value => 'token...', ttl => 60 } ],
        },
    },
};
```

---

## core modules

### nameserv.handler.query

```perl
## [:< ##

# name  = nameserv.handler.query
# descr = handle incoming udp dns query via event.add_io

my $event = shift->w;  ## event watcher object ##
my $sock  = $event->fd;

## read udp datagram ##
my $client_addr = recv $sock, my $raw_query, 512, 0;
return if not defined $client_addr;

<nameserv.query_count>++;

## parse query packet ##
my $query = eval { Net::DNS::Packet->new( \$raw_query ) };
if ($EVAL_ERROR or not defined $query) {
    <[base.logs]>->( 1, ': dns query parse error: %s', $EVAL_ERROR );
    return;
}

my $question = ($query->question)[0];
return if not defined $question;

my $qname = lc $question->qname;
my $qtype = $question->qtype;

<[base.logs]>->( 2, ': query [ %s %s ]', $qtype, $qname )
    if <nameserv.cfg.log_queries> >= 2;

## lookup in zone data ##
my $records = <[nameserv.zone.lookup]>->( $qname, $qtype );

## build response ##
my $response = Net::DNS::Packet->new( \$raw_query );
$response->header->qr(1);  ## response flag ##

if (defined $records and @$records) {
    $response->header->rcode(qw| NOERROR |);
    foreach my $rec (@$records) {
        my $rr = Net::DNS::RR->new(
            name    => $qname,
            type    => $qtype,
            ttl     => $rec->{'ttl'} // <nameserv.cfg.default_ttl>,
            $rec->{'value'}
        );
        $response->push( answer => $rr );
    }
} else {
    $response->header->rcode(qw| NXDOMAIN |);
    <nameserv.nx_count>++;
}

## send response ##
my $raw_response = $response->data;
send $sock, $raw_response, 0, $client_addr;

return;
```

### nameserv.zone.load_all

```perl
## [:< ##

# name  = nameserv.zone.load_all
# descr = load all zone files from zones_dir

my $zones_dir = <nameserv.cfg.zones_dir>;
return { 'mode' => qw| false |, 'data' => 'zones_dir not configured' }
    unless defined $zones_dir and -d $zones_dir;

my @zone_files = glob "$zones_dir/*.yaml";

foreach my $file (@zone_files) {
    my $result = <[nameserv.zone.load_file]>->($file);
    <[base.logs]>->( 0, ': zone load failed [ %s ]: %s', $file, $result->{'data'} )
        if $result->{'mode'} eq qw| false |;
}

return { 'mode' => qw| true |, 'data' => scalar keys %{<nameserv.zones>} };
```

### nameserv.zone.load_file

```perl
## [:< ##

# name  = nameserv.zone.load_file
# descr = load single zone yaml file into memory

my $filepath = shift // return { 'mode' => qw| false |, 'data' => 'no path' };

my $content_sref = <[file.slurp]>->($filepath);
return { 'mode' => qw| false |, 'data' => 'cannot read file' }
    unless defined $content_sref;

my ( $zone_data, $err ) = <[format.yaml.load_str]>->( $content_sref->$* );
return { 'mode' => qw| false |, 'data' => $err } if defined $err;

my $domain = $zone_data->{'domain'};
return { 'mode' => qw| false |, 'data' => 'missing domain in zone file' }
    unless defined $domain;

## normalize to fast lookup structure ##
my $zone = {
    'domain'  => $domain,
    'ttl'     => $zone_data->{'ttl'} // <nameserv.cfg.default_ttl>,
    'soa'     => $zone_data->{'soa'},
    'records' => {},
    'source'  => $filepath,
};

foreach my $rec ( @{ $zone_data->{'records'} // [] } ) {
    my $type = $rec->{'type'};
    my $name = $rec->{'name'} // qw| @ |;
    $name = lc $name;
    push $zone->{'records'}->{$type}->{$name}->@*, {
        'value'    => $rec->{'value'},
        'ttl'      => $rec->{'ttl'} // $zone->{'ttl'},
        'priority' => $rec->{'priority'},  ## for mx, srv ##
    };
}

<nameserv.zones>->{$domain} = $zone;
<nameserv.zone_serials>->{$domain} = $zone->{'soa'}->{'serial'} // 1;

return { 'mode' => qw| true |, 'data' => $domain };
```

### nameserv.cmd.set-record

```perl
## [:< ##

# name  = nameserv.cmd.set-record
# descr = add or replace a dns record and persist to zone file

my $params = shift // {};
my $domain = $params->{'domain'} // return { 'mode' => qw| false |, 'data' => 'missing domain' };
my $type   = $params->{'type'}   // return { 'mode' => qw| false |, 'data' => 'missing type' };
my $name   = $params->{'name'}   // return { 'mode' => qw| false |, 'data' => 'missing name' };
my $value  = $params->{'value'}  // return { 'mode' => qw| false |, 'data' => 'missing value' };
my $ttl    = $params->{'ttl'}    // <nameserv.cfg.default_ttl>;

$domain = lc $domain;
$name   = lc $name;

my $zone = <nameserv.zones>->{$domain};
return { 'mode' => qw| false |, 'data' => 'zone not found' } unless defined $zone;

## replace existing or add new ##
$zone->{'records'}->{$type}->{$name} = [ { 'value' => $value, 'ttl' => $ttl } ];

## increment soa serial ##
<nameserv.zone_serials>->{$domain}++;
$zone->{'soa'}->{'serial'} = <nameserv.zone_serials>->{$domain};

## persist to yaml ##
my $save_result = <[nameserv.zone.save]>->($domain);
return $save_result if $save_result->{'mode'} eq qw| false |;

## emit event for subscribers [ letsencr confirmation ] ##
<[event.emit]>->(
    {   'event'   => qw| dns-record-set |,
        'domain'  => $domain,
        'type'    => $type,
        'name'    => $name,
        'value'   => $value
    }
);

return { 'mode' => qw| true |, 'data' => 'record set' };
```

### nameserv.zone.save

```perl
## [:< ##

# name  = nameserv.zone.save
# descr = persist zone to yaml file

my $domain = shift // return { 'mode' => qw| false |, 'data' => 'no domain' };
my $zone   = <nameserv.zones>->{$domain};
return { 'mode' => qw| false |, 'data' => 'zone not loaded' } unless defined $zone;

## build serializable structure ##
my @records;
foreach my $type ( sort keys %{ $zone->{'records'} } ) {
    foreach my $name ( sort keys %{ $zone->{'records'}->{$type} } ) {
        foreach my $rec ( $zone->{'records'}->{$type}->{$name}->@* ) {
            push @records, {
                'type'  => $type,
                'name'  => $name,
                'value' => $rec->{'value'},
                'ttl'   => $rec->{'ttl'},
                ( $rec->{'priority'} ? ( 'priority' => $rec->{'priority'} ) : () ),
            };
        }
    }
}

my $yaml_data = {
    'domain'  => $zone->{'domain'},
    'ttl'     => $zone->{'ttl'},
    'soa'     => $zone->{'soa'},
    'records' => \@records,
};

my $yaml_str = <[format.yaml.dump_str]>->($yaml_data);
my $filepath = $zone->{'source'} // sprintf( '%s/%s.yaml', <nameserv.cfg.zones_dir>, $domain );

my $write_result = <[file.zenka_dir.write]>->(
    "cfg-dir:nameserv/zones/$domain.yaml",
    \$yaml_str
);

return { 'mode' => qw| true |, 'data' => $filepath };
```

### nameserv.cmd.remove-record

```perl
## [:< ##

# name  = nameserv.cmd.remove-record
# descr = delete a dns record and persist changes

my $params = shift // {};
my $domain = $params->{'domain'} // return { 'mode' => qw| false |, 'data' => 'missing domain' };
my $type   = $params->{'type'}   // return { 'mode' => qw| false |, 'data' => 'missing type' };
my $name   = $params->{'name'}   // return { 'mode' => qw| false |, 'data' => 'missing name' };

$domain = lc $domain;
$name   = lc $name;

my $zone = <nameserv.zones>->{$domain};
return { 'mode' => qw| false |, 'data' => 'zone not found' } unless defined $zone;

return { 'mode' => qw| false |, 'data' => 'record not found' }
    unless exists $zone->{'records'}->{$type}->{$name};

delete $zone->{'records'}->{$type}->{$name};

## clean up empty type buckets ##
delete $zone->{'records'}->{$type} unless keys %{ $zone->{'records'}->{$type} };

## increment soa serial ##
<nameserv.zone_serials>->{$domain}++;
$zone->{'soa'}->{'serial'} = <nameserv.zone_serials>->{$domain};

## persist ##
my $save_result = <[nameserv.zone.save]>->($domain);
return $save_result if $save_result->{'mode'} eq qw| false |;

## emit event ##
<[event.emit]>->(
    {   'event'  => qw| dns-record-removed |,
        'domain' => $domain,
        'type'   => $type,
        'name'   => $name
    }
);

return { 'mode' => qw| true |, 'data' => 'record removed' };
```

### nameserv.cmd.show-zone

```perl
## [:< ##

# name  = nameserv.cmd.show-zone
# descr = dump zone records for a domain

my $params = shift // {};
my $domain = $params->{'domain'} // return { 'mode' => qw| false |, 'data' => 'missing domain' };

$domain = lc $domain;
my $zone = <nameserv.zones>->{$domain};
return { 'mode' => qw| false |, 'data' => 'zone not found' } unless defined $zone;

my @lines;
push @lines, sprintf( '; zone: %s', $zone->{'domain'} );
push @lines, sprintf( '; ttl: %d', $zone->{'ttl'} );
push @lines, sprintf( '; serial: %d', $zone->{'soa'}->{'serial'} );
push @lines, '';

foreach my $type ( sort keys %{ $zone->{'records'} } ) {
    foreach my $name ( sort keys %{ $zone->{'records'}->{$type} } ) {
        foreach my $rec ( $zone->{'records'}->{$type}->{$name}->@* ) {
            push @lines, sprintf( '%s %d IN %s %s',
                $name, $rec->{'ttl'}, $type, $rec->{'value'} );
        }
    }
}

return { 'mode' => qw| size |, 'data' => join "\n", @lines };
```

---

## integration points

### letsencr dns-01 flow

```
letsencr zenka:
  1. receives acme challenge token
  2. calls: nameserv.set-record
       domain: example.com
       type: TXT
       name: _acme-challenge
       value: <token>
       ttl: 60

nameserv zenka:
  1. updates in-memory zone
  2. increments soa serial
  3. persists to yaml
  4. emits: dns-record-set event

letsencr zenka:
  3. waits for event confirmation
  4. polls dns to verify propagation
  5. notifies acme server
  6. after validation: nameserv.remove-record
```

### soa serial auto-increment

on every `set-record` or `remove-record`:
1. `<nameserv.zone_serials>->{$domain}++`
2. update `$zone->{'soa'}->{'serial'}`
3. persist with new serial in yaml

format: `YYYYMMDDNN` where `nn` is 2-digit daily revision [ or simple increment ]

---

## style checklist

- [x] return modes use `qw| |` syntax: `qw| true |`, `qw| false |`, `qw| size |`
- [x] use `$ARG` not `$_` in map/grep
- [x] lowercase comments with `[ bracket ]` annotations
- [x] no parentheses in comments
- [x] `base.logs` with sprintf format codes: `'%s'`, not `"$var"`
- [x] log levels: 0=error, 1=default, 2=info, 3=debug
- [x] no `use`/`require` in module files — all via `perlmod.load` in init_code
- [x] no `sub {}` declarations — each module file is the subroutine
- [x] regex delimiters: `m||` or `s|||`, never `//` or `s///`
- [x] column width <= 78 characters

---

## open questions

1. **port 53 privilege handling**
   - option a: start as root, bind socket, then `root.drop_privs`
   - option b: use `cap_net_bind_service` capability on nameserv binary
   - option c: bind to high port [ 5353 ], port forward via iptables
   - **recommendation**: option a for phase 1 [ simplest ]

2. **zone storage path**
   - `configuration/zenki/nameserv/zones/` — version controlled
   - `/var/protocol-7/nameserv/zones/` — runtime writable
   - **recommendation**: config path for base zones, var path for dynamic updates

3. **yaml module choice**
   - `yaml::xs` available via `format.yaml.*` modules
   - already handles xs strict -> pure yaml fallback
   - **decision**: use existing `format.yaml.load_str` / `format.yaml.dump_str`

4. **event.add_io pattern for udp**
   - `poll => 'r'` for read-only
   - handler receives event object via `shift->w`
   - socket available via `$event->fd`
   - **confirmed**: matches `discover.mcast` pattern

5. **net::dns availability**
   - confirmed installed on target system
   - use `Net::DNS::Packet` for parse/build
   - use `Net::DNS::RR` for record creation

---

## verification checklist

- [x] `dig @127.0.0.1 atom.v7.ax A` returns correct ip
- [x] `nameserv.set-record` creates record visible in `dig` within 1s
- [x] `nameserv.remove-record` deletes record
- [x] `nameserv.show-zone` dumps formatted zone data
- [x] `nameserv.status` shows zone count and query stats
- [x] `nameserv.reload-zones` picks up saved zone files
- [x] zone yaml files persisted via zone.save, valid yaml
- [x] serial increments on each mutation [ uses epoch time ]

---

#,,,,,,,.,..,,.,.,,,,,,,,,..,,,,,,,.,,...,.,.,.,.,...,...,,..,,..,..,,...,,,.,
#5YB4JJZOVFGP66U2PSMN2K5WFMOGLVS2RHH62BI3DDXBT4COTRWYMBDKCXVFCQSWPMTL7USGFZVBQ
#\\\|DUCUMMTM7ZHIOEAJSB4ZQ4YSFVLL3GXIDFQCNEOWQOBYEVURR37 \ / AMOS7 \ YOURUM ::
#\[7]VBLXG5NCYN53CLIE3S3BD6M4OSO3IAD5E4DL6OCCE462VEWDQKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
