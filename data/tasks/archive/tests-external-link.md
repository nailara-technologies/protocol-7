# tests : external named links [ external.cmd.connect \ external.link.open ]

ONE test-only script for code verified only live [ `c26bfb171`,
`201605f07`, 2026-10-05 ]. no change to anything under `src/` or `cfg/`
-- if a test reveals a real bug, STOP, describe it in the report
[ inputs, expected, actual ], do not fix it.

do NOT start, restart or reload any zenka, no sudo, no commit, do NOT
try to sign files, no real network [ no tcp to any host ; use a
socketpair or stubs ]. never read any real key dir [ `~/.n/` ].

you write exactly one new file : `bin/test-scripts/test-external-link.pl`.
a second agent works in parallel on `bin/test-scripts/test-host-root-keygen.pl`
-- do not touch it, and touch no other file.

harness pattern : copy the setup of `bin/test-scripts/test-link-upgrade-client.pl`
[ BEGIN lib path, `compile_module`, `%code` \ `%data`, `TRUE => 5`,
`FALSE => 0`, `ok()`, exit code ]. that test already covers the
handshake + client_activate themselves -- here they are STUBS
[ recorders with scripted results ], the subject is the link logic.

## modules under test [ read both headers ]

- `src/external.link.open`
- `src/external.cmd.connect`

stub : `base.open` [ returns a socketpair end, or undef ],
`auth.client.auth-keypair.authenticate`, `protocol.protocol-7.
link-upgrade.handshake` [ returns ( 1, {..} ) or ( 0, { error } ) or
dies ], `base.session.init` [ returns an id, creates
`$data{'session'}{$id}` ], `base.session.init_state`, `protocol.
protocol-7.link-upgrade.client_activate`, `base.session.shutdown`,
`base.logs`, `event.add_timer` [ RECORD the timer, run its cb by hand ],
`base.callback.cmd_reply` [ record ]. `<regex.base.usr>` : take the real
value from `cfg/` or the module defining it [ grep ], do not invent one.

## checks : external.link.open

- missing name \ host \ port, non-numeric port -> mode false, no
  `base.open` call
- link name not matching `<regex.base.usr>` -> false
- no `as_username` and no `<external.cfg.link_user>` -> false, no open
- `base.open` undef -> false "cannot connect"
- auth undef -> false, socket CLOSED [ check the fh is closed ]
- auth dies -> the die propagates AND the socket is closed
- handshake ( 0, { error } ) -> false with the error text, socket closed
- handshake dies -> propagates, socket closed
- session.init undef -> false, socket closed
- client_activate false -> session.shutdown( id ), false
- success -> ( true, sid ) ; init_state( id, 1 ) called ;
  `$data{'session'}{$id}{'authenticated'}` eq 'yes' ;
  `<external.links>->{name}` = { sid host port user } ; session.init got
  the link name as session name
- reuse : same name + host + port while `$data{'session'}{sid}` exists ->
  same sid, NO new base.open
- same name, other host -> false "link X is open to ..", old entry kept
- stale entry [ session gone ] -> deleted, a new link is opened

## checks : external.cmd.connect

- no args \ one arg -> false usage ; no reply_id -> false
- valid -> returns mode deferred, ONE timer with after 0, link.open not
  yet called
- run the cb : link.open got { name, host, port, as_username } ; port
  defaults to `<protocol-7.remote.default-port>` and to 42 when unset
- link.open true -> cmd_reply( reply_id, true, "linked .. session N" )
- link.open false -> that false result passed through
- link.open dies -> cmd_reply with false "link setup failed : <msg>" --
  never no reply

## pitfalls [ hit in this codebase this week ]

- `ok( .. ) or say .. for @list` loops the WHOLE statement -- write the
  `for` as its own statement
- `my $x = a and b` parses as `( my $x = a ) and b` -- use if-conditions
- the production runtime loads `use bytes` transitively -- keep the
  precedent's `use bytes`
- stub `base.s_warn` and `base.caller` when a module may complain
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`
- `bin/format-code -c <file>` for syntax checks, not bare `perl -c`

## report

write `data/tasks/tests-external-link.report.md` : full script output,
what each check proves, anything that looked like a real bug
[ described, not fixed ]. write it as soon as the script passes.

#,,.,,...,...,,.,,,,.,..,,.,,,,,,,.,,,.,.,..,,..,,...,...,..,,,,,,,.,,.,.,,..,
#G3LJGGJOBGUXZYFWZVY372QQPTLJHWB64TYWELJRFQCGFX6PEPNLA3V63GGI5ZLRHG6ZT34PR67TU
#\\\|Z7JRPPVKA23UHYCWYPRTHI4S2VH25PTTCK7YPGTKBCQUV2G2AD4 \ / AMOS7 \ YOURUM ::
#\[7]VBH7LW35SMUMEEMENLLXBGATVH76FDRSTQXEJL7LAWHEWBUUN2BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
