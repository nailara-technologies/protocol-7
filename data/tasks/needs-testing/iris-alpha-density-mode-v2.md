## [:< ##

# name  = task: iris new visualization mode - proportional bit coverage
# descr = add 'alpha-density' mode to iris wheel visualization
#         node brightness proportional to how many modules share each angular position

## background

the BMW384 coordinate system assigns each module an angular position (0-359 degrees).
multiple modules can share similar angular positions. currently all nodes render at
the same opacity regardless of how many modules cluster at their angular position.

the new mode makes brightness proportional to clustering — nodes at popular
angular positions glow brighter, nodes at rare positions are dimmer.

## step 1: update route.bmw384.index.init

read the current file first. then add two new keys to the index structure:
  degree_density      — array of 360 integers, all starting at 0
  degree_density_max  — integer, starts at 0

```perl
<bmw384.index>->{'degree_density'}     = [ (0) x 360 ];
<bmw384.index>->{'degree_density_max'} = 0;
```

## step 2: update route.bmw384.index.from-file

read the current file first. after the line that stores the coordinate:
  <bmw384.index>->{'by_name'}{$name} = $coord;

add code to accumulate the angle_bits into the counting array:

```perl
if ( defined $coord->{'angle_bits'}
    and length( $coord->{'angle_bits'} ) == 360 ) {
    my $arr = <bmw384.index>->{'degree_density'};
    my $max = <bmw384.index>->{'degree_density_max'} // 0;
    for my $d ( 0 .. 359 ) {
        if ( substr( $coord->{'angle_bits'}, $d, 1 ) eq '1' ) {
            $arr->[$d]++;
            $max = $arr->[$d] if $arr->[$d] > $max;
        }
    }
    <bmw384.index>->{'degree_density_max'} = $max;
}
```

## step 3: new module route.bmw384.visual.wheel.alpha-density

create a new file. copy the structure from route.bmw384.visual.wheel
(read that file first as reference).

key differences from the base wheel module:
- read degree_density and degree_density_max from the index
- for each node, compute its degree position (integer 0-359) from angle_deg
- set node opacity based on counting array value at that degree

the opacity formula:
```perl
my $count = $density_arr->[$degree_position] // 0;
my $alpha = sprintf '%.2f',
    0.15 + 0.85 * ( $count / $density_max );
```

floor 0.15 means all nodes are at least slightly visible.
ceiling 1.0 means the most popular angular positions are fully bright.

tooltip for each node should show: module name, count value, percentage of max.

## step 4: update route.bmw384.visual.wheel-mode

read the current file first. add a new branch:

```perl
elsif ( $mode eq 'alpha-density' ) {
    return <[route.bmw384.visual.wheel.alpha-density]>
}
```

## step 5: update iris.v7.ax/index.html

read the file first. add one button to the mode buttons row:

```html
<button class="mode-btn" data-mode="alpha-density">α-density</button>
```

## step 6: update subroutine whitelist

add to configuration/zenki/httpd/subroutine.white-list:
  route.bmw384.visual.wheel.alpha-density

## style notes

- $ARG not $_ in for loops
- lowercase comments with [ word ] bracket style
- new module: leave clean, no footer stub
- existing modules: signatures will be updated on commit

#,,.,,.,.,...,..,,,.,,.,.,.,.,.,.,,..,,..,,,,,..,,...,..,,.,,,,..,.,,,...,,..,
#HMS3PNBOGREVNF5J67ZFVAXUZHDGYPRA2JQXW6VDGHODWT64SYYX2FMMIP5JSMUPCZP5AS7G57NJK
#\\\|GNEQ43623OX2LNLWQ5QBFMEDDR6WT4YU4WMEVI6EVCKXOL7YFZM \ / AMOS7 \ YOURUM ::
#\[7]NJCLHS32NLTKWJD5US46P646SFIMXLSZ5MM5EP3DR7UEFKVGC4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
