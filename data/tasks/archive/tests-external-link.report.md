# tests : external named links report

script : `bin/test-scripts/test-external-link.pl` -- run with `perl bin/test-scripts/test-external-link.pl`, exit 0.

## full output

```
  ok   : regex.base.usr taken from the real base.regex module
external.link.open : argument validation
  ok   : missing name -> false
  ok   : missing name -> no base.open call
  ok   : missing host -> false
  ok   : missing host -> no base.open call
  ok   : missing port -> false
  ok   : missing port -> no base.open call
  ok   : non-numeric port -> false
  ok   : non-numeric port -> no base.open call
  ok   : empty args -> false
  ok   : empty args -> no base.open call
  ok   : invalid link name 'bad name' -> false
  ok   : invalid link name 'bad/name' -> false
  ok   : invalid link name '-lead' -> false
  ok   : invalid link name 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -> false
  ok   : invalid link name 'a[b]' -> false
  ok   : invalid names -> no base.open call
  ok   : a valid name passes the name check
  ok   : no as_username and no cfg.link_user -> false
  ok   : no identity -> no base.open call
external.link.open : failure paths close the socket
  ok   : base.open undef -> false "cannot connect"
  ok   : open failure -> auth not attempted
  ok   : auth undef -> false
  ok   : auth undef -> socket closed
  ok   : auth undef -> no handshake
  ok   : auth dies -> die propagates
  ok   : auth dies -> socket closed
  ok   : handshake ( 0, { error } ) -> false with the error text
  ok   : handshake failure -> socket closed
  ok   : handshake failure -> no session
  ok   : handshake dies -> die propagates
  ok   : handshake dies -> socket closed
  ok   : session.init undef -> false
  ok   : session.init undef -> socket closed
  ok   : session.init undef -> no init_state
  ok   : client_activate false -> false
  ok   : client_activate false -> session.shutdown( id ) once
  ok   : client_activate false -> no link registered
external.link.open : success and reuse
  ok   : success -> ( true, sid )
  ok   : auth got as_username and the link name
  ok   : base.open got ip.tcp output host port
  ok   : session.init got the link name as session name
  ok   : init_state( id, 1 ) called
  ok   : client_activate got id and the handshake link
  ok   : session marked authenticated = yes
  ok   : external.links entry = { sid host port user }
  ok   : success -> socket left open
  ok   : reuse : same name host port -> same sid
  ok   : reuse -> no new base.open
  ok   : same name other host -> false "link lnk is open to .."
  ok   : same name other port -> false
  ok   : conflict -> no new base.open
  ok   : conflict -> old entry kept
  ok   : stale entry -> a new link is opened [ new sid ]
  ok   : stale entry -> one new open
  ok   : stale entry replaced by the new link
  ok   : as_username //= external.cfg.link_user
external.cmd.connect
  ok   : args '' -> false usage
  ok   : args 'onlyname' -> false usage
  ok   : usage failure -> no timer
  ok   : no reply_id -> false
  ok   : no reply_id -> no timer
  ok   : valid -> mode deferred
  ok   : ONE timer with after 0
  ok   : timer carries a callback
  ok   : link.open not called before the timer fires
  ok   : no reply before the timer fires
  ok   : cb -> link.open called once
  ok   : link.open got { name host port as_username }
  ok   : link.open true -> cmd_reply( reply_id, true, "linked .. session N" )
  ok   : port defaults to 42 when unset
  ok   : as_username undef when not given [ link.open applies cfg ]
  ok   : port defaults to protocol-7.remote.default-port when set
  ok   : bare-string args without reply_id -> reply route error
  ok   : link.open false -> that false result passed through
  ok   : link.open dies -> cb itself does not die
  ok   : link.open dies -> cmd_reply false "link setup failed : <msg>"
  ok   : die message trailing whitespace trimmed
  ok   : link.open returns undef -> still a reply [ "no result" ]

passed : 79  failed : 0
```

## what each group proves

- argument validation : missing name \ host \ port, non-numeric port, bad link names [ checked against the real `regex.base.usr` from `base.regex` ] and a missing identity all return false BEFORE any `base.open`.
- failure paths : base.open undef, auth undef \ die, handshake fail \ die, session.init undef all return false [ or propagate the die ] and the socketpair end is verified closed [ `fileno` undef ] ; client_activate false calls `session.shutdown( id )` and registers nothing.
- success : ( true, sid ), init_state( id, 1 ), `authenticated eq yes`, `external.links` entry { sid host port user }, link name used as session name, cfg.link_user fallback.
- reuse : same name+host+port -> same sid with no new open ; other host or port -> false "link X is open to .." with the old entry kept ; stale entry [ session gone ] -> replaced by a new link.
- external.cmd.connect : usage and no-reply_id errors, deferred result with exactly one `after 0` timer and link.open not yet called, port default 42 \ `protocol-7.remote.default-port`, true -> "linked .. session N" reply, false passed through, die -> "link setup failed : <msg>" reply [ trailing whitespace trimmed ], undef result -> "no result" reply [ never a hung caller ].

## suspected real bugs

none found. observation only : the config port arrives as a string and the reuse comparison uses `ne` on host and port, so `42` vs `042` would count as a different port -- harmless, not changed.

#,,,,,...,.,,,,,,,,.,,,,,,.,.,.,,,,,,,..,,...,..,,...,...,,.,,...,...,,.,,,,.,
#YLTAKVJLAMXGMBTFQ3QCHMEPQ53DBWGKD6SW7HQNQY4IUURUAGLTWWESMJXUJHSVIEGJUC52Y2IB2
#\\\|5VSDONUIZF3S266S6TSAPW7Q3ORIXM73CX6HRPBVYIQ7PWDYAI5 \ / AMOS7 \ YOURUM ::
#\[7]PYJSQIIHKOSURFEVCLKHESEXZRBT7I6WKNFV52XIDQN5PT6GWCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
