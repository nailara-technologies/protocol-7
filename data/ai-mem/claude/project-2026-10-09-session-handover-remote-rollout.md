---
name: project-2026-10-09-session-handover-remote-rollout
description: handover of the 2026-10-08 -> 09 session [ 6a16dfa32 .. 30a688058, pushed ] -- remotes upgraded + host-root pinned [ both remotes ], perl floor 5.32 with a floor-perl check, yaml wrappers everywhere, letsencr auto-enrollment [ staging first ], form \ host-edit ui fixes, signature fragment cleanup + :strip: ; next = first real enrollment
metadata:
  type: project
---

previous : [[project-2026-10-08-session-handover-host-setup]].

## landed [ base ]

- **perl floor 5.32** : `bin/Protocol-7` `use v5.32.0` [ a 5.28 sweep showed the code
  already needed 5.32 ]. `bin/format-code -c` \ `bin/dev/ptd -c` also compile with the
  floor perl [ `~/.local/perl-5.32.1`, errors tagged `[ perl 5.32 ]` ] -- see
  [[sweep-src-with-remote-perl]]. chained comparisons are welcome.
- **logger** : base.logs \ log.fmt lost a passed `$EVAL_ERROR` [ aliased @ARG cleared by
  the inner eval, ~130 call sites ] -- fixed.
- **yaml** : 82 modules on `format.yaml.load_str` \ `load_file` [ decoded text broke
  YAML::XS ; load_str encodes first ] ; format.yaml in 13 more zenki's modules.load.
- **letsencr** : repeats vhost discovery once httpd is online [ v7-zenki.notify_online ] ;
  only FQDN vhosts become domains, no implicit www alt name ; one log line per result ;
  **automatic enrollment** [ 4a3e42c0b ] : discovered domains w\o cert [ or
  cfg.enroll_domains ], dns + http-01 self-test in the CHILD, async [ deferred reply ],
  2 per check, backoff 1 h .. 24 h, 'pending' guard, state `enroll-state.json` ;
  `cfg.enroll_staging = yes` -> staging server + separate account, staging certs NOT
  installed ; renewals stay on production. VERIFIED live on staging [ zenki.v7.ax via
  `install-vhosts :nocert:` : discovery -> dns -> async self-test -> staging cert ] ;
  default since then `enroll_staging = no` [ production ].
  an EXPLICIT request [ install-vhosts 'tls: yes', api, httpsd -> letsencr.parent.cmd.
  request-certificate ] claims the domain in enroll-state [ 'explicit' ] -> auto skips it,
  no double order ; `install-vhosts :nocert:` leaves a vhost to auto enrollment. auto
  covers what the explicit path misses : letsencr started after http[s]d, 'deferred'
  requests [ httpsd offline -- never retried ].
- **host-edit \ form** : add-host flow works live [ event.add_timer, not base.event ] ;
  fixed 'host actions' row + 'action state' row ; status line on its own row ; frame
  capped at the terminal width [ form engine ] ; Ctrl-C in tab mode ; Enter opens a tab
  row [ Right still works ] ; trust \ owner trust render LIVE ; a host-named record dials
  its name when it has no address ; add host uses the form's unsaved values ;
  'since 0' shown as no date [ since = owner-certified not_before, not a pin date ].
- **jobs.vhost** : notes were pushed to the wrong jobs by browser form restore
  [ autocomplete off + focus guard ] ; local note \ date overlays expire like stage.
- **remotes** : both upgraded, clean start, each host-root pinned from host-edit through
  the ssh forward ; the pins equal their `p7c host-root-id`.
- **signatures** : 56 files carried agent leftovers above the real footer [ lone
  separator, PLACEHOLDER line \ block, '</content>' ] -- stripped with one ncode pattern
  [ ed8f5e06d ]. the rule lives in `AMOS7::Protocol::P7Syntax p7_syntax__sig_fragment_rx` ;
  `update-signatures` reports fragments, `:strip:` removes them, the pre-commit hook warns
  [ not blocking ] ; AI-COLLABORATION-GUIDE names every variant [ 30a688058 ].
- **tests** : `test-form-stdin-key.pl` [ kimi, 29 : tab-row entry, plugin keys, ctrl-c ],
  `test-form-width-cap.pl`, `test-letsencr-enroll.pl` [ 74 ], host-edit flow \ records \
  actions-tab extended.

## lessons [ see their own memories ]

- [[route-send-buffers-timer-gets-event]] : route-send only buffers until the loop runs ;
  timer handlers get the event ; event.* not base.event.* -- stub tests hide all three.
- [[amend-env-and-unsigned-files-staging]] : web-root pages \ new test files are unsigned
  -- stage them myself ; check `git status --short` for ' M' before every commit.
- kimi reviews : both k2.8 and k3 runs needed real fixes [ cursor offset, async
  self-test, timer data ] -- always review kimi diffs line by line and add the test
  that would have caught it.
- [[search-existing-paths-and-history-first]] : enrollment was built while three
  request-certificate callers already existed [ the user found them ] ; a stray line was
  blamed on the sign tool while the file's own history showed it predated the edit.

## next

1. first PRODUCTION enrollment after the pull : the issued-staging domains become
   candidates again -> watch `:: letsencr.status` for the installed certs.
   a dev box behind nat also probes every vhost [ self-test protects, but it fetches
   from third-party hosts like wpad.net ] -- candidates : a `cfg.enroll = no` switch,
   httpd.vhost-list without pattern vhosts \ *.bak-* dirs.
2. pull on both remotes : they run the version before the enrollment claim, the form
   key changes and `:strip:` [ check the zenka STDOUT log afterwards ].

#,,,.,.,.,,.,,..,,..,,,.,,..,,,..,.,.,,,,,...,..,,...,...,,.,,,,,,,..,,,,,...,
#WOHTFNJVZCSTCU7PWYQSVFZC2JMIG5DW5NUVWMKQ6CL2YVNTNA4PELF5HQX6N7NNREIMRUQTTJQEI
#\\\|FASQ4LR4MUNFIOHXMZ45KT7EJ3XR756ZBFP7O5GPV3VLJN6PYAZ \ / AMOS7 \ YOURUM ::
#\[7]7OHIJ424ZLNA7NFJSUT7QM2WP56XTFB54AWBBYUFYNHOEJO54IAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
