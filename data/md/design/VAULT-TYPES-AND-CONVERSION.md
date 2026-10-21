# vault types and conversion : p7-vault

2026-10-21. design only -- nothing here is implemented yet. source : todo
5OT [ 'types refinement + conversion', owner 2026-10-21 ], with the
credential layers map of todo 6C6 [ CREDENTIAL-LAYERS.md, written in a
parallel session ] for the type vocabulary. the record format itself is
`VAULT-FORMAT.md` ; this file adds types, per-type secret fields and a
way to move existing entries into them. nothing below changes format 1 :
a new type is a new value of the record's `type`, and unknown fields are
already kept as they are.

host names, user names and urls below are EXAMPLE values [ `*.example`,
rfc 2606 ], not real records.

## where it stands today

- `AMOS7::Vault` `%TYPES` : `login` [ title url username password totp
  notes ], `note` [ title body ], `contact` [ title name phone email
  address notes ], `file` [ title blob size origins ]. the list is the
  prompt order of `add` \ `edit` and the display order of `show`
- `%SECRET` : ONE global list by field name -- `password totp body`.
  `secret_field( $field )` answers for any type
- a record without `type` is a `login` [ `// 'login'` all through
  `bin/p7-vault` ]
- `entry_save` always ADDS a version ; `entry_versions` lists them from
  the file names ; `history` shows them, `restore [ n ]` writes an older
  one again as the newest [ default : the newest older version that is
  not a deletion ]. `code` and the entry id survive every save
- provider \ registrar \ hosting panel logins were imported one by one
  as `login` entries ; server access sits in them too [ url = the host,
  username = the ssh user ] -- the reason for a conversion, not only new
  types

what the script does with fields today, and what a new type runs into :

- `show` loops over `type_fields( $type )` only : a field the type does
  not list is never shown, even though it is stored
- `edit` copies the whole record and asks only the type's fields : other
  fields survive an edit unseen
- `matches` searches `title url username name email phone` and the file
  origins ; a server found by its host or ssh user needs more
- `summary_line` : contact -> phone email, file -> path, everything else
  -> username url
- `get` \ `copy` default to `password`
- `ask_field` special-cases `password` [ keep \ new \ generate ] and
  `body` [ the editor, or the hidden multi-line prompt with `-s` ] ; every
  other secret field is a single-line hidden prompt
- `add`'s usage text and refusal message name `login note contact` by
  hand

## 1. new types and their fields

every type keeps `title` first, as the four existing ones do [ the list
needs it, `pick` resolves by it ]. `notes` is added where a free text
field fits. fields marked * are secret [ section 2 ].

```
server       title host port ssh_user host_key_fp key_ref password*
             host_record notes
ssh-key      title private_key* public_key fingerprint passphrase* notes
app-account  title app platform username password* totp* recovery*
             notes
api-token    title service url token* scope expires notes
```

- `server` : one ssh-reachable account on one machine.
  - `host` : the name or address ssh dials
  - `port` : ssh port, empty = 22
  - `ssh_user` : the remote account
  - `host_key_fp` : the OpenSSH host key fingerprint as `ssh-keygen -lf`
    prints it [ `SHA256:<base64>` ], the owner's verified reference
  - `key_ref` : the entry id of an `ssh-key` entry [ 16 chars ; shown
    with that entry's code and title ]
  - `password` : the account password, for password logins and `sudo`
  - `host_record` : the name of a host-edit record [ section 5 ], optional.
    this field and `notes` go beyond the list in 5OT ; both are optional
- `ssh-key` : one key pair. `private_key` is the full OpenSSH private key
  text [ multi-line ], `public_key` the one-line `.pub` form,
  `fingerprint` as `ssh-keygen -lf` prints it, `passphrase` the key's own
  passphrase when it has one. several servers point at one key through
  `key_ref`, so a rotated key is changed once
- `app-account` : android \ app logins [ memory
  project-credential-types-into-user-edit : 'android application accounts
  -- NO existing type' ]. `app` names the application, `platform` where it
  runs [ android, ios, desktop ], `recovery` holds recovery codes
  [ multi-line ]. an app account is a login without a url ; it is its own
  type so the list and the grant layer [ 6C6 ] can tell them apart
- `api-token` : a token for an api. `service` names it, `url` its
  endpoint, `scope` the granted rights as the provider names them,
  `expires` a date `YYYY-MM-DD` [ empty = no expiry ; the list marks an
  expired token ]
- provider \ registrar \ hosting panel logins stay `login`. a login
  carries the web account ; the machines it rents out become `server`
  entries of their own
- host passwords [ the same memory, case 3 ] are `server` entries with
  `password` set and no `key_ref`

### one vocabulary across the layers

the three lists name different things and do not overlap today :

```
p7-vault         login note contact file  [ + the four above ]
credentials      web-session api-key smtp imap ssh-key      [ cmd.add ]
cred-mesh slots  api-key bearer-token session-cookie basic-auth
                 tls-client-cert psk oauth-token          [ register ]
```

a vault type says WHAT the person owns [ the shape of the secret ] ; a
credentials type or a cred-mesh slot type says HOW a zenka uses it [ the
auth mechanism ]. a grant [ 6C6 : one vault entry provisioned into one
runtime slot for named zenki ] translates one into the other. so the vault
does not adopt the runtime names wholesale, and where the same thing is
meant the same word is used :

```
vault type    credentials type           cred-mesh slot type
-----------   ------------------------   ---------------------------
login         web-session [ smtp imap ]  basic-auth, session-cookie
server        --  [ none for passwords ] --  [ ssh is not a slot kind ]
ssh-key       ssh-key  [ same name ]     --
app-account   --  [ rejected today ]     basic-auth, oauth-token
api-token     api-key                    api-key, bearer-token,
                                         oauth-token
note \ contact \ file   --  [ not credentials ]
```

- `ssh-key` is the same word in the vault and in `credentials.cmd.add` on
  purpose
- `api-token` [ 5OT's name ] against `api-key` [ both runtime lists ] is
  left as an open question : the vault entry holds bearer and oauth tokens
  too, which `api-key` does not cover in cred-mesh
- the `credentials` whitelist and the cred-mesh type list are NOT changed
  by this design ; extending them for `server` and `app-account` belongs
  to the grant layer [ 6C6 ]
- CREDENTIAL-LAYERS.md section 4 calls the two axes 'entry type' and 'use
  kind' and holds the same entry types with the same secret fields as
  section 2 below. it proposes one types yaml for the zenki ; the vault
  keeps its own table in `AMOS7::Vault` [ a vault opens without
  protocol-7 ] and a test checks that both agree once the yaml exists

## 2. secret-ness per type and field

`%SECRET` by field name stops working once types bring secrets of their
own : `token` is secret in `api-token`, `recovery` in `app-account`, while
a future non-secret field could share a name with one of them. the rule
moves into the type table :

```
login        password totp
note         body
contact      --
file         --
server       password
ssh-key      private_key passphrase
app-account  password totp recovery
api-token    token
```

[ in `AMOS7::Vault` : `%TYPES` keeps the ordered field lists, a new
`%TYPE_SECRET` holds the table above ; `%SECRET` stays as the union of all
of them plus the old three names, for the legacy call ]

`secret_field( $type, $field )` :

1. the field is one of `$type`'s fields -> the type's table decides
2. otherwise [ a kept field after a retype, a field an older or newer
   p7-vault wrote ] -> secret when ANY type, or the old global list,
   declares that name secret. secret status is only ever added, never
   lost through a retype : a `totp` kept on a server entry stays masked
3. an unknown `$type` [ a vault written by a newer p7-vault ] -> rule 2
   for every field

`secret_field( $field )` with one argument keeps answering by name alone
[ rule 2 ] for callers that do not know the type.

### compatibility with existing records

- for the four existing types the table holds exactly `%SECRET`
  intersected with their fields : `login` password totp, `note` body,
  `contact` and `file` none. every field that is masked today stays
  masked
- the only change for an existing record : fields outside its type,
  hidden today, are shown under the new `show` [ section 6 ] -- masked by
  rule 2 when the name is secret anywhere
- invariant, for the tests : for every existing record the masked set
  under the new rule is a SUPERSET of the masked set today
- no stored data changes, no new version is written for this

### an older p7-vault reading a new type

a synced copy can meet a host that still runs the older script. there
`type_fields( 'server' )` is empty :

- `list` shows the entry [ type column `server`, title, an empty who
  column ]
- `show` prints `type`, `code` and `updated` only -- no field is shown,
  so nothing leaks
- `edit` asks nothing and saves the record unchanged as a new version ;
  `get <filter> <field>` still prints a named field raw, as it does today
- `add server` is refused as an unknown type

blind, not lossy : no format bump is needed. VAULT-FORMAT.md's record
section gains the new types and the per-type secret table once stage 1
lands.

## 3. the conversion function : retype

retype changes an entry's `type` and moves its fields by a map. it is two
functions in `AMOS7::Vault`, so the dry run and the real run share every
decision :

- `retype_plan( $record, $to_type, \%map )` -> `( \%new_record, \@moves,
  \@problems )`. pure : no vault, no i/o. `@moves` lists every field with
  what happens to it ; `@problems` lists what stops the retype
- `entry_retype( $vault, $id, $to_type, \%map )` -> loads the newest
  version, runs `retype_plan`, refuses on any problem, otherwise
  `entry_save( $vault, $id, \%new_record )` : ONE new version, same entry
  id, same `code`

### the map

- a field whose name exists in both types stays where it is [ `title`
  `password` `notes` ] -- the identity part of the map is implicit
- a pair `src=dst` renames. a target can be named once only
- built-in default maps per type pair live in `AMOS7::Vault`
  [ `%RETYPE_MAP` ] ; pairs given on the command line extend or override
  them. only the built-in maps can use a transform

```
login -> server        url -> host  [ split, below ]
                       username -> ssh_user
                       password, notes, title : unchanged
login -> app-account   url -> app   [ only when no scheme : a bare name ]
                       username, password, totp, notes, title : unchanged
login -> api-token     password -> token
                       url, notes, title : unchanged
server -> login        host -> url  [ ssh://ssh_user@host:port, the
                       reverse of the split ] ; ssh_user -> username
```

### the url split [ login.url -> server ]

a login url is not always a bare host name. the split reads it and fills
`host`, `port`, `ssh_user` -- but only targets the map did not already
fill :

```
ssh://admin@vps1.example:2222   host vps1.example  port 2222
                                ssh_user admin     url consumed
admin@vps1.example              host vps1.example  ssh_user admin
                                url consumed
vps1.example:2222               host vps1.example  port 2222
                                url consumed
https://panel.example:8443/x    host panel.example
                                url KEPT [ a panel address : the port
                                and path are not ssh's ]
```

- the port is taken from `ssh://` and from a scheme-less url only
- a url the split cannot read fully stays as a kept `url` field, so
  nothing is lost and `show` keeps showing it
- a user in the url that differs from `username` is a collision [ below ]

### unmapped fields are kept

a field neither in the target type nor in the map keeps its name and
value : `totp` on a login that becomes a server, `body` from a note. the
format already keeps unknown fields ; `show` lists them under `[ kept ]`
[ section 6 ], masked by rule 2 ; a later retype or a later map can still
place them. nothing is ever dropped -- there is no 'drop' move.

### refused [ the problems list ]

- target type unknown, or equal to the current type
- `file` as source or target : `import -u`, `files` and `export` find
  entries by `type eq file`, and `blob` \ `origins` only mean something
  there
- a deleted entry [ restore it first ]
- two sources mapped to one target, or a target already present in the
  record with a different value [ e.g. a kept `host` field from an earlier
  edit, or the url's user against `username` ] -- listed with both
  values masked when secret ; the owner adds a pair that moves one of them
  elsewhere
- the vault is locked

an empty source field is not a problem : the move is listed as
`[ empty, skipped ]`.

### dry run first

the plan is printed before anything is written -- always, not only with
`--dry-run`. one line per field :

```
  retype 'vps1' [ K7Q ] login -> server

    url        -> host        vps1.example     [ split ]
    url        -> port        2222             [ split ]
    username   -> ssh_user    admin
    password      password    ********         [ unchanged ]
    totp          totp        ********         [ kept, not a server field ]
    notes         notes       ...              [ unchanged ]
```

- secret values are masked in the plan, the same rule as `show`
- `--dry-run` stops here ; otherwise one confirm, then the write
- without a tty the confirm needs `-y`
- flags : p7-vault's flags are single-dash [ `-r -s -a -u -x` ] ; the new
  ones follow that [ `-y -rule -hosts -host-dir` ]. `--dry-run` is kept
  as 5OT names it, `-n` as its short form

### reversible

- the old typed version stays in the entry's history [ `entry_versions` ]
  -- retype wrote a version, it overwrote nothing
- right after the retype, `restore <filter>` with no count writes the
  version before it again as the newest : the old type with every field
  as it was. later, after further edits, `restore <filter> n` counts back
  to the version `history` shows before the type change. that is the
  undo ; no reverse map is needed for it
- `history` shows the type next to each version where it changes, so a
  retype can be found again
- no provenance field is added to the record : the previous version IS the
  provenance

### sync

a retype is an ordinary new version, so `sync` carries it as a file like
any other. the existing rule applies : the newest version is the entry.
an offline edit of the same entry on another host, made LATER than the
retype, becomes the newest and brings the old type back. after a batch :
sync first, edit elsewhere afterwards.

## 4. batch conversion by rule

the provider logins imported one by one become typed in one pass :

```
p7-vault retype -rule ssh-hosts [ -hosts <file> ] [ -host-dir <dir> ]
                [ --dry-run ] [ -y ]
```

rule `ssh-hosts` selects live `login` entries where :

- `url` starts with `ssh://`, or
- the host part of `url` [ the split above ] equals a known host name, or
- `title` equals a known host record name

known host names come from, in this order, each only when present :

1. `-hosts <file>` : one name per line [ `#` comments ]
2. host-edit records : `/var/protocol-7/host-edit/hosts/<name>.json`
   [ `[VAR_P7]/hosts` inside the zenka -- p7-vault cannot expand the
   keyword, so it takes the absolute default, `-host-dir <dir>` overrides ]
   -- `name`, every `addresses` entry without its port, the host of `ssh`.
   the directory belongs to the zenka's own user : unreadable, it is
   skipped with a note, never an error
3. `Host` names [ no wildcards ] and their `HostName` from `~/.ssh/config`

p7-vault must keep opening a vault without protocol-7 [ VAULT-FORMAT.md ],
so 2 and 3 are read only when the files exist ; the rule never needs a
running zenka. a match through a host-edit record also fills
`host_record` with that record's name.

the batch :

- builds the plan of every matching entry first, prints all of them, then
  a summary [ `n entries, m refused` ]
- an entry with problems is left out and listed with its problems ; the
  rest go on
- one confirm for the whole batch, then one new version per entry
- each entry is undone on its own with `restore` ; a whole-batch undo is
  an open question
- more rules later [ `api-tokens` : logins whose title or notes say token
  ... ] -- named rules built into p7-vault, no rule language in stage 3

## 5. a server entry and a host-edit record

two records describe one machine for two readers : the host-edit record
[ `[VAR_P7]/hosts/<name>.json`, HOST-SETUP.md 'host record' ] tells
protocol-7 how to LINK to the host ; the vault entry holds what the
PERSON needs to log in. they share the machine, not the purpose :

```
what                               source of truth     the other side
---------------------------------  ------------------  ------------------
record name [ 'atom' ]             host-edit name      server.host_record
                                                       refers to it
addresses, transports, owner,      host-edit           not in the vault
roles, link_user
p7 host-root key id \ leaf \ since pin store           neither record
                                   [ servers/ ]
ssh dial host, port, user          see below           see below
OpenSSH host key fingerprint       vault host_key_fp   ~/.ssh/known_hosts
                                                       is the working copy
passwords, private keys            vault only          host-edit refuses
                                                       secrets
```

- host-edit holds NO secrets : `host-edit.source.secret_hold` refuses
  every hold. a server password never goes there
- the p7 host-root key id [ 77 base32 chars ] and the OpenSSH host key are
  two different keys of one machine. the pin store stays the only home of
  the first [ never copied, HOST-SETUP.md ] ; the vault's `host_key_fp`
  is the second, kept as the owner's verified reference -- for a new
  machine, or to check `known_hosts` out of band
- overlap : host-edit's `ssh` [ `[user@]host` ] and `ssh_port` against the
  vault's `host` \ `ssh_user` \ `port`. they can differ for good reason
  [ protocol-7 links as `link_user` through a tunnel, the person logs in as
  root ]. stage 4 : with `host_record` set, `show` reads the host-edit
  record when it is there and marks a difference [ `differs from host-edit
  'atom'` ]. nothing writes into the other side ; which one wins on a
  deliberate sync is an open question
- the later zenki integration [ 5OT : 'a remote link or deploy step asks
  the vault instead of reading ~/.ssh' ] goes through a grant [ 6C6 ], not
  through host-edit reading the vault

## 6. command-line surface in bin/p7-vault

new :

```
retype <filter> <type> [ src=dst ]... [ --dry-run ] [ -y ]
                         change an entry's type ; fields moved by the
                         built-in map + the given pairs, the rest kept.
                         prints the plan first [ --dry-run : only the
                         plan ] ; the old version stays in history,
                         'restore' undoes it
retype -rule <name> [ -hosts <file> ] [ -host-dir <dir> ] [ --dry-run ]
       [ -y ]            every live entry the rule selects [ ssh-hosts ]
types                    the types, their fields in order, secret fields
                         marked
```

arguments of `retype` : flags and `src=dst` pairs are taken out first ;
of the words left, the LAST is the target type and every word before it
is the filter [ as `get` \ `copy` pop their field ] -- a title of several
words needs no quoting. the type must be a known type, else the refusal
lists the types.

changed :

- `add [ <type> ]` : usage text and the refusal list built from `%TYPES`,
  never typed out by hand again [ `add` refuses `file` as today --
  `import` makes those ]
- `show` : the type's fields, then every other stored scalar field under
  a dim `[ kept ]` line, masked by `secret_field( $type, $field )` ; `-r`
  reveals both
- `matches` : a search list per type in the type table, never 'every
  field'. `pick` falls back to `matches` and, without a tty, refuses more
  than one hit -- a wider search would make a script's `get <filter>` that
  finds one entry today start refusing. so :
  - the four old types keep exactly today's list [ `title url username
    name email phone` + the file origins ]
  - server `title host ssh_user host_record`, ssh-key `title
    fingerprint`, app-account `title app username`, api-token `title
    service url`
  - free text [ `notes` ], kept fields and secret fields are never
    searched
- `summary_line` who column per type : server `ssh_user@host[:port]`,
  ssh-key `fingerprint`, app-account `username app`, api-token
  `service` + `expires` [ marked when past ]
- `get` \ `copy` default field per type : `password` [ login, server,
  app-account ], `private_key` [ ssh-key ], `token` [ api-token ]. copying
  a multi-line private key to the clipboard asks first
- `ask_field` :
  - `private_key` and `recovery` take the multi-line path of `body`, but
    always hidden -- never the editor, which shows the text. `private_key`
    also offers `f(ile)` : a path [ `~/.ssh/id_ed25519` ], read, then
    `public_key` and `fingerprint` offered from `ssh-keygen -y -f` \ `-lf`
    when ssh-keygen is there [ the key's passphrase is asked by ssh-keygen
    itself, never put on a command line ]
  - `passphrase` and `token` : single-line hidden, as every other secret
  - `key_ref` : a filter like `pick`, limited to `ssh-key` entries ;
    stored as the entry id
  - `expires` : `YYYY-MM-DD` or empty, anything else asked again
- `edit` : asks the type's fields as today ; kept fields stay untouched
  [ an open question : offer them too ]
- `history` : the type next to each version where it changes

### tests

`bin/test-scripts/test-vault-retype.pl`, the style of `test-vault.pl` :
own `ok()`, cheap kdf, a tempdir, `AMOS7::Vault` only [ no tty ] :

- `secret_field` : the per-type table ; one-argument form unchanged ;
  for every old type and every field name ever used, new masked set is a
  superset of the old one [ the compatibility invariant ]
- search lists : for the four old types `matches` hits exactly what it
  hits today ; a word only in `notes` or in a kept field finds nothing
- kept secret : a login with `totp` retyped to server -> `totp` kept,
  `secret_field( 'server', 'totp' )` true
- unknown type : `secret_field( 'future-type', 'password' )` true
- `retype_plan` is pure : the vault's `entry_versions` unchanged after a
  plan [ the dry run writes nothing ]
- `entry_retype` adds exactly ONE version ; entry id and `code` equal
- every field of the old record present in the new one, under its old or
  its mapped name [ nothing dropped ]
- the url split : the four example rows above, plus a url with a user
  that differs from `username` [ refused ]
- refused : target `file`, source `file`, unknown target, same type,
  deleted entry, two sources to one target, a target present with another
  value
- reversible : retype, then `restore`'s rule [ the newest older version
  not deleted ] gives back the old record field for field ; after one more
  edit, counting back two versions does
- batch rule : a temp host list + temp host-edit dir with one record ;
  `ssh://` url, matching host, matching title selected ; others not ; an
  entry with a problem left out, the rest written
- an older reader : a record of type `server` through the four-type
  `%TYPES` -> `type_fields` empty, an edit-style save keeps every field

## 7. staged plan

1. **types and secrets** -- `%TYPES` with the four new types,
   `%TYPE_SECRET`, `secret_field( $type, $field )` with the one-argument
   fallback ; `add` \ usage from `%TYPES` ; `show` with kept fields ;
   `matches`, `summary_line`, `get` \ `copy` defaults ; `types` ; tests for
   the secret rule and the compatibility invariant ; VAULT-FORMAT.md
   record section updated. new entries can be made from here on
2. **retype, one entry** -- `retype_plan`, `entry_retype`, `%RETYPE_MAP`
   with the url split ; `retype <filter> <type>` with the plan, `--dry-run`,
   `-y` ; `history` showing the type ; the retype tests
3. **batch** -- `retype -rule ssh-hosts`, the three host name sources ;
   the batch tests ; run it on the real vault with `--dry-run` first, read
   the plan, then for real
4. **ssh-key input and links** -- `f(ile)` for private keys, derived
   public key and fingerprint, `key_ref` picking and display, the
   `host_record` difference in `show`
5. **later, outside p7-vault** -- grants into `credentials` \ cred-mesh
   [ 6C6 ], their type lists extended there ; zenki asking the vault
   instead of `~/.ssh`

each stage is usable on its own, and no stage changes the file format.

## open questions

- `api-token` or `api-key` as the vault's name -- 5OT says api-token, both
  runtime lists say api-key
- `host` against `host_record` : CREDENTIAL-LAYERS.md section 5 has the
  server entry refer to its record through `host` holding the record
  name. this design keeps `host` as what ssh dials [ an address, a name
  through a tunnel, a provider's ip ] and the record name in
  `host_record`, because the two differ whenever the record name is a
  label like `atom` that does not resolve. settle one reading for both
  docs before stage 1
- `ssh` \ `ssh_port` in host-edit against `host` \ `ssh_user` \ `port`
  in the vault : report differences only [ proposed ], or sync one way on
  request, and which way
- `host_key_fp` : typed by hand only, or fetched with `ssh-keyscan` and
  confirmed [ trust on first use, against the point of a verified
  reference ]
- a field name that no type declares secret but looks like one [ `pin`,
  `secret`, `psk` from an import ] : masked by a name pattern too, or
  only by the table
- `edit` : ask kept fields after the type's fields, or leave them for a
  retype
- a whole-batch undo [ `retype --undo <batch>` ] -- needs a batch id in
  the record, which this design avoids so far
- `smtp` \ `imap` credentials : a `login` with a `smtp://` url, or a type
  of their own in the vault
- `key_ref` to a deleted or retyped ssh-key entry : warn in `show` only, or
  refuse the delete while a server points at it
- `app-account` against `login` : one type with an optional `app` field
  would also work -- kept apart here for the grant layer ; confirm

#,,..,,,,,,.,,,,.,.,.,,,,,,,.,.,.,.,.,,.,,,..,..,,...,...,,,,,.,,,,,.,,,.,,.,,
#BDZDOUYOKXWWY4TJSYNKEIUPYNZ6AXKYTDZ7JXESPWTLTLTMD624TPJRWF6RIANE7KNBFSU3JTCHM
#\\\|5Y3ACZ4IVSBKCF3TKPUZRLKIQ6ZM3N6X3C5R6W7Y26ZQXZO35PG \ / AMOS7 \ YOURUM ::
#\[7]I42EEIIYVQAXCJYWLUNJGM4PWGA4TCPRE4AIWRSPHVD2XYVGVSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
