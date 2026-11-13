## [:< ##

package AMOS7::N7FS::Receiver;    ###########################################

## root-signed requests for a holder forced command, and their home counters.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;
our $VERSION = qw| AMOS7::N7FS::Receiver-VERSION.ENNH4BY |;

@EXPORT_OK
    = qw| holder_id root_id_for_public root_tag_for_public request_token
    request_sign request_parse request_verify |;

use Fcntl qw| LOCK_EX |;
use JSON::PP;
use AMOS7::N7FS qw| b32 unb32 random_bytes read_file write_new_file make_dirs
    sync_dir refuse |;
use AMOS7::N7FS::Sum  qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign qw| verify |;

my $JSON   = JSON::PP->new->utf8->canonical;
my $DOMAIN = "p7 n7fs holder request v1\0";

sub holder_id {
    my $spec = shift // '';
    return bmw_b32(
        bmw384_bytes( "p7 n7fs holder request target v1\0" . $spec ) );
}

sub root_id_for_public {
    my $pub = shift // '';
    refuse('root public key is not 32 bytes') if length $pub != 32;
    return b32( bmw384_bytes( 'p7 n7fs seal root id v1' . $pub ) );
}

sub root_tag_for_public {
    return 'r-' . substr( root_id_for_public(shift), 0, 7 );
}

sub _payload {
    my ( $root, $spec, $op, $args, $counter ) = @ARG;
    refuse('holder request root is missing') if not ref $root->{'signer'};
    refuse('holder request operation is invalid')
        if ( $op // '' ) !~ m|\A[a-z][a-z-]+\z|;
    refuse('holder request arguments are not an object')
        if ref $args ne qw| HASH |;
    refuse('holder request counter is invalid')
        if ( $counter // '' ) !~ m|\A[1-9]\d*\z|;
    return {
        qw| op |      => $op,
        qw| root_id | => $root->{'root_id'},
        qw| holder |  => holder_id($spec),
        qw| counter | => $counter + 0,
        qw| nonce |   => b32( random_bytes(16) ),
        qw| args |    => $args,
    };
}

sub _encode {
    my ( $root, $payload ) = @ARG;
    my $body = $DOMAIN . $JSON->encode($payload);
    my $sig  = $root->{'signer'}->sign($body);
    refuse('root signer returned no 64 byte signature')
        if not defined $sig
        or length $sig != 64;
    return b32($body) . '.' . b32($sig);
}

## test and recovery entry point : an explicit counter, no home state write ##
sub request_sign {
    my ( $root, $spec, $op, $args, $counter ) = @ARG;
    return _encode( $root, _payload( $root, $spec, $op, $args, $counter ) );
}

## reserve before sending : a failed command never lets a later request reuse
## its counter. the per-holder lock also covers independent n7fs processes
sub request_token {
    my ( $root, $spec, $op, $args ) = @ARG;
    my $id  = holder_id($spec);
    my $dir = "$root->{'path'}.state/receiver";
    make_dirs( $dir, 0700 );
    open( my $lock, '>>', "$dir/$id.lock" )
        or refuse('cannot open the holder request counter lock');
    flock( $lock, LOCK_EX() )
        or refuse('cannot lock the holder request counter');
    my $path = "$dir/$id.json";
    my $old  = read_file($path);
    my $data = defined $old ? eval { $JSON->decode($old) } : {};
    refuse('holder request counter state is invalid')
        if ref $data ne qw| HASH |
        or ( $data->{'counter'} // 0 ) !~ m|\A\d+\z|;
    my $counter = ( $data->{'counter'} // 0 ) + 1;
    my $tmp     = "$path.tmp";
    unlink $tmp if -e $tmp or -l $tmp;
    write_new_file( $tmp, $JSON->encode( { qw| counter | => $counter } ) );
    rename $tmp, $path or refuse('cannot reserve the holder request counter');
    sync_dir($dir);
    close $lock;
    return request_sign( $root, $spec, $op, $args, $counter );
}

sub request_parse {
    my $token = shift // '';
    my ( $body_b32, $sig_b32 ) = $token =~ m|\A([A-Z2-7]+)[.]([A-Z2-7]+)\z|;
    refuse('holder request token is invalid') if not defined $sig_b32;
    my $body = unb32($body_b32);
    my $sig  = unb32($sig_b32);
    refuse('holder request token is invalid')
        if not defined $body
        or not defined $sig
        or length $sig != 64
        or substr( $body, 0, length $DOMAIN ) ne $DOMAIN;
    my $payload = eval { $JSON->decode( substr( $body, length $DOMAIN ) ) };
    refuse('holder request payload is invalid')
        if ref $payload ne qw| HASH |
        or ref $payload->{'args'} ne qw| HASH |
        or ( $payload->{'root_id'} // '' ) !~ m|\A[A-Z2-7]{77}\z|
        or ( $payload->{'holder'}  // '' ) !~ m|\A[A-Z2-7]{77}\z|
        or ( $payload->{'counter'} // '' ) !~ m|\A[1-9]\d*\z|
        or ( $payload->{'nonce'}   // '' ) !~ m|\A[A-Z2-7]{26}\z|
        or ( $payload->{'op'}      // '' ) !~ m|\A[a-z][a-z-]+\z|;
    return {
        qw| payload | => $payload,
        qw| body |    => $body,
        qw| sig |     => $sig,
    };
}

sub request_verify {
    my ( $token, $pub, $holder, $op ) = @ARG;
    my $request = request_parse($token);
    my $payload = $request->{'payload'};
    refuse('holder request signature does not verify')
        if not verify( $pub, $request->{'body'}, $request->{'sig'} );
    refuse('holder request root does not match its key')
        if $payload->{'root_id'} ne root_id_for_public($pub);
    refuse('holder request is for another holder')
        if $payload->{'holder'} ne $holder;
    refuse('holder request names another operation')
        if $payload->{'op'} ne $op;
    return $payload;
}

1;

#,,,.,..,,..,,.,.,,..,,.,,...,,,.,...,,.,,,,,,..,,...,...,.,,,,..,..,,,,,,.,.,
#GCVF6DZWT56RDUG4JJZMXT2UCTVWJ26APY75KCHCFPFAD3KFIWD5AXBVUDNHZNPM4MA23POUGZXOM
#\\\|GTS7GVXCE3SQJMJWTA4XNF7KIUI63LSBAUGGWEJWC55YXTMNRJL \ / AMOS7 \ YOURUM ::
#\[7]TQK2NJSQSB3IUPRS67B5C7MBVOOQPC7SQL6WFND5DGJEONSXRMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
