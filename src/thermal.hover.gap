## [:< ##

# name  = thermal.hover.gap
# descr = seconds to hold the next work round : grows with the gpu
#         temperature over the hover mark of the current window, max
#         while the verdict stops work [ 0 = run now ]

my ( $temp, $verdict, $now, $boost ) = @ARG;

my $gap_max = <thermal.cfg.hover.gap_max> // 180;

## the ceiling and memory verdicts hold in every window ##
return $gap_max
    if defined $verdict
    and ( $verdict eq qw| pause | or $verdict eq qw| unload | );

## no fresh temperature : run as before [ the hold is a comfort brake ] ##
return 0 if not defined $temp;

my $night = <[thermal.window.current]>->($now) eq qw| night |;
my $target
    = $night
    ? <thermal.cfg.hover.night>
    : <thermal.cfg.hover.day>;
return 0 if not defined $target or not length $target or $target <= 0;

## cold outside, warmer room wanted : the night mark rises with the outdoor ##
## amplifier [ 1.0 .. outdoor.max ] -- 3 C out = about +5.6 C               ##
if ($night) {
    my $amp = <[thermal.outdoor.amp]>->(
        <thermal.outdoor.temp>, <thermal.outdoor.at>, $now
    );
    $target += ( $amp - 1 ) * ( <thermal.cfg.hover.amp_c> // 12 );
}

if ( defined $boost and ( $boost->{'until'} // 0 ) > $now ) {
    return 0 if $boost->{'delta'} eq qw| full |;
    $target += $boost->{'delta'};
}

my $gap = ( $temp - $target ) * ( <thermal.cfg.hover.per_c> // 15 );
return 0 if $gap <= 0;

$gap = $gap_max if $gap > $gap_max;

return 0 + sprintf( qw| %.1f |, $gap );

#,,,.,...,.,.,.,.,,.,,,..,,,,,.,.,..,,.,,,.,,,..,,...,...,.,,,...,,,,,.,.,,,,,
#MNV6KGDY4ZF7YBJYCQ5HC6WV4CAERKKB3BZKWEEH7UEIBHBF5P4CLCF5XNBTSE2STGAHVKNSHTMHM
#\\\|A42BLORXDAPOXUWS5QC774C3NMBN4FOZGMJHVVLHKBUGYYN2SMW \ / AMOS7 \ YOURUM ::
#\[7]6YEMAUSEO64MX7MXZJULCFUCWZ7V6EJW265HP2QJERTLBVUZO4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
