## [:< ##

# name  = base.p7ref.self
# descr = Construct P7REF for current zenka identity
# return = TYPE:CHKSUM7:ADDR_B32 string

## Get zenka identity from configuration ##
my $zenka_name = <system.zenka.name> // 'unknown';

## Determine TYPE from zenka name ##
my $type = 'ZENKA';    # default

## Map known zenka types ##
$type = 'CUBE'   if $zenka_name =~ m{^cube}i;
$type = 'V7'     if $zenka_name =~ m{^v7}i;
$type = 'CODE'   if $zenka_name =~ m{^coding}i;
$type = 'MODEL'  if $zenka_name =~ m{^model}i;
$type = 'VISION' if $zenka_name =~ m{^lm-vision}i;
$type = 'LOG'    if $zenka_name =~ m{^p7-log}i;
$type = 'HTTPD'  if $zenka_name =~ m{^httpd}i;

## Generate CHKSUM7 from zenka name using AMOS7 ##
## Use first 7 chars of AMOS7 checksum ##
my $chk_input = "$zenka_name:" . ( <system.hostname> // 'localhost' );

## Check which AMOS checksum module is available ##
my $full_chksum;
if ( exists $code{'chk-sum.amos'} ) {
    $full_chksum = <[chk-sum.amos]>->($chk_input);
} else {
    $full_chksum = <[base.chk-sum.amos]>->($chk_input);
}

my $chksum7 = substr( $full_chksum, 0, 7 );

## Generate ADDR_B32 - 6 chars base32-encoded ##
## Derive from C25519 pubkey if available ##
my $addr_input;
if ( exists $keys{'C25519'}{'pubkey'} && length $keys{'C25519'}{'pubkey'} ) {
    $addr_input = $keys{'C25519'}{'pubkey'};
} else {
    $addr_input = $chk_input;    # deterministic fallback
}

## Use Crypt::Misc for base32 encoding ##
my $addr_b32 = substr( encode_b32r($addr_input), 0, 6 );

## Assemble P7REF: TYPE:CHKSUM7:ADDR_B32 ##
my $p7ref = sprintf( "%s:%s:%s", $type, $chksum7, $addr_b32 );

<[base.log]>->( 2, "[p7ref.self] %s -> %s", $zenka_name, $p7ref );

return $p7ref;

#,,,,,,,.,.,.,,..,,..,,,..,,,..,..,,.,,,...,,..,.,.,...,...,,..,,,.,,,.,..,,...
#G2G2ZMGCSHZ46R3XGL7TAMKMHFG33INKSRTK7L6RUDGZBIRLBBG3VEZNRLQOIUHROB5KHJBBN7D3G
#\\\|GCV2JLN4EVV54LYN73XQO4NRN7FQIYOWO4YB7ZOXXB32KSGFHTF \ / AMOS7 \ YOURUM ::
#\\[7]FDF3X4QBYHL7JHMLCYIMQI5U3QIPN23JFI6IBGYRBE532B5O3CBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
