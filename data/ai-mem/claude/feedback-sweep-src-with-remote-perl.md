---
name: sweep-src-with-remote-perl
description: floor perl = bin/Protocol-7 'use v5.32.0' [ raised from 5.28 2026-10-08 ] ; format-code -c \ ptd -c compile with it too [ tag '[ perl 5.32 ]' ]
metadata:
  type: feedback
---

2026-10-08 : `trust.statement` \ `auth.binding.message` used `{1,65535}` ; perl 5.36 [ a remote ]
caps {n,m} at 65534 [ 32766 below 5.30 ] and refuses to compile the module, 5.42 [ dev host ]
accepts it. every local suite passed, the remote had no delegation [ .dlg ] and broken
auth-keypair logins. fixed `6a16dfa32`.

**Why:** the test suites only ever run under the dev host's perl ; version-dependent compile
failures are invisible here and only show as "module not loaded" downstream on the remote.

**How to apply:**
- the floor is the `use v5.NN` line of bin/Protocol-7 -- raised to 5.32 the same day, since a
  5.28 sweep showed the code already relied on 5.32 [ chained comparisons, 25+ files with
  `(*pla:..)` assertions ]. user LIKES chained comparisons : use them freely.
- `bin/format-code -c` \ `bin/dev/ptd -c` compile with the local perl AND the floor perl
  [ `AMOS7::Protocol::P7Syntax` : p7_syntax__perl_c ] ; floor-only errors are tagged.
  floor perl built from source : `~/.local/perl-5.NN.N/bin/perl5.NN.N` [ -Dversiononly,
  patchperl + -std=gnu99 for gcc 15 ; its own cpanm modules : Const::Fast JSON IPC::Run CryptX ].
  a bareword of a module the floor perl lacks [ Gtk3 ] is dropped as setup noise.
- never rely on large {n,m} bounds : match with + \ * and check `length` apart.
- after a remote source update, still check its zenka STDOUT log
  [ `/dev/shm/.7/STDOUT/*`, lines without "no errors" ].

#,,.,,,.,,..,,.,.,,.,,...,,,.,,..,,.,,,..,,,.,..,,...,...,.,,,..,,,.,,.,.,...,
#FTQTCNSGINCLVQGNZF5EVJMCUR77IRZFPVTGFE23PY3376ARHOE3OORKX3D2Y3Z7KQN4JTS7KDQYC
#\\\|U4QVD3HSY2T5DIVFYDJF2OAZTZUYZA56UKTZ7IM4S3ZXEPTI55P \ / AMOS7 \ YOURUM ::
#\[7]FIS5SFHQR66Y34QKVUI2J6WK2D4QY524I45AAEYI5YJGF5EXC2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
