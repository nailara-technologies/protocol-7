## [:< ##

# name  = task: break long lines in BMW384 visual wheel modules
# descr = pure formatting — no logic changes, max 80 chars per line

## files to fix

  src/route.bmw384.cmd.visual-wheel          [ 92 violations, max 119 ]
  src/route.bmw384.visual.wheel-html         [ 25 violations, max 133 ]
  src/route.bmw384.visual.wheel.gauss        [ 77 violations, max 92 ]
  src/route.bmw384.visual.wheel.metric       [ 4 violations, max 81 ]
  src/route.bmw384.visual.wheel.overlay      [ 4 violations, max 86 ]
  src/route.bmw384.visual.wheel.heatmap      [ 80 violations, max 96 ]
  src/route.bmw384.visual.wheel.density      [ 4 violations, max 86 ]

## how to break lines

use perl string concatenation to break long strings across lines.

before:
  $svg .= sprintf '  <circle cx="%.2f" cy="%.2f" r="%d" fill="%s" opacity="%s">' . "\n", $x, $y, $r, $color_hex, $opacity;

after:
  $svg .= sprintf
      '  <circle cx="%.2f" cy="%.2f" r="%d" fill="%s" opacity="%s">'
      . "\n", $x, $y, $r, $color_hex, $opacity;

for long sprintf format strings, break the format into concatenated pieces:
  $svg .= sprintf
      '  <text x="%.2f" y="%.2f" fill="rgba(255,255,255,%.2f)"'
      . ' font-size="%d" text-anchor="middle"'
      . ' dominant-baseline="middle">%s</text>'
      . "\n", $x, $y, $lop, $label_font_size, $label;

for chained .= sprintf that overflow, same approach — move format to next line.

for long variable assignments, break at operators:
  my $min_excess
      = $some_long_expression + $another_thing;

## what NOT to change

- do not alter the ## [:< ## header line
- do not alter # name = / # descr = lines
- do not alter the 4-line AMOS7 signature footer at end of each file
- do not change any perl logic or variable names
- keep $ARG not $_
- keep <[module.name]> and <data.key> syntax intact
- keep all lowercase comments with [ word ] bracket style

## verify each file

after editing each file, run:
  grep -n '.\{81\}' src/route.bmw384.visual.wheel.gauss

zero output = done for that file. fix remaining violations if any.

## signatures note

existing modules are re-signed by the signing system on commit.
leave the 4-line footer exactly as-is — do not regenerate or stub it.

## reasoning

low — mechanical reformatting only.

#,,.,,,..,...,,.,,,..,..,,,,.,..,,,..,..,,.,,,..,,...,...,.,.,...,,,,,,,,,.,.,
#S7E5EWUEBTNOZT7YPNV7YSZQJY67Y3Z3AWP6OJUAXYXE7RC4VEBWYKHNRZJDO576Y3VKG7V3LCQMG
#\\\|ABCYE62XITRYSGTPFMU7TNMA3FZKBQQQJVGZGNJ6KMP5SJC7FUF \ / AMOS7 \ YOURUM ::
#\[7]ZJFAD26Q5TLMESPXD23YFN7ULTA2TT7PA7OOFP45SYLB7MEGSQAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
