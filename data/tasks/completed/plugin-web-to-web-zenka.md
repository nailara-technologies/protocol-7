## [:< ##

# name  = task: migrate plugin.web.* back to web zenka
# descr = remove plugin.web.* from httpd (temporary workaround),
#         route all /api/*, /iris/*, /jobs/* through web zenka
#         using route-send + SIZE reply pattern (like radio relay)

## background

plugin.web.* modules were loaded into httpd as a quick testing workaround.
the correct architecture:
  httpd:      thin proxy only — routes to web zenka, never blocks on data
  web zenka:  owns all plugin.web.* logic, handles route-send to data zenki
              crashes: httpd unaffected
              retries: transparent to clients
              state: isolated, restartable

## read first

- cfg/zenki/httpd/start          (current httpd config)
- cfg/zenki/web/start            (web zenka config)
- modules/plugin.httpd.radio.handler.stream_request  (route-send + reply pattern)
- modules/plugin.httpd.radio.handler.strm_open       (SIZE reply handler)
- modules/httpd.route.handler.iris-svg               (current iris handler)
- modules/httpd.handler.iris-svg.relay               (current relay handler)

## step 1: httpd cleanup

in cfg/zenki/httpd/start:
  REMOVE: [base.white-list.register:'plugin.web.jobs']
  REMOVE: plugin.web.jobs from plugins.load
  REMOVE: plugin.web.iris from plugins.load (if present)
  
  plugins.load should contain only: plugin.httpd.radio
  (radio stays in httpd — it uses the STRM open-ended stream pattern
   which requires direct httpd socket access)

in cfg/zenki/httpd/routes:
  keep: GET /iris/svg     httpd.route.handler.iris-svg
  keep: POST /iris/route  httpd.route.handler.iris-route
  keep: GET /jobs.json    → change to route through web zenka
  keep: POST /jobs-sync   → change to route through web zenka

## step 2: web zenka loads plugin.web.*

cfg/zenki/web/start already has:
  plugins.load = plugin.web
  [load_plugins:<plugins.load>]

verify plugin.web.iris is in the web zenka's plugin.web namespace
and loaded correctly. no changes needed if web zenka already loads all
plugin.web.* modules.

## step 3: httpd relay handlers for web zenka routes

create a generic relay handler pattern for web zenka routes:

### new module: httpd.route.handler.web-relay

```perl
# name  = httpd.route.handler.web-relay
# descr = relay HTTP request to web zenka via route-send SIZE pattern
#         generic handler — command and args from route config

my $id      = shift;
my $args    = shift // {};
my $session = $data{'session'}->{$id};

my $command = $args->{'command'} // 'web.request';
my $method  = $session->{'meta'}->{'request_method'} // 'GET';
my $path    = $session->{'meta'}->{'request_path'}   // '/';
my $body    = $session->{'buffer'}->{'input'}        // '';
$session->{'buffer'}->{'input'} = '';

$session->{'http'}->{'close'} = 1;

<[protocol-7.route-send]>->(
    {   'command'   => $command,
        'call_args' => {
            'args' => join( "\n", $method, $path, $body )
        },
        'reply' => {
            'handler' => 'httpd.handler.web-relay.response',
            'params'  => { 'http_sid' => $id },
        },
    }
);

return 0;   # [ deferred — reply handler writes response ]
```

### new module: httpd.handler.web-relay.response

```perl
# name  = httpd.handler.web-relay.response
# descr = write web zenka SIZE reply to HTTP session

my $reply    = shift;
my $params   = shift // {};
my $http_sid = $params->{'http_sid'};

return unless defined $http_sid;
my $session = $data{'session'}->{$http_sid};
return unless defined $session;

my $data_ref = ( ref $reply eq 'HASH' ) ? $reply->{'data'} : $reply;
my $ct       = ( ref $reply eq 'HASH' ) ? ( $reply->{'content_type'} // 'application/json' )
             : 'application/json';

if ( not defined $data_ref ) {
    $session->{'buffer'}->{'output'} .= <[httpd.send_error_page]>->( $http_sid, 502 );
    return;
}

$session->{'buffer'}->{'output'} .= <[httpd.new_header]>->(
    200,
    {   'Content-Type'   => $ct,
        'Content-Length' => length($data_ref),
        'Cache-Control'  => 'no-cache',
    }
);
$session->{'buffer'}->{'output'} .= $data_ref;
```

## step 4: update httpd routes to use web-relay

in cfg/zenki/httpd/routes, change:
  GET   /jobs.json   plugin.web.jobs.data
  POST  /jobs-sync   plugin.web.jobs.sync

to:
  GET   /jobs.json   httpd.route.handler.web-relay  [command=web.jobs.data]
  POST  /jobs-sync   httpd.route.handler.web-relay  [command=web.jobs.sync]
  GET   /iris/svg    httpd.route.handler.iris-svg    (keep as-is for local modes)
                     (oscilloscope already uses route-send)

OR: keep iris-svg as dedicated handler since it has caching logic.
just remove plugin.web.jobs from httpd.

## step 5: web zenka command handlers

in the web zenka, add command handlers that the relay calls:
  web.jobs.data  → calls plugin.web.jobs.data logic, returns SIZE JSON
  web.jobs.sync  → calls plugin.web.jobs.sync logic, returns SIZE JSON

these exist already in plugin.web.jobs.* — just need to be accessible
as commands from outside the web zenka.

add to cfg/zenki/web/start access.cmd:
  access.cmd.usr.httpd = jobs.data jobs.sync ...

## step 6: iris web zenka integration

plugin.web.iris (if it exists) moves fully to web zenka.
the oscilloscope relay (httpd.handler.iris-svg.relay) remains in httpd
as the SIZE reply handler — it just writes SVG to the http session.

## step 7: add web zenka to httpd access.zenki

if not already present, httpd needs permission to call web zenka:
  in cfg/zenki/web/access.zenki or cube/access.zenki:
  access.cmd.usr.httpd = jobs.data jobs.sync visual-wheel ...

## minimum viable migration (do this first)

1. remove plugin.web.jobs from httpd plugins.load
2. verify web zenka loads it and has the commands accessible
3. add web-relay handler + response handler
4. update /jobs.json and /jobs-sync routes to use web-relay
5. test: jobs UI still works via the relay

iris-svg can stay as-is for now (it's already partially P7-native
via the oscilloscope route-send). full iris migration: separate task.

## timeout + retry in web zenka

the web zenka can implement retry for failed data zenka calls:
  on first failure: wait 500ms, retry once
  on second failure: return last cached response
  on cache miss: return 503 with helpful message
  
httpd never sees the retry — only the final result or 503.

## signatures note

new modules: leave clean. existing: re-signed on commit.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

#,,,,,,..,...,...,,..,,.,,,,,,.,.,...,,.,,,.,,..,,...,...,..,,,..,.,,,.,.,,..,
#IGMLU63AYQQEW5ONF4QFL4ADBOGIK4NPU3LIZY5EDKU45TV25UGOOIHRNXOSCNNLRG4LUCVOVBRTK
#\\\|3EP6GFZTG2NUDQN4NJVERZE2BOGPVUD3P3IR3QQTCM5SOXKYGJP \ / AMOS7 \ YOURUM ::
#\[7]SEZIK7E32AY7NFRAOEYT3EKJUAESE74ZDEGCN4PRKFK3VVGE72BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
