## [:< ##

# name  = [ kimi-task ] space-orbital-data-endpoint
# descr = add live orbital node data endpoint to plugin.web.space.*
#         serving JSON of all known orbital positions for visualization

## objective

extend the plugin.web.space.* namespace to fetch and serve live orbital node
data from the orbital layer zenki (nodes, discover, external, nameserv).
the result is a JSON endpoint at space.v7.ax that the visualization can poll
or stream to render live orbital positions, connections, and discovery state.

## background

the plugin.web.space.* namespace already exists with:
- plugin.web.space.init_code: initializes <web.space.cache> with TTL 7s
- plugin.web.space.fetch: async fetch from data source (currently graphics-matrix)
- plugin.web.space.state: renders cache as HTML fragment or JSON
- plugin.web.space.handler.state_reply: merges replies into cache

the orbital layer now provides:
- <nodes.orbital.current_p7ref>: our own NODE:CHKSUM7:ADDR_B32
- <nodes.orbital.params>: { theta, phi, psi, omega }
- <nodes.orbital.session_start>: high-res timestamp
- <discover.orbital.known>: { $pkey_L13 => { hostname, pkey, p7ref, timestamp } }
- <external.connections>: { $name => { status, encrypted, p7ref, ip } }
- <nameserv.discovered>: { $domain => [ { name, p7ref, ... } ] }

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code.

## modules to create

### plugin.web.space.orbital.fetch
- async fetch of all orbital data sources via route-send
- fetches in parallel: nodes.orbital.current_position, discover.list-orbital,
  external.list-connections, nameserv (if configured)
- stores results in <web.space.orbital.cache> with timestamp
- called on a repeating timer (interval 13, repeat TRUE) set up in init
- each route-send uses reply handler: plugin.web.space.orbital.handler.reply
- log at level 3: "orbital fetch dispatched"

### plugin.web.space.orbital.handler.reply
- reply handler for all orbital data route-sends
- params include 'field' to identify which data arrived:
  'self' | 'known' | 'connections' | 'nameserv'
- merges each field into <web.space.orbital.cache>->{'data'}->{$field}
- updates <web.space.orbital.cache>->{'timestamp'} when all fields received
- log at level 3: "orbital field '$field' received"

### plugin.web.space.orbital.json
- returns the orbital cache as a complete JSON structure for the visualization:
  {
    "self": { "p7ref": "...", "theta": N, "phi": N, "psi": N, "omega": N },
    "known": [ { "hostname": "...", "p7ref": "...", "age": N, "pkey7": "..." } ],
    "connections": [ { "name": "...", "p7ref": "...", "status": "...",
                       "encrypted": true/false } ],
    "nameserv": [ { "name": "...", "p7ref": "...", "domain": "..." } ],
    "timestamp": N,
    "cache_age": N
  }
- used as raw JSON (content-type application/json) via web template command
- call as: [web.space.orbital.json] in .tmpl files

### plugin.web.space.orbital.init_code
- initializes <web.space.orbital.cache> = { data => {}, timestamp => 0, ttl => 13 }
- sets up repeating fetch timer: interval 13, repeat TRUE
- handler: plugin.web.space.orbital.fetch
- log at level 2: "orbital data endpoint initialized"

## modules to modify

### plugin.web.space.init_code
- add call to [plugin.web.space.orbital.init_code] at the end
- ensures orbital cache is initialized alongside the main space cache

### plugin.web.space.state
- add new section handler: elsif ($section eq 'orbital-json')
- returns plugin.web.space.orbital.json result
- this allows [web.space.state:orbital-json] in templates to serve the
  orbital data inline

## web template to create

### data/web-root/space.v7.ax/orbital.json.tmpl
  [web.response.content_type:application/json]
  [web.space.state:orbital-json]

this makes /orbital.json on space.v7.ax serve live orbital data.

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- route-send returns count not reply — use reply handler pattern
- call_args => { 'args' => $string } NOT param => { hashref }
- timer: { 'interval' => 13, 'repeat' => TRUE }
- <[protocol-7.command.send.local]> for all cross-zenka calls
- do NOT add fake signature stubs — leave files clean
- the orbital JSON must be valid JSON — use JSON::XS::encode_json

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave new files clean.

## deliverables

1. src/plugin.web.space.orbital.init_code
2. src/plugin.web.space.orbital.fetch
3. src/plugin.web.space.orbital.handler.reply
4. src/plugin.web.space.orbital.json
5. modified src/plugin.web.space.init_code (add orbital init call)
6. modified src/plugin.web.space.state (add orbital-json section)
7. data/web-root/space.v7.ax/orbital.json.tmpl

#,,..,,.,,,,,,.,.,,.,,,,.,,,.,..,,.,.,,,.,..,,..,,...,...,,,,,,.,,,,.,.,,,,.,,
#36UHWKDXL5O7L4VFQYVTBFQFF7WENJRRXX37JFRWOMFMAGJVVW6YY6DLQLCRY5SELOO5MR4XAJCKU
#\\\|F6HL2THEZIJNNNQLO6RI6ZMXL65J2EB72XS43QDVTMJYTKX3ZKD \ / AMOS7 \ YOURUM ::
#\[7]E3ISIX6646K2XKQWHKZNTWUNDNHPI44XW6YWMXON2K5EVBPFBEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
