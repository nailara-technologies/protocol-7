# task: extract inline subroutines from web plugin modules

## context

two `plugin.web.*` modules contain inline `sub` declarations which cause
"Subroutine redefined" warnings on plugin reload. in P7, each module file
IS a single callable subroutine — inline subs need to be extracted to their
own module files.

## modules to process

### 1. plugin.web.content.dirlist

contains two inline subs:

- `_format_size` (line ~151) — format bytes to human-readable string
  → extract to `plugin.web.content.util.format_size`

- `_calculate_checksum` (line ~169) — compute elf checksum for file
  → extract to `plugin.web.content.util.calculate_checksum`

update call sites in `plugin.web.content.dirlist`:
- `_format_size($size)` → `<[plugin.web.content.util.format_size]>->($size)`
- `_calculate_checksum(...)` → `<[plugin.web.content.util.calculate_checksum]>->(...)`

### 2. plugin.web.menu.tree

contains one inline sub:

- `_generate_submenu` (line ~97) — recursive submenu html generation
  → extract to `plugin.web.content.util.generate_submenu`

update call sites in `plugin.web.menu.tree`:
- `_generate_submenu(...)` → `<[plugin.web.content.util.generate_submenu]>->(...)`

also update the recursive self-call inside `_generate_submenu` itself (line ~74
in the sub body calls itself recursively).

## P7 module rules — MUST follow

- each new file starts with `## [:< ##` then `# name = ...` and `# descr = ...`
- NO `sub { }` wrapper — the file content IS the subroutine body
- use `$ARG` not `$_` in map/grep
- use `my $param = shift;` for parameters
- lowercase comments only: `## format bytes ##` not `## Format Bytes ##`
- do NOT add signature stub lines (`#,,.,,,...`) — leave files clean
- use `<[module.name]>->($args)` syntax — closing `]>` BEFORE `->`
- qw| word | style for hash keys: `qw| mode | => qw| size |`

## verification

after creating all new modules and updating call sites:

1. `ptd -c` all modified and new module files
2. confirm no `sub _` declarations remain in the two source modules
3. confirm no `$_` usage (should be `$ARG`)

## whitelist

new modules must be added to `cfg/zenki/web/subroutine.white-list`:
- plugin.web.content.util.format_size
- plugin.web.content.util.calculate_checksum
- plugin.web.content.util.generate_submenu

#,,.,,.,,,,.,,,.,,.,.,..,,...,,,,,.,,,...,.,.,..,,...,...,,.,,,,.,,,.,.,.,,..,
#HSKFIZHW3SH5M26FJOBI5WRJCKLMVWRP4P7P5TAPEYVVT43IVG7SSHDATLMX5ITVVCIZSGD45EKIY
#\\\|CEALUSHUOGRPCGZNVPHABYWF3HKXE6Y4GTA3CG5YLW6UIC2IFTT \ / AMOS7 \ YOURUM ::
#\[7]JU2MHXECRKHFRFOXV5UCLGFVD6IM2CQCHTR4HHDYLTGYBSFSAYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
