# sys-deps auto-install, stage 1 : a zenka start waits for its dependencies

the servers upgrade themselves at night ; a dependency a zenka declares but
the host lacks must be installed before that zenka starts -- on every start
path, without blocking v7-zenki. this extends what exists ; it replaces
nothing a host relies on while the feature is off.

## what exists today [ read these first ]

- `src/v7-zenki.check_zenka_deps` : probes a zenka's declared deps
  [ `AMOS7::deps::module::scan_zenki_pm_deps`, `AMOS7::deps::os_package::
  scan_zenki_os_deps`, probe_module \ probe_os_pkg \ probe_binary ] ; with
  `<v7-zenki.cfg.auto_install_deps>` [ default no ] it resolves them
  [ `AMOS7::deps::module::resolve_install` + `load_known_deps` ] : apt
  packages ASYNC via route-send `debian.install-packages` [ reply :
  `src/v7-zenki.handler.deps_install_reply` ], cpan modules SYNCHRONOUSLY
  via `base.perlmod.install_cpan_module` [ blocks v7-zenki for minutes ].
  tracking : `var/sys-deps/tracked.yaml` [ the same block exists twice ].
- `src/v7-zenki.autostart_zenki` : its ONLY caller -- on-demand, start_once
  and manual starts [ `src/v7-zenki.zenka.cmd.start` ] never check deps.
  and the job is queued at once : the zenka starts while apt still runs.
- **start conditions - the mechanism to use** : a job waits in the
  'depending' queue while `base.dependency.ok_resolve( $obj_id )` is false.
  condition TYPES are found by name [ `src/base.dependency.install_callbacks`
  ] : `v7-zenki.callback.object.<type>` = the check [ TRUE \ FALSE ],
  `v7-zenki.resolve.object.<type>` = the hook start paths call on an unmet
  check. precedent : `src/v7-zenki.callback.object.unix_group` [ unmet ->
  `<[v7-zenki.condition.recheck_later]>` re-checks after 5 s ] and
  `src/v7-zenki.resolve.object.zenka`. chains are built in
  `src/v7-zenki.set_up_zenka_dependencies` [ a `<type>.<name>` entry gets
  its object on first use ]. `jobqueue.check_dependencies` releases jobs.
- debian zenka apt queue - **the precedent for cpan** : `src/debian.cmd.
  install-packages` -> `src/debian.apt_enqueue_install` ->
  `src/debian.apt_pump` -> `src/debian.job.apt_install` [ the root apt
  child, names sanitized right before the shell ] -> `src/debian.handler.
  apt_child_output` [ deferred reply when apt-get finishes ].
- `cfg/zenki/cube/access.zenki` : `access.cmd.usr.v7-zenki` lists
  `debian.install-packages` -- v7-zenki may only call what is listed.
- tests : `bin/test-scripts/test-dependency-resolve-hook.pl` [ the
  resolve-hook harness - start from it ].

## what to build

1. **condition type `sys_deps`** [ object name = the zenka name ] :
   - `src/v7-zenki.callback.object.sys_deps` : state per zenka in
     `<v7-zenki.sys_deps.state>->{<zenka>}` :
     - feature off [ `auto_install_deps` false ] : TRUE, always.
     - no state yet : probe [ the cached scan, see 3 ] -> 'ok' or 'missing'.
     - 'ok' -> TRUE. 'missing' \ 'installing' -> FALSE +
       `<[v7-zenki.condition.recheck_later]>`.
     - 'failed' -> TRUE, logged ONCE at level 0 with what is still missing
       -- the zenka starts degraded, exactly as it does today. an optional
       module that never builds must not block a zenka forever.
   - `src/v7-zenki.resolve.object.sys_deps` : 'missing' -> start the
     install [ apt via debian.install-packages, cpan via the new
     debian.install-cpan, both async ] -> 'installing'. never two installs
     for one zenka at a time.
   - the reply handler[s] re-probe what was missing : all present -> 'ok',
     else 'failed' ; track in tracked.yaml ; then
     `<[jobqueue.check_dependencies]>`. a route-send failure \ FALSE reply
     -> 'failed'.
   - `src/v7-zenki.set_up_zenka_dependencies` : with the feature on, every
     zenka's chain gets `sys_deps.<zenka>` implicitly [ also zenki without
     a dependencies line ]. off : no change at all.
   - `src/v7-zenki.autostart_zenki` : the direct check_zenka_deps call stays
     only for the feature-off case [ warn-only, as today ].
   - a 'failed' state is retried after `<v7-zenki.cfg.sys_deps.retry_after>`
     [ default 3600 s ] -- not on every start.
2. **cpan async in the debian zenka** : `debian.cmd.install-cpan
   <Module::Name>...` through the SAME serialized queue as apt [ one
   install at a time across apt and cpan ], `cpanm --quiet --notest`,
   deferred reply when it finishes. module names sanitized right before
   the shell : `^[A-Za-z_][A-Za-z0-9_]*(::[A-Za-z0-9_]+)*$`, anything else
   fails the job. `<system.bin_path.cpanm>` as base.perlmod.install_cpan_
   module uses it. add `debian.install-cpan` to `access.cmd.usr.v7-zenki`.
3. **scan cache** : scan_zenki_pm_deps \ scan_zenki_os_deps once, kept in
   `<v7-zenki.sys_deps.scan>`, dropped on v7-zenki reinit [ init_code gets
   `$reinit` as first argument ] -- not a full tree scan per zenka start.
4. **one tracking helper** : `src/v7-zenki.sys_deps.track` replaces the
   two copies of the tracked.yaml block [ same file format ].
5. **config** : `v7-zenki.cfg.auto_install_deps` keeps default no ; add a
   commented example line + the retry key to `cfg/zenki/v7-zenki/zenka.v7`
   [ or where the other v7-zenki.cfg keys are documented ] ; hosts enable
   it in /etc/protocol-7/v7-zenki/host.cfg [ not your part ].

## rules

- module files : `## [:< ##`, `# name  = ...`, `# descr = ...` ; NO
  `sub { }` wrapper -- the file IS the sub ; args via `@ARG` \ `shift`.
  call modules as `<[module.name]>->( ... )`, data as `<a.b.c>`. a
  `.cmd.` module has `$call` set by the loader [ `$call = $ARG[0]` when
  it is a hash -- @ARG is NOT shifted ].
- event api : `event.add_timer` \ `event.add_io`, never `base.event.*` ;
  handlers get the EVENT [ `$event->w->data` ]. route-send reply handlers
  get ONE hash [ `{ mode, data, params }` ].
- never block v7-zenki : no `system` \ backticks \ `open -|` that waits for
  an install in v7-zenki code. the probes [ module \ binary \ os package
  ] are fine.
- a nested data read before init_modules autovivifies : read early data
  through `( <a.b> // {} )->{c}`.
- comments lowercase, annotations in `[ ]` never `( )`, `##  ...  ##`
  style as in the surrounding files. no copyright \ author \ license headers.
- minimum perl 5.32 [ chained comparisons ok ].
- module files end with a 4-line AMOS7 signature footer starting with
  `#,,` -- IGNORE these lines completely ; new files get them later.
- syntax check every touched file with `bin/format-code -c <files>`
  [ NOT `perl -c` ].

## tests [ the acceptance criterion ]

`bin/test-scripts/test-sys-deps-autoinstall.pl`, modelled on
`test-dependency-resolve-hook.pl` : real src modules, AMOS7::deps probes
and route-send stubbed, timers recorded. at least :

- feature off : the callback is TRUE, no install, no sys_deps in chains
- nothing missing : 'ok', TRUE, no install
- missing apt + cpan : FALSE, the resolve hook sends ONE
  debian.install-packages and ONE debian.install-cpan, state 'installing',
  a second resolve sends nothing
- reply TRUE + re-probe ok -> 'ok', TRUE, jobqueue.check_dependencies run
- reply FALSE or still missing -> 'failed', TRUE [ degraded ], logged once
- 'failed' retried only after retry_after
- route-send failure -> 'failed'
- the scan runs once, again after a reinit
- set_up_zenka_dependencies : with the feature on every zenka's chain
  holds sys_deps.<zenka>, also one without a dependencies line
- debian cpan queue : a bad module name fails the job before any shell ;
  apt and cpan jobs serialized in one queue [ stub the child ]

run it plus `test-dependency-resolve-hook.pl` [ must stay green ] and
`bin/format-code -c` on every file.

## out of scope

- no live installs, no apt-get \ cpanm runs, no zenka starts, no `p7c`,
  no git commits, no signing, no host.cfg edits.
- the bootstrap case [ Event \ CryptX missing before the module system ]
  is stage 2 -- not yours.
- appmgr \ lazy wrappers \ policies : later.
- do not touch files not named here, except new `v7-zenki.sys_deps.*` \
  `debian.*cpan*` modules you need.

## report

new \ changed files, test output [ last lines ], format-code result,
anything you had to decide yourself.

#,,,,,,,,,.,.,,,,,,,.,,,,,.,.,...,,,.,,..,,..,..,,...,...,..,,,,,,.,.,,..,...,
#DUFAATAW3VQ2LMBQLGCSN46FFHCKS5E4JWHO5Y2QA6UPC464HWLFPHLSJ2EPT77ZMS6MJOEGIJBVQ
#\\\|4TV7ZJBDLGB5FU732VESNEI3NF4765PZK7EXSVUOGJLP6NIGK2W \ / AMOS7 \ YOURUM ::
#\[7]7QAOC3MSQM57QAEPRXMOBXCIZAXBSHFTRHFSWK3IFSPGGBFO34DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
