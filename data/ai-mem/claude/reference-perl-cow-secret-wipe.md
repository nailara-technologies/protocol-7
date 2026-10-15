---
name: reference-perl-cow-secret-wipe
description: perl copy-on-write : `my $copy = $secret` [ also `my $x = shift`, hash value copies ] SHARES the buffer -- wiping one of them un-shares and overwrites a fresh copy, the secret stays in the other. build key buffers with `$k = ''; $k .= $src`, pass secrets by reference, never keep a second copy ; aio_mlock runs without a poll
metadata:
  type: reference
---

verified 2026-10-15 with Devel::Peek [ same PV address, IsCOW ] :
- `my $original = $case->{'value'}` then `erase_secure( \$case->{'value'} )`
  -> `$original` still holds the secret [ was form.handler.secret_release_reply ]
- `my $secret = shift` in a callee shares the caller's buffer
  [ was sessions.secret.child -- now takes `\$secret` ]
- a sub returning a lexical : the caller gets the SAME buffer, the other
  owners are gone -> a wipe there is in place [ fine, p7-auth-keypair-helper.pl ]
- `$keys{..}{'secret'} = $decrypted_sref->$*` keeps the mlocked buffer [ fine ]

also 2026-10-15 : a regex with a capture [ `s{(..)$}{}` ] and a growing `.=`
MOVE the string -- the old copy stays unwiped. read secrets into one
preallocated buffer written with 4-arg substr [ p7-vault read_secret_raw ].

best tool : `vec( $buf, $i, 8 )` reads \ writes ONE byte in place, no string
copy at all [ even substr's 1-byte pad target goes ] -- AMOS7::TERM's reader
now edits a fixed buffer with vec only.

verify by SCANNING /proc/self/mem after the wipe [ bin/test-scripts/
test-term-password.pl ] : search bytes 16+ of the value [ free() writes its
list pointers over the first 16 ], pass the pattern masked, and keep a
control run that must find an unwiped value. under `use v5.28+` `^` is
NUMERIC [ feature bitwise ] -- string xor is `^.`.

`IO::AIO::aio_mlock` executes on a worker thread at once [ VmLck 0 -> 4 kB
without any poll ] ; only the completion waits for a poll \ flush. BUT a
request without a callback makes the next `IO::AIO::poll` \ `flush` DIE with
any stale `$@` [ verified ] -> `local $EVAL_ERROR` around every poll loop
[ base.s_read.file_io, base.s_write.file_io, AMOS7::Vault _mlock ].

**How to apply:** wipe [ base.buffer.erase_secure \ AMOS7::Vault `_wipe` ]
only works on the sole owner of a buffer -- for every secret check that no
second scalar holds it, or wipe that one too. derived temporaries [ b32
strings, sprintf results ] are a separate limit. related : [[no-personal-data-in-repo-tree]].

#,,..,..,,,,,,.,,,.,,,,,,,,..,..,,.,.,..,,,,,,..,,...,...,..,,,.,,.,,,..,,,.,,
#RCPEWEEFQ37Z3DLR46ZOPJMZLQ6SK246IFKJYRDFIZGES5S5C7MBHFAFJHJP5HOTZZAYGZXMON4XS
#\\\|YKFRUFWDFB3K3A3LKMJR5D6MT3CU3FGUXMFKJEI7ZV7HDDRERN4 \ / AMOS7 \ YOURUM ::
#\[7]RQ4CXI6NOOJJETOENWOABKAR443TG3D6SNFUUK5AW7PGAFMLWUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
