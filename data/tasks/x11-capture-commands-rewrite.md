# task: X-11 capture commands — rewrite as async screenshot zenka proxy

## context

`X-11.cmd.capture-window` and `X-11.cmd.capture-region` currently spawn
external subprocesses (`scrot` or ImageMagick `import`) with a blocking
`system()` call, and accept a caller-specified `$output_path` that is an
attack surface. both problems are removed by delegating to the screenshot
zenka, which uses Imager directly and controls the output path internally.

## style reference

read and follow: `data/ai-mem/kimi/coding-style.md`
also: `data/yaml/docs/protocol-7-coding-style.md`

## design

`screenshot.cmd.capture-to-disk` accepts four space-separated integers:
`left top right bottom` (screen coordinates, not x/y/w/h).

conversion from x/y/w/h to left/top/right/bottom:
```
left   = x
top    = y
right  = x + w
bottom = y + h
```

both commands route-send to `screenshot.capture-to-disk` and return deferred.
the reply from screenshot comes back via `X-11.handler.capture_reply`,
which forwards the result to the original caller using `base.callback.cmd_reply`.

the `output_path` parameter is **removed entirely** from both commands —
the path is chosen by the screenshot zenka and returned in the reply.

## modules to modify

### X-11.cmd.capture-window

remove the `output_path` param and all subprocess logic. new flow:

1. validate `$window_id` (digits only)
2. `GetGeometry($window_id)` on `<X-11.obj>` to get x, y, width, height
3. compute region: `left=x, top=y, right=x+w, bottom=y+h`
4. route-send to `screenshot.capture-to-disk` with `"$left $top $right $bottom"`
5. pass `reply_id` via `reply.params` so the handler can forward the response
6. return `{ mode => 'deferred' }`

```perl
## [:< ##

# name  = X-11.cmd.capture-window
# param = <win_id>
# descr = capture x11 window to png via screenshot zenka; returns file path

my $window_id = $call->{'args'} // '';
$window_id    =~ s|^\s+|\s+$||g;

return { 'mode' => qw| false |, 'data' => 'window id required' }
    if not length $window_id;
return { 'mode' => qw| false |, 'data' => 'invalid window id' }
    if $window_id !~ m|^\d+$|;

my %geom = eval { <X-11.obj>->GetGeometry( $window_id + 0 ) };
if ( $EVAL_ERROR or not exists $geom{'width'} ) {
    return { 'mode' => qw| false |, 'data' => 'GetGeometry failed' };
}

my ( $x, $y, $w, $h )
    = @geom{qw| x y width height |};
my $region = sprintf '%d %d %d %d', $x, $y, $x + $w, $y + $h;

<[protocol-7.route-send]>->(
    {   'command'   => qw| screenshot.capture-to-disk |,
        'call_args' => { 'args' => $region },
        'reply'     => {
            'handler' => qw| X-11.handler.capture_reply |,
            'params'  => { 'reply_id' => $call->{'reply_id'} }
        }
    }
);

return { 'mode' => qw| deferred | };
```

### X-11.cmd.capture-region

remove `output_path` param and subprocess logic. validate x y w h, convert
to left/top/right/bottom, route-send to screenshot.capture-to-disk.

```perl
## [:< ##

# name  = X-11.cmd.capture-region
# param = <x> <y> <w> <h>
# descr = capture screen region to png via screenshot zenka; returns file path

my $param_str = $call->{'args'} // '';

return { 'mode' => qw| false |, 'data' => 'expected: x y w h' }
    if $param_str !~ m|^(\d+) +(\d+) +(\d+) +(\d+)$|;

my ( $x, $y, $w, $h ) = ( $1 + 0, $2 + 0, $3 + 0, $4 + 0 );
my $region = sprintf '%d %d %d %d', $x, $y, $x + $w, $y + $h;

<[protocol-7.route-send]>->(
    {   'command'   => qw| screenshot.capture-to-disk |,
        'call_args' => { 'args' => $region },
        'reply'     => {
            'handler' => qw| X-11.handler.capture_reply |,
            'params'  => { 'reply_id' => $call->{'reply_id'} }
        }
    }
);

return { 'mode' => qw| deferred | };
```

### new module: X-11.handler.capture_reply

forwards the screenshot zenka reply to the original caller:

```perl
## [:< ##

# name  = X-11.handler.capture_reply
# descr = forward screenshot.capture-to-disk reply to original capture caller

my $reply    = shift // {};
my $params   = $reply->{'params'} // {};
my $reply_id = $params->{'reply_id'} // '';

return unless length $reply_id;

my $mode = lc( $reply->{'cmd'} // '' );
my $data = $reply->{'call_args'}{'args'} // $reply->{'data'} // '';

<[base.callback.cmd_reply]>->(
    $reply_id,
    {   'mode' => $mode eq qw| true | ? qw| true | : qw| false |,
        'data' => $data
    }
);
```

## access control

add to `configuration/zenki/cube/access.zenki` wherever
`X-11.get_pointer_scr_rect` or `X-11.get_monitors` appear — same pattern:

```
X-11.capture-window
X-11.capture-region
```

add to `configuration/zenki/X-11/subroutine.white-list`:
```
X-11.handler.capture_reply
```

(capture-window and capture-region are already whitelisted)

## notes

- `reply.params.reply_id` carries the original caller's reply_id across the
  async boundary — this is the standard pattern for thin proxy cmds
- screenshot zenka must be started (on-demand or always-on) for the route-send
  to succeed; if not running, cube returns an error which capture_reply
  forwards as false to the caller
- do not add `output_path` param back under any circumstances — caller
  receives the system-chosen path in the reply data

## acceptance

- `p7c X-11.capture-region 0 0 100 100` returns a png path under
  `/var/protocol-7/screenshot/`
- `p7c X-11.capture-window <id>` returns a png path
- no `system()` calls remain in either module
- no `output_path` parameter exists in either module
- `bin/dev/ptd -c` passes on all 3 modules

## dispatch

## kimi: rewrite X-11.cmd.capture-window, X-11.cmd.capture-region, and
## create X-11.handler.capture_reply as described above.
## verify with p7c after each module. do not modify signature footer lines.

#,,.,,,,.,,,.,..,,.,,,...,,.,,,,.,.,,,,,,,.,,,..,,...,...,.,.,.,,,,..,,..,,,,,
#KLYKRHXIC6YG7VJV2NSJBETWOKV2KMWEJ4G4DDYM4TYZNUSKIPS5IJBH5772STCZZHGG5DD3PLHJG
#\\\|XST2TLAG6THZGJQ6MLE2GCBKPX247X2YWXCC46JCAQQG4GXVYW4 \ / AMOS7 \ YOURUM ::
#\[7]YBBEXAK54MTYQ27RJZNBSUKXHOHG7XMK7QNWWPSV5SAYDL23K2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
