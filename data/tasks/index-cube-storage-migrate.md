## [:< ##

# task: index zenka — schema v2 to v3 migration

implement `index.migrate.v2-to-v3` — read the existing `.zxps` (schema v2
monolithic storable), build a schema v3 `.zxpc` cube in one pass, and update
`index.init_code` to prefer the cube restore path. keep the old file as
`.zxps.v2.bak` for safety.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## module: index.migrate.v2-to-v3 (new)

### when it runs

triggered automatically by `index.persist.cube` when:

```perl
my $zxpc = <[path.zenka_dir]>->('numerical/numerical-index_state.zxpc');
my $zxps = <[path.zenka_dir]>->('numerical/numerical-index_state.zxps');

if ( not -f $zxpc and -f $zxps ) {
    <[base.log]>->( 1, 'index.migrate: v2 found, v3 missing — starting migration' );
    return <[index.migrate.v2-to-v3]>->($zxps, $zxpc);
}
```

### what it preserves

all data from the v2 state must survive:

- `freq`           — ring-0 character frequencies
- `level`          — ring N-gram frequencies
- `terminal`       — terminal flag per prefix
- `contributions`  — contribution vectors (if present)
- `addr`           — address mapping
- `packed_rank`    — rank packing tables
- `trie`           — the full trie structure

### migration flow

```perl
sub index.migrate.v2-to-v3 {
    my ( $v2_path, $v3_path ) = @ARG;

    ## 1. load v2 state via existing restore path ##
    my $v2_state = <[index.restore.v2]>->($v2_path);
    return unless defined $v2_state;

    ## 2. temporarily install v2 state into live zenka keys ##
    local <index.freq>         = $v2_state->{'freq'}         // {};
    local <index.level>        = $v2_state->{'level'}        // {};
    local <index.terminal>     = $v2_state->{'terminal'}     // {};
    local <index.contributions> = $v2_state->{'contributions'} // {};
    local <index.addr>         = $v2_state->{'addr'}         // {};
    local <index.packed_rank>  = $v2_state->{'packed_rank'}  // {};
    local <index.trie>         = $v2_state->{'trie'}         // {};

    ## 3. build cube via writer ##
    my $ok = <[index.persist.cube]>->($v3_path);
    return unless $ok;

    ## 4. verify by re-loading the cube ##
    my $verify = <[index.restore.cube]>->($v3_path);
    return unless defined $verify;

    ## 5. backup old file ##
    my $bak_path = $v2_path . '.v2.bak';
    rename( $v2_path, $bak_path )
        or <[base.log]>->( 0, "index.migrate: backup failed [ $! ]" );

    <[base.log]>->( 1, 'index.migrate: v2 -> v3 complete' );
    return TRUE;
}
```

### schema version detection

```perl
sub index.cube.detect_schema {
    my ($path) = @ARG;

    open( my $fh, '<:raw', $path ) or return;
    my $magic;
    read( $fh, $magic, 4 );
    close($fh);

    return 'v3' if $magic eq 'P7IC';
    return 'v2' if $magic =~ m/^pst0/;   ## storable magic
    return 'unknown';
}
```

first 4 bytes `'P7IC'` → v3 cube loader. storable header (`pst0`) or no
recognizable magic → v2 zxps thaw path.

---

## module: index.init_code (modify)

change the restore sequence to try cube first, fall back to v2:

```perl
## schema v3 cube preferred, v2 legacy fallback ##
my $restored = <[index.restore.cube]>->();

if ( not defined $restored ) {
    <[base.log]>->( 1, 'index.init: cube not found, attempting v2 restore' );
    $restored = <[index.restore.v2]>->();
}

if ( not defined $restored ) {
    <[base.log]>->( 1, 'index.init: no state restored, starting fresh' );
    <index.freq>     //= {};
    <index.level>    //= {};
    <index.terminal> //= {};
    <index.trie>     //= {};
}
```

if `index.restore.cube` detects a v2 file and no v3 file, it may trigger the
migration inline or simply return `undef` and let the v2 fallback handle it.
the cleanest separation: `index.restore.cube` only loads v3; `index.init_code`
calls v2 fallback explicitly.

---

## module: index.persist.cube (modify)

add migration trigger at the top of the persist path:

```perl
sub index.persist.cube {
    my ($target_path) = @ARG;

    my $zxpc = $target_path
        // <[path.zenka_dir]>->('numerical/numerical-index_state.zxpc');
    my $zxps = <[path.zenka_dir]>->('numerical/numerical-index_state.zxps');

    ## auto-migrate if v3 missing but v2 present ##
    if ( not -f $zxpc and -f $zxps ) {
        my $migrated = <[index.migrate.v2-to-v3]>->($zxps, $zxpc);
        return $migrated if $migrated;
    }

    ## ... normal v3 persist logic ...
}
```

---

## notes

- prerequisite: `index-cube-storage-writer` task
- the v2 state can be large (36MB xz-compressed). migration holds both the v2
  thawed structure and the v3 serialized bytes in memory simultaneously — peak
  memory will be higher than normal operation. consider running migration
  during a maintenance window or with a memory cap.
- `.zxps.v2.bak` is kept for one cycle. after the v3 cube has been verified
  through normal operation, the backup may be removed manually or by a future
  cleanup task.
- if migration fails at any step (write error, verify mismatch, disk full),
  the v2 file is left untouched and the v3 partial file is unlinked.
- `index.restore.v2` should be factored out of the existing `index.restore` if
  it is not already a separate module, so that both `index.init_code` and
  `index.migrate.v2-to-v3` can call it directly.

#,,,.,.,.,..,,,..,.,,,,..,...,..,,.,,,...,...,..,,...,...,...,..,,..,,.,.,,..,
#AV7ITDPYWO33VV4XQZHAKRJ2AO4A5RZDTURL4D7MZHMAULYHYEAKOK3PV66K5RYIIRQW6YOM4CTE4
#\\\|FIINS7QWYQTX4E5KAVVTDXXNU6TGOZX3F5U4B5VULP3N4UAGFCJ \ / AMOS7 \ YOURUM ::
#\[7]5B6M7HPOAWYUN73WFKM2AQUPMB274JSHW5IZB3Q6NAIIRZQIYWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
