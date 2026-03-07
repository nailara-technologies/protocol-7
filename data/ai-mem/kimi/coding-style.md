# protocol-7 coding style [ kimi-specific ]

nuances and patterns that kimi specifically needs to get right.
canonical reference: data/yaml/docs/protocol-7-coding-style.md
complementary reference: data/ai-mem/claude/coding-style.md

---

## core philosophy

**minimal changes, maximal clarity**
- every edit should be purposeful
- prefer explicit over implicit
- when in doubt, follow existing patterns exactly

---

## syntax validation [ critical ]

### do not trust `perl -c`
protocol-7 syntax extends perl in ways that confuse `perl -c`:
- `<key.path> //= 0` looks like glob assignment to perl — produces false error
- p7-specific constructs may pass silently but still be wrong

### use `bin/ptd` instead
```bash
## validate and reformat
./bin/ptd modules/namespace.module.name

## check only (no reformat) — requires -c or -check flag
./bin/ptd -c modules/namespace.module.name
./bin/ptd -check modules/namespace.module.name
```

### verbatim escape for unusual constructs
```perl
#<<V  code skipping: perltidy passes this verbatim

    <some.unusual.construct> //= {};

#>>V
```
use sparingly — rewrite into cleaner form once logic settles.

---

## invocation syntax [ critical ]

### closing token is `]>` — never `]->` or `>` alone
```perl
<[base.command]>->($arg)    ## correct
<[base.command]->($arg)     ## wrong — missing >
<[base.command>->($arg)     ## wrong — missing ]
```

### no-arg calls
```perl
<[base.exit]>               ## correct — implicit ->()
<[base.exit]>->()           ## redundant but valid
```

---

## data access patterns [ critical ]

### three distinct notations — never mix them

```perl
<[module.name]>->($arg)          ## function call — exact key match in %code
<key.path>                       ## data read — dots become nested hash access
$data{'key'}{'path'}             ## explicit data read — always valid
```

### data path vs module path
```perl
<data.fuse.mounts>{$mp}               ## data: $data{'data'}{'fuse'}{'mounts'}{$mp}
<[data.fuse.init_code]>               ## call: $code{'data.fuse.init_code'}->()
<web.metrics>->{commands_executed}    ## data hash deref
```

### assignment patterns
```perl
<key.path> = $value;                 ## simple assignment
<key.path> //= $default;             ## defined-or assignment
push <key.path>->@*, $item;          ## array push via postfix dereference
```

---

## reply handling [ critical ]

### return format — always use hashref with 'mode'
```perl
## success with data
return { 'mode' => qw| true |, 'data' => $result };

## success with size (multi-line)
return { 'mode' => qw| size |, 'data' => $multi_line_content };

## failure
return { 'mode' => qw| false |, 'data' => $error_message };
```

### never embed newlines in 'true' mode
```perl
return { 'mode' => qw| true |, 'data' => "line1\nline2" };   ## wrong
return { 'mode' => qw| size |, 'data' => "line1\nline2" };   ## correct
```

### error messages
- lowercase
- descriptive but concise
- no interpolation — use sprintf-style

---

## logging [ critical ]

### format strings — never interpolate
```perl
<[base.log]>->(2, "loading module '%s'", $name);        ## correct
<[base.log]>->(2, "loading module '$name'");            ## wrong — interpolation
```

### log levels
log levels correspond to -v[v[v[v[v]]]] flags when starting the zenka.

colors per level (from base.log.format_entry):
- 0: error — always visible, color highlighted
- 1: default — normal operation
- 2: info — info/debug combined, development use
- 3+: debug — extended debug, compiles routines with additional logging
- 4: dumps parsed sourcecode after syntax parsing on startup
- 5: with devmod enabled, dumps entire %data hash on shutdown

### common usage
```perl
<[base.log]>->(0, "error: %s", $msg);        ## always visible, highlighted
<[base.log]>->(1, "normal: %s", $msg);        ## normal operation logging
<[base.log]>->(2, "info: %s", $msg);          ## info/debug (development)
```

### rarely used in regular code
levels 3+ are primarily for development/debugging:
- 3: extended debug, routine call tracing
- 4: sourcecode dump on startup
- 5: data hash dump on shutdown

levels 7,8,9 are technically possible but unused.

### separate verbosity control
logged verbosities can be controlled separately for different targets:
- `<system.verbosity.console>` — console output
- `<system.verbosity.zenka_buffer>` — uim-memory buffer
- `<system.verbosity.zenka_logfile>` — log files (via network to p7-log zenka)

the effective verbosity is the max of all three (see modules/base.get_max_verbosity).

---

## module structure

### header template
```perl
## [:< ##

# name  = namespace.category.action
# descr = brief lowercase description
# param = $params [ { expected_keys } ]

my $params = shift // {};
```

### signature footer [ critical ]
**never add signature footer manually** — `bin/Protocol-7 sourcecode update-signatures` adds the real footer.

**placeholder footers**: do not include placeholder signature lines with trailing spaces — they block the signing system.
```
#,,,.,,,.,,..,.,.,..,,,..,..,,,..  ## wrong — trailing space
#,,,.,,,.,,..,.,.,..,,,..,..,,,..  ## correct — no space
```

leave files clean for proper signing.

### never add signature footer manually
`bin/Protocol-7 sourcecode update-signatures` adds the real footer.
leave files clean for proper signing.

---

## hash and array operations

### postfix dereference (preferred)
```perl
<array.path>->@*;                    ## full array
<array.path>[0];                     ## single element
<hash.path>->%*;                     ## full hash
<hash.path>{key};                    ## single value
```

### checking existence
```perl
exists <hash.path>{key};             ## key exists
defined <hash.path>{key};            ## value defined
<hash.path>{key} // 'default';       ## defined-or default
```

---

## string handling

### qw| | for word lists
```perl
qw| success error pending |          ## correct — spaces separate
qw|success error pending|            ## also correct
```

### qq| | for interpolation needs
```perl
qq|error: $err at line $line|;       ## when you need interpolation
```

### single quotes for literals
```perl
'fixed string'                       ## no interpolation needed
```

---

## column width

### 78 character limit
code and comments must fit within 78 columns. ptd enforces this.

### breaking long strings
ptd **cannot** automatically break up long strings. you must manually split them:

```perl
## wrong — exceeds 78 columns
"[module] failed to render system message: $result->{message}"

## correct — split with concatenation
"[module] render failed: "
    . $result->{message}
```

### check for violations
```bash
./bin/vc-changed-files -exc-len | grep modules/
```

---

## control flow

### early returns for guard clauses
```perl
return { 'mode' => qw| false |, 'data' => 'missing param' }
    unless defined $required_param;
```

### foreach with meaningful names
```perl
foreach my $task_file (@task_files) { ... }
```

### map/grep for transformations
```perl
my @names = map { $_->{name} } @tasks;
my @pending = grep { $_->{status} eq 'pending' } @tasks;
```

---

## error handling

### defensive coding
```perl
## check before use
unless ( -f $path and -r $path ) {
    return { 'mode' => qw| false |, 'data' => "not readable: $path" };
}

## eval for risky operations
my $result = eval { risky_operation() };
if ($@) {
    return { 'mode' => qw| false |, 'data' => "failed: $@" };
}
```

### file operations
```perl
open my $fh, '<', $path
    or return { 'mode' => qw| false |, 'data' => "cannot open: $!" };
```

---

## protocol-7 idioms

### route-send for cross-zenka calls
```perl
my $sent = <[protocol-7.route-send]>->(
    {   command   => qw| cube.web.render-template |,
        call_args => { template_path => $path, budget => 2000 },
        reply     => { handler => qw| my.handler |, params => {} }
    }
);
```

### callback pattern
```perl
<[base.callback.cmd_reply]>->(
    $reply_id,
    { 'mode' => qw| size |, 'data' => $output }
);
```

### time handling
```perl
my $start = <[base.time]>->(4);      ## high precision
my $elapsed_ms = (<[base.time]>->(4) - $start) * 1000;
```

---

## common pitfalls

### confusing data and code paths
```perl
<data.key>              ## data access
<[code.key]>            ## code call
```

### missing -> in hash/array access
```perl
<data.key>{sub}         ## wrong — missing ->
<data.key>->{sub}       ## correct
```

### wrong return format
```perl
return $value;                       ## wrong
return { mode => 'true', data => $value };  ## correct
```

### forgetting // for undefined safety
```perl
my $val = <data.key>;                ## may be undef
my $val = <data.key> // '';          ## safe default
```

---

## cli flag conventions

### single `-` prefix always — multi-character flags are fine, `--` prefix is not used:
```
-c          ## ok — single char
-check      ## ok — multi-char with single dash
--check     ## wrong — double dash not used in this project
```

## signature and versioning

### never modify signatures manually
use the signing system:
```bash
./bin/Protocol-7 sourcecode update-signatures
./bin/Protocol-7 sourcecode update-version
```

### pre-commit checklist
1. `bin/ptd -c` passes on all modified modules (syntax check without reformat)
2. no manual signature lines added
3. all returns use proper mode/data hashref
4. no variable interpolation in log messages
5. column width ≤ 78 characters

---

## kimi-specific reminders

**when analyzing code:**
- look for existing patterns first
- follow the same indentation and spacing
- preserve comment style (lowercase, concise)

**when modifying modules:**
- make minimal changes
- keep diffs clean and focused
- prefer adding new modules over modifying core ones

**when creating modules:**
- one subroutine per file (protocol-7 convention)
- clear, descriptive names
- comprehensive but concise description header

---

## quick reference card

```perl
## call module
<[namespace.module.name]>->($arg)

## read data
<data.path.here>

## assign data
<data.path> = $value;
<data.path> //= $default;

## return success
return { 'mode' => qw| true |, 'data' => $result };

## return multi-line
return { 'mode' => qw| size |, 'data' => $content };

## return error
return { 'mode' => qw| false |, 'data' => $error };

## log message
<[base.log]>->(2, "format string %s", $var);

## check file
-f $path and -r $path

## safe eval
my $r = eval { operation() } // {};
```

---

## regular expressions [ critical ]

### delimiter hierarchy

**never use `//` or `s///` forms** — they obscure delimiter intent and complicate escaping.

preferred order based on pattern content:

```perl
## 1. pipes preferred (no pipes in pattern)
$path    =~ m|/var/log/.*\.txt$|;      ## correct — pipes
$filename =~ s|\.gguf$||i;               ## correct — pipes

## 2. braces when pipes exist in pattern
$html    =~ m{[|]};                      ## braces — pipe in pattern
$cmd     =~ s{\|}{ }g;                  ## braces — pipe in replacement

## 3. other delimiters as needed (parens, etc.)
$expr    =~ s(\(([^)]+)\))[$1]g;        ## parens for paren-heavy patterns
```

### matching

```perl
## correct — m||
if ( $path =~ m|/var/log/.*| ) { ... }
if ( $name =~ m{vl|vision}i ) { ... }   ## braces — pipe in pattern

## wrong — // form
if ( $path =~ /\/var\/log\/.*\/ ) { ... }
```

### substitution

```perl
## correct — s|||
$filename =~ s|\.gguf$||i;
$path     =~ s|^/tmp/|/var/|;

## correct — s{}{} when pipes present
$html =~ s{\|}{<pipe>}g;
$html =~ s{<([^>]+)>}{[$1]}gsx;          ## complex patterns — braces read better

## wrong — s/// form
$filename =~ s/\.gguf$//i;
```

### modifiers always explicit

```perl
m|pattern|i      ## case-insensitive
m|pattern|g      ## global match
s|old|new|gsx    ## global + single-line + extended
```

---

## style principles

1. **readability first** — code is read more than written
2. **consistency** — match surrounding code exactly
3. **explicitness** — no clever shortcuts, be clear
4. **defensiveness** — check inputs, handle errors
5. **minimalism** — smallest change that works

---

#,,.,,,,.,,,,,.,.,,..,,,.,,..,,,,,.,.,,,.,.,.,.,.,...,...,..,,,,.,.,.,...,,,.,
#JJFGKN6CCL7DPZXUKEHA7ZXVIIQSS2A5A5QAGXMINQTNHKXWCHEFHXPDZMJCDJXXZZYK5YNTQOL2Q
#\\\|WCIW6WG4ZJY44BWOMLIKAZFLY55HEAFZMFJNOCEDGW4GTXXETPX \ / AMOS7 \ YOURUM ::
#\[7]MZ25LGG5TFYN5IR7SIKX7VIOWLQXYZ3LPUY2UWJMAXUJTHBRRECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
