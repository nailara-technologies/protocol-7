---
name: session-handover-release-6-77-7
description: 2026-11-18 afternoon : release AMOS7-v6.77.7, SEGV fix, pri -> zulum, challenge alias, perl 5.44 deps ; all servers deployed clean
metadata:
  type: project
---

builds on [[session-handover-rcm-builds]].

landed + pushed [ hub base ] :
- WEQ 2 21cb7c97f ; one unlock per key d3dfdda07 ; RCM 1 + 2 fec620aca af7a10299
- sign agent own dir \ crash line \ events.log 2fad3ac44 ; keys rename host pins + known: prefix 8812ac572
- managed challenge alias 50dc65f5e [ nameserv.ensure-challenge-alias, letsencr calls it ]
- SEGV fix b3f7dddec : truth fallbacks were calc_true -> bridging wrapper recursion on a cold inline cache
- release AMOS7-v6.77.7 4c928ba97 [ tag pushed ] ; base.file.temp File::Path 688e2c18f
- p7-deps a03ce5afb : deps after dist-upgrade + apt verified by module load [ worked live : IPC::Shm::Simple -> cpan ]

servers : all four on d644193fb [ 6.77.7 + p7-deps fix ], clean starts, 0 missing deps -- 13:15
- deploy : `p7c v7-zenki.start_once :wait-down: pull-git`, deps check, then `p7c v7-zenki.teardown`

open :
- format-code -c passes bin/ scripts using TRUE \ undefined globals [ prelude ] : compile shebang files outside src/ plainly
- base.prng.bytes \ characters \ chars-anum : lazy reseed when init_code has not run [ pm-src build early ]
- sign agent : after a 'changed' abort the approval screen stays up
- v7.ax still at the registrar : our local v7.ax copy mirrors it ; pri alias removed everywhere

lesson : test a deploy on a COLD inline cache, the bridge path never ran locally. cube restart = all zenki reconnect.

#,,.,,,..,,..,,.,,,,,,...,.,.,,,.,..,,.,.,,,,,..,,...,..,,...,...,,,.,.,.,.,,,
#MRI2IM6EHCO6RLB5ET5SR47KMHXDGBKNISI2LR2DGBUSGA6TEUEDPRZMR33HVXJIUZOP73BGQEDGQ
#\\\|2ILNHSRV3HWVKMT7DNWCBT3UN57ALZMMPVKKTBZIUOQCN4CKS3M \ / AMOS7 \ YOURUM ::
#\[7]X57FW7FMLADCGOKJSSRJ7QXH77FFI4H7RQXQGOWBLEWDEYZ5O4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
