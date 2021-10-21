
# [ [nailara 'protocol seven' project](http://nailara.network/) ]

### [ source code version : ZLQZP6WYNA-4962.0 ]

### this is the public domain [license](read-me/license)d 'base' branch
---
## current [release](https://github.com/nailara-technologies/protocol-7/releases) \\\\// [AMOS7-v2.47.0](https://github.com/nailara-technologies/protocol-7/releases/tag/AMOS7-v2.47.0)
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
[binary](bin/c_src/p7c.c) written in C that can run single network commands
and return their output.



<!--

#,,..,.,.,...,,..,..,,,,,,,,,,.,,,,..,..,,...,..,,...,...,...,.,,,...,..,,,,.,
#R7K7W4GPJKLS6PCRP4G2QMITTSQ5MDSH4RO347NLFT27VGQ32TG66DXSKQIWT556XIZK57AWT5ZG4
#\\\|QGA35E62O65IM5UW4LX3G5RLSFCWSMQF53NY46JYRD3TMCKTGEJ \ / AMOS7 \ YOURUM ::
#\[7]FLWEXXSRDOGFD5QI2HBB7ABQMIDTDVI6UAAJZALMMZ6OKFMTAKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
