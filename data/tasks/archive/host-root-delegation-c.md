# host-root delegation : C client [ lane 3 ]

implement the CLIENT side of `data/md/design/HOST-ROOT-DELEGATION.md`
[ read it all ; base : `AUTH-LINK-BINDING.md` -- your previous lane's
work, live since ad31ddd5a ] in `bin/c_src/p-7-r.c`,
`bin/p7-auth-keypair-helper.pl` [ and `bin/p7-link-upgrade-helper.pl`
only if needed ]. touch nothing else ; lanes 1 \ 2 edit src/ + tests in
parallel. no zenka start \ reload, no sudo, no commit, no signing, no
real network, no install, no git command that changes the tree.

## what changes

- select reply : `TRUE <S_pub> <nonce> <delegation b32>` ; v2 replies
  without the 4th field are refused
- helper `check-pin` -> verifies the delegation [ statement parse, sig
  under the issuer pub, not_before <= now <= not_after, subject == S_pub,
  scope rule ] and pins the host-root FINGERPRINT [ bmw384 of the issuer
  pub, `encode_b32r`, 77 chars ; Digest::BMW like
  `src/osf-cache.fetch.complete` ] in
  `~/.n/remote-keys/servers/<host>_<port>.public` [ same naming as now ] ;
  a different host-root -> refuse [ exit 6 ] ; a ROTATED S delegated by
  the pinned host-root -> accept
- p-7-r passes the 4th field to the helper [ public value, argv ok ] and
  keeps every existing rule [ no shell, strict parsing ]
- print on first contact : `pinned host-root <fingerprint> [ <name> ]`

## verification

- lane 1 puts a TEST VECTOR into the spec [ statement hex, sig,
  fingerprint ] -- it may land while you work ; `self-test` must
  reproduce it ; until then build your own and say so
- extend `self-test` : delegation ok \ expired \ not yet valid \ wrong
  subject \ bad sig \ wrong fingerprint \ rotated S
- your scratchpad mock server [ from the last lane, if still there ] or a
  new one : first contact pins, rotated S accepted, foreign host-root
  refused
- `gcc -Wall -Wextra` into the scratchpad [ /tmp/claude-1000/
  -data-projects-protocol-7/5178c25a-c386-4d7a-8663-001388ec65bc/
  scratchpad ] -- no new warnings ; `bin/format-code -c` on the helpers

## report

`data/tasks/host-root-delegation-c.report.md` : changes, self-test +
compile + mock output, open questions. spec wrong \ ambiguous -> STOP on
that point and report it.

#,,.,,..,,.,,,..,,,..,,,,,..,,.,,,.,,,.,,,...,..,,...,...,...,.,,,,..,..,,,,,,
#OFT46RV6EQMB5KJZCBYIBKNTTK7OTHCS3U4L7RGWCIBYYDWLKKUPPVZNERE3CBREPOTSLFWIPYIR6
#\\\|D42NENVFMZOO6T2RNNM556SGEZLA73KBIXSRE6BECDXKFHLGLK6 \ / AMOS7 \ YOURUM ::
#\[7]W2GB5LDF2FG23FTTW4RPRAOKMA5GJX2WPQ3VB6VR4RAT4FCXTKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
