# zenka name resolution through the launcher symlink chain

## what this covers

how `bin/Protocol-7` decides *which zenka* it is starting when it was
invoked under a name other than its own, and what happens to the other
names it walked through on the way there.

before this, resolution was a single-hop pattern match against
`$PROGRAM_NAME` — the name the process was `exec`'d under. that works
only when the *directly invoked* name itself carries a recognized
prefix. a user's own convenience symlink does not:

```
~/bin/radio-jazz  ->  /usr/local/bin/p7-radio  ->  <root>/bin/Protocol-7
```

`$PROGRAM_NAME` here is `radio-jazz`, which matches none of the known
forms, so the old code fell through to the bare-`$ARGV[0]` branch —
wrong when arguments were given, and "no zenka name" when they were
not. the same match was also written out twice, in two places that
had already drifted apart in their comments.

## the terminal segment rule

a link name **names a zenka** when its *basename* is one of three
forms, the remainder of the basename being the zenka name:

```
p7-<zenka>            current form, installed by
                      <[v7-zenki.install_zenka_symlinks]> into
                      /usr/local/bin/ [ v7-zenki.cfg.zenka_symlink_dir ]
v7.<zenka>            deprecated form, superseded by 23a0e8d53
Protocol-7.<zenka>    interpreter-name form
```

three properties of that rule are deliberate and load-bearing:

- **basename only.** the old patterns were `m|^.*p7-|` style — a
  greedy any-prefix match that got away with it only because
  `$PROGRAM_NAME` is normally a bare name. the chain walk feeds *full
  paths* in, so a directory component would otherwise be able to name
  the zenka: `/opt/v7.tools/bin/radio-jazz` must not resolve to
  `tools`.
- **a bare `Protocol-7` is not recognized.** it carries no trailing
  dot, so it does not match `Protocol-7.<zenka>`. this is exactly why
  `./bin/Protocol-7 httpd` keeps naming its zenka through the argument
  list, unchanged.
- **the recognized segment is terminal.** the walk stops there. the
  zenka name comes from that one segment and from nothing else in the
  chain.

### known ambiguity : zenka names starting with `p7-`

the rule strips the *first* `p7-`, so an invoked `p7-log` resolves to
the zenka `log`, not to `p7-log`. the installed link for the real
`p7-log` zenka is `p7-p7-log` and resolves correctly — the ambiguity
only bites a link named `p7-log` by hand, which is exactly the kind
of thing someone writes now that arbitrary launcher symlinks
resolve. this behaviour is unchanged from the pre-chain `s|^.*p7-||`
form, so it is not a regression and is left as-is; it is recorded
here because this document is now the normative statement of the
rule. a zenka whose own name begins with `p7-` is best reached
through a launcher name that does not.

## the walk

```
start  :=  $FindBin::Bin/$FindBin::Script   [ if it exists ]
           $PROGRAM_NAME                    [ otherwise ]

loop, at most 32 hops, never revisiting a path :
    reject the path if it leaves the startup character whitelist
    record its basename in 'chain'
    if the basename names a zenka  ->  that is the zenka, stop
    target := readlink(path)
    if there is no target         ->  a real file, chain ends, stop
    if target is relative         ->  resolve against the link's own dir
    path := target
```

`$FindBin::Bin/$FindBin::Script` is the chain head rather than
`$PROGRAM_NAME` because FindBin performs the `PATH` lookup for a
bare invoked name **and** keeps the invoked link name unresolved.
both matter: `~/bin/radio-jazz` typed at a shell arrives as a bare
`$0` that no `readlink` can find, and `$RealBin/$RealScript` would
have collapsed the whole chain to `Protocol-7` before we could read
anything off it. this works because `use FindBin` in
`p7_load_perl_modules` compiles *before* the `BEGIN` block in
`p7_security_hardening` replaces `$ENV{'PATH'}` with the sanitized
one — FindBin still sees the inherited `PATH`, the rest of the
process does not.

two guards are not optional: a hop cap and a visited-path set, since
a symlink cycle the kernel happens not to reject would otherwise
spin. relative link targets resolve against the *link's own
directory*, never the working directory — a relative `~/bin/<name>
-> ../<dir>/p7-<zenka>` is the ordinary way a user writes one.

`p7_security_hardening`'s own `readlink` walk — the one that derives
the local `data/lib-path/pm` from the invoked binary — carried the
same relative-target bug and was fixed alongside, because it runs
first and a broken lib path aborts the process long before zenka
resolution is reached.

## two terminal conditions, both meaningful

```
~/bin/radio-jazz -> /usr/local/bin/p7-radio -> <root>/bin/Protocol-7
    chain    = [ radio-jazz, p7-radio ]
    zenka    = radio                       [ source : symlink-chain ]
    launcher = [ radio-jazz ]

~/bin/plainname -> <root>/bin/Protocol-7            [ plainname nosuch ]
    chain    = [ plainname, Protocol-7 ]
    zenka    = nosuch                      [ source : argv ]
    launcher = [ plainname ]
```

the second case matters as much as the first: the chain reached the
interpreter binary without any recognized segment, so the zenka name
still comes from `$ARGV[0]` exactly as it always has — but
`plainname` is *still collected*. an arbitrary user symlink is
meaningful launcher context whether or not it happened to be the
thing that named the zenka.

`launcher` is defined as **every name in the chain but the last**.
the last one is either the segment that named the zenka or the
interpreter binary the chain ended in; neither is launcher context.

## how the collected names reach the zenka

```perl
<system.start.symlink_chain>    ##  the full result hashref  ##
<system.start.launcher_chain>   ##  aref, invoked name first  ##
<system.start.launcher_name>    ##  the invoked name, or undef  ##
```

the result hashref is:

```perl
{   zenka_name => 'radio',
    chain      => [ 'radio-jazz', 'p7-radio' ],
    launcher   => [ 'radio-jazz' ],
    target     => undef,          ##  final non-symlink path, if reached  ##
    source     => 'symlink-chain' }  ##  or 'program-name' / 'argv'  ##
```

**decision : the launcher names are not merged into `<system.args>`.**
they are offered as their own keys and a zenka opts in by reading
them. merging would silently change the meaning of the argument
string for *every* symlink-invoked zenka — a `radio` zenka that
parses `<system.args>` strictly would start seeing `radio-jazz`
appear there without anyone asking for it. the names are launcher
*preset context*, not arguments, and the zenka that knows what its
own presets mean is the right place to interpret them.

**decision : the raw names are surfaced, not derived tokens.**
deriving `jazz` from `radio-jazz` by stripping the zenka's own name
is one plausible convention out of several, and picking one here
would freeze it for every zenka. the chain gives the names; a zenka
that wants a preset token derives it.

## where the implementation lives, and why

the normative rule is this document. the *implementation* is two
core subroutines in `bin/Protocol-7`:

```
p7_zenka_name_from_link_name   ->  $code{'base.zenka_name_from_link_name'}
p7_resolve_zenka_symlink_chain ->  $code{'base.resolve_zenka_symlink_chain'}
```

and the **canonical names zenka code should call** are registry
entries under `path-template.*`, which delegate straight to those:

```
src/base.path-template.zenka-name-from-link
src/base.path-template.zenka-symlink-chain
src/base.path-template.zenka-symlink      ##  the constructing direction  ##
```

the tradeoff, stated plainly. the right home for these path decisions
is the `path-template.*` registry — that is what the namespace is
for. but zenka-name resolution runs at two points that are *earlier
than the registry can exist*:

- `p7_early_whitelist_load` runs **before** `p7_load_code('base')`, so
  `%code` holds only the interpreter's own core subs at that moment.
- the main resolution at the top of the file runs after `base` is
  loaded but **before** `base.init_modules` — and it is
  `base.init_modules` that runs `base.path-template.pre_init`, which
  is what `<[base.swap_subs]>`s `base.path-template.*` into
  `path-template.*` in the first place.

so the registry namespace cannot be the implementation site without
either a bootstrap-order change or a second copy of the rule that
would drift. putting the single implementation in the interpreter and
*publishing* it under the registry name gives one behaviour, one
place to change it, and one name for zenka code to call. the cost is
one level of indirection in three small files; the alternative cost
was two divergent copies of a pattern match, which is precisely the
state this work removed.

`base.path-template.zenka-symlink` is the inverse direction —
`<dir>/p7-<zenka>` from a zenka name. it has no bootstrap constraint
and is a plain implementation.

## the other sites that construct a launcher name

a sweep of `bin/` and `src/` finds the naming decision written out in
two further places. neither is changed here; both are recorded so the
registry entry has a known set of consumers to absorb.

- **`<[v7-zenki.install_zenka_symlinks]>`** builds
  `sprintf qw| %s/p7-%s |, $symlink_dir, $zenka_name` itself. moving
  it onto `<[path-template.zenka-symlink]>` is a one-line follow-up,
  deliberately left out so the installer's behaviour stays untouched
  in this change.
- **`<[v7-zenki.install_workflow_shortcuts]>`** installs a **fourth,
  unrecognized form** — `p7.<shorthand>`, mapping short aliases onto
  *multi-word* command patterns [ `wo` -> `workflow overview`,
  `srcd` -> `sourcecode verify-dev-signatures` ]. it is currently
  disabled at its first line, marked *"requires parameter
  propagation"*.

  that second one is worth naming precisely, because the launcher
  chain is the missing half of it. `p7.<shorthand>` matches none of
  the three recognized forms, so such a link resolves through to the
  interpreter and falls back to `$ARGV[0]` — the shorthand never
  names its zenka, and its trailing words have nowhere to go. the
  chain now carries exactly that: the alias name reaches the started
  zenka as launcher context. whoever revives that feature should
  decide whether `p7.<shorthand>` becomes a fourth recognized form or
  whether shorthands are instead expressed as ordinary chains onto an
  existing `p7-<zenka>` link, and record the answer here. the
  shorthand tables belong in this namespace either way.

no other site parses or builds a zenka launcher name.
`bin/c_src/p7c.c` and `bin/c_src/p-7-r.c` use `argv[0]` for usage
text only, and `bin/nshell` walks `readlink` solely to locate its own
lib path.

## relation to the rest of `path-template.*`

`path-template.*` is meant to become the single source of truth for
*calculable* path and name structure across the multi-zenki set-up —
including the unix-domain-socket directory structure that console
redirection, `bin/c_src/p-7-r.c`, `bin/nshell` and the `zenki` zenka
will all have to agree on, which is expected to nest directories by
`AMOS7::CHKSUM` output [ AMOS and BMW ] rather than by a flat name,
in the manner `base.path-template.amos-ntime-dec` already composes a
checksum with an ntime-decimal suffix.

this work does not build any of that, and deliberately touches no
socket path. what it contributes to it is the **identity end**: the
chain resolves an invocation to exactly one canonical zenka name, and
that name is the natural key a checksum-nested socket path would be
calculated *from*. keeping recognition and construction of the
launcher name as a matched pair in this namespace [
`zenka-name-from-link` / `zenka-symlink` ] is the same shape a socket
primitive would want — one calculable structure, readable in both
directions.

the `zenka-*` sub-namespace used here leaves `path-template.zenka-socket*`
and neighbours free.

## verified behaviour

exercised with scratch symlinks against the real interpreter:

```
p7-<zenka>                            -> program-name
Protocol-7.<zenka>                    -> program-name
v7.<zenka>                            -> program-name  [ legacy ]
custom -> p7-<zenka>                  -> symlink-chain, launcher [ custom ]
custom -> ../rel/p7-<zenka>           -> symlink-chain, launcher [ custom ]
a -> b -> p7-<zenka>                  -> symlink-chain, launcher [ a, b ]
custom -> Protocol-7, with argument   -> argv,          launcher [ custom ]
./bin/Protocol-7 <zenka>              -> argv,          launcher [ ]
no name at all                        -> <stdin> config mode, unchanged
```

`$ARGV[0]` is consumed at the main call site alone, and only when
`source` is `argv`. the resolver itself never touches `@ARGV`: it is
called twice — the early whitelist load peeks first — and is
memoized, so the filesystem walk happens once and the two sites
cannot disagree.

the keys were then read back *from zenka code*, not just checked
where they are assigned — start-up config run through `-stdin` after
`[init_modules]`, so the read happens on the far side of config
parsing and module init:

```
[init_modules]
[path-template.zenka-symlink:<system.start.launcher_name>]
```

invoked through a `radio.jazz -> p7-<zenka>` chain the validation
reports `unexpected characters in zenka name 'radio.jazz'`; invoked
directly as `p7-<zenka>` it reports `zenka name is undefined`. the
launcher name survives to the zenka, and is absent exactly when there
was no launcher. the same probe confirms `<system.start.launcher_chain>`
arrives as a live array reference.

#,,,,,,.,,,.,,.,.,.,.,,..,...,...,.,,,...,..,,..,,...,...,,..,...,..,,,,.,.,.,
#SVCNCMKMDFOXOCMITY5NPCDAS625XGU7F5UIT4GSKW4IJRYBPQ6VWPN7EMQBYYOBZ6WR3CIDUO3FK
#\\\|SMQUHBYNGCQ5BM3LPH2ICJIFVEIXMWP64HUYTBZUYA4MYOQDTP7 \ / AMOS7 \ YOURUM ::
#\[7]34ZRE5DHUEMWFN3S53CMV757IDB7RADTR53RPT2NCZ32TS4OBWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
