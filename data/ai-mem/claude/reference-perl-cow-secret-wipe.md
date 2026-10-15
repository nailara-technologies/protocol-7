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

`IO::AIO::aio_mlock` executes on a worker thread at once [ VmLck 0 -> 4 kB
without any poll ] ; only the completion waits for a poll \ flush. BUT a
request without a callback makes the next `IO::AIO::poll` \ `flush` DIE with
any stale `$@` [ verified ] -> `local $EVAL_ERROR` around every poll loop
[ base.s_read.file_io, base.s_write.file_io, AMOS7::Vault _mlock ].

**How to apply:** wipe [ base.buffer.erase_secure \ AMOS7::Vault `_wipe` ]
only works on the sole owner of a buffer -- for every secret check that no
second scalar holds it, or wipe that one too. derived temporaries [ b32
strings, sprintf results ] are a separate limit. related : [[no-personal-data-in-repo-tree]].

#,,,,,,..,..,,,..,,.,,.,.,,.,,.,,,..,,,,,,.,.,..,,...,...,.,.,,.,,.,,,,,.,,.,,
#3T2AINABNOBO727NSDUHXSHLVXJ6WJF3V4XBLG3VJGB3ASAMXOCJTDML2MXM5IKAX4KPLLMNSHLPK
#\\\|5PGCA3UKJDBK7NOC7O3JXQ2M3ELDWIDOD2TPTCIGFDMYOZ6A6DN \ / AMOS7 \ YOURUM ::
#\[7]GCSS3DLDHUSYVJSY3LQQZOVTINVCGLXW3VD5KV7P22XN467JY4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
