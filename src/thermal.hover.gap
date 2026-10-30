## [:< ##

# name  = thermal.hover.gap
# descr = seconds to hold the next work round : grows with the gpu
#         temperature over the hover mark of the current window, max
#         while the verdict stops work [ 0 = run now ]

my ( $temp, $verdict, $now ) = @ARG;

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

my $gap = ( $temp - $target ) * ( <thermal.cfg.hover.per_c> // 15 );
return 0 if $gap <= 0;

$gap = $gap_max if $gap > $gap_max;

return 0 + sprintf( qw| %.1f |, $gap );

#,,.,,.,.,,,.,..,,..,,,..,.,,,.,.,,..,..,,,,.,..,,...,..,,..,,..,,.,,,,,.,,,.,
#NG2FKJIKKSWFW7MNOXP6VR57LTDWLGITOD5CFOUS2JHRQ3NSQUFGH5OWSHHMDMPZ7JSB6M4EN7RCM
#\\\|XUFNDD4H7NFSVOKCZIKMSKSS4BQAJ25CU3R35ROWKN5LAUCYLUY \ / AMOS7 \ YOURUM ::
#\[7]KIMPP3MRXGKB6IWO6TOSQTYARJV6RNQ6EDAI5GBZVH4YF7SBT4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
