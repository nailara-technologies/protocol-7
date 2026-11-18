---
name: session-handover-release-6-77-7
description: 2026-11-18 afternoon : release AMOS7-v6.77.7, SEGV fix, pri -> zulum, challenge alias, perl 5.44 deps ; all servers deployed clean
metadata:
  type: project
---

builds on [[session-handover-rcm-builds]].

landed + pushed [ hub base ] :
- WEQ 2 0aa738011 ; one unlock per key 75b86f1df ; RCM 1 + 2 406f0048f dc31ffb65
- sign agent own dir \ crash line \ events.log 0383081b5 ; keys rename host pins + known: prefix a12c18db3
- managed challenge alias ecfd024d5 [ nameserv.ensure-challenge-alias, letsencr calls it ]
- SEGV fix 5d85e3f06 : truth fallbacks were calc_true -> bridging wrapper recursion on a cold inline cache
- release AMOS7-v6.77.7 9e39ca6e4 [ tag pushed ] ; base.file.temp File::Path b7234b63a
- p7-deps 6556bac76 : deps after dist-upgrade + apt verified by module load [ worked live : IPC::Shm::Simple -> cpan ]

servers : all four on a0e2b987e [ 6.77.7 + p7-deps fix ], clean starts, 0 missing deps -- 13:15
- deploy : `p7c v7-zenki.start_once :wait-down: pull-git`, deps check, then `p7c v7-zenki.teardown`

open :
- format-code -c passes bin/ scripts using TRUE \ undefined globals [ prelude ] : compile shebang files outside src/ plainly
- base.prng.bytes \ characters \ chars-anum : lazy reseed when init_code has not run [ pm-src build early ]
- sign agent : after a 'changed' abort the approval screen stays up
- v7.ax still at the registrar : our local v7.ax copy mirrors it ; pri alias removed everywhere

lesson : test a deploy on a COLD inline cache, the bridge path never ran locally. cube restart = all zenki reconnect.

#,,,,,,,,,,,,,,,,,..,,...,,,,,.,.,.,.,,.,,,,,,..,,...,...,.,,,,,.,.,,,,,.,,..,
#MPH7WNNLXV4WAPFU5DAVQSRUYYDAUXNH3ZLTAZLEAGQVDQIKKB5IBOFAKYZXL3WZSH5WPYR5SXGYK
#\\\|U44EKSULLRCJTRYGV6RWSF7WLJZAA7NWA4VCGWW2XDI5NAQSKJR \ / AMOS7 \ YOURUM ::
#\[7]YXWMQ4SLDETMVMMYYMFILAQ7DGQ6EDYIC74EUOSGWHJACCQTKCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
