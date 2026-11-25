## watcher registry : signals from watched processes, files, logs -- local first, then across hosts

owner direction 2026-11-25. completes data/tasks/claude-zenka.md item 8 [ sessions started by
signals ] : standalone tools [ n7fs place ] raise no signal ; a watcher does it for them.

### stage 1 : the registry in the system zenka

the system zenka polls processes and resources already [ system.process.handler.collect_table,
the memory guard, the disk poll ] -- the watcher uses that data, no new polling.

    system.watch-add <id> <kind> <pattern> signal=<name> [ key=value .. ] [ once | repeat ]
                     [ unless=.. ] [ valid-until=.. ]
    system.watch-remove <id>      system.watches

kinds :
- proc-exit  a process matching <pattern> [ command line regex, user ] ends -> the signal carries
             rc, runtime, pid [ e.g. n7fs place ends -> place.complete rc=0 ]
- proc-start a matching process starts
- file       a path appears \ changes \ grows past a size
- log        a new line in a log matches a pattern
- threshold  a value from the system table crosses a limit [ up \ down ]

signals go through events.signal [ buckets, reminders, notify, parked sessions hang off them ] ;
grants in cfg/zenki/events/access.signals [ events.signal.system = .. ]. registry native, in the
system zenka's dir, survives restarts ; `unless=` \ `valid-until=` as for reminders [ persistence
follows reality ].

### roles : the system zenka detects, the events zenka routes [ owner ]

the system zenka only watches and raises ; it knows nothing about channels. the events zenka is
the hub for every signal [ buckets, reminders, notify, session starts ] and in stage 2 also for
the CHANNELS : it picks the path to another host, receives remote signals, checks them against
access.signals [ with a host part ], drops duplicates. one place for transport -- every source
[ system watchers, usage thresholds, claude \ kimi runs ] gets it.
refined [ owner ] : the CHANNELS zenka exists and is the transport -- subscriptions
[ channels.subscribe \ unsubscribe \ update \ channels-since, subscription.manager ] and cross-host
sync [ memory-sync.publish \ fetch \ batch-send \ conflict-resolver \ register-watch ]. so :
1. sources [ system, usage, claude \ kimi ] raise clearly translated signals
2. the events zenka applies its rules and access ; what must reach another host it PUBLISHES
   to a channel, and it subscribes to the channels meant for it
3. the channels zenka carries : delivery over the available path, `since` to catch up after an
   outage, conflict resolution. the paths [ p7 link, discover, DNS, UDT ] live there, for every
   publisher -- the events zenka needs no transport logic of its own.
the transports are REGISTERED backends of the channels zenka [ owner ; the plugin pattern of the
events zenka's sources \ actions ] : p7-link [ authenticated links, reliable ], discover [ the
discover zenka's LAN announcements, no link, local reach ], dns [ nameserv, registered expected
events, across networks without an open link ], udt [ later ]. each declares reach, needs-link,
latency, confirmed delivery ; the channels zenka picks one per message or several as fallback,
the receiver drops duplicates. a new transport is one more registration.

### stage 2 : across hosts, independent of transport [ in the events zenka ]

an expected event names its host [ `place.complete@azurum` ]. the transport is picked by what is
there, the receiving side sees the same signal whatever the path :
1. native protocol-7 [ p-7-r ] where a link exists
2. discover zenka announcements in the LAN
3. a DNS based channel through nameserv for registered expected events [ works without an open
   link ; data/tasks : nameserv ]
4. UDT once it is ready

### open

- which hosts may raise which remote signals [ access.signals gets a host part ]
- duplicate suppression when two paths deliver the same event

#,,..,.,.,,,.,.,,,,,,,..,,,,,,..,,,.,,...,...,..,,...,...,.,.,..,,,.,,,..,,,,,
#F4LTVEGLIKBPKBEXMUG4YNJPME4OCT4ZJVFWKYBY36QPGPDMNKYYMNGFHHZAFPASU6LQU26R55HS2
#\\\|MKEZCTROHXZJVVFECU56WCLDOUDXLNYNKC23PFX4G5FIDVM2HO6 \ / AMOS7 \ YOURUM ::
#\[7]T2HBJ2QUOFIHLBWECAAHQLVCXGOKW3BOI3IZ4WZEBRAEBRF2MCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
