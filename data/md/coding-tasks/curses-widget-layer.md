## [:< ##

# task: terminal.curses_ui widget layer — ui adapter step 1

implement the curses widget foundation that makes `ui.app.models` possible.
this is standalone-first: the modules must work as a Curses::UI application
launched from the command line, before any zenka wiring.

read the design doc first:
    data/md/design/TERMINAL-ZENKA-ARCHITECTURE.md


## p7 code style (strictly enforced)

- lowercase comments: `## read config from file` not `## Read Config`
- annotations in [ brackets ] not (parentheses)
- `$ARG` not `$_`
- `<[module.name]>->($args)` — closing `]>` before `->`
- `<[module.name]>` with no args (parser adds `->()` automatically)
- `:flag:` not `--flag` in all p7 command contexts
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules return `{ mode => 'size', data => $str }` for output,
  `{ mode => 'false' }` only for error/no-output fallback
- do NOT use `$data{'models'}{'cfg'}{...}` — correct is `$data{'models'}{...}`
- do NOT add the `#,,...` stub signature line — leave files clean for signing
- do NOT generate any footer lines at all — not even partial ones
  (the signing system adds the complete 4-line AMOS7 footer)
- new modules start with: `## [:< ##\n\n# name  = ...\n# descr = ...`


## existing foundation to read first

    modules/terminal.curses_ui.load_lang     (style reference, Curses::UI usage)
    modules/terminal.curses_ui.modified.english  (language mod pattern)
    modules/models.storage.adapter.invoke.discover  (data source for widget)
    modules/models.storage.adapter.lmstudio.discover
    data/md/design/TERMINAL-ZENKA-ARCHITECTURE.md   (full UI adapter design)


## modules to create

### 1. modules/terminal.curses_ui.widget.list

    # name  = terminal.curses_ui.widget.list
    # descr = curses list widget — paginated filterable model list

    a Curses::UI Listbox widget wrapper that:
    - takes a data arrayref (model records from adapter.discover_all)
    - renders each row as: "type  base  format  name" (fixed-width columns)
    - supports j/k vim-style navigation, arrow keys
    - supports / for filter (live filter as user types)
    - returns selected record on Enter
    - q or Escape exits

    interface:
        $ARG = {
            items    => \@model_records,    ## arrayref of model hashrefs
            title    => 'invoke models',    ## optional title string
            on_select => \&callback,        ## called with selected record
        }

    use Curses::UI — specifically Curses::UI::Listbox
    load via: <[base.perlmod.autoload]>->('Curses::UI')

    format each row:
        sprintf "%-12s %-8s %-12s %s",
            $rec->{'type'}, $rec->{'base'}, $rec->{'format'}, $rec->{'name'}

    return the selected model record hashref, or undef if cancelled


### 2. modules/terminal.curses_ui.widget.detail

    # name  = terminal.curses_ui.widget.detail
    # descr = curses detail widget — single model record display

    a Curses::UI TextViewer widget showing full model record:
    - shows all fields of a model hashref in a scrollable text panel
    - formatted as key: value pairs (aligned)
    - q or Escape closes

    interface:
        $ARG = {
            record => \%model_record,
            title  => 'model detail',
        }

    fields to show (in order):
        name, type, base, format, path, size (human-readable), source,
        source_type, adapter (if present), quant (if present)

    use human_size logic: show bytes as GB/MB/KB as appropriate


### 3. modules/terminal.curses_ui.keybindings

    # name  = terminal.curses_ui.keybindings
    # descr = shared keybinding definitions for curses UI widgets

    a data module (not a subroutine) returning a hashref of keybindings:

        return {
            'quit'    => [ 'q', "\e" ],
            'up'      => [ 'k', KEY_UP ],
            'down'    => [ 'j', KEY_DOWN ],
            'select'  => [ "\n", KEY_ENTER ],
            'filter'  => [ '/' ],
            'detail'  => [ 'd', "\n" ],
            'repair'  => [ 'r' ],
            'refresh' => [ 'R' ],
            'help'    => [ '?' ],
        }

    these are shared across all curses widgets via:
        my $keys = <[terminal.curses_ui.keybindings]>;


### 4. modules/terminal.curses_ui.app.models

    # name  = terminal.curses_ui.app.models
    # descr = standalone curses model manager application

    the main application module — wires together discover + list + detail.

    standalone-first: can be launched directly from command line:
        perl -e 'require "bin/Protocol-7"; ...'
    or via p7c command (wired later).

    logic:
        1. call <[models.storage.adapter.discover_all]> to get all models
        2. show widget.list with results
        3. on select: show widget.detail for selected record
        4. on 'r' key: call adapter repair for selected model's adapter
        5. on 'R' key: re-run discover_all and refresh list
        6. on 'q': exit

    use Curses::UI application loop:
        my $cui = Curses::UI->new( -color_support => 1 );
        my $win = $cui->add( 'main', 'Window', ... );
        $cui->mainloop;

    apply P7 color theme:
        background: dark blue/black
        selected:   bright cyan on dark blue
        borders:    dark blue
        text:       light grey


### 5. modules/models.cmd.app-models

    # name  = models.cmd.app-models
    # descr = cmd: launch curses model manager

    thin cmd wrapper:
        <[terminal.curses_ui.app.models]>;
        return { mode => qw| false | };

    add to models zenka start:
        access.cmd.usr.cube: app-models
    (modules.load unchanged — models.* loads automatically)


## verify

    ptd -c on all 5 files
    check no double footers (file should have zero AMOS7 lines — signing adds them)
    check no #,,... stub lines
    report any Curses::UI API uncertainties as comments in the code


## what this enables

    p7c models.app-models   → launches interactive model browser
    lists all invoke + lmstudio models, navigate with j/k, view detail with d,
    repair symlinks with r. foundation for full ui.app.models.

#,,..,.,.,,,.,,,,,.,,,,..,,.,,.,,,.,.,...,...,..,,...,...,..,,...,...,..,,,.,,
#PHP636JDJ5AU2N7V7IKV6CFK6FEUDJKA5NI4XV2PCEMPRVX2F3LHW6PSLUYAUWB2EFUW2Y6UXP4YE
#\\\|KLFJT7YQIOWQY5DUUFVRAUZ25NV4LXKKHDCA3V4MQ6CO2ELKG2D \ / AMOS7 \ YOURUM ::
#\[7]NCKFHYJLIUBQ4SP2DJVJTX47ZMDKKVGXBQFBQCVMEEXNHTVJSQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
