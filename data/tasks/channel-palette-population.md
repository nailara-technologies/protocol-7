# task: graphics-matrix channel palette population

## context

the orbital visualization colors CCW trails using `channel.palette` from orbital.json.
currently `channel.palette = []` — empty because no cells are placed at channel frequencies.

the graphics-matrix channel system (6 modules: channel.init/select/current/translate/palette,
cmd.channel) separates frequency bands using the division-13-table (generator 076923).
`channel.palette` should return an array of hex color strings for the active channel.

## what to investigate

1. read `modules/graphics-matrix.channel.init` — how are channels initialized?
   what data does `$data{'graphics-matrix'}{'channel'}` contain after init?

2. read `modules/graphics-matrix.channel.palette` — what does it return?
   does it depend on cells being placed, or is the palette static per channel?

3. read `modules/graphics-matrix.cmd.orbital-sync` — it calls:
   `my $palette_raw = eval { <[graphics-matrix.channel.palette]> } // [];`
   `$channel->{'palette'} = [ map { $ARG->{'color'}{'hex'} // '' } @$palette_raw ];`
   what format does channel.palette actually return?

## goal

after `p7c v7.start_once graphics-matrix` and waiting for the orbital fetch cycle (13s):
`NO_PROXY=127.0.0.1 curl -s -H "Host: space.v7.ax" http://127.0.0.1/orbital.json`
should show `channel.palette` as a non-empty array of hex color strings like:
  `["#3040ff", "#4060cc", "#2080aa", ...]`

## fix options

a) if palette.init is static: call channel.init with appropriate freq params during
   graphics-matrix.init_code so palette is populated from startup

b) if palette depends on placed cells: seed graphics-matrix with the orbital coordinates
   as initial cells during init (before first orbital fetch arrives)

c) if channel.palette returns wrong format: fix the map in orbital-sync to match
   the actual structure returned

## signatures note

do NOT add stub signature line to modified files.

#,,..,..,,,,,,.,.,,..,.,.,.,,,.,.,.,.,...,..,,..,,...,...,.,,,,.,,,,,,,..,.,.,
#Q4YUS5JTCEYNVJT5PHY4AU6NAQ2AM2Z3GLX7OPX3KXY6LBKG4KXFEYIUHVUTOSPLEB6UOONE7G43K
#\\\|D2QO5DHDUPFCPNEYMC4HI4FIIPB4TXRE7O2CSGWLJLD6NOPJT32 \ / AMOS7 \ YOURUM ::
#\[7]VMLQI623DLYB4UMZPIUDQQQMLZMGVJMBZJB6D26FF3IAKPQRDUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
