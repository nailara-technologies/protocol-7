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

## resolve amos checksum sub — works before and after swap ##
## use $code{} directly to bypass P7 pre-validation of <[...]> names ##
my $amos_chksum = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};

my $chksum7 = substr( $amos_chksum->($chk_input), 0, 7 );

## generate ADDR_B32 — 6 chars from AMOS7 checksum of pubkey ##
my $addr_input;
if ( exists $keys{'C25519'}{'pubkey'} && length $keys{'C25519'}{'pubkey'} ) {
    $addr_input = $keys{'C25519'}{'pubkey'};
} else {
    $addr_input = $chk_input;    ## deterministic fallback ##
}

my $addr_b32 = substr( $amos_chksum->($addr_input), 0, 6 );

## Assemble P7REF: TYPE:CHKSUM7:ADDR_B32 ##
my $p7ref = sprintf( "%s:%s:%s", $type, $chksum7, $addr_b32 );

<[base.log]>->( 2, "[p7ref.self] %s -> %s", $zenka_name, $p7ref );

return $p7ref;

#,,,,,.,.,...,,..,,,.,..,,...,,,.,.,,,.,,,.,.,.,.,...,...,.,,,,,,,,,.,..,,,,.,
#MJ2ELVP6WCGJPU7OGDIZCXVLIKX75MBNWXHHUYFT6QXOKPTCURE4OP3AI3ZRM3WUUMP2LXFXFAGDU
#\\\|XKE3MY4ZE2HDJQ4RTUIFP6P6PMW5G72HRO3WE76XHULF6RB6TJ3 \ / AMOS7 \ YOURUM ::
#\[7]QNJATH7PEWPSQ4T54EX656HTHCJXAQRJMUG5D5ZHHIJFITPYOODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
