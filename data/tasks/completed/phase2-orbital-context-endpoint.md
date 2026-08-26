## task : phase 2 — /orbital.json?context=<p7ref> endpoint

goal: make the recursive navigation in visualization.html pull real sub-node data
instead of mock data when the user double-clicks into a node context.

the JS side (visualization.html) already has the nav stack wired. when it reaches
phase 2 it will fetch `/orbital.json?context=NODE:NODEB:ADDR` and expects the same
JSON shape as the root `/orbital.json` but scoped to that node's known peers.

---

### signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files — that blocks
signing. leave new files without a footer; the signing system adds the real 4-line
footer automatically.

---

### what needs to change

#### 1. pass URI query string into session meta — httpd.process_template

file: `src/httpd.process_template`

at line 48, `$session->{'meta'} // {}` is where meta vars come from.
before that line, parse the raw request URI's query string and merge any params
into the meta hash so the template can see them.

the raw URI is at `$session->{'http'}->{'request'}->{'uri'}` (same as `$http_uri`
in httpd.http_get which built the URI object — httpd.process_template receives
only the template path, so it needs to build its own URI object from the session).

add near the top of httpd.process_template, before line 48:

```perl
my $request_uri = $session->{'http'}->{'request'}->{'uri'} // '';
my $uri_obj     = URI->new( $request_uri );
my $query_meta  = {};
if ( my $query = $uri_obj->query ) {
    foreach my $pair ( split /[&;]/, $query ) {
        if ( $pair =~ m|^([^=]+)=(.*)$| ) {
            my ( $k, $v ) = ( $1, $2 );
            $v =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;  ## url-decode ##
            $query_meta->{$k} = $v;
        }
    }
}
my $meta_vars = { %{ $session->{'meta'} // {} }, %$query_meta };
```

this merges URL query params into meta_vars so the template receives them.

#### 2. orbital.json.tmpl — pass context param through to state module

file: `data/web-root/vhosts/space.v7.ax/orbital.json.tmpl`

current content:
```
<[web.response.content_type:application/json]><[web.space.state:orbital-json]>
```

change to pass the context meta var through when present:
```
<[web.response.content_type:application/json]><[web.space.state:orbital-json:<[meta.context]>]>
```

if `meta.context` is empty string (no query param), the section arg becomes
`orbital-json:` which the state module should treat as `orbital-json` (no context).

#### 3. plugin.web.space.state — route orbital-json with optional context

file: `src/plugin.web.space.state`

the `orbital-json` branch currently does:
```perl
} elsif ( $section eq qw| orbital-json | ) {
    return <[plugin.web.space.orbital.json]>;
```

change it to also handle a context p7ref argument:
```perl
} elsif ( $section =~ m|^orbital-json(?::(.*))?$| ) {
    my $context_p7ref = $1 // '';
    $context_p7ref =~ s/^\s+|\s+$//g;
    return length($context_p7ref)
        ? <[plugin.web.space.orbital.json.context]>->($context_p7ref)
        : <[plugin.web.space.orbital.json]>;
```

#### 4. new module — plugin.web.space.orbital.json.context

file: `src/plugin.web.space.orbital.json.context`

this is the main new module. it receives a context p7ref, asks discover zenka
for nodes that have that p7ref as a known peer (or: returns the known[] list from
the orbital cache filtered/centered on that node), and returns JSON in the same
shape as plugin.web.space.orbital.json.

for the initial implementation, the simplest valid approach:
- treat the context p7ref as the "self" for this scope
- return orbital cache `known[]` unchanged as the sub-level peers (real peers of
  the entire network are visible, not pre-filtered — filtering can come later)
- set `self` to a placeholder struct with the context p7ref

this gives real node data at each depth level without requiring new zenka commands.

```perl
## [:< ##

# name  = plugin.web.space.orbital.json.context
# descr = return orbital json scoped to a context node (recursive nav)

my $context_p7ref = shift // '';

my $cache = <web.space.orbital.cache>;
my $data  = $cache->{'data'} // {};
my $now   = time();
my $age   = $now - ( $cache->{'timestamp'} // 0 );

## use context p7ref as self for this scope ##
my $self = {
    qw| p7ref | => $context_p7ref,
    qw| theta | => 0,
    qw| phi   | => 0,
    qw| psi   | => 0,
    qw| omega | => 0,
};

## find hostname from known[] if available ##
my $known_all = $data->{'known'} // [];
$known_all = [] unless ref $known_all eq qw| ARRAY |;

foreach my $n ( @$known_all ) {
    if ( ( $n->{'p7ref'} // '' ) eq $context_p7ref ) {
        $self->{'hostname'} = $n->{'hostname'} if defined $n->{'hostname'};
        last;
    }
}

## return known[] excluding the context node itself ##
my @sub_known = grep { ( $_->{'p7ref'} // '' ) ne $context_p7ref } @$known_all;

## build payload matching root orbital.json shape ##
my $gm_state = $data->{'gm_state'} // {};

my $glow_shells = $gm_state->{'glow_shells'};
$glow_shells = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ]
    unless ref $glow_shells eq qw| ARRAY | and @$glow_shells;

my $channel = $gm_state->{'channel'} // {};
$channel = { index => 0, name => '', palette => [] }
    unless ref $channel eq qw| HASH |;

my $graph = $gm_state->{'graph'} // {};
$graph = { counts => {}, total => 0 }
    unless ref $graph eq qw| HASH |;

my $payload = {
    qw| self        | => $self,
    qw| known       | => \@sub_known,
    qw| connections | => [],
    qw| nameserv    | => [],
    qw| timestamp   | => ( $cache->{'timestamp'} // 0 ),
    qw| cache_age   | => $age,
    qw| context     | => $context_p7ref,
    qw| glow_shells | => $glow_shells,
    qw| channel     | => $channel,
    qw| graph       | => $graph,
};

return eval { JSON::XS::encode_json($payload) } // '{}';
```

---

### JS changes needed (small, do in same commit or after)

in `visualization.html`, the `navPush` function currently builds mock data with
`generateMockSubNodes`. once the endpoint exists, replace that with a real fetch:

```js
function navPush(node) {
    const parentData = navOrbitalData || orbitalData;
    navStack.push({
        p7ref: node.p7ref,
        label: node.hostname || (node.p7ref || '').split(':')[1] || 'node',
        snapshot: { ...parentData }
    });
    // fetch real context data
    fetch('/orbital.json?context=' + encodeURIComponent(node.p7ref))
        .then(r => r.json())
        .then(data => {
            navOrbitalData = data;
            nodeHistory = {};
        })
        .catch(() => {
            // fallback to mock on fetch failure
            navOrbitalData = {
                self: { ...node },
                known: generateMockSubNodes(node.p7ref),
                connections: [], nameserv: [],
                channel: parentData.channel,
                glow_shells: [0,0,0,0,0,0]
            };
            nodeHistory = {};
        });
    updateBreadcrumb();
    selectedNodeP7ref = null;
    zoomTargetZoom = ZOOM_OVERVIEW;
}
```

---

### summary of files to create/modify

| file | action |
|------|--------|
| `src/httpd.process_template` | add query string → meta_vars merge |
| `data/web-root/vhosts/space.v7.ax/orbital.json.tmpl` | pass `<[meta.context]>` arg |
| `src/plugin.web.space.state` | regex match orbital-json with optional context arg |
| `src/plugin.web.space.orbital.json.context` | new module (main work) |
| `data/web-root/vhosts/space.v7.ax/visualization.html` | replace mock navPush with fetch |

### testing

after the changes:
```bash
# test root endpoint still works
curl -s 'https://space.v7.ax/orbital.json' | python3 -m json.tool | head -20

# test context endpoint with a known p7ref from the root response
curl -s 'https://space.v7.ax/orbital.json?context=NODE:NODENAME:ADDR' | python3 -m json.tool | head -20
```

the context response should have `self.p7ref` equal to the context arg, and
`known[]` should contain real nodes (minus the context node itself).

#,,.,,...,.,.,.,.,,,.,,,,,.,.,...,,,.,,,,,..,,..,,...,.,.,..,,,..,,,,,..,,,,,,
#E6HKTBZMBOGG5DSEMXLW4ULJ5SKVQF7NXZOO7O3AXBPFMQDCKCJ56DFJNLVVKQ2BGWYVNODIZ6WSI
#\\\|34SDCFLIFMOC7CA6HLVCEDHH2JU4FVFB3DRQWELXFWQD46OFCGT \ / AMOS7 \ YOURUM ::
#\[7]W6YXESRZMDGROWNSNZX6JQNEP6DTDXMPYZTPAHB374AUFPOM6YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
