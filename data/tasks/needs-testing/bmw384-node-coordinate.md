## [:< ##

# name  = task: implement AMOS7::CHKSUM::BMW384::Coordinate — universal node position
# descr = given any scalar input, compute its BMW384 field coordinate as a structured
#         hashref: { color, arc, angle_bits, angle_int, segment_label }
#         this is the foundational primitive — all field index and routing builds on it

## depends on

task: bmw384-color-extract.md — AMOS7::CHKSUM::BMW384 base primitives must exist first.
extend that module rather than creating a new one — add Coordinate functions to
AMOS7::CHKSUM::BMW384 and export them alongside the existing ones.

## background

every addressable entity in the P7 field — zenka name, checksum string, IP address,
arbitrary scalar — can be mapped to a unique position in the BMW384 resonance field.
the position is derived by hashing the input with BMW384 and decomposing the digest:

  - bits 0..23   → color (24-bit unsigned int, 0..16777215)
  - bits 24..383 → angle (360-bit value encoding position on the unit circle)

the arc segment (0..25, mapping to A..Z) is derived from the color.
the segment label is the corresponding uppercase letter.

this coordinate is the universal address — routing, discovery, and visualization
all operate on coordinates rather than on the original input values.

## functions to add to AMOS7::CHKSUM::BMW384

export list addition: bmw384_coordinate, bmw384_coordinate_str

### bmw384_coordinate ( $input )

$input is any defined scalar (string, number, binary data).
returns a hashref:

  {
    color         => $color,          ## 24-bit int 0..16777215
    arc           => $arc,            ## int 0..25
    segment_label => $label,          ## 'A'..'Z'
    angle_bits    => $angle_bits,     ## 360-char '0'/'1' string
    angle_int     => $angle_int,      ## Math::BigInt of the 360-bit value
    digest        => $raw_digest,     ## raw 48-byte binary string
  }

implementation:
  1. compute raw digest:
       use Digest::BMW;
       my $bmw = Digest::BMW->new(384);
       $bmw->add( $input );
       my $digest = $bmw->digest;
  2. extract color via bmw384_color( $digest )
  3. extract arc via bmw384_arc_segment( $color )
  4. segment_label = chr( ord('A') + $arc )
  5. extract angle_bits via bmw384_angle_bits( $digest )
  6. convert angle_bits to Math::BigInt:
       use Math::BigInt;
       my $angle_int = Math::BigInt->new('0b' . $angle_bits);
  7. return hashref

### bmw384_coordinate_str ( $input )

returns a compact human-readable string representation of the coordinate:
  sprintf '%s:%06X:%s', $coord->{segment_label}, $coord->{color}, substr($coord->{angle_bits}, 0, 16)

format: "B:1A3F2C:0110100110110101" — segment letter, hex color, first 16 angle bits
useful for logging and debug output

## zenka wrapper modules to create

### src/base.chk-sum.bmw384.coordinate

thin wrapper: takes a scalar $ARG, returns the coordinate hashref.

  <[base.perlmod.autoload]>->('AMOS7::CHKSUM::BMW384');
  return AMOS7::CHKSUM::BMW384::bmw384_coordinate( $ARG );

### src/base.chk-sum.bmw384.coordinate-str

thin wrapper returning the compact string form.

## notes on signatures

- new zenka module files: leave clean, no stub footer
- AMOS7::CHKSUM::BMW384.pm additions: extend existing file, preserve existing exports
- Math::BigInt is a core CPAN module, available in the P7 environment

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging in zenka wrappers
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,,,,,,,,..,,,,,,,..,..,,,,.,...,,..,.,,,,..,..,,...,.,.,.,,,...,,,,,..,,.,.,
#YHH32PY7VDFR4Z5I3GQ5SNF7XW3X3ZS7WSGXLYLLWVF2I3FZ3PZX32XLA6EPTAGSJLFWHQGXUFK3Y
#\\\|D4HT45H2H6QSLMAR2M7RN2B26HVLFCVMKQ6AOJBEZGJMBZEV7M5 \ / AMOS7 \ YOURUM ::
#\[7]VUIWJE3PZMO4IDYLEFCLUXO5MWDGY4CHE4Y2XMI2TIKQWMEJJCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
