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

add to cfg/zenki/httpd/subroutine.white-list:
  route.bmw384.visual.wheel.alpha-density

## style notes

- $ARG not $_ in for loops
- lowercase comments with [ word ] bracket style
- new module: leave clean, no footer stub
- existing modules: signatures will be updated on commit

#,,.,,,..,,.,,,.,,..,,,,.,,..,...,,,,,...,...,..,,...,...,...,.,.,..,,.,.,..,,
#BBOP7BFI3OMI65J7F2CTXWV6FG4EQV2VS3FXMDZ7XZKIO75LOVCMH74IGP6MXJLIKGM3JRI43NXCS
#\\\|PRBYGIM2BFXMM4VDXSK2BGJ5JLFZ2NHLXX7WNU2TNIJOM7HAY7J \ / AMOS7 \ YOURUM ::
#\[7]S2MQYPTWZ6IM52UXYJW4IVPIQNAJEAFY3NKZH4SYWIYOQNKLFOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
