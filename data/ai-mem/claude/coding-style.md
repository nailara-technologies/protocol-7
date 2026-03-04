# protocol-7 coding style [ claude-specific ]

nuances and patterns that claude specifically needs to get right.
canonical reference: data/yaml/docs/protocol-7-coding-style.md

---

## syntax checking ##

do not rely on `perl -c` to validate module files — it sometimes fails on p7 syntax.
the most common case: `<key.path> //= 0` looks like a glob assignment to plain perl,
producing "Can't modify glob in scalar assignment" on a perfectly valid module.
other p7 constructs may pass perl -c silently without actually being correct.

[ future: a standalone bidirectional p7 syntax translator ( p7 ↔ perl ) would allow
  proper perl -c validation, and open the full perl toolchain — critics, profilers —
  against translated module code ]

use `bin/ptd` instead — it runs perltidy with an extended syntax flag that is generically
more lenient (not p7-specific, but happens to accept p7 constructs). ptd validates and
reformats in one pass; if ptd is happy, the module is valid.

for constructs that still don't pass even with the extended flag, ptd supports verbatim
code-skipping markers that pass the block through without error checking:

    #<<V  code skipping: perltidy passes this verbatim, no error checking

        <some.unusual.construct> //= {};

    #>>V

blocks wrapped this way are usually rewritten into something cleaner once the logic
is settled — the markers are a temporary escape hatch, not a permanent solution.

[ future: a check-only mode in bin/ptd using /dev/null as output could highlight
  syntax pass/fail without reformatting — useful for quick validation in tooling ]

---

## invocation syntax [ critical ] ##

the closing token is `]>` — bracket followed by angle bracket, both required.

```perl
<[base.command]>->($arg)    ## correct  — ]> closes token, then -> passes args
<[base.command]->($arg)     ## wrong    — missing > after ], parser sees unclosed token
<[base.command>->($arg)     ## wrong    — missing ] before >
```

no-arg calls — `->()` is redundant, parser adds it implicitly:
```perl
<[base.exit]>               ## correct — expands to $code{'base.exit'}->()
<[base.exit]>->()           ## also correct but redundant
```

---

## data access vs function calls [ critical ] ##

three distinct notations that must never be mixed up:

```perl
<[module.name]>->($arg)          ## function call — dots are literal key in %code
<key.path>                       ## data read  — dots become nested: $data{'key'}{'path'}
$data{'key'}{'path'}             ## data read  — explicit form, always valid
```

`<key.path>` works in any module, not just init_code — reads/writes `%data`.
`<[module.name]>` dots are NOT nested — they match the filename exactly.

```perl
<data.fuse.mounts>{$mp}          ## reads $data{'data'}{'fuse'}{'mounts'}{$mp}
<user.cube.session>->%*          ## hash deref of $data{'user'}{'cube'}{'session'}
<[data.fuse.init_code]>          ## calls $code{'data.fuse.init_code'}->()
```

---

## perl module loading ##

one module per autoload call — not a list:
```perl
<[base.perlmod.autoload]>->('JSON::XS')         ## correct
<[base.perlmod.autoload]>->('JSON::XS', 'YAML')  ## wrong — only first is loaded
map { <[base.perlmod.autoload]>->($_) } qw| JSON::XS YAML::XS |  ## correct for multiple
```

for modules that export constants (Socket, POSIX, etc.) autoload is too late — strict
subs checks happen at compile time. use require + fully-qualified names instead:
```perl
require Socket;
socketpair( $a, $b, Socket::AF_UNIX, Socket::SOCK_STREAM, Socket::PF_UNSPEC )
```

---

## constants ##

no `use constant` — it injects into the shared main:: namespace:
```perl
use constant PI => 3.14159;     ## wrong — pollutes main::
my $pi = 4 * atan2( 1, 1 );    ## correct — exact value, lexically scoped
```

for module-level constants, call a constant-returning module and store locally:
```perl
my $cube_size = <[data.topology.interference.map.CUBE_SIZE]>;
```

---

## reply format ##

column width: 78 characters for both code and comments [ ptd enforces this ].

single-line result:
```perl
return { 'mode' => qw| true |,  'data' => $result };
return { 'mode' => qw| false |, 'data' => sprintf( "error : %s", <[base.str.os_err]> ) };
```

multi-line result — use `size` mode, never embed `\n` in a `true` reply:
```perl
return {
    'mode' => qw| size |,
    'data' => join( "\n", @lines )
};
```

do not append help text or instructions to reply data — machine replies only.

---

## logging ##

no variable interpolation in format strings — use sprintf-style codes:
```perl
<[base.log]>->( 1, "loading module '%s'", $name )  ## correct
<[base.log]>->( 1, "loading module '$name'" )       ## wrong — interpolation
```

---

## module headers ##

```perl
## [:< ##

# name  = namespace.category.action
# param = <required> [optional]
# descr = brief lowercase description
```

do not add the signature stub line (`#,,,...`) — it blocks the signing system.
leave the file clean; `bin/Protocol-7 sourcecode update-signatures` adds the real footer.

---

## fork-child pattern [ ordering matters ] ##

child side must follow this exact sequence:
```perl
IO::AIO::reinit() if defined &IO::AIO::reinit;
<[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'dev.null' } );
<callback.session.closing_last.params>->[1] = 1;
$data{'session'}{$session_id}{'shutdown'} = TRUE if defined $session_id;
<buffer.zenka.log_cmd> = qw| p7-log.append |;
delete <access.cmd.usr.cube>; delete <access.cmd.regex.usr.cube>;
unshift <protocol-7.network.parent_route>->@*, qw| parent |;
```

parent side:
```perl
delete <access.cmd.usr.parent>; delete <access.cmd.regex.usr.parent>;
$data{'session'}{$id}{'authenticated'}          = qw| yes |;
$data{'session'}{$session_id}{'authenticated'}  = qw| yes | if defined $session_id;
```

---

## event timers ##

repeating timers require BOTH keys — a common source of silent failure:
```perl
'interval' => 62, 'repeat' => TRUE    ## correct
'repeat'   => 62                       ## wrong — sets bool to 62, no interval
```

one-shot: `'after' => $seconds` with no interval key.

#,,,.,..,,,.,,.,.,,.,,..,,.,.,.,.,..,,...,,..,..,,...,...,.,.,,..,,.,,,,,,,,,,
#3J42JURDHVGFZZN4GJZ3LRMHFKBHCZSBD5RFS6GQMAL4U4TWTNXCTWYBDUJGFSKEFWH5AXDDEGICA
#\\\|Q2OFGE4FF2GCFLBA4V3LBC5H62TF6GFKKOUPKZAMTO4M3GXKTRV \ / AMOS7 \ YOURUM ::
#\[7]SLWECQYVC6WFXG7TNDKK2V23XOZXGT4CLTVLKAKCCEBV43EGJODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
