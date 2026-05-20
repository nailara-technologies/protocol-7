## [:< ##

# name  = task: ncode doc command — unified documentation lookup
# descr = add 'doc' command to bin/ncode and ncode.cmd.doc module with
#         automatic source selection: p7 module / perldoc-f / perldoc / introspection

## context

`bin/ncode` is the code intelligence tool with search, replace, and transform
commands. `modules/ncode.cmd.*` expose these as P7 zenka commands, registered
in `modules/ncode.cmd.tool_list` for coding zenka tool calls.

`bin/dev/dump-class` was recently fixed to support GObject Introspection classes
(WebKit2GTK 4.1) with perltidy fallback for glob-heavy output. that logic should
be the foundation of the introspection path here.

the `doc` command gives any caller — human via CLI or LLM via coding zenka tool —
unified documentation lookup with automatic source selection.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat bin/ncode                          ## understand command dispatch structure
cat modules/ncode.cmd.search           ## pattern for P7 module implementation
cat modules/ncode.cmd.tool_list        ## pattern for tool registration
cat bin/dev/dump-class                 ## introspection logic to reuse
```

---

## decision logic

the argument shape determines the documentation source. apply in order:

| argument shape | source | notes |
|---|---|---|
| contains `.` (no `::`) | **P7 module** | look up in `modules/` by name |
| starts with GObject root | **introspection** | Gtk3 Glib Gdk Pango Cairo Gio |
| contains `::` | **perldoc + introspection** | narrative + live method list |
| single word | **perldoc -f → perldoc** | built-in function first, then module |
| fallback | try all, return what has content | note source in output |

### source: P7 module

argument contains `.` but no `::` — treat as P7 module name.

```perl
## look up module file
my $root     = <system.root_path>;
my $mod_path = "$root/modules/$arg";

if ( -f $mod_path ) {
    ## read header lines (name, descr, todo)
    open my $fh, '<', $mod_path or return error;
    my @lines = <$fh>;
    close $fh;

    ## extract ## [:< ## header fields
    my %header;
    for my $line (@lines) {
        if ( $line =~ m|^#\s+(name|descr|param|todo)\s+=\s+(.+)$| ) {
            $header{$1} = $2;
        }
        last if $line =~ m|^\s*$| and %header;  ## stop at first blank after header
    }

    ## format output
    my $out = "[ p7 module ]\n\n";
    $out .= "name  : $header{name}\n"  if $header{name};
    $out .= "descr : $header{descr}\n" if $header{descr};
    $out .= "param : $header{param}\n" if $header{param};
    $out .= "\n" . join( '', @lines );
    return { 'mode' => 'size', 'data' => $out };
}
```

### source: GObject Introspection

argument starts with a known GObject namespace root. use the introspection
approach from `bin/dev/dump-class` — set up the typelib, dump the symbol table.

known roots: `Gtk3` `Glib` `Gdk` `Pango` `Cairo` `Gio` `GObject` `GLib`

```perl
## set up Gtk3 and introspection
eval {
    Glib::Object::Introspection->setup(
        basename => 'Gtk', version => '3.0', package => 'Gtk3'
    );
};

## set up WebKit2 if requested
if ( $arg =~ m|^Gtk3::WebKit2| ) {
    eval {
        Glib::Object::Introspection->setup(
            basename => 'WebKit2', version => '4.1',
            package  => 'Gtk3::WebKit2'
        );
    };
}

## dump symbol table
my $dump = Data::Dumper::Dumper( { eval "%{${arg}::}" } );

## apply perltidy if available — fall back if it can't parse globs
if ( length $perltidy_path ) {
    ## ... (same pattern as dump-class)
}

## format with source label
return { 'mode' => 'size', 'data' => "[ introspection: $arg ]\n\n$dump" };
```

### source: perldoc + introspection supplement

argument contains `::`. run `perldoc -t` for narrative docs, then check
introspection for method list supplement.

```perl
## get perldoc output
my $pdoc = qx( perldoc -t '$arg' 2>/dev/null );

## try introspection supplement for GObject-adjacent modules
my $idoc = '';
## ... (same introspection block, capture instead of return)

my $out = '';
if ( length $pdoc ) {
    $out .= "[ perldoc: $arg ]\n\n$pdoc";
}
if ( length $idoc ) {
    $out .= "\n\n[ introspection: $arg ]\n\n$idoc";
}
return length $out
    ? { 'mode' => 'size', 'data' => $out }
    : { 'mode' => 'false', 'data' => "no documentation found for '$arg'" };
```

### source: perldoc -f then perldoc

single word argument — built-in function first, then module shortname.

```perl
## try built-in function first
my $fdoc = qx( perldoc -t -f '$arg' 2>/dev/null );
if ( length $fdoc ) {
    return { 'mode' => 'size',
             'data' => "[ perldoc -f: $arg ]\n\n$fdoc" };
}

## try as module shortname
my $mdoc = qx( perldoc -t '$arg' 2>/dev/null );
if ( length $mdoc ) {
    return { 'mode' => 'size',
             'data' => "[ perldoc: $arg ]\n\n$mdoc" };
}

return { 'mode' => 'false', 'data' => "no documentation found for '$arg'" };
```

---

## what to implement

### 1. add `doc` command to `bin/ncode`

read `bin/ncode` to understand the command dispatch. find where `search`,
`replace`, `transform` etc. are dispatched. add `doc` to the same dispatch
table. the implementation body goes in a `sub ncode_doc` or inline block,
using the decision logic above.

also add `doc` to the `--help` / usage output alongside other commands.

### 2. new module: `modules/ncode.cmd.doc`

follows `modules/ncode.cmd.search` exactly:
- `my $call_args = shift;`
- parse `$call_args->{'args'}` for the argument
- apply decision logic
- return `{ 'mode' => 'size', 'data' => $output }`
- return `{ 'mode' => 'false', 'data' => $error }` on failure

the module needs these at the top (check what ncode.init_code already loads):
```perl
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Glib::Object::Introspection;
chomp( my $perltidy_path = qx(which perltidy) );
```

if ncode.init_code already loads these, do not re-import.

### 3. add `doc` entry to `modules/ncode.cmd.tool_list`

add alongside existing tools:
```perl
{   'name'  => qw| doc |,
    'descr' => 'look up documentation for a perl class, built-in function,'
             . ' or p7 module — auto-selects perldoc / introspection / source',
    'params' => [
        {   'name'     => 'arg',
            'type'     => 'string',
            'required' => qw| true |,
            'descr'    => 'class name (Gtk3::WebKit2::WebView),'
                        . ' built-in (push, splice), or p7 module'
                        . ' (web-browser.open_window)',
        },
    ],
    'example' => "ncode.doc { arg: 'Gtk3::WebKit2::WebView' }",
},
```

---

## test sequence

```bash
## built-in function
bin/ncode doc push
## expected: [ perldoc -f: push ] followed by push() documentation

## CPAN module
bin/ncode doc LWP::UserAgent
## expected: [ perldoc: LWP::UserAgent ] with narrative docs

## GObject class — method list
bin/ncode doc Gtk3::WebKit2::WebView
## expected: [ introspection: Gtk3::WebKit2::WebView ] with ~178 entries
## including: get_snapshot  evaluate_javascript  set_background_color  load_uri

## GObject subclass
bin/ncode doc Gtk3::WebKit2::CookieManager
## expected: introspection showing set_accept_policy  delete_all_cookies  etc.

## P7 module
bin/ncode doc web-browser.open_window
## expected: [ p7 module ] header + source

## short module name
bin/ncode doc POSIX
## expected: [ perldoc: POSIX ] module docs

## via P7 command
p7 ncode.cmd.doc 'Gtk3::WebKit2::NetworkProxySettings'
## expected: same introspection output via zenka
```

## success criteria

- [ ] `bin/ncode doc <arg>` dispatches to doc command
- [ ] P7 module lookup works for `web-browser.open_window` style args
- [ ] `perldoc -f push` returns built-in function docs
- [ ] `perldoc LWP::UserAgent` returns module narrative
- [ ] GObject introspection returns method list for `Gtk3::WebKit2::WebView`
- [ ] `Gtk3::WebKit2::WebView` output includes `get_snapshot` and `evaluate_javascript`
- [ ] source label prefix on all output (`[ perldoc -f ]`, `[ introspection ]` etc.)
- [ ] `ncode.cmd.doc` P7 module works via `p7 ncode.cmd.doc`
- [ ] `doc` entry added to `ncode.cmd.tool_list` with correct params
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,.,,..,,..,,..,,,.,,,..,...,,,.,...,,..,,.,,..,,...,...,...,,.,,,,,,,.,,,..,
#DJGT5U7IHJDOGUFNQR23GDQKJBVQVUSBYOFMKF4WVYFDNEEPPNA3MXNT5T4MSFIE74OYXR26TWFKU
#\\\|6FFHGSTH3KOMN6EALSH6KTGHIDHZMPVLP4OFTU3Q6UET36PYDPF \ / AMOS7 \ YOURUM ::
#\[7]XQZBRDXJ6DKVCC33UGTIQNQ2WWZVRAYUIZWNVO2MSKXP7TEYBEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
