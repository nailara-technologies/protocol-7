
# [ [nailara 'protocol seven' project](http://nailara.network/) ]

### [ source code version : 2KVZBPFPLI-5077.0 ]

### this is the public domain [license](license)d 'base' branch
---
## current [release](https://github.com/nailara-technologies/protocol-7/releases) \\\\// [AMOS7-v2.79.7](https://github.com/nailara-technologies/protocol-7/releases/tag/AMOS7-v2.79.7)
---

the protocol 7 framework is a multi agent system written in perl. it is not
documented yet. there are a a number of key features still being implemented
after which it will be more useful to the general public. once these are
committed there will be a website with use case examples and descriptions
of how it works and how to install and operate protocol-7 systems.


in short, there is an interpreter like program called
[Protocol-7](bin/Protocol-7) which can read description files in
[configuration/zenki](configuration/zenki) either from stdin or by name
as command line parameter. they describe what kind of 'zenka' it will become
and it then loads the appropriate [modules](modules) and executes the
callbacks in these 'start' files. there are already a lot of agents [zenki]
implemented and functional. one of them
[['cube']](configuration/zenki/cube/start) can route messages between the
others, the ['v7'](configuration/zenki/v7/start) zenka can start others
and manage them [it would usually be
[started](data/lib-path/systemd/system/Protocol-7.service) first].
there are many more performing all kinds of tasks and even graphical frontends
like one that controls the ['mpv'](configuration/zenki/mpv/start) video player
or a [optionally] self-scrolling
[web-browser](configuration/zenki/web-browser/start) which can be controlled
from other zenki.

the protocol itself is human readable and there exists a
[terminal](bin/nshell) program for interaction with it and a
[binary](bin/c_src/p7.c) written in C that can run single network commands
and return their output.

The ultimate project goal is to pool existing idle ressources present in
todays networks and offer them back to its users with low latency and a lot
of burst capacity, much like a supercomputer would, but based on advanced
peer to peer technology. it would be a global marketplace that values and
utilizes ressources in realtime based on what is required the most at any
given time and in which workloads exist that are interesting to users and
operate autonomously on their behalf.

after the network is saturated with what it needs to maintain a stable
topology, a kind of overflow becomes available that is then distributed
equally to the individual users. not only can this even generate a form
of basic income each user would receive but also support content creators
based on the interests of their audience as a whole.

one can imagine this like the flow of water irrigating farm land where
each field of interest receives enough water to grow all kinds of plants
and compensate for time and effort invested into creativity.

taking part will be as simple as connecting a hard disk to the network,
acquiring ressources using crypto currencies or creating and sharing
something that is of interest to others.

the overflow principle also makes it possible to maintain public
ressource pools available to those who are just joining or had nothing
to offer yet, so that there are no barriers to the global community
for who can profit from the practical wealth that exists in the so far
not utilized idle capacity.

it will easily prove our possibilities to be limitless. it is all a
matter of algorithms and protocols. hardware and connectivity we
already have.


<!--

#,,..,.,.,.,.,,,,,...,.,.,,,,,,.,,..,,...,,,,,..,,...,..,,.,.,.,.,,,,,,..,.,,,
#5TGCAF42YIEY67HGMW7A44QNWFX6Q3WIHGTATLGUX2S2X2YKVUAD6ICMSXI2FIVRRXCNWTALAVM76
#\\\|GZRMEYDV67KNUUBEAMYSQP6XI2QEPDCJSHGYQMEZDM56VQJ2HNH \ / AMOS7 \ YOURUM ::
#\[7]UOHMQYFGHIEIOVDAMNI6FRHJNA2FQ4364N6IIOXV6ITGYG57SYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
