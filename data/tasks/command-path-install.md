# command path install : bin/, bin/admin/, bin/dev/ into the path, by role

status : brief, not dispatched [ 2026-11-19 ]. builds on
data/tasks/p7-deps-service-pm-src.md [ install-service, launch symlinks ],
src/v7-zenki.install_zenka_symlinks [ p7-<zenka>, '::' links, own links only ],
src/v7-zenki.compile_bin_p7c, bin/p7-install [ steps 1-7 ].

## problem

- only the launchers [ Protocol-7, nshell, p7c, p7-<zenka>, '::' ] are linked today ;
  the tools in bin/, bin/admin/ and bin/dev/ are callable by full path only
- /usr/local/bin is not in root's default path after installation on every host and
  login form -- links there are not enough for root

## shape

1. one declaration [ p7 config style, e.g. cfg/install/commands ] : per command its role
   and optional dependency profile ; commands not listed stay internal
   - bin/        -> role 'admin' or 'all' per entry
   - bin/admin/  -> role 'root'
   - bin/dev/    -> role 'dev' [ developers only ]
2. one directory per role, the installed links only : e.g.
   /usr/local/lib/protocol-7/path/{all,admin,root,dev}
3. path setup that works for root too : /etc/profile.d/protocol-7.sh adds the role
   directories a user may use [ group membership : p7-admin, p7-dev ; uid 0 -> root +
   admin + dev ] ; root's own shell rc gets one sourcing line if its login form does not
   read profile.d. sudo : secure_path is not touched, a hint is printed instead
4. verify, do not assume : after installing, check with a fresh login shell per role
   [ 'su - <user> -c command -v <tool>', root included ] and report what is not
   reachable, with the reason
5. who installs :
   - first install : p7-deps install-commands [ root, before the first start ] ;
     p7-install calls it as a step of its own
   - kept current : v7-zenki at each start, like install_zenka_symlinks -- new commands
     appear, removed ones disappear, only its own links are touched
   - both use one shared AMOS7 module for the link logic [ like AMOS7::Config ]
6. two profile types, kept apart :
   - command profiles : WHICH commands belong together [ e.g. admin-base, power,
     rescue, dev-tools ], each with its dependency profile -- a command whose
     dependencies are not installed gets no link
   - target profiles : WHERE and HOW they are mapped on a host [ role directories, link
     names \ aliases, path setup form, which users \ groups ] -- e.g. a server, a
     desktop, a minimal appliance
   a host combines both : the command profiles it enables, mapped through its target
   profile. the same command profile maps differently on a server and on a desktop
   without being duplicated

## syntax : reuse cfg/p7-file-permissions

the target profile uses the line form of cfg/p7-file-permissions [ restore_permissions ] :
flags [ C create if missing, L links only, D \ F, R recursive ], octal mode, u:<user>
g:<group>, then `path --> <:link-target:>` -- it already describes links [ e.g.
`CL --> bin/Protocol-7.gtk3 --> Protocol-7` ]. a role directory and its links are then
ordinary entries, e.g.

    DC 750 u:root g:p7-admin  -->  /usr/local/lib/protocol-7/path/admin
    CL                        -->  /usr/local/lib/protocol-7/path/admin/ncode  -->  bin/ncode

the reader is bin/admin/restore-permissions [ standalone perl, -n \ --check dry run,
-v ] -- its line parser moves into the shared AMOS7 module, the tool keeps working on it.
the tool already had an optimization run [ fewer passes over the tree, in-memory
normalizer 98cec1c01, net-change-only reporting 1f7dfebac ] : moving the parser must keep
that -- same pass count, same reported changes before \ after on a test tree.
the files themselves are read through AMOS7::Config::Reader [ sources + layers : inline <
disk < host ] -- paths come from the one definition, not from the tool, and the same
profiles can later ship as inline cfg/ entries.
one parser for both files ; the open item noted there [ glob \ wildcard support ] is
needed here too [ a whole command profile as one entry ] and lands once for both.

## rules

- symlinks into the checkout only, never copies ; replace only links that are own links
- idempotent, every step reports ok \ set \ changed \ failed ; -dry-run reads only
- p7 config style, no json ; perl 5.32 floor

#,,,,,,..,,.,,.,,,...,,.,,,,.,..,,,,.,.,.,.,.,..,,...,...,...,...,,.,,,..,,..,
#YT546W4FKILQDOBTVGONLG2ZVCYV47WHRXHYTUURZEAHMTVOJKTCMNC7LFHB4HLD2ENB5LGOXW7I4
#\\\|X2YUGQDTF7EVSICBEHVPFAGJ3PECOIUKPEV6TXQAKA36NIZWDDI \ / AMOS7 \ YOURUM ::
#\[7]YEABFWWFXRUDLDXYJJ4IC7SVPDNGDASDZ6LJU3YVCWYLXV765OAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
