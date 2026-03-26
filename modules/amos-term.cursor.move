## [:< ##

# name  = amos-term.cursor.move
# descr = Move cursor by delta (with bounds checking)

my ( $window_id, $dx, $dy, $dz ) = @ARG;
$dx //= 0;
$dy //= 0;
$dz //= 0;

my $window = <amos-term.windows.by_id>->{$window_id};
return undef unless defined $window;

my $cursor = $window->{'buffer'}->{'cursor'};
my $dims   = $window->{'buffer'}->{'dimensions'};

## calculate new position ##
my $new_x = $cursor->{'x'} + $dx;
my $new_y = $cursor->{'y'} + $dy;
my $new_z = $cursor->{'z'} + $dz;

## bounds checking ##
$new_x = 0              if $new_x < 0;
$new_x = $dims->[0] - 1 if $new_x >= $dims->[0];
$new_y = 0              if $new_y < 0;
$new_y = $dims->[1] - 1 if $new_y >= $dims->[1];
$new_z = 0              if $new_z < 0;
$new_z = $dims->[2] - 1 if $new_z >= $dims->[2];

## update cursor ##
$cursor->{'x'} = $new_x;
$cursor->{'y'} = $new_y;
$cursor->{'z'} = $new_z;

## reset blink cycle ##
<graphics-3d.cursor.blink_start> = <[base.time]>->(3);

return $cursor;

#,,,,,..,,,,,,,..,,.,,,,.,...,..,,...,,..,.,.,.,.,...,.,.,.,.,,,.,,,.,,,,,,..,
#7QX57KHM54BJCUFWX7JLGGIBVLK443EJTOOF6MKOJRKQIJKHYPSUUAN245PCSQUTCG6XF56P6OBSA
#\\\|ILDWHGBDGH6K3KZS2SKSBWCKWZ22TOIVWMBT7OURWH3EJDEZELB \ / AMOS7 \ YOURUM ::
#\[7]EMO7C7D5R2DARTAXMPFHNPNM3YYYUHBBRCLGV7EBPQNJXE2LYECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
