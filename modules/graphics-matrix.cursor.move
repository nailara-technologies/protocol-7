## [:< ##

# name  = graphics-matrix.cursor.move
# descr = move cursor by relative offset

my $params = shift // {};

my $cursor = $data{'graphics-matrix'}{'cursor'};

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

## return new position (shallow copy) ##
return {
    qw| selX | => $cursor->{'selX'},
    qw| selY | => $cursor->{'selY'},
    qw| selZ | => $cursor->{'selZ'}
};

#,,.,,,,,,.,.,,,,,.,,,,,,,.,.,,,,,..,,,,,,.,,,.,.,...,..,,..,,,..,..,,...,.,.,
#X4BTFNSYCSR2LJYZMYKXXU7HNI3J24JU6HSQ2WMIJZKE23BWFODLQKJKOOQKB7I7E6I5UN6D4QO7S
#\\\|KPLUKLGYC6T5K2V5ADUUYE2AXNBLH2N2LQ2CI4UNEZXY5OIKYPH \ / AMOS7 \ YOURUM ::
#\[7]GT4SMVUN6WZ5JMKKI2Y3OTNVQIQ3CNXGBARDUBK3MCCF3M2PLKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
