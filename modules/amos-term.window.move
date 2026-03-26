## [:< ##

# name  = amos-term.window.move
# descr = Move GTK3 window to new position

my ( $window_id, $x, $y ) = @ARG;

my $window = <amos-term.windows.by_id>->{$window_id};
return undef unless defined $window;

my $gtk_win = $window->{'display'}->{'gtk_window'};
return undef unless defined $gtk_win;

$gtk_win->move( $x, $y );

return $window_id;

#,,.,,...,.,.,,.,,,,,,..,,...,...,,..,...,,,.,.,.,...,...,.,.,..,,,,,,.,.,,,.,
#4MW77MRW4KG3AQJA6GWH5BE76XFGKK4PZQ3HT3HZP5KBS44Z6MIX4QZQJDYOG727Y7TG7BS6P2TSE
#\\\|4TV5O6X6LIBSGRBNLWTEII7ZK4N4TOYQ7GS2SF4BFNG7PPEKK3R \ / AMOS7 \ YOURUM ::
#\[7]HJHVYFPLC6XIZ4TSKKGJDU63QFKCEAJVG75VD6KOFYJURNXJGOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
