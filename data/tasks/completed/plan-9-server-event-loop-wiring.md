## archive: DONE ✓ -- 2026-08-22
## commit: 599a24103 -- wire plan-9 zenka into v7/cube and complete real-directory 9P export
## notes: live-verified end to end against a real plan-9 + storage zenka pair; see the
##        commit message and the file body below for the full 5-gap arc and the
##        File::stat shadowing gotcha found along the way

## [:< ##

# name  = task: wire plan-9 server's accept/read/dispatch loop into the event loop
# descr = plan-9.server.client.accept/data/close exist and are individually
#         correct in shape, but nothing ever registers the listener socket
#         (or accepted client sockets) with the event loop -- the whole
#         9P TCP server is currently inert once bound.

## context

session: 2026-08-22, found while live-testing the storage.9p.* client fixes
(see commit history around `f24495bc0` and the follow-up commit that added
`plan-9.server.export_directory`/`realpath-read` + fixed the `plan-9`
zenka's `zenka.v7`/`start.cfg`/`auth.zenki` so it could actually be started
via `v7.start plan-9` for the first time ever). Getting the real zenka to
`online` with a real bound TCP listener (`ss -tlnp` confirmed
`127.0.0.1:15640 LISTEN`) required fixing FOUR independent, previously
undiscovered gaps in this subsystem, in order:

1. `plan-9.protocol.constants` used plain Perl `use constant` instead of
   this codebase's `<...>` data-tree syntax -- fixed (renamed to
   `.pre_init`, real `Const::Fast` constants, see commit history).
2. `plan-9`'s own `modules.load` referenced nonexistent module names
   (`plan-9.server.buffer.read`/`.write`/`.stat` with dots, `handle_io`) --
   fixed by simplifying to the namespace-level convention
   (`plan-9.protocol plan-9.config plan-9.server`, matching how `storage`
   already loads `plan-9` as a bare namespace token -- **do not re-expand
   this into an explicit per-file list**, that was tried and reverted
   during this same session; the whitelist, regenerated via
   `bin/dev/gen-sub-whitelist plan-9`, handles eager-vs-on-demand compile
   selection correctly on its own).
3. Nothing ever called `<[plan-9.server]>->()` (the function that actually
   does `io.ip.tcp.input.open` to bind the listener) -- fixed by adding
   `[plan-9.server]` to `zenka.v7` after `[base.net.connect:'unix']`.
4. `plan-9` had no `start.cfg` (v7 didn't know it was startable) and no
   `auth.zenki` entry in `cfg/zenki/cube/auth.zenki` (cube wouldn't
   authenticate it) -- both added, modeled on `storage`'s equivalents.
   Also needed `v7.reload` (not just `reload config`) for v7 to pick up
   the brand-new `start.cfg` at all.
5. `io.ip` was missing from `modules.load` (only `io.unix` was listed) --
   the TCP listener bind (`io.ip.tcp.input.open`) needs it; `io.unix` alone
   only covers the cube unix-socket connection.

**This task is the fifth gap**, found immediately after (4) and (5) got it
to `online` with the socket genuinely `LISTEN`ing: a test client
(`storage.plan9-connect` from the real, working `storage` zenka -- see
`src/storage.9p.*`, already fixed and live-verified against a *different*,
throwaway test-harness server earlier this session) connected at the TCP
level but then hung until `storage` itself was auto-restarted by its own
watchdog. `plan-9`'s own log showed no trace of ever receiving the
connection.

## root cause

`grep -rln "plan-9.server.client.accept" src/` turns up only
`plan-9.server.client.accept`'s own file and the auto-generated
`base.list.subroutines` index -- **nothing calls it**. Same for
`plan-9.server.client.data`/`plan-9.server.client.close` presumably (not
independently re-checked, but given the pattern, assume the same). The
listener socket is bound successfully but never registered with
`event.add_io`, so the event loop never learns a connection is waiting to
be accepted, and even if it were, nothing would ever read from an accepted
client socket either.

This matches the user's own account of this subsystem's history: it was
sketched out (bind socket / accept client / parse message / dispatch by
type / handle each type -- `plan-9.server.handle_request` already
correctly dispatches by 9P message type to `handle_version`/
`handle_attach`/`handle_walk`/`handle-io-*`, all independently verified
correct or fixed earlier this session) but never actually wired into a
running accept-and-read loop before the effort moved to the client side
(realizing WSL itself already provides 9P access to Windows host disks,
making a *client* the more immediately useful piece).

## what already works and must not be broken

- `plan-9.server.handle_request` -- dispatches Tversion/Tattach/Twalk/
  Topen/Tread/Twrite/Tclunk/Tstat correctly, by message type, to the
  right handler. **Do not modify signature/dispatch logic.**
- `plan-9.server.handle_version`/`handle_attach`/`handle_walk`/
  `handle-io-{open,read,stat,write,clunk}` -- all take `($client, $tag,
  $data)` where `$data` is the message *payload only* (header already
  stripped) and return a fully-encoded 9P reply message (ready to write
  directly to the socket). This task's job is purely: get bytes off the
  wire, frame them into complete messages, call
  `plan-9.server.handle_request($client, $fd, $type, $tag, $payload)`,
  and write the returned bytes back.
- `plan-9.server.client.accept($fd, $peer_addr)` -- already correctly
  initializes `$data{'plan-9'}{'server'}{'clients'}{$fd}` with
  `fids/msize/uname/aname/buffer/peer`. Reuse this shape; don't
  reinvent per-client state.
- `plan-9.server.export_buffer`/`export_directory` -- registration-only,
  unaffected by this task, no changes needed.

## the precedent to mirror -- proxy.listen / proxy.handler.accept / proxy.handler.connection / proxy.client.close

This exact shape (listen -> event.add_io on the listener -> accept
handler registers a *second* event.add_io on each new client fd ->
per-connection buffer/state hash -> read handler accumulates bytes and
detects one complete message at a time -> dispatch -> cleanup on
error/EOF) already exists, working, in this codebase. Read these four
files in full before writing anything:

- `src/proxy.listen` -- binds the listen socket, then:
  ```perl
  <[event.add_io]>->(
      {   fd      => $sock,
          poll    => 'r',
          handler => 'proxy.handler.accept',
          data    => $sock,
          desc    => 'proxy accept handler'
      }
  );
  ```
- `src/proxy.handler.accept` -- `my $listen_sock = shift->w->data;` then
  `$listen_sock->accept`, `$client_sock->blocking(0)`, builds a per-client
  state hash (`sock/buffer/state/...`), then registers a *second*
  `event.add_io` on the new client socket with a *different* handler
  (`proxy.handler.connection`), storing the returned watcher object in
  the client state (`$data{...}{$client_id}{'watcher'} = <[event.add_io]>->(...)`)
  so it can be cancelled later on disconnect.
- `src/proxy.handler.connection` -- `my $client_id = shift->w->data;`,
  reads via `<[base.s_read]>->($sock, \$chunk, 65536)` and follows this
  return-value convention exactly (mirror it precisely, this is the part
  most likely to get subtly wrong): **`-1` = read error** (log + close),
  **`0` = clean disconnect** (close, with a `half_closed` deferred-cleanup
  wrinkle worth reading but probably not needed for 9P's simpler
  request/response shape), **positive = bytes read**, appended to
  `$client->{'buffer'}`. Then checks whether the accumulated buffer
  contains one complete message and only acts once it does, leaving any
  leftover bytes in the buffer for the next read event.
- `src/proxy.client.close` -- `delete $data{...}{'clients'}{$client_id}`,
  cancels the stored watcher (`$client->{'watcher'}->cancel if
  $client->{'watcher'}->is_active`), closes the socket. Mirror this for
  `plan-9.server.client.close`.

## the one thing that's different: 9P framing vs proxy's HTTP framing

`proxy.handler.connection` detects a complete HTTP request via
`$client->{'buffer'} !~ s{^(.+\r?\n\r?\n)}{}s` (blank-line-terminated).
9P framing is length-prefixed instead, per `plan-9.protocol.codec.encode-message`/
the read side already implemented correctly in `storage.9p.read-message`
(client-side precedent for the exact same framing rule, already
live-verified this session): a message is `size[4] type[1] tag[2]
...payload...` where `size` is the *total* message length including the
4-byte size field itself. So the server-side read handler needs to:

1. Wait until `length($client->{'buffer'}) >= 4`, then peek the size via
   `plan-9.protocol.codec.decode-uint32(substr($client->{'buffer'}, 0, 4))`.
2. Wait until `length($client->{'buffer'}) >= $size` (the full message
   hasn't necessarily arrived in one read).
3. Extract exactly `$size` bytes as one message, leave the rest in the
   buffer (there may already be a second complete message queued behind
   it -- loop, don't just handle one and return, the same way
   `storage.9p.readdir`'s directory-parsing loop keeps consuming
   complete stat-entries until the buffer's exhausted).
4. Decode `type[1]` at offset 4, `tag[2]` at offset 5, payload is
   everything from offset 7 onward within that one message.
5. Call `<[plan-9.server.handle_request]>->($client, $fd, $type, $tag,
   $payload)`, get back a fully-encoded reply message, write it to the
   socket (non-blocking write considerations: proxy's outbound path has
   its own `outbound.io_watcher`-style pattern for handling partial
   writes on a non-blocking socket if the reply doesn't fit in one
   `syswrite` -- check if `base.s_write` or similar already handles this
   generically before writing new buffering logic for it).

## suggested split -- CORRECTED after reading client.data/client.close in full

Good news: this task is much smaller than the discovery above suggested.
`plan-9.server.client.data` and `plan-9.server.client.close` are **already
complete, correct implementations** of the framing/dispatch/cleanup logic
-- `client.data` already does the exact length-prefix buffer loop
described above (decode-uint32 size peek, wait for the full message,
extract with `substr(..., '')` [4-arg form, mutates buffer in place],
decode type/tag, slice the payload, call `handle_request`, send the
response via `base.net.send_to_socket`, loop for any additional queued
messages). `client.close` already does the delete-from-registry cleanup.
**Do not rewrite either of these -- they were already correct, just never
invoked.**

The entire remaining gap is exactly two `event.add_io` registrations,
mirroring `proxy.listen`/`proxy.handler.accept` precisely:

1. **`plan-9.server`** -- after the successful `io.ip.tcp.input.open`
   call, add an `event.add_io` registering the listener fd for read-
   readiness, with a new accept-handler (see #2) as the callback --
   exactly like `proxy.listen`'s registration of `proxy.handler.accept`.
2. **A new accept handler** (or extend `plan-9.server.client.accept`'s
   own signature/role -- check whether it's meant to be the event
   callback directly, since `event.add_io` handlers receive the watcher
   object via `shift->w->data` per `proxy.handler.accept`'s
   `my $listen_sock = shift->w->data;`, but `client.accept`'s current
   signature is `my ( $fd, $peer_addr ) = @ARG;` -- a mismatch that needs
   resolving, likely by having the listener's `event.add_io` callback do
   the actual `accept()` call itself [ mirroring `proxy.handler.accept`
   exactly ], then call `<[plan-9.server.client.accept]>->($fd,
   $peer_addr)` for the state-init part that already exists, then add a
   *second* `event.add_io` on the newly-accepted client fd with
   `plan-9.server.client.data` as the handler [ note: `client.data`'s
   signature is `my ($fd, $data) = @ARG;` -- takes the raw bytes read,
   not a watcher object directly, so whatever registers it needs to do
   the `base.s_read`-equivalent itself and pass the bytes through, one
   layer of glue `proxy.handler.connection` doesn't need to separate out
   since it inlines the read+dispatch in one handler ].
3. **`event.add_io`'s disconnect path** -- when a read returns 0/-1
   (proxy.handler.connection's convention), call
   `<[plan-9.server.client.close]>->($fd)` and cancel the watcher,
   mirroring `proxy.client.close`.

## verification

Storage's `storage.plan9-connect`/`storage.plan9-scan` (already fixed and
live-tested against a throwaway harness this session) are the ready-made
test client -- no new client-side code needed. Suggested test sequence,
all via `p7c`:

```
p7c v7.start plan-9          # or v7.restart if already running
p7c plan-9.export-directory /some/real/directory testdir
p7c storage.plan9-connect 127.0.0.1 15640 realtest
p7c storage.plan9-scan realtest testdir
```

Expect a real directory listing back, sourced from the real filesystem,
through the real `plan-9` zenka -- not a throwaway test harness. This is
the first time this entire subsystem (both client and server) would have
worked end-to-end as a real, independently-running two-zenka system since
it was first written.

## status: DONE, live-verified end to end (2026-08-22, same session)

Implemented as scoped above, with one more surprise found along the way:
sizes came back as 0 for every real file even though names/types/counts
were all correct. Traced via temporary debug logging (`CORE::stat(...)`
vs bare `stat(...)`) to `ui.fields.fallback` -- loaded generically via
every zenka's `ui` namespace, completely unrelated to this subsystem --
doing `use File::stat;`, which globally overrides `CORE::GLOBAL::stat`
for the *whole process* once compiled (a documented File::stat quirk).
Bare `stat($path)` inside `plan-9.server.buffer-stat`/`realpath-read`
silently returned an empty list instead of the real 13-element array;
`CORE::stat($path)` bypasses the override and was the fix, in both
files. `-e`/`-d` file-test operators are unaffected (File::stat only
overrides the `stat`/`lstat` *functions*), which is why existence/type
checks worked throughout while only the stat-array fields were broken --
worth remembering if this bites another module sharing a zenka process
with anything that loads File::stat.

Final live-verified sequence, exactly as prescribed above, against the
real `plan-9` zenka (not a throwaway test harness) and the real
`storage` zenka as client:

```
p7c v7.start plan-9
p7c plan-9.export-directory /data/projects/protocol-7/bin/test-scripts/9p-live-test test1
p7c storage.plan9-connect 127.0.0.1 15640 finaltest
p7c storage.plan9-scan finaltest test1
```

Returned all 15 real files with correct names, types, and byte-exact
real sizes (2282, 11288, 0, 1132, ... matching `ls -la` exactly). First
time this entire subsystem -- client and server both -- has worked
end-to-end since it was written.

Files touched beyond the original scope estimate: `plan-9.server`
(listener event.add_io registration), `plan-9.server.handler.accept` +
`plan-9.server.handler.read` (new, thin glue between event.add_io's
watcher-object calling convention and `client.accept`/`client.data`'s
existing `($fd, ...)`-style signatures), `plan-9.server.client.close`
(added watcher-cancel + socket-close, was only deleting the registry
entry before), `plan-9.server.client.data` (fixed `base.net.send_to_socket`
call to pass the actual socket object instead of a raw fd integer --
another pre-existing bug, `send_to_socket` requires a real filehandle),
`plan-9.server.buffer-stat` + `plan-9.server.realpath-read` (the
`CORE::stat` fix above).

#,,.,,,,.,.,,,..,,,.,,,.,,,,,,,..,..,,..,,,,,,..,,...,...,.,,,,,.,,,.,,..,.,,,
#7RY7BYV7FSQE3WSVTBHUZHD7LBJ2I72UWTPIUAMG4ZJHQ7XWAMYV7BLBQBBND7TB7MXBREXR3LAOW
#\\\|OEVPRMSOZNMJ7ICWIFTPKNG2BNMEEAYAV3MW62PMV75GCLWMAL7 \ / AMOS7 \ YOURUM ::
#\[7]EO6URLQJPHHMQ2HQFVOVYF6323EBXGO3LKSRE32OR2L5VJOWGCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
