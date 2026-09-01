## [:< ##

# name  = graphics-matrix.cursor.move
# descr = move cursor by relative offset

my $params = shift // {};

my $cursor = <graphics-matrix.cursor>;

## store previous position for logging ##
my ( $old_x, $old_y, $old_z )
    = ( $cursor->{'selX'}, $cursor->{'selY'}, $cursor->{'selZ'} );

## apply deltas (unlimited integer range, no clamping) ##
$cursor->{'selX'} += $params->{'dx'} // 0;
$cursor->{'selY'} += $params->{'dy'} // 0;
$cursor->{'selZ'} += $params->{'dz'} // 0;

<[base.logs]>->(
    2, 'cursor.move [%d,%d,%d] -> [%d,%d,%d]',
    $old_x, $old_y, $old_z, $cursor->{'selX'}, $cursor->{'selY'},
    $cursor->{'selZ'}
);

## register position in address registry ##
<[graphics-matrix.address.register]>->(
    {   qw| position | => {
            qw| selX | => $cursor->{'selX'},
            qw| selY | => $cursor->{'selY'},
            qw| selZ | => $cursor->{'selZ'},
        },
    }
);

## return new position (shallow copy) ##
return {
    qw| selX | => $cursor->{'selX'},
    qw| selY | => $cursor->{'selY'},
    qw| selZ | => $cursor->{'selZ'}
};

#,,.,,...,.,.,.,,,,.,,,,.,,.,,,..,,..,.,,,,,.,.,.,...,...,.,,,,,.,,,.,..,,.,,,
#SSZYFFGICKMW7XWWTRANJ5UX7DXK6MCPGYDZK3TW3JIC3YC3I6JJS4UWNMOFUWPTRTFFADXMUE5QY
#\\\|P2M6O6J77GX6YHFG5VOFAM6ASKTXHZTO45PBVIXAUUE67NJFCB5 \ / AMOS7 \ YOURUM ::
#\[7]6OJI3M2JME2AL6QMXCFIFJHGHULXHVAAGQKIT3FJYLIXGNOV2YCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
