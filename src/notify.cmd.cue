## [:< ##

# name  = notify.cmd.cue
# param = <info|warn|loves> [ sound=<profile> ] <text>
# descr = popup and sound, or ticker while dnd is on
#
# the events zenka sends this [ events.notify.send ]. do-not-disturb on :
# no popup, no sound -- the text goes to a ticker status line instead and
# is kept in the held list [ notify.dnd shows it ], nothing is lost

my $args = $call->{'args'} // '';
$args =~ s{\A\s+|\s+\z}{}g;

my ( $level, $rest ) = split m{\s+}, $args, 2;
return { 'mode' => qw| false |, 'data' => 'level : info, warn or loves' }
    if ( $level // '' ) !~ m{\A(?:info|warn|loves)\z};
$rest //= '';
my $sound = qw| none |;
$sound = $1 if $rest =~ s{\Asound=(\S+)\s*}{};
$rest =~ s{[\x27\\]}{}g;
return { 'mode' => qw| false |, 'data' => 'no message text submitted' }
    if $rest !~ m{\S};

if (<[notify.dnd.active]>) {
    my $held = <notify.dnd.held> //= [];
    ## time and count : a key a restarted zenka cannot hand out again ##
    my $n = sprintf '%d.%d', time, ++<notify.dnd.held_count>;
    push @{$held}, { 'key' => "notify.held.$n", 'text' => $rest };
    <[protocol-7.command.send.local]>->(
        {   'command'   => qw| cube.ticker.status-set |,
            'call_args' => { 'args' => "notify.held.$n [ $level ] $rest" }
        }
    );
    return { 'mode' => qw| true |, 'data' => 'held [ do not disturb ]' };
}

my $reply = $code{"notify.cmd.$level"}->(
    {   %{$call},
        'args' =>
            sprintf( "'%s' '%s'", <notify.cue.title> // 'protocol-7', $rest )
    }
);

<[notify.sound.play]>->($sound) if $sound ne qw| none |;

return $reply;

#,,.,,,.,,...,,..,.,,,,,.,.,.,,,.,,.,,...,,.,,..,,...,...,..,,,,.,,.,,.,,,,..,
#LS5WIYU7F5YG64YDKHQ2XGC6JY2WTWBHO6Y62T777BBDSGAM5XGQCRQ7MXUFQYK5NDREFAEDCTWVS
#\\\|T7YIO7KJVG5TZI37KWUA4KANA32AOVN54YSHFBZR4ORAFLMHNMK \ / AMOS7 \ YOURUM ::
#\[7]UQI6QGZB56IDPTJIC6UQCCQW4OVKHWDPQAVLLRGMZ52YPJ6PJWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
