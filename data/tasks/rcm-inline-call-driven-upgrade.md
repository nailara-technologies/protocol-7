# RCM : inline C call-driven upgrade [ kimi task spec ]

todo RCM follow-up, after c236fa2cc [ reproducible builds ] + f19723b81 [ race-free builds ].
file : data/lib-path/pm/AMOS7/INLINE.pm [ compile_inline_source, _build_slot, _publish_build ]

## problem

compile_inline_source builds in line : a missing object blocks the caller for the
whole gcc run [ or up to $build_wait_seconds = 120 on a busy lock ], then falls back
to pure perl for the life of the process. a process that started pure perl never
gets the compiled routine.

## goal

1. no blocking build : when the object is not published, install the pure-perl
   fallback AT ONCE and start the build detached [ fork + setsid, child runs the
   existing _build_slot \ Inline->bind \ _publish_build path, then exits ]. no
   fallback defined : keep today's blocking path.
2. call-driven upgrade : the installed sub is a thin wrapper ; on a call it checks
   [ cheaply, rate-limited : not a stat per call -- use base.interval-style growth,
   first check short ] whether the object got published, then loads it with
   Inline->bind against the published dir [ load only, no build ] and swaps the
   glob to the compiled coderef. after the swap the wrapper is gone : zero cost.
3. compiler time limit : the build child gets a hard limit [ alarm + kill of the
   compiler process group ] ; default 77 s, `our $build_time_limit` [ only guards a hung compiler : the build is detached, these sources compile in seconds ].
4. host build cap : at most N concurrent builds per user [ default 2 ] via slot
   lock files next to the object dirs [ O_NOFOLLOW, owner check as _build_slot ] ;
   no free slot : stay pure perl, retry on a later call.
5. pre-build in two places, both calling one shared entry : v7-zenki next to its p7c \ p-7-r recompile segment, and bin/p7-deps install \ p7-install for standalone scripts. a step that compiles every
   registered source [ walk $source_registry ] in the foreground -- reuse
   compile_inline_source, no new build code.
6. prune : remove object dirs in the parent whose name has the old 2-part form
   [ <sub>.<chksum> without the toolchain key ] and dirs of other toolchain keys
   older than 13 days ; only dirs owned by this user, never follow links.
7. trust by checksum [ INLINE-OBJECT-TRUST.md, attested binaries ] : publish only
   after the object checksum is taken ; key holders load only an object whose
   checksum is on a signed list -- the list is a later slice : build the loader
   side now [ list absent -> key holders stay pure perl, others warn on
   unverified ]. reproducible builds [ c236fa2cc ] make an on-demand build
   verifiable, no matter who built it

## constraints

- keep RCM security : force_pure_perl processes [ p7-sign-agent, sourcecode ]
  never fork a builder and never upgrade.
- a zenka forks : the upgrade must work in a child that inherited the wrapper.
- the build child must not run END blocks \ DESTROY of the parent : POSIX::_exit.
- floor perl 5.32 [ bin/format-code -c checks it ].
- no sha, no json. style : CLAUDE.md [ lowercase comments, [ ] not ( ) ].
- do not touch files you did not change, never git restore \ checkout.
- tests : extend the existing INLINE tests [ find them ] : fallback-first, upgrade
  after publish, time limit kill, cap reached, prune skips foreign \ linked dirs.

## settled with the owner 2026-11-18

- time limit 77 s [ not a round 60 ], cap 2
- pre-build : v7-zenki [ beside p7c \ p-7-r ] + p7-deps install \ p7-install
- user-writable objects stay : that is what makes inline code transparent ; the
  sensitive processes already run pure perl. not part of this task

#,,..,,..,,,,,.,.,..,,,,.,.,,,...,,..,,..,...,..,,...,..,,..,,,..,...,.,.,.,,,
#A26VOOVK5UO56E3TH6BFJWSH5GUUV363SFVE56HNKGABA46PXSA4SPNO67IFDKIYJU3OK7T5SBHMA
#\\\|UWVSUXLVFWPVSEOGQHI4325VAPR7GTBSZ4CSI5S3HB43HCSP56Q \ / AMOS7 \ YOURUM ::
#\[7]6E5FQ3XT2CKHE4SZTHVAQ23ZEGMGTLWUAHCHGUKM3WM5GVE5JEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
