# N7FS search index : design notes

status : design only, nothing built. `n7fs find` is a plain scan of the meta
records ; meta records are NOT signed in format 1, the bytes verify against
their address but a name -> address mapping does not. what follows assumes
signed meta [ spec : 'store key signs meta and state', still only suggested ]
-- that decision comes before any index relying on it. every index type here is an optional speed-up on top of that scan,
and the scan stays the fallback. the on-disk details are open.

## index types

**type id** : the checksum of the type name string selects the code path, a
signed record inside its directory gives the settings.

    index/<type-chksum>/...

- the name form is exactly `<name>:<4 digits>` : `word-groups:0001`. no colon
  in the name, one colon, always four digits. `word-groups:1` is invalid, it
  would hash differently -- tools refuse any other spelling. the literal
  string of each type is frozen by the spec, tests pin its checksum
- several indexes can sit side by side ; a client skips a checksum it does not
  know and falls back to the scan
- no registry : a new type needs no assigned number
- the checksum identifies, it does not hide : type names are a small guessable
  set, a reader learns which types a disk has
- settings [ lossy width, length buckets, key id ] and the plain type name for
  tools live in the signed record, not in the name
- existing record labels [ `p7 n7fs meta v1` ] are signed on disk and stay ;
  moving them to the new form would be a format conversion

## exact lookup

the checksum of the search term, optionally with a prefix, or of the path,
addresses the result directly. fast, the whole term must be known.

## word groups

a name is split into words, each word's checksum addresses a reference node
group. a group does not answer, it narrows : the match is somewhere among its
members. the meta records decide the real match, signed ones once that exists.

- false positives only cost scanning, with signed meta a wrong result cannot pass the meta check
- a missing member hides a real result : a tampered group can do this, so
  groups need signing where that matters, and a stale group can too -- new
  files reach the groups before an import counts as finished, or a search also
  scans what is newer than the index
- the split rule is part of the type : changing it means a new type and a rebuild
- regex searches use groups only for a literal word found in the pattern, else
  they stay full scans
- open : words from names and paths only, or from content too [ far larger ]

## the kill chain

smaller groups narrow larger ones, the cost follows the smallest group :

1. sort the words by group size, smallest first
2. the smallest group's members are the candidates
3. each larger group only answers whether it holds a candidate ; the others die
4. no candidates left : stop, larger groups are never read
5. survivors go to the meta scan

a chain may stop early when few candidates remain and reading their meta costs
less than more probes.

**format needs** : a member count in each word's head [ the order is chosen
before anything is read, approximate is fine, a wrong count only costs speed ],
members sorted or split by checksum prefix. checksums spread evenly, so a large
group splits into segments and a probe opens only those its candidates land in.
this also settles very common words : they are probed, never read whole.

**exclusions** : `-word` drops candidates found in that group. needs an exact
group [ a chance match in a lossy one would drop a real result ] and cannot
start a chain. **or** searches combine their branches, each runs its own chain.

**updates** : content-addressed groups change address with each member, so a
word needs a current head or append-only segments merged later. same missing
piece as `references/` in format 1, design them together.

## exposure

an index type declares what it exposes, the fast types stay allowed with a
warning that says so.

| type | an index reader can see | search cost |
|---|---|---|
| exact lookup, unkeyed | whether a guessed term or path exists | direct |
| word groups, keyed and lossy | group sizes, which nodes share groups | medium, more scanning |
| word groups, unkeyed | the above, plus dictionary guesses of the words | medium |
| with term length columns | the above, plus each term's length | lowest |

**term length columns** split a group by length : a cheaper chain, fewer chance
collisions in lossy groups. this is already a deanonymizing type : hashing the
length hides nothing since lengths are a small set, a key still leaves the
column sizes. known lengths shrink the guessing space, and length patterns
fingerprint known titles or paths. coarse buckets [ 1-4, 5-8, 9+ ] keep part of
the gain and reveal less.

keep separate indexes per trust level. rebuilding a weak index as a stronger
one does not undo the exposure if the old one was copied.

## also possible

a link tree of names -> addresses, in the way of `source.cmd.update-src-links`,
built from the same meta entries.

#,,,.,.,,,,.,,,,,,,..,,,,,,.,,.,.,,..,.,.,.,,,..,,...,..,,..,,,..,,,,,,..,,,,,
#3IV7XTDNT5FC6FWIQOIUUMVF3AGLKDZX7XKPMN5OQQLKJWQCHX6SIEBAYEP2MUFV3WMTH6SBF5GN6
#\\\|WBO2XQHUPT34ICTXJ6MYIXVKKVWUHC4YRV643RRMT5U2QFSUFJR \ / AMOS7 \ YOURUM ::
#\[7]3FQWSWSP3UPUMVLASAPA5FLOZXF3FHS4ZGUR6QPQ7HPGZ2RC7EBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
