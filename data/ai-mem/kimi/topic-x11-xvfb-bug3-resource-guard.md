# X-11 xvfb-start bug 3 resource guard — implemented 2026-08-28

Implemented the `xvfb_resource_available` dependency callback and wired it
into `X-11.cmd.xvfb-start` per `data/tasks/x11-xvfb-start-async-refactor.md`.

Files changed:
- `src/X-11.callback.object.xvfb_resource_available` [new] : checks that
  requested width/height are nonzero and <= 4096 and that the framebuffer
  size (WxHxbytes-per-pixel, with 24-bit treated as 4 bytes) plus 128 MB
  overhead fits in `/proc/meminfo` `MemAvailable`.
- `src/X-11.cmd.xvfb-start` : get-or-create a self-chained
  `xvfb_resource_available` dependency object per geometry, mirror of
  `coding.task.ensure_model_pinned`. The `start_server` job keeps its
  `object_id => 0` (bug 1 fix); the new check is a synchronous pre-queue
  rejection, not a job dependency gate.
- `src/X-11.job.start_server` + `src/X-11.handler.display_poll` : added
  diagnostic timing logs around `open()` spawn, `report_child_pid`, and
  `X11::Protocol->new()` to help pinpoint the bug 2 stall in a future
  controlled live test. No signal-based timeout and no live test performed.

Lessons reinforced:
- Use `base.logs` (sprintf wrapper) for multi-arg log calls.
- `TRUE`/`FALSE` are `5`/`0`.
- New source files must NOT include a placeholder signature footer; the
  human runs `bin/Protocol-7 sourcecode update-signatures` separately.
- `ptd -c` is the correct syntax validator, not `perl -c`.

Bug 2 (blocking `X11::Protocol->new()` connect stalling the Event.pm loop)
remains unfixed. The next step is a controlled live test with verbosity
bumped, using the new timing logs to identify whether the stall is in
`open()`, `report_child_pid()`, or `X11::Protocol->new()`, before any
signal-free non-blocking connect refactor is attempted.

#,,..,,,.,.,,,..,,,..,,..,.,.,..,,,,.,,..,.,.,..,,...,...,.,.,.,,,,..,,..,...,
#GA6HESAVI5SMZCSU4UFC56CFCVAVYRV372AS2ZGEDS2Z4ZE6ZCA34QYKUL2AXN5VUFTRTYRDITHBK
#\\\|OO42PW7QVIMBUA5WTQZGN22MOSVNWC7VLXMKPFFD37BTTPXCFQS \ / AMOS7 \ YOURUM ::
#\[7]S6A7GWTWUDQKZ2JSCYKFFD3WJGMQDJDX5OGUJ253SSGUIVX7KSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
