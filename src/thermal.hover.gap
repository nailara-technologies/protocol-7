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

my $target
    = <[thermal.window.current]>->($now) eq qw| night |
    ? <thermal.cfg.hover.night>
    : <thermal.cfg.hover.day>;
return 0 if not defined $target or not length $target or $target <= 0;

if ( defined $boost and ( $boost->{'until'} // 0 ) > $now ) {
    return 0 if $boost->{'delta'} eq qw| full |;
    $target += $boost->{'delta'};
}

my $gap = ( $temp - $target ) * ( <thermal.cfg.hover.per_c> // 15 );
return 0 if $gap <= 0;

$gap = $gap_max if $gap > $gap_max;

return 0 + sprintf( qw| %.1f |, $gap );

#,,,.,.,.,.,,,,,.,,,,,.,.,,,,,..,,...,,,.,..,,..,,...,...,,,.,,,,,...,.,.,,,.,
#HELJADBQX4C46VP2EFQFOT4KZIQ7LHT5GRDL6XQFPNAMID225VEUG4PZJA5SR44FK7YHVGUZMYG4Q
#\\\|2PHPAZ6S26Y3YMAOW3N2Y5IIJQOJIKAN4NLLOR6CPIJ74ILXPMU \ / AMOS7 \ YOURUM ::
#\[7]5PZNQMMLQTL52QC3H72UIXMOLMIMILGKOZ3MBPZQJCSLRZHV5MAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
