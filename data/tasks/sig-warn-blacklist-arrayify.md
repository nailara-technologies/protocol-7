## [:< ##

# name  = task: array-ify $data{'sig_warn_blacklist'}
# descr = the central $SIG{__WARN__} handler's warning-suppression
#         blacklist is a single hash slot (one package + one pattern),
#         not a list -- a pre-existing, pre-LLM-era TODO already marked
#         in the code -- so it can't support more than one concurrent
#         suppression need without callers stomping each other

## context

found 2026-09-10 while chasing a recurring, not-yet-root-caused
`Prototype mismatch: sub main::decode_json: none vs ($)` warning (see
`data/ai-mem/claude/bug-fetch-files-huggingface-four-real-bugs-2026-09-10.md`).
A local `$SIG{__WARN__}` override inside `src/base.perlmod.autoload`
(suppressing a known List::MoreUtils `qsort`/`bsearch` prototype
mismatch) was found to be silently bypassing the ENTIRE central warning
pipeline for the duration of every autoload call -- not just the one
pattern it targeted. Removed entirely per the user
(`data/ai-mem/claude/bug-local-sig-warn-bypasses-central-blacklist.md`
has the full writeup). The user confirmed the intended, correct
mechanism is the blacklist already sitting in `bin/Protocol-7`'s real
handler, and asked for this array-ification to be filed as its own task.

## the actual mechanism [ read directly from bin/Protocol-7, ~line 4234 ]

```perl
if ( defined $data{'sig_warn_blacklist'} ) {    # <-- use array [LLL]
    return
        if defined $data{'sig_warn_blacklist'}{'package'}
        and $package eq $data{'sig_warn_blacklist'}{'package'}
        or defined $data{'sig_warn_blacklist'}{'pattern'}
        and join( ' ', @err )
        =~ $data{'sig_warn_blacklist'}{'pattern'};
}
```

this sits inside the process's real, central `$SIG{__WARN__}` handler
(which also does deep-recursion detection with an emergency-exit safety
net, caller-chain cleanup, filename shortening, and a
`<{C[level]}>`-style parent-caller redirect -- read the surrounding
~50 lines before touching this, all of that logic must keep working
for every warning that ISN'T blacklisted). `$data{'sig_warn_blacklist'}`
is a single hash: one `package` match XOR one `pattern` regex match, not
a list of independent entries. The `# <-- use array [LLL]` comment
already marks this as known-incomplete, predating this session.

## scope

1. change `$data{'sig_warn_blacklist'}` from a single hash to an array
   of hashes (each `{'package' => ..., 'pattern' => ...}`), checking
   ALL entries rather than just the one slot -- decide the exact
   iteration/short-circuit semantics (first match suppresses, same as
   today's single-entry OR-across-package/pattern logic, just repeated
   per array element).
2. find every current reader/writer of `<sig_warn_blacklist>` across
   `src/`/`bin/` (grep for the literal string, not just this one read
   site -- there may be write sites setting the single hash today that
   need to become array-push instead) and update them to the new shape.
3. decide whether entries need a TTL/scope (e.g., auto-removed after
   the specific call site that added them finishes, so a suppression
   doesn't leak indefinitely) or are meant to be permanent/global,
   process-lifetime entries -- the CURRENT single-hash usage (whatever
   it is, confirmed by step 2's grep) tells you which semantics existing
   callers actually rely on; don't guess without checking.
4. **do not reintroduce a local `$SIG{__WARN__}` override anywhere** as
   part of this work -- the whole point is that suppression should only
   ever happen through this one central, declarative mechanism.
5. the `decode_json` prototype-mismatch warning that originally
   motivated this (see the bug file referenced above) turned out to be
   fully root-caused after all (a real JSON::XS vs JSON::PP symbol
   collision, fixed by not loading JSON::PP) -- no longer a pending
   candidate for this blacklist. The still-open, not-yet-root-caused
   candidate is the pre-existing List::MoreUtils `qsort`/`bsearch`
   prototype mismatch that `base.perlmod.autoload`'s (now-removed) local
   override used to silence -- that one is the fallback candidate for
   this array-ified mechanism, root-causing it first is still preferred.

## explicitly out of scope

- do not attempt to root-cause the `qsort`/`bsearch` List::MoreUtils
  warning itself as part of this task -- that's a separate thread
- do not touch anything else in `bin/Protocol-7`'s warning handler
  beyond the blacklist-check block itself unless a bug is found there
  during this work (in which case, document it separately, same
  discipline as everything else this session)

do not add any trailing signature/checksum footer to this file or any
new file for this task -- the real signing pipeline (`bin/Protocol-7
sourcecode update-signatures`) adds that later.

#,,,,,,,,,,,,,..,,...,,,.,,.,,,,.,.,,,.,.,..,,..,,...,...,.,.,,.,,.,,,.,,,.,.,
#3JPWDASJOVOV2MATEQQCA2LJMIU4XTGU7526XHMCDIZDKVCAALIPNAX7LXWRIW3D4F7VHCSP6RNTI
#\\\|AJLRPVTUVQ76U4RPXK42S3UATUVVHHC4N26QH7EM5FIJBQRLV4Q \ / AMOS7 \ YOURUM ::
#\[7]BGRANDMULDRM7O6IBYUF33FWOBS2S5KZSK56IVK4TAN7NPTNJGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
