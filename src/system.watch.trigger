## [:< ##

# name  = system.watch.trigger
# descr = a watch triggered : valid-until, unless, emit
# args  = watch, signal values, now
#
# a once watch takes no further trigger from here on [ state 'triggered'
# while its unless conditions are asked ]. past valid-until the watch ends
# without a signal

my ( $w, $values, $now ) = @ARG;
$now //= time;
<system.watch.dirty> = TRUE;

if ( AMOS7::Switch::expired( $w->{'until'}, $now ) ) {
    $w->{'state'}  = qw| expired |;
    $w->{'reason'} = qw| valid-until |;
    delete @{$w}{qw| held gate |};
    <[base.logs]>->( 1, "watch '%s' expired [ valid-until ]", $w->{'id'} );
    return FALSE;
}

## signal values carry no spaces [ the signal line splits on them ] ##
my %all = ( 'watch' => $w->{'id'}, %{$values} );
my @pairs;
foreach my $key ( sort keys %all ) {
    my $text = $all{$key} // '';
    $text =~ s{[^\x21-\x7e]}{_}g;
    push @pairs, "$key=" . substr( $text, 0, 200 );
}
my $args = join ' ', $w->{'signal'}, @pairs;

$w->{'fired'} = ( $w->{'fired'} // 0 ) + 1;
$w->{'last'}  = int $now;

if ( not length( $w->{'unless'} // '' ) ) {
    $w->{'state'} = qw| fired | if $w->{'mode'} eq qw| once |;
    <[system.watch.emit]>->($args);
    return TRUE;
}

push @{ $w->{'held'} //= [] }, $args;
shift $w->{'held'}->@* while $w->{'held'}->@* > 13;
$w->{'state'} = qw| triggered | if $w->{'mode'} eq qw| once |;
<[system.watch.gate]>->($w)     if not defined $w->{'gate'};
return TRUE;

#,,..,,,.,,,,,,,,,.,.,,,.,,.,,..,,...,,..,,,.,..,,...,...,.,,,,,.,,,.,.,.,,.,,
#IY23CUQSPAWW3P7DDF6RL63RQKYRPVVIQB22Z6FQMDCSAQIEXPZX4DTF3VFPSDCEKJ6NPIQ33DAEC
#\\\|AZPC4HUJKSFNXKJ64DVXEQ6C4IICRTMT6VFDNSBGFYWJAIFZQ4T \ / AMOS7 \ YOURUM ::
#\[7]3Z6VJE5FK7XPSIUCPZTJW5KU5TKVCWAVQP34U5DPDTUFNG4TFADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
