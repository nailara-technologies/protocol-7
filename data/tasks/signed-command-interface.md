# signed command interface [ from data/md/design/SIGNED-COMMAND-INTERFACE.md ]

high-security commands [ teardown, host reboot, forced reload, key
operations ] carry a signature footer that the receiving zenka verifies
before the handler runs. read `CLAUDE.md`, the design file, and
`data/ai-mem/claude/feedback-llm-fix-regressions-pattern.md` first. this
touches the command dispatch of every zenka -- security AND a generic path.

## state [ 2026-09-30 ]

nothing built : no verify module, no `bin/p7-sign-cmd`, no
`security.cmd.require-signed` config. existing pieces to reuse :
`crypt.C25519.verify_sign`, `crypt.C25519.create_signature_request`,
`source.signature.util.verify_signature_with_data`,
`source.load_signature_key`, the keys zenka, `AMOS7::CHKSUM::BMW384`.

## corrections to the design file before building

- its signer sketch uses `Crypt::PK::X25519` -- that is key agreement, not
  signatures. use the project's own C25519 signing [ the module signature
  path above ], do not add new crypto
- key location : the sketch says `~/.p7/keys/<user>.priv` ; the project
  keeps keys with the keys zenka \ `src/USR.<user>.*` -- follow the
  existing layout [ see crypt.C25519.load_keypair, the 2026-08-26 fixes
  in it ]
- "generate on first use + TOFU pinning" is a trust decision -- the
  user's, not the implementer's. do not build it without that decision

## phase 1 : inventory [ read-only ]

1. how module signatures are made and checked today [ which key, which
   digest, footer layout ] -- the command footer should be the same shape
2. the command dispatch : where a call is routed to its handler in the
   RECEIVING zenka [ base.handler.command.* ] -- the one place a verify
   step can go so no handler is reachable unsigned. list every path that
   reaches a handler [ network, local send, internal <[..]> calls, cube
   routing, child zenki ] -- a gate that one path bypasses is no gate
3. identity today : cube's access control [ cfg/zenki/cube/access.* ],
   unix-socket auth [ plugin.auth.unix -- see the 2026-09-20 identity
   bypass fix in memory ] -- what a signature adds on top, per path
4. p7c [ bin/c_src/p7c.c ] \ p7-r : where a footer would be attached,
   and how p7c would know a command requires signing [ ask the target ?
   a local list ? ]

## phase 2 : smallest useful slice [ after the user's go ]

- one zenka [ v7-zenki ], one command [ teardown ], `require-signed` tier
- verify before dispatch : digest over command + ntime + nonce, replay
  window [ ntime age ], nonce store with expiry, authorized key
  fingerprints per command -- a valid signature from an unlisted key is
  rejected ; failures answer only 'signature verification failed'
- `bin/p7-sign-cmd` [ stdin -> stdout ], then p7c integration
- tests on mod-test : unsigned rejected, bad signature rejected, replay
  rejected, expired rejected, unlisted key rejected, valid accepted --
  and the handler never sees the footer

## output

findings with file:line, the dispatch insertion point with every path
listed, open questions for the user [ key location, TOFU, which commands
per tier ]. no src changes in phase 1.

#,,..,...,.,.,,,.,.,.,..,,,.,,,,.,,..,,,,,.,.,.,.,...,...,.,,,,..,.,,,...,,..,
#66IF6KFJMF4O5EEFSRE5W5H42QBLYQ54XGF2XGQ6BR2Z2FOBQSS6OV6XC4D67JO2SVCF4F6AVENQW
#\\\|S2GNSHOFEZNCN7OEUT47QJCCNOEBI65Z4FMNW2IBM7PPQEKXIQ3 \ / AMOS7 \ YOURUM ::
#\[7]H34LB2PUGPDQCHLJPPMFFOR7ZXOLKQSTXK6NVHC3PHAF6UJKMECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
