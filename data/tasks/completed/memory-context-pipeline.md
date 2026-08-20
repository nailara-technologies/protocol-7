## task: memory-context-pipeline

## dispatch
wire the scored memory tree into the LLM context injection pipeline.
the memory zenka already builds + scores the tree; the coding zenka still
uses a flat alphabetical dump. bridge them through a cache file written
by `memory.render.context` and read by `context.memory.load`.

read first:
`src/memory.render.context`,
`src/context.memory.load`,
`src/memory.tree.render`,
`src/memory.startup`,
`src/memory.cmd.search`,
`src/memory.cmd.digest`,
`cfg/zenki/memory/start`.

do NOT touch signatures or unrelated logic. do NOT add `#,,..,.,,,...` stubs.

## context: why a cache file

memory zenka and coding zenka are SEPARATE processes — `context.memory.load`
cannot call `memory.render.context` synchronously. the bridge is a small
on-disk cache that memory writes after each render and coding reads on
demand. fall back to the existing flat dump when the cache is missing or
stale, so coding still works when memory zenka is down.

cache path:
- `<system.root_path> . '/var/memory-context-cache.txt'`    — tree text
- `<system.root_path> . '/var/memory-context-cache.ntime'`  — write ntime

freshness window: 600 seconds. older than that → fall back to flat load.

writes are atomic: write to `.tmp` then rename, so a partial file is never
visible to readers.

## implementation

### change 1: `src/memory.render.context` (MODIFY)

after computing `$tree`, write it + the timestamp to the cache files,
then return as before. failure to write must NOT cause the module to die —
log at level 1 and continue.

```perl
## [:< ##

# name = memory.render.context
# descr = plain ascii tree render for llm context injection

my $params = shift // {};
my $n      = $params->{'n'};

my $tree = <[memory.tree.render]>->( { variant => 'compact', n => $n } );
$tree //= '';

## [ write cache for cross-zenka context.memory.load consumption ]##
my $root      = <system.root_path>;
my $cache_txt = "$root/var/memory-context-cache.txt";
my $cache_nt  = "$root/var/memory-context-cache.ntime";
my $ntime_now = <[base.ntime]>;

eval {
    ## [ atomic-ish write : tmp + rename ]##
    my $tmp_txt = "$cache_txt.tmp";
    my $tmp_nt  = "$cache_nt.tmp";

    open( my $fh_t, '>:utf8', $tmp_txt ) or die "open $tmp_txt : $OS_ERROR";
    print {$fh_t} $tree;
    close $fh_t or die "close $tmp_txt : $OS_ERROR";
    rename( $tmp_txt, $cache_txt ) or die "rename $tmp_txt : $OS_ERROR";

    open( my $fh_n, '>:utf8', $tmp_nt ) or die "open $tmp_nt : $OS_ERROR";
    print {$fh_n} $ntime_now;
    close $fh_n or die "close $tmp_nt : $OS_ERROR";
    rename( $tmp_nt, $cache_nt ) or die "rename $tmp_nt : $OS_ERROR";

    TRUE;
} or <[base.logs]>->( 1, ':. memory.render.context : cache write failed [ %s ]', $EVAL_ERROR );

return $tree;
```

notes:
- use `$OS_ERROR` and `$EVAL_ERROR` (English already in scope per project style)
- if `file.write_scalar` exists in this codebase and is preferred, the eval
  block may use it instead — but the atomic tmp+rename behaviour must be
  preserved either way
- the `var/` dir is expected to exist (standard p7 layout); do not mkdir

### change 2: `src/context.memory.load` (MODIFY)

prepend a cache-check stanza at the TOP of the module body (after the
`my $params = shift // {};` line). if the cache file is present AND its
companion ntime file shows it was written within the last 600 seconds,
slurp + return it directly with NO budget truncation — the scored tree
is already sized appropriately. otherwise fall through to the existing
flat-file logic unchanged.

```perl
## [ try scored tree cache from memory zenka first ]##
my $root      = <system.root_path>;
my $cache_txt = "$root/var/memory-context-cache.txt";
my $cache_nt  = "$root/var/memory-context-cache.ntime";

if ( -f $cache_txt and -f $cache_nt ) {
    my $written_at;
    if ( open( my $fh_n, '<:utf8', $cache_nt ) ) {
        local $INPUT_RECORD_SEPARATOR;
        $written_at = <$fh_n>;
        close $fh_n;
        $written_at =~ s|\s+||g if defined $written_at;
    }

    my $age = defined $written_at ? ( <[base.ntime]> - $written_at ) : 99999;

    if ( $age >= 0 and $age <= 600 ) {
        if ( open( my $fh_t, '<:utf8', $cache_txt ) ) {
            local $INPUT_RECORD_SEPARATOR;
            my $cached = <$fh_t>;
            close $fh_t;
            if ( defined $cached and length $cached ) {
                <[base.logs]>->(
                    2, ':. context.memory: using scored tree cache [ %d chars ]',
                    length $cached
                );
                return $cached;
            }
        }
    }
}

<[base.logs]>->( 2, ':. context.memory: cache miss, using flat file load' );

## [ fall through to existing flat-file load below ]##
```

leave everything after this block as-is.

### change 3: `src/memory.startup` (MODIFY)

after `<memory.ready> = TRUE;` and the existing `base.logs` call, prime
the cache so the first coding task finds it ready. guard with eval so a
render error never breaks startup:

```perl
## [ prime context cache on startup ]##
eval { <[memory.render.context]>; };
```

place immediately before `return TRUE;`.

## style rules (mandatory)
- comments lowercase, no capitals
- snake_case for any new variables
- no manual AMOS7 signature stubs in new or modified files
- module descr ≤ 55 chars (no changes to descr here — leave as-is)
- no trailing whitespace
- `TRUE` / `FALSE` not `1` / `0`
- opening brace on same line: `if ( ... ) {`

## acceptance
- after `p7c v7.restart memory`,
  `cat /data/projects/protocol-7/var/memory-context-cache.txt`
  shows the scored tree (highest-ranked branches at the top)
- `cat /data/projects/protocol-7/var/memory-context-cache.ntime`
  shows a recent numeric ntime value
- `p7c coding.submit "explain memory.render.context"` uses the scored
  cache — log at level 2: `context.memory: using scored tree cache`
- with memory zenka stopped + cache files removed, `context.memory.load`
  falls back to the flat load — log: `cache miss, using flat file load`
- no pre-commit hook failures
- no manual AMOS7 signature stubs added to any file

#,,,.,,,.,.,.,..,,...,.,,,.,,,.,.,...,,..,..,,..,,...,...,,,,,,.,,.,.,,,,,.,.,
#MJQWWN7FX35ILIK4DRBQNZ4EVWOKEW5QOGZFYUGEQZ347NOVUQBBRNIX3SWYKZ73TOCMKE6RIVQYY
#\\\|32364EJR4WABH3AEBU4UW5YZB2L5HDMSFH3RW4FPCGP2KOTZ57D \ / AMOS7 \ YOURUM ::
#\[7]VQVQHI4V3RNJ6JW2KCIA4TTYNH3PCAMUB7HPCYIFX53TXBNQ46DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
