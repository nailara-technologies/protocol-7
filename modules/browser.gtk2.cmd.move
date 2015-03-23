# >:]

# name  = browser.gtk2.cmd.move
# param = <x> <y>
# descr = move browser window to specified coordinates

return { 'mode' => 'nack', 'data' => 'expected numerical coordinates!' }
    if not defined $$call{'args'}
    or $$call{'args'} !~ /^\d+ +\d+$/;
my ( $x, $y ) = split( / +/, $$call{'args'} );
my $window = <browser.gtk2.obj.window>;

$window->move( $x, $y );

<browser.loop_timer>->cancel;
Event->unloop_all();

return { 'mode' => 'ack', 'data' => 'window moved' }
