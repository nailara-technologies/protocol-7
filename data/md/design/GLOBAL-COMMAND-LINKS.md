# global command links : bin/ tools callable by name

status : design, nothing implemented yet [ 2026-11-05 ]. depends on todo VWF
[ `signature_valid` ignores a caller truth map ]. related :
`v7-zenki.install_zenka_symlinks` [ the `p7-<zenka>` links ],
`AMOS7::deps::service` [ `bin/p7-deps install-service` \ `check-service` ].

## 1. what exists

- `bin/p7-deps install-service` [ `AMOS7::deps::service` ] : the checkout link
  `/usr/local/protocol-7`, `Protocol-7` and `nshell` -- nothing else.
- `v7-zenki.install_zenka_symlinks` : `p7-<zenka>` links in `/usr/local/bin`
  for zenki with console commands [ + nshell ].
- standalone tools [ `ned`, `todo`, `p7-vault`, `amos-chksum` .. ] have no
  installer : called by full path only. PATH itself is fine -- `/usr/local/bin`
  is in every user's PATH, `/usr/local/sbin` + `/usr/local/bin` in root's
  [ and sudo's `secure_path` ].

## 2. selection : the tool declares itself

a header line in the script, next to the usual header lines :

```
# launch = user      ->  /usr/local/bin/<name>
# launch = root      ->  /usr/local/sbin/<name>
```

- no separate list to keep in step ; adding \ removing the line is the opt-in
  \ opt-out, decided by whoever writes the tool.
- the link name is the file name, unprefixed. no profiles : hosts differ in
  what is installed, not in what is linked -- a tool with missing
  dependencies fails with its own message, as it does by full path.
- `user` links are also reached by root [ /usr/local/bin is in root's PATH ] ;
  `root` keeps root-only tools out of normal users' PATH.

## 3. acceptance : every check, every link

a header is only honored when ALL of these hold. any failure : no link, a
logged reason, an existing link of ours is removed. fail closed.

1. **signature** : the whole file carries a valid AMOS7 signature [ header
   included ]. an unsigned file never gets a link -- the header would
   otherwise turn write access to `bin/` into a command in root's PATH.
2. **no shadowing** : the name must not resolve anywhere else in the system
   PATH [ `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`, .. ] -- refused even when
   signed : a signed `bin/ls` is still a mistake. only a link of ours at the
   target path counts as "already there".
3. **ownership + permissions** [ every global link, user and root alike ] :
   - the target file and each directory up to `/` : owned by root, not
     writable by group or others. a swapped file after the check is the
     window a signature at link time can not close -- this closes it.
   - the link directory itself : root-owned, not group \ world writable.
   - the target is a regular file, executable, inside the checkout ; symlinks
     in the target path are resolved first and the RESOLVED path is checked.
4. **never replace foreign entries** : only create, or replace a symlink that
   already points into the checkout. a regular file or a foreign link at the
   name is left alone and reported.

## 4. who links

- one pass next to `install_zenka_symlinks` in v7-zenki [ root, at start and
  on reload ] : reads `bin/*` headers, applies section 3, creates \ removes.
  re-checks existing links of ours : a target that lost its signature,
  ownership or header loses its link.
- `bin/p7-deps install-service` \ `check-service` : the same checks through a
  shared module [ AMOS7, so the standalone installer needs no zenka ] -- a
  fresh host has the links before v7-zenki ever ran ; check reports missing,
  refused and foreign ones with their reason.
- one implementation of the checks for both callers, not two.

## 5. open

- the header word : `# launch =` is the working name.
- first set : `ned`, `todo`, `p7-vault`, `amos-chksum` as `user`.
- VWF first : the signature check here must be the strict form VWF settles.

#,,..,,..,...,.,.,,..,...,,,.,,..,...,,,,,.,,,..,,...,..,,.,,,...,,.,,.,,,,..,
#64JTIOEYHTXJ5ZTURRVX2LOVJDXLH7FWP63LGSCY6JNITDO7DRVL6FYFZCQT2GKW3F6HAKPGG6FQE
#\\\|ZCMLU3HLGVEHD7O6LPN6NWSTSXD5VDPX6FXFYTNU7VFJYT45B4K \ / AMOS7 \ YOURUM ::
#\[7]QK5VCRGQFN67I3FDAHOPYRXX2IQYERVHMTMJCWNXTC6TJR5XVWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
