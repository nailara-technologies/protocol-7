# os-pkg \ debian : condensed install log as a STRM reply stream

brief [ 2026-10-02 ]. no defaults left in place : an apt \ dpkg upgrade log
is mostly implicit, repeated context. reformat it into one line per
package, full detail only for failures and anything unexpected.

## what exists

- **debian zenka** : root apt child forked before privilege drop
  [ `debian.start.apt_child` ], serialized install queue
  [ `debian.apt_pump`, `debian.apt_enqueue_install`, `debian.job.apt_install` ],
  per-line output accumulation [ `debian.handler.apt_child_output` : '>' =
  apt output, '< N' = exit code ], deferred reply once apt finishes
  [ `debian.cmd.install-packages` ], `debian.cmd.install-history`
- **os-pkg zenka** : on-demand, configured [ `cfg/zenki/os-pkg/` ] but
  `os-pkg.init_code` is still an empty stub -> the natural distribution-
  neutral frontend, with debian as the first backend
- **STRM replies** exist [ e.g. `channels.cmd.strm-test`,
  `coding.cmd.subscribe-session` ] -> pattern for streaming lines back to
  the caller while the job runs

## condensing rules [ first draft ]

```
Get:N <mirror> <suite>/<comp> <arch> <pkg> <arch> <ver> [<size>]   -> size per pkg
Preparing to unpack .../<pkg>_<ver>_<arch>.deb ...                -> drop
Unpacking <pkg>:<arch> (<new>) over (<old>) ...                   -> old -> new
Setting up <pkg>:<arch> (<ver>) ...                               -> done mark
```

one line per package : `<pkg>  <old> -> <new>  <size>` [ `new` for fresh
installs ]. pass through verbatim : errors, warnings, conffile prompts,
held \ removed packages, trigger failures, anything that matches no rule.
mirror, suite and arch once in a header line.

## work

1. condenser as a pure module [ e.g. `debian.log.condense` ] : lines in,
   condensed lines out, keeps unknown lines verbatim ; tests with real
   captured apt \ dpkg output [ install, upgrade, failure, conffile ]
2. stream mode : `debian.handler.apt_child_output` forwards condensed lines
   as a STRM reply while the job runs, final summary with the exit code
3. `os-pkg.*` frontend : `os-pkg.install`, `os-pkg.upgrade` routing to the
   debian backend [ later other distributions ]
4. shell use : `p7c os-pkg.install <pkg>` prints the stream lines as they
   arrive -> the lightweight frontend for shells and scripts

5. status segment : route the condensed stream into a status region of an
   interactive terminal ui or dashboard [ nshell, ascii-frame \ vterm
   frontends ] -- one line per package fits a fixed-height segment ;
   header line with `n of m packages`, errors raise the segment's
   attention level instead of scrolling past

the custom format is the point [ user ] : nobody else has to parse it, so
it can be designed purely for reading and for the network.

## careful

- never drop an error or prompt line ; when in doubt, pass through
- keep the raw log too [ history \ forensics ], condensed is only the view

#,,..,..,,.,,,..,,.,,,,..,,..,,,.,.,,,,,,,..,,..,,...,..,,..,,...,,.,,,,,,..,,
#HKUOXWG3A5ODFIZJG5ACL4D3OYLDCNWL4ZW77N23BA5K2DASXY6P3VTDGEWKAMC2LRQJNSQJTZSAE
#\\\|3WWRRBDBLJ4REJYUOQUSC2BXY222ZC5LBATENOB2R4CF3GG2FIB \ / AMOS7 \ YOURUM ::
#\[7]NHABHLGE7VICGWOGQFUZO4UHAHKHZU27ODS2GTDIWNHTV4JC5GDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
