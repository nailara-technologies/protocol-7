## [:< ##

# name  = task: implement AMOS7::CHKSUM::BMW384 and base.chk-sum.bmw384.* primitives
# descr = BMW384 geometry: extract color (24-bit) and angle (360-bit) from a raw digest,
#         compute closed-wheel color distance, group checksums by color proximity,
#         and map a color value to its arc segment (0..25)

## background

BMW384 digest = 384 bits total. the bit layout treats the first 24 bits as a 'color'
field and the remaining 360 bits as an angular value on the unit circle. the 24-bit
field encodes a spectral wheel position (0..16777215) and divides the circle into
26 arc segments (24 separators → 26 elements = 2 × 13). this geometry is the basis
for resonance-based routing, temporal sync, and stream self-location.

## module to create: AMOS7::CHKSUM::BMW384

file: data/lib-path/pm/AMOS7/CHKSUM/BMW384.pm

exports (all optional import):
  bmw384_color       -- extract 24-bit color value from raw 48-byte digest
  bmw384_angle_bits  -- extract 360-bit angle bitstring from raw 48-byte digest
  bmw384_color_dist  -- closed-wheel distance between two color values
  bmw384_arc_segment -- which arc segment (0..25) a color value falls in
  bmw384_group       -- filter a list of digests by color proximity to a center

### bmw384_color ( $digest_bytes )

$digest_bytes is a 48-byte raw binary string (Digest::BMW output at 384 bits).
extract bits 0..23 as a 24-bit unsigned integer using vec():

  my $color = 0;
  for my $i ( 0 .. 23 ) {
      $color = ( $color << 1 ) | vec( $digest_bytes, $i, 1 );
  }
  return $color;

return: integer 0..16777215

### bmw384_angle_bits ( $digest_bytes )

extract bits 24..383 as a 360-bit string of '0' and '1' characters.
return: string of length 360

### bmw384_color_dist ( $color_a, $color_b )

closed-wheel distance on a 2^24 circle:
  my $max  = 2**24;
  my $diff = abs( $color_a - $color_b );
  return $diff < $max / 2 ? $diff : $max - $diff;

return: integer 0..8388608

### bmw384_arc_segment ( $color )

divide the color wheel into 26 equal segments:
  return int( $color / ( 2**24 / 26 ) );

clamp result to 0..25. return: integer 0..25

### bmw384_group ( $center_color, $radius, @digest_list )

@digest_list is a list of raw 48-byte digest strings.
return arrayref of digests whose color is within $radius of $center_color
(using bmw384_color_dist for closed-wheel comparison).

## zenka wrapper modules to create

these are thin pass-throughs callable as <[base.chk-sum.bmw384.color]>->($digest):

### modules/base.chk-sum.bmw384.color
  calls bmw384_color( $ARG ) and returns the integer color value

### modules/base.chk-sum.bmw384.angle-bits
  calls bmw384_angle_bits( $ARG ) and returns the 360-char bit string

### modules/base.chk-sum.bmw384.color-dist
  calls bmw384_color_dist( $ARG[0], $ARG[1] )

### modules/base.chk-sum.bmw384.arc-segment
  calls bmw384_arc_segment( $ARG )

### modules/base.chk-sum.bmw384.group
  calls bmw384_group( $ARG[0], $ARG[1], @ARG[2..$#ARG] )

each wrapper must autoload AMOS7::CHKSUM::BMW384 via:
  use AMOS7::CHKSUM::BMW384 qw| bmw384_color ... |;
or load it once via <[base.perlmod.autoload]>->('AMOS7::CHKSUM::BMW384').

## notes on signatures

- new files: leave clean, no stub footer — signing system adds the real 4-line footer
- AMOS7::CHKSUM::BMW384.pm: standard Perl module format with package declaration,
  use Exporter, and a plain 1; at the end — no P7 stub footer on .pm files

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging in zenka wrappers
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules (wrappers)
- AMOS7::CHKSUM::BMW384.pm may use standard Perl pragmas (strict, warnings, Exporter)

#,,..,.,,,,,.,,..,,..,,,,,,,.,...,.,,,..,,,,,,..,,...,..,,...,,,.,,..,,.,,...,
#Q5VPDZUWY4IAX3MB7W5MR7PKXILCATX7HFNPBOWYIYGWRA2ELL4OQQTQA7TMP7Z4FDBY3EPT5YFQ2
#\\\|5PE7OCFHHMHQMV6G7TPDEGPRW74KDDOBBBC6YZVVIHW2VGHUHTR \ / AMOS7 \ YOURUM ::
#\[7]B7JWSK6UU5ZWMPUPLQX6QDWWWGR774ZCXKTTJJIVXY5Z4Z6ZFMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
