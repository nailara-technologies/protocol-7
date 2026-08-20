# task: index zenka — init_code + data structure

## context

implementing the `index.*` zenka — a numerical language deduplication tree
that builds a self-organizing frequency-ranked address space from raw text.
the corpus shapes its own geometry through use. no wordlist initialization
needed — the tree discovers its own vocabulary.

see `data/md/design/NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md` for full design.
see `data/md/design/ZERO-AS-ETERNAL-TREE.md` for root semantics (-1 vs 0).
see `data/md/design/RING-FIELD-SPHERE-PRIMITIVE.md` for disk/ring geometry.

## data structure

all data lives in the `index` namespace using P7 tree syntax:

```perl
<index.freq>->{$token}      ## frequency count per token (any string)
<index.addr>->{$token}      ## token -> numerical address (rank)
<index.rank>->{$addr}       ## address -> token (reverse map)
<index.seq>->{$sequence}    ## higher-order token registry (dedup sequences)
<index.level>->{$n}         ## hashref of tokens at abstraction disk N
<index.meta>->{'root'}      ## '' as -1 (signed root, outside address space)
<index.meta>->{'total'}     ## total tokens ingested
<index.meta>->{'dirty'}     ## TRUE if rebalance needed
```

the empty string `''` is special: it is -1, the signed root outside the
address space. it generates the address space without occupying it.
`<index.meta>->{'root'} = ''` marks it as present and initialized.

disk 0 is the character level. disk 1 is the token/word level. disk N is
higher-order compressed sequences. each disk is a hashref under
`<index.level>->{$n}` mapping token => address_at_this_level.

## signatures note

the module files will have 5-line AMOS7 signature footers already present.
do NOT modify, remove, or regenerate signatures. do NOT add stub signatures.
leave the footer exactly as-is. only edit code above the signature block.
the signature block begins with a line matching `^#,,`.

## file to create

`src/index.init_code`

```
## [:< ##

# name = index.init_code
# descr = initialize index zenka data structures
```

## implementation

initialize all data structures to empty/default state:

```perl
<index.freq>   = {};
<index.addr>   = {};
<index.rank>   = {};
<index.seq>    = {};
<index.level>  = {};
<index.meta>   = {
    root  => '',       ## '' is -1, the signed root outside address space
    total => 0,
    dirty => FALSE,
};

## disk 0 is the character level — initialize empty ##
<index.level>->{0} = {};

<[base.log]>->( 1, 'index zenka initialized [ numerical language tree ]' );
```

also create the zenka start file and configuration referencing standard
modules. look at an existing simple on-demand zenka (e.g. `calc`) for the
start file pattern. the index zenka should be on-demand with a reasonable
idle timeout (e.g. 4200s like calc).

## success criteria

- [ ] `src/index.init_code` created with correct module header
- [ ] all data structures initialized correctly
- [ ] `<index.meta>->{'root'}` set to `''` (-1 semantics documented in comment)
- [ ] `<index.level>->{0}` initialized as empty hashref
- [ ] uses FALSE/TRUE constants not 0/1
- [ ] uses `$ARG` not `$_`
- [ ] no stub signatures added
- [ ] zenka start file created (cfg/zenki/index/start)
- [ ] module passes ptd

#,,.,,,,,,,,.,,..,,,,,,.,,.,.,,..,.,.,,,,,.,.,..,,...,...,..,,,,.,,.,,..,,..,,
#BXDEJBR32LKTC7GAPAUFWYGEEBHLRZHWA6VGQITWBVOH22EKHCYXQLO7RRVEQFOM6VK42S3PU2TW4
#\\\|JGY2GIQKNWBDZBM2LX7EBHTUG5TFW5ACDJ2AXWSPS5CFGSZR4R7 \ / AMOS7 \ YOURUM ::
#\[7]6IFBLYPOCKIZ5SFZWR4FL4BJAWCYAJNL3ISBNKMPLO6VJKI2Y2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
