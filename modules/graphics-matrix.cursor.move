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

#,,,,,.,,,.,.,...,.,,,,..,,,,,..,,..,,,,,,,,.,.,.,...,...,,.,,.,.,,,.,..,,..,,
#YPOLZU2MK6V2DVUEOIZOFXIW3IZ5IK7RYCLT3P45MVBQEYMROZOUF7Y7GONYAP36THZGOJVFF7IEK
#\\\|VLKQSDJVRNCUVKBAYSXXG4HDUZYYQTFQHZQGRPG5IG663QTZW25 \ / AMOS7 \ YOURUM ::
#\[7]RNYKHHZN2KTVLPBJDKD4VG6ID5CHANZSC53YLJSLZHDH25OCCECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
