# task: make httpd.route.handler.web-relay truly async

## problem

opening `http://172.24.32.1/` (jobs UI) crashes the httpd zenka. the
`httpd.route.handler.web-relay` module dispatches HTTP requests to the web
zenka via `route-send` with a SIZE reply pattern, but the dispatch is not
truly async: the HTTP session's 23-second `input_handler` IO watcher
(timeout_cb sets `$session->{'shutdown'} = TRUE`) fires before the web zenka
reply arrives, tearing down the session and collapsing the pending route.

the fix must make the dispatch non-blocking so that the session stays alive
until the SIZE reply arrives and `flush_shutdown` closes it cleanly.

**important**: simply cancelling `input_handler` was tried and was identified
as wrong — it will terminate the session prematurely in this context (even
though the radio relay also cancels it, there is likely a difference in
context or ordering that makes it dangerous here). the correct mechanism
needs to be determined by examining the working async handlers listed below.

## session lifecycle (key watchers, set up in base.session.init)

- `input_handler` — `Event->io`, `poll => 'rt'`, `repeat => FALSE`, timeout
  23s (httpd.timeout config key). timeout_cb: `$session->{'shutdown'} = TRUE`
- `shutdown_trigger` — var watcher on `$session->{'shutdown'}`, calls
  `base.session.check.close` → cancels all routes, tears down session
- `flush_shutdown` — var watcher on `$session->{'flush_shutdown'}`, calls
  `base.session.check.flushed` → clean drain+close
- `output_buffer` — var watcher on `$session->{'buffer'}{'output'}`,
  `repeat => FALSE`, fires `base.handler.write` when buffer becomes non-empty
- `input_error` — `Event->io`, `poll => 'e'`, catches socket exceptions

## file to fix

`src/httpd.route.handler.web-relay`

```perl
## [:< ##

# name  = httpd.route.handler.web-relay
# descr = relay HTTP request to web zenka via route-send SIZE pattern
#         generic handler : command and args from route config

my $id      = shift;
my $args    = shift // {};
my $session = $data{'session'}->{$id};

my $command = $args->{'command'}           // qw| web.request |;
my $body    = $session->{'http'}->{'body'} // $session->{'buffer'}->{'input'}
    // '';
$session->{'http'}->{'body'}    = '';
$session->{'buffer'}->{'input'} = '';

$session->{'http'}->{'close'} = TRUE;

<[protocol-7.route-send]>->(
    {   'command'   => $command,
        'call_args' => { 'args' => $body },
        'reply'     => {
            'handler' => qw| httpd.handler.web-relay.response |,
            'params'  => { 'http_sid' => $id },
        },
    }
);

return 0;    # [ deferred : reply handler writes response ]
```

## reply handler (already correct, do not change)

`src/httpd.handler.web-relay.response`

```perl
my $reply    = shift // {};
my $http_sid = $reply->{'params'}->{'http_sid'};
return warn 'httpd_sid not defined' if not defined $http_sid;

my $session = $data{'session'}->{$http_sid};
if ( ref($session) ne qw| HASH | ) {
    return <[base.logs]>->( 1, '[%d] client already gone.. [web-relay.response]', $http_sid );
}

my $data_ref = ( ref $reply eq qw| HASH | ) ? $reply->{'data'} : $reply;
my $ct = ...;

$session->{'buffer'}->{'output'} .= <[httpd.new_header]>->( 200, { ... } );
$session->{'buffer'}->{'output'} .= $data_ref;
$session->{'flush_shutdown'} = TRUE;
```

## working examples to analyze — find the common async pattern

### 1. radio relay (works — same route-send pattern but STRM not SIZE)

`src/plugin.httpd.radio.handler.stream_request`

this handler:
1. writes 200 headers to output buffer immediately
2. cancels `input_handler`
3. calls route-send (STRM reply, not SIZE)

the key question: does writing to the output buffer first make cancel safe?
or is there another mechanism? does the order matter?

### 2. download transfer handler

`src/httpd.handler.download_transfer`

async file transfer from httpd — examine how it keeps the session alive
during a long transfer without the input_handler timeout firing. what does
it do differently from web-relay?

### 3. web zenka template dispatch

`src/httpd.route.handler.context` (or similar — list_modules web-relay
or httpd.route.* to find the template dispatch handler)

the template reply path also dispatches to the web zenka and waits for a
reply. if it works, how? what mechanism prevents timeout?

### 4. base.session.init — input_handler setup

`src/base.session.init` lines 206-262

re-read the exact timeout_cb and how the watcher is set up. is there a way
to extend or reset the timeout? is there a `no_timeout` variant?

## what to produce

a concrete, minimal fix for `src/httpd.route.handler.web-relay` that:

1. prevents the 23-second `input_handler` timeout from killing the session
   while waiting for the SIZE reply from web zenka
2. keeps the session alive until either:
   a. the SIZE reply arrives → `flush_shutdown` closes it cleanly, OR
   b. the client disconnects (TCP RST/FIN) → `input_error` or EOF closes it
3. does NOT break the existing reply handler path
4. is consistent with the pattern used by the working async handlers

if cancel IS safe (and the user's concern was about something else), explain
exactly why cancel is safe here and show the correct ordering. if a different
mechanism is needed (timeout extension, flag, watcher restart), show that.

## signatures note

all module files end with a 4-line AMOS7 signature block like:

```
#,,,.,,..,...,,..,...
#PGQNE2QJ...
#\\\|VNFS...
#\[7]IA63...
```

do not modify, replicate, or comment on these signatures. they are
cryptographic and will be regenerated by the signing system. just leave them
as-is at the end of any file you read or edit.

## dispatch note

this is a research + fix task. read the working async handlers first to
understand the pattern, then produce the fix. do not guess — derive the
mechanism from the working code.

#,,,.,,,.,,,.,,..,...,.,,,,,,,,,,,.,,,.,,,,,,,..,,...,..,,...,.,.,.,.,,..,,,.,
#AEPR75AO5HGXFO3XEF7E7M24LJREKGZXECJUEMPXDKGXVKQKWATT5QKDNI5PT3LY2CBQ3BAQ6QD3S
#\\\|7B2HRR6TNCE6WQE4NOTPGDDUG6F5IVESW7X55VBE5UTQEXIL45H \ / AMOS7 \ YOURUM ::
#\[7]WH46EVMNQE3YZLVLQ2SCUJPQ6DRCF3CSAPB3VRGMMO2WHG6ENIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
