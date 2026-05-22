## [:< ##

# name  = space.register.self
# descr = engine registers itself as @INDEXCUBE[0] with branch node
# param = {}

## create branch node for the engine ##
my $branch_node;
$branch_node = <[branch.node.create]>->(
    {   'name'   => 'space-engine',
        'parent' => '',
        'face'   => 0,
        'meta'   => { 'role' => 'space-engine' },
    }
);

my $engine_node_id = $branch_node->{'id'} // '';
return { 'mode' => qw| false |, 'data' => 'branch node creation failed' }
    unless length $engine_node_id;

## assign outer shell coordinate ##
my $existing = scalar keys %{ <space.grid.nodes> // {} };
my $n        = $existing + 1;
my $pos      = int( $n / 2 ) || 1;
my $sign     = ( $existing % 2 ) ? -1 : 1;

my $coord = {
    'z' => $sign * $pos,
    'y' => $sign * $pos,
    'x' => $sign * $pos,
};

<space.grid.nodes>->{$engine_node_id} = {
    'z'     => $coord->{'z'},
    'y'     => $coord->{'y'},
    'x'     => $coord->{'x'},
    'shell' => $pos,
};

## derive base32 coordinate string ##
my $coord_str = sprintf '%d:%d:%d', $coord->{'z'}, $coord->{'y'},
    $coord->{'x'};
my $chksum_fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
my $coord_b32 = substr( $chksum_fn->( \$coord_str ), 0, 6 );

## push to @INDEXCUBE[0] ##
my $p7ref = 'SPACE:' . $engine_node_id . ':' . $coord_b32;
my $entry = {
    'p7ref'     => $p7ref,
    'timestamp' => <[base.time]>->(5),
    'depth'     => 0,
};

## sign entry if checksum available ##
my $entry_str = sprintf "%s:%d:%d", $p7ref, $entry->{'timestamp'}, 0;
$entry->{'signature'} = $chksum_fn->( \$entry_str );

$INDEXCUBE[0] = $entry;

## create empty aura ##
<space.orbit.auras>->{$engine_node_id} //= {
    'typical_frame_scale' => 13,
    'burst_profile'       => [13],
    'entropy_signature'   => 'AMOS7',
    'buffer_reserve'      => 13,
    'confidence'          => 0,
};

<[base.logs]>->( 1, 'space: engine registered at [%s]', $coord_b32 );

return { 'mode' => qw| true |, 'data' => $engine_node_id };

#,,,.,,,.,,..,,,,,..,,.,,,..,,...,.,.,,.,,,..,.,.,...,...,.,,,..,,...,..,,.,.,
#RUMI5YQ4AHFM63QVTEGLMZQMSPFBABFFTATS3NN5A2BVEH2J66E5KL3IBL6EVVLJH74DORQFXCFJY
#\\\|EJL2HBSPETFWGJN3XVBRPLAKIHRC24HUJODW7URHFY4TKSOF3TW \ / AMOS7 \ YOURUM ::
#\[7]6LGUAKWUNWFTVDYTWQEFUJRLZYJ7F6JND4PYOMVMJCTGSRBOTWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
