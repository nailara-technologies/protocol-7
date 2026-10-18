package BlockInlineC;
## test only : hides Inline::C for one run ##
unshift @INC, sub {
    die "blocked for " . "test\n" if $_[1] eq 'Inline/C.pm';
    return;
};
1;

#,,,,,,,.,,.,,.,.,,,.,,,.,.,.,,,,,,,,,,,.,,..,..,,...,...,..,,..,,,,,,.,.,,,.,
#GPH3MRHPQ7UTNDB6IPOFFIVLVVCGBKV24CQEZPE7B7PKZ5JCS7GXTCJBQWAJBTSXKYN54Z64IYI3S
#\\\|CU7JJCTB6WB57LF2DEYDJQRA624SKDV326EY3OHACI5C77DFFLT \ / AMOS7 \ YOURUM ::
#\[7]RSNJGKSBCYOKJPPF7X3AZWV6SVZ3EJF522E322FVTCATJQIH7SAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
