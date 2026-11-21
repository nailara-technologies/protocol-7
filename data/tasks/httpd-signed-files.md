# httpd : serve signed files -- verify, strip the signature, refuse invalid ones

status : brief, not dispatched [ owner 2026-11-21 ]. found in a live test : the jobsite
page's signature footer [ `#,,,` lines after `</html>` ] is rendered as visible text
at the bottom of the page, and a signing run once put a footer into a generated css
file, which browsers read as broken rules.

## problem

- repo files served by httpd \ httpsd carry the AMOS7 data signature footer ; for html
  [ and css \ js ] the footer is visible or breaks the file
- nothing checks the signature at serve time : a modified or corrupted signed file is
  served like any other

## shape

1. at serve time httpd recognises a signed file [ the footer form the sourcecode
   zenka writes ] and verifies it with the existing verification code [ the same as
   `sourcecode verify-signatures`, through a shared module, not a copy ]
2. valid : the footer [ and an envelope header if present ] is stripped before
   sending ; the client gets the plain html \ css \ js. content-length and range
   requests use the stripped size
3. invalid : not served -- an error page and one log line [ path, which check failed ].
   fail closed : a file that looks signed but does not verify is never sent
4. unsigned files are served as today ; a per-vhost option may require signatures for
   every file of a given type [ e.g. all html ]
5. verification results are cached by file identity [ inode, size, mtime ] so a hot
   file is verified once, not per request
6. generated files are signed by the zenka that GENERATES them [ owner 2026-11-21 ],
   not by the source signing run [ which must not touch them : an exclude list for
   generated output ] :
   - a multi-server application can hand its generating zenka the key it signs with
   - preferred : the key reaches httpd as a signed delegation over the authenticated
     zenka network [ pinned host keys, host-root signed delegations -- the network is
     the trusted key channel ], so delegation works at any distance, across hosts
   - fallback without a delegation : httpd pins the generating zenka's key on first use and accepts
     its files until a valid key rotation [ a rotation signed by the old key, or by
     the host-root delegation ] -- the generator may even run on another host
   - an attacker then has to extract a key from a zenka's memory or make a zenka sign
     something it did not intend -- a much harder attack surface than editing a file
     on disk ; editing alone only produces a file httpd refuses to serve

## later : serving n7fs trees through their signed manifests [ owner 2026-11-21 ]

- a signed n7fs tree manifest is already a signed list : every path with its content
  address, signed as a whole. httpd can serve a tree [ or a view, via the n7fs mount ]
  by checking the manifest signature once and each file's bytes against its address --
  no per-file footer needed
- a path appears on the web as soon as it is in a signed list, and disappears when a
  new signed manifest drops it ; anything not listed or not matching does not exist
  for httpd

## rules

- reuse the sourcecode zenka's verification and strip logic ; no second signature parser
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- never block the event loop : verification of a large file runs in the existing
  async file path or a child

#,,..,.,.,.,.,,.,,,,.,,..,..,,,,.,,..,,.,,,..,..,,...,..,,...,.,.,.,.,,.,,,,,,
#SSNHLFTS5SM6VWWWNMKFQAAPPYFTFW6TVHZ5WF2RPEW3NDFESXSQQ5SGFK5JA45B6RDLKLL3ITT4U
#\\\|5PVUMRPRNC6CQE7WU37IAPK6WVBAW2XEENBQQGN5LLGTS6RCFHB \ / AMOS7 \ YOURUM ::
#\[7]HIZJLQBNUNZEWBHVAJ4UUCMPCS36G4CBQZ2DTUHJR5MZY7G626BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
