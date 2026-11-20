# UDT feasibility result

## answer

**stock libudt 4.11 is not enough to replace hysteria's loss resilience.**
In this loopback experiment its default congestion control fell behind the
emulated TCP path at 1% loss, and no 64 MiB UDT transfer completed within
45 seconds at 5%, 10% or 20% loss. A useful hysteria alternative therefore
needs a rate-based congestion-control mode that does not treat every loss as
a signal to collapse the sending rate. Forward error correction can reduce
retransmission and head-of-line delay, but FEC alone does not hold a
configured sending rate. The plausible combination is rate-based control
plus optional FEC, not stock DAIMD with FEC as a substitute for rate control.

hysteria itself was not measured here, so this is not a numerical UDT versus
hysteria ranking. It answers the narrower prerequisite: stock UDT does not
provide the required behavior on its own.

## measurements

64 MiB payload, three attempts per cell. Values are medians of completed
attempts. `timeout` means the attempt was stopped after 45 seconds; no
completion goodput is inferred from partial data.

| configured loss | transport | median completion [ s ] | median goodput [ mbit/s ] | outcomes |
| ---: | --- | ---: | ---: | --- |
| 0% | tcp | 0.470 | 1142.818 | 3 complete |
| 0% | udt | 7.346 | 73.079 | 3 complete |
| 1% | tcp | 1.681 | 319.329 | 3 complete |
| 1% | udt | 43.128 | 12.448 | 3 complete |
| 5% | tcp | 6.092 | 88.128 | 3 complete |
| 5% | udt | not completed | not completed | 3 timeout |
| 10% | tcp | 12.691 | 42.304 | 3 complete |
| 10% | udt | not completed | not completed | 3 timeout |
| 20% | tcp | 25.532 | 21.027 | 3 complete |
| 20% | udt | not completed | not completed | 1 connection lost, 2 timeout |

The full attempts, including unfinished elapsed times and failure status, are
in `results.tsv`.

## UDT perfmon counters

These are client-side cumulative counters read after the final acknowledgement.
Each value below is the median of the three completed runs. Send and receive
rates are libudt's own `mbpsSendRate` value, not the wall-clock goodput above.

| configured loss | rtt [ ms ] | send rate [ mbit/s ] | sender loss events | receiver loss events | retransmits |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0% | 86.568 | 77.052 | 112 | 0 | 112 |
| 1% | 84.012 | 13.161 | 7560 | 0 | 1405 |

The nonzero retransmits at configured 0% show that concurrent loopback runs
also experienced host scheduling or socket-queue loss. They are retained as
measured rather than presented as a clean zero-loss network. Final perfmon
snapshots do not exist for interrupted attempts.

## binding

`lib/UDT/Simple.pm` uses the repository's existing `Inline->bind` approach.
`Inline::C` 0.82 and `g++` were already installed. The C++ headers remain
outside an `extern "C"` block; only the small wrapper functions have C
linkage. The module links to the installed libudt 4.11 and keeps Inline's
cache under this directory.

Only startup, cleanup, stream socket creation, loopback bind, listen, accept,
connect, send, recv, close, last-error code and description, and perfmon are
exposed. Perfmon includes RTT, sender and receiver loss totals, send rate and
retransmits. This is a procedural feasibility binding, not a drop-in object
API for the old scratchpad scripts or a production transport integration.

## method

- `udp-loss-relay.pl` forwards datagrams in both directions, delays each by
  40 ms and independently drops the configured percentage in each direction.
  Loss is random by default. `--burst N` instead starts bursts of N dropped
  datagrams with adjusted trigger probability. A separate 1 MiB burst-4 smoke
  transfer completed successfully.
- `tcp-stall-relay.pl` adds 40 ms delay to relayed chunks. At the configured
  probability it adds a 120 ms stall and holds later chunks behind that stall
  to approximate in-order head-of-line blocking.
- `benchmark.pl` transfers 64 MiB in 64 KiB stream writes, correctly advancing
  after partial writes. The receiver acknowledges exactly 64 MiB; elapsed time
  ends after that acknowledgement and includes relay and process setup.
- All listeners and targets were loopback-only. Three attempts for all five
  loss levels ran concurrently for one transport at a time, with a 45-second
  per-attempt cap. This bounded the experiment but adds CPU scheduling and
  queue contention, especially to the 0% UDT baseline.
- libudt defaults were used: no buffer tuning, custom congestion controller,
  FEC, rate cap or encryption. TCP used the host's normal stack settings.

A representative single case is:

```sh
bin/dev/udt-feasibility/benchmark.pl --transport udt --loss 1 --runs 3
```

`--transport tcp`, `--loss 0,1,5,10,20`, `--burst 4` and `--timeout 45` select
the other modes. The default output is `results.tsv`.

## limits

- TCP datagram loss cannot be dropped in an unprivileged userspace relay. Its
  loss column is a probability of 120 ms stalls, not an equivalent packet-loss
  rate. The TCP rows are therefore a delay/head-of-line comparison, not a
  controlled TCP retransmission benchmark.
- Concurrent attempts and loopback do not model a WAN bottleneck, competing
  flows, policing, NAT or real internet queueing. UDT's slow-start and the
  relay's per-direction loss both affect these bulk-transfer results.
- A 45-second cap establishes failure to finish within the test budget, not a
  final rate or an estimate of eventual completion time.
- One deterministic unidirectional stream with a final acknowledgement does
  not measure interactive latency, message mode, multiple STRM channels or
  external-link integration.
- No direct hysteria sample was taken. Claims about its configured-rate
  behavior come from the task premise, not from this experiment.

## maintenance consequence

Upstream's newest listed SDK is 4.11, released in February 2013
[upstream release listing](https://sourceforge.net/projects/udt/files/udt/4.11/).
Distribution packages still carry build and packaging fixes; the installed
Debian package is 4.11+dfsg1-2, but that is not a new upstream protocol or
congestion-control release.

Depending on it for production means accepting a small, old upstream with no
recent feature maintenance. The binding surface here is deliberately small,
but a production decision still needs a security and compiler-warning review,
a pinned source/package plan, and an owner for future fixes. That maintenance
burden is additional to implementing and validating a custom rate controller.

libudt does expose a C++ `CCC` extension point. Its installed documentation
includes a pure-rate example using a fixed packet sending period and a large
congestion window, so a rate-based experiment does not require replacing the
whole transport library.

## open points

1. Implement a bounded rate-based `CCC` experiment and test whether it can hold
   a configured rate without causing unbounded retransmission delay.
2. Add FEC only after that baseline, measuring overhead and recovered loss
   separately from congestion control.
3. Repeat sequential and real-link tests against hysteria and kernel-observed
   TCP loss; include smaller interactive transfers and multiple streams.
4. If integration proceeds, design the production object/nonblocking adapter
   separately. The old `UDT::Simple->new` scratchpad API is not implemented by
   this minimal binding.

## review notes [ 2026-11-20 ]

read the numbers as a direction, not as values :

- the tcp column never lost a packet -- loss was emulated as stalls, so tcp looks better
  than it would on a really lossy link
- the runs overlapped [ to bound the run time ] and disturbed each other
- 73 Mbit/s for udt at 0 % loss on loopback points to the set-up [ the perl udp relay,
  default buffers ], not to a udt limit
- hysteria itself was not measured

what holds : stock udt 4.11 backs off on loss and collapses at 5 % and above -- it is no
replacement for hysteria's resilience on its own. the open choice is udt with an own
rate-based CCC [ on a library without upstream releases since 2013 ] versus a native p7
udp transport with rate control and fec. the next useful measurement is a sequential
run on a real link between two servers, against hysteria, not more loopback runs.

#,,.,,,,.,,,,,...,,..,,.,,,..,,.,,,,.,,..,..,,..,,...,...,,..,.,.,.,.,..,,..,,
#W6Q5NCNLFCTH7MOZVVXPXA72QVLRS6L2Q5FONNGM4D65WU44MPS776IM3ZBUA4IRMSWCZISGYAIKS
#\\\|N2UZBQ3DDSRUAYYOY4FILREZOZ67KT6JGZQULY354NQ7OGX7QYT \ / AMOS7 \ YOURUM ::
#\[7]UTPIMKE2CLBHHR7VS5MO5P4FL5XYLQJBX7Q3AX5GDDIBQERG7EDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
