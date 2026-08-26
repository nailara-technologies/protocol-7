# key_32 breakage 2026-08-25 : inline_elf C + perl 5.42 utf8_to_uvchr_buf

Root cause of "password is not correct" on real C25519 key after perl 5.40.1->5.42.3 upgrade.

## mechanism
- `AMOS7::13::key_32` final gate: `is_true($enc_bin, FALSE, TRUE)` -> `elf_chksum` (modes 4,7)
  on 32 bytes of RANDOM BINARY candidate key -> C `inline_elf` -> `sv_2pvutf8_nolen` +
  `utf8_to_uvchr_buf` (codepoint semantics since 2021).
- `utf8_to_uvchr_buf` on malformed UTF-8 (= random binary) returns DIFFERENT (char,len)
  under 5.42 than 5.40 (same finding as the 2026-07-26 hang fix 9affb84e0). Different elf
  checksum -> different is_true verdict -> different candidate accepted -> key_32 derives a
  DIFFERENT 32-byte Twofish key from the SAME password -> decrypt yields 64 bytes garbage
  -> compare_keypair FALSE. Twofish/b32r/BMW/Curve25519 all innocent (user tested clean).

## empirical proof [ 2026-08-25, /tmp/p7-elf-ab ]
- old .so `~/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY` (built 2025-10-10, perl 5.40.1, md5
  b5fadf93) vs new `inline_elf.IJGVOPICH2BTB6Q` (built tonight, 5.42.3, md5 04eff134):
  elf checksums IDENTICAL on ASCII, DIFFER on any high-byte/binary input.
- full chain: key_32('test-passphrase-13chars') = 47639ed1... (5.40+old .so) vs
  89965518... (5.42+new .so). 3/3 test passphrases diverge.
- recovery harness: /tmp/p7-elf-ab/recover_key.pl (derive under /usr/bin/perl5.40-x86_64-linux-gnu
  boots old .so's via DynaLoader; decrypt+verify under 5.42). shims in /tmp/p7-elf-ab/lib540
  (pure-perl Crypt::Misc b32r = byte-exact vs CryptX, Inline stub, Fortuna stub).
- /usr/bin/perl5.40-x86_64-linux-gnu still exists; 5.40-era CryptX/Inline::C were REMOVED by apt.

## bonus landmines found
- `no warnings 'utf8'` in elf_chksum CHANGES checksum VALUES on malformed input, not just
  silences (020971539 vs 029290131 same input, 5.40). warnings-state-dependent crypto. yikes.
- inline_elf C mutates input SV in place (sv_2pvutf8 upgrade) + reads SvCUR BEFORE upgrade
  (processes first N bytes of expanded buffer).
- BitConv pure-perl fallback `unpack Q, pack B64` is WRONG for <64-bit strings (pads zeros
  at END): bit_string_to_num('101') = 0xA000000000000000 not 5. Only used when C compile fails.
- brief claimed bit_string_to_num .so NOT rebuilt tonight -- wrong: COMPILE/003 built 04:20 tonight
  (old COMPILE/000 feb-2026 5.40 build survives, used by recovery harness).
- old true_int/true_float 5.40 .so's were deleted by tonight's rebuild; pure-perl calc_true
  fallback verified equivalent (5.42 side identical with and without C true_int).

## relation to elf-chksum-c-vs-pure-perl-utf8-divergence.md
Same subsystem, DIFFERENT bug: that one = pure-perl fallback vs C on valid UTF-8.
This one = compiled C itself across perl versions on malformed/binary input, in key_32's gate.

#,,,.,,..,,.,,.,.,.,,,,..,,.,,.,.,,.,,.,.,,.,,..,,...,...,...,,,,,,..,.,.,,,,,
#RMPRXW7VX25VB5YCFWJU3676NQOVR54XSQRCAMONQZG4WPV2QKGIQYGSB76PFAJPXCM4CA3INEWWQ
#\\\|QFYW6SS2N6STQLUMD64XDD6N2YWKXPHSFZXWBO4MSMTCAXL6GBR \ / AMOS7 \ YOURUM ::
#\[7]FOV4FWLI5BDNDMJ4LGO6VDADTEWOVBAWBL4BRCC3D2WOTQD2AIAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
