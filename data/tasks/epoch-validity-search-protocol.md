## [:< ##

# name  = task: epoch validity windows + checksum search protocol
# descr = v7 epoch timestamp as temporal network root: collision exclusion
#         window, rolling triple-epoch validity, and checksum-based search
#         protocol where the search result's BMW384 checksum IS its route.

## context

the v7 epoch timestamp (e.g. `V7L36SA`) is already embedded in the system.
this task elevates it to a **temporal network root** — a pre-grouping parent
that gives keys and user identities an auto-closing collision exclusion window.

design context: `data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md`
relates to: `data/tasks/epoch-bmw-l13-truth-templates.md`,
            `data/tasks/epoch-chksum-path-helper.md` (check if these landed)

## part A: epoch as temporal collision exclusion

### the problem

user-key collision: two users independently generate the same key.
timestamp collision: near-current entropy is easier to brute-force.

### the solution: `<epoch>:<key>` or `<epoch>:<key>:<name>`

the v7 epoch participates in the key/name entropy:

```
raw key:          K                    (collision-possible across epochs)
epoch-scoped key: V7L36SA:K           (collision excluded within epoch window)
epoch+name:       V7L36SA:K:username  (human-readable + epoch + key triple)
```

once an epoch expires, nothing new can generate the same `<epoch>:<key>` pair.
network-wide accidental collision within one epoch: vanishingly unlikely.
users can memoize their creation epoch (e.g. `V7L36SA`) as their identity
anchor — stable, human-memorable, yet entropy-backed.

### rolling triple-epoch validity window

only three epochs are simultaneously valid:

```
previous epoch:   transitional — keys created here still accepted
current epoch:    primary — all new operations use this epoch
next epoch:       preparatory — can be computed in advance
```

any index, cache, or route using an epoch-scoped key outside this window
is considered expired. the triple window matches the rolling triple-window
from `categorical-compartmentalization.yaml` applied to temporal validity.

### epoch directories as storage pattern

```
data/store/V7K28AB/   ← previous epoch (archival, read-only)
data/store/V7L36SA/   ← current epoch (read-write)
data/store/V7M44CD/   ← next epoch (prepared, not yet active)
```

benefits:
- natural rollback grouping (revert to previous epoch directory)
- scanner defense (epoch prefix is not guessable without knowing current epoch)
- forensics timeline: every resource is epoch-stamped at creation
- empty epoch dirs auto-collapse; populated ones mark events
- older epochs can be squashed into difference layers (delta compression)

## part B: checksum-based search protocol

### the insight

the BMW384 checksum of a search result IS its route in the network.
the search process and the content routing process are the same operation.

### protocol steps

```
step 1: client computes search token
        amos-chksum 'search.type : <pattern>'
        → short checksum e.g. KU5GOWY
        sent into the network as the search request

step 2: network processes search, produces result
        result has a BMW384 checksum (content identity)
        network returns: short confirmation checksum (BMW-L13 or similar)
        that proves the search performed matches an even-longer BMW384
        content checksum of the result

step 3: BMW384 checksum doubles as the route
        the content checksum is simultaneously:
        - proof of what the result contains (content identity)
        - the address of the result in the network (route ID)
        - the cache key for any cached copy of this result

step 4: transparent cache reply
        any zenka with a local cache registered on that BMW384 route
        can reply before the primary store responds — transparently,
        without the client knowing whether the reply came from cache
        or primary. the BMW384 content checksum guarantees the cache
        hit is faithful.
```

### the three-checksum result structure

```
search_token:     KU5GOWY           (7-char, sent by client)
confirmation:     BMW-L13 checksum  (proves search→result mapping)
content_id:       BMW384 checksum   (IS the route + IS the cache key)
```

### implementation modules

```
search.token.compute    amos-chksum of 'type : pattern' → short token
search.confirm          verify BMW-L13 confirmation ties search to result
search.route            BMW384 checksum → route ID for content fetch
search.cache.register   register a BMW384 route with a local cache
search.cache.reply      check local cache before forwarding to primary
```

## implementation order

```
phase 1:  epoch-scoped key format parser/formatter
          <epoch>:<key> and <epoch>:<key>:<name> round-trip
          epoch validity window check (previous/current/next)

phase 2:  epoch directory storage pattern
          epoch.dir.current / epoch.dir.previous / epoch.dir.rotate
          epoch rollover: current → previous, next → current

phase 3:  search token computation
          search.token.compute ( type, pattern ) → short token
          search.confirm verification

phase 4:  BMW384-as-route integration
          search.route ( bmw384_chksum ) → route for content fetch
          search.cache.register + search.cache.reply

phase 5:  epoch-scoped index checksumming
          all networked indices salted with current epoch
          rollover: re-sign indices as epoch transitions
```

## dispatch prompt

implement phase 1 and 2 of the epoch validity window system.

1. create `modules/epoch.validity.*`:
   - `epoch.validity.current` — return current epoch string from v7 epoch
   - `epoch.validity.window` — return { previous, current, next } epoch set
   - `epoch.validity.check` — given an epoch string, return TRUE if in window
   - `epoch.validity.format-key` — format `<epoch>:<key>` or `<epoch>:<key>:<name>`
   - `epoch.validity.parse-key` — parse that format → { epoch, key, name }

2. create `modules/epoch.dir.*`:
   - `epoch.dir.current` — return current epoch directory path
   - `epoch.dir.rotate` — advance previous→archive, current→previous, next→current
   - `epoch.dir.ensure` — create epoch directory structure if not present

3. add p7c commands:
   - `p7c epoch.current` — show current epoch + window
   - `p7c epoch.check V7L36SA` — is this epoch in the validity window?
   - `p7c epoch.format-key <key> [<name>]` — format epoch-scoped key
   - `p7c epoch.dir.rotate` — advance epoch window

check `data/tasks/epoch-bmw-l13-truth-templates.md` and
`data/tasks/epoch-chksum-path-helper.md` for what may already be
implemented — build on rather than duplicate.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,,,..,,...,..,,,.,,,,.,...,...,,.,,,.,,...,..,,...,...,.,,,.,,,.,.,,,.,,.,,
#Z77WUFHXDQVFE5U2DSJDRFJK22NRB43PMRDOHME4W66YW2Z6GIIEU7VW7PZAV7ETG55PA2MWMPLCY
#\\\|N7F5VWZCTZW2DWKP6YDLY5SEYD4QDYJGZYF4TK65BL2IWAUEQ65 \ / AMOS7 \ YOURUM ::
#\[7]E6N4BJNQQI2X2QMYNEE7BDLJMEW752ITCNPJWLOMAXOJUX4PVSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
