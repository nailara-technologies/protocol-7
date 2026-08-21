## [:< ##

# task: index zenka — persist and restore index state

save the current index to disk and restore on startup — avoiding full re-feed
after restart. save the raw corpus data; derived structures rebuild from it.

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## what to save

only the raw corpus data — everything else is derived and can be rebuilt
by calling `<[index.rank]>->()` after restore:

- `<index.meta>` — total chars, root, dirty flag
- `<index.freq>` — character frequencies (ring 0 source)
- `<index.level>` — sequence frequencies per window (ring 1-7 source)

do NOT save `<index.addr>`, `<index.packed_rank>`, `<index.trie>` — these
are rebuilt by `index.rank` from the above in seconds.

## storage format

use `Storable` (already available in perl core):

```perl
use Storable qw( nstore retrieve );
```

save path: `<index.path.index-files> . '/index-state.storable'`

---

## module: index.persist

```
# name  = index.persist
# descr = save raw corpus data to disk via Storable
```

```perl
<[base.perlmod.autoload]>->( 'Storable', qw( nstore ) );

my $path = <index.path.index-files> . '/index-state.storable';

my $state = {
    'meta'  => { %{ <index.meta>  // {} } },
    'freq'  => { %{ <index.freq>  // {} } },
    'level' => { map { $ARG => { %{ <index.level>->{$ARG} } } }
                     keys %{ <index.level> // {} } },
};

nstore( $state, $path )
    or return <[base.log]>->( 1, "index.persist: failed [ $path ]" );

my $total = <index.meta>->{'total'} // 0;
<[base.log]>->( 1, "index persisted [ $total chars -> $path ]" );

return TRUE;
```

---

## module: index.restore

```
# name  = index.restore
# descr = load raw corpus data from disk and rebuild derived structures
```

```perl
<[base.perlmod.autoload]>->( 'Storable', qw( retrieve ) );

my $path = <index.path.index-files> . '/index-state.storable';

return FALSE if not -r $path;

my $state = retrieve($path);
return FALSE if not defined $state;

<index.meta>  = $state->{'meta'}  // {};
<index.freq>  = $state->{'freq'}  // {};
<index.level> = $state->{'level'} // {};

## rebuild all derived structures ##
<[index.rank]>->();

my $total = <index.meta>->{'total'} // 0;
<[base.log]>->( 1, "index restored [ $total chars from $path ]" );

return TRUE;
```

---

## module: index.cmd.persist

```
# name  = index.cmd.persist
# descr = save index state to disk
```

```perl
my $ok = <[index.persist]>->();
return $ok
    ? { 'mode' => 'size', 'data' => 'index state saved' }
    : { 'mode' => 'false', 'data' => 'persist failed' };
```

---

## module: index.cmd.restore

```
# name  = index.cmd.restore
# descr = restore index state from disk
```

```perl
my $ok = <[index.restore]>->();
return $ok
    ? { 'mode' => 'size', 'data' => 'index state restored' }
    : { 'mode' => 'false', 'data' => 'no saved state found' };
```

---

## auto-restore on startup

in `src/index.init_code`, after the data structure initialization block,
add:

```perl
## auto-restore if saved state exists ##
if ( -r <index.path.index-files> . '/index-state.storable' ) {
    <[index.restore]>->();
}
```

---

## access list

add `persist restore` to `access.cmd.usr.cube` in
`cfg/zenki/index/zenka.v7`

---

## whitelist

add `index.persist index.restore` to
`cfg/zenki/index/subroutine.white-list`

---

## notes

- `Storable::nstore` uses network byte order — portable across architectures
- restore calls `index.rank` which rebuilds addr, packed_rank, trie from
  freq + level — takes a few seconds, much faster than re-feeding
- the storable file will be ~10-50MB for a full data/md corpus
- index.init_code already loads the path config before this runs

#,,..,,,.,..,,.,.,.,,,.,.,,,.,,.,,,,.,..,,,.,,..,,...,...,,,.,,,.,,,,,..,,..,,
#GXAN2OROHJBFPBRQ34QUZZB5PX4HP2KEGC2LRXNTO7NJMWR3IJG63NB5YCTYLIJGNJVYSECVDREM6
#\\\|54NFQ6XCR7Q4T66WTLCJGJE3P4DDXU4A7IA4PV7GSPGVK6J2M4M \ / AMOS7 \ YOURUM ::
#\[7]3XV23D6URRGS35WO3RYVP4FN2SDRVYXFW2DBMDYFBUREKTM26OBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
