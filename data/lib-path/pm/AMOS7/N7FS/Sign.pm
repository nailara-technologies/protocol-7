## [:< ##

package AMOS7::N7FS::Sign;    ###############################################

## N7FS version 1 : signers and signature checks [ ed25519, rfc 8032 ].
##
## a SIGNER is an object with two methods -- secret key bytes never cross this
## interface [ Crypt::Ed25519 and CryptX keep secrets in different forms, both
## produce standard signatures ] :
##
## ->public        32 byte ed25519 public key
## ->sign( $msg )  64 byte signature over $msg
##
## three kinds :
##   seed_signer( $seed )       a 32 byte seed in memory [ tests, keygen ]
##   key_file_signer( $path )   an n7fs key file [ 0600, base32 seed ]
##   command_signer( @argv )    an external signer, list-form exec, no
##                              shell : '<argv> public' prints the public
##                              key, '<argv> sign <label>' reads the message
##                              [ base32 ] on stdin and prints the signature
##                              [ base32 ]. THE HOST-ROOT PLUG : a v7-zenki
##                              command behind p7c holding host-root, e.g.
##                              command_signer( 'p7c', 'v7-zenki.n7fs-sign' )
##                              -- it must accept only the n7fs labels
##                              [ AMOS7::N7FS %LABEL ], so host-root never
##                              becomes a general signing oracle

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Sign-VERSION.0000001 |;

@EXPORT_OK = qw|
    seed_signer
    key_file_signer
    key_file_write
    command_signer
    verify
    new_seed
    |;

use AMOS7::N7FS qw| b32 unb32 random_bytes refuse read_file
    write_new_file |;

our $KEY_FILE_HEAD = 'p7 n7fs ed25519 seed v1';

##[ BACKEND ]#################################################################

## CryptX first [ the vault's dependency ], Crypt::Ed25519 [ the zenki's ] as
## the verify fallback
sub _cryptx {
    state $ok = eval { require Crypt::PK::Ed25519; 1 } ? TRUE : FALSE;
    return $ok;
}

sub _crypt_ed25519 {
    state $ok = eval { require Crypt::Ed25519; 1 } ? TRUE : FALSE;
    return $ok;
}

sub verify {
    my ( $pub, $msg, $sig ) = @ARG;
    return FALSE if not defined $pub or length $pub != 32;
    return FALSE if not defined $sig or length $sig != 64;
    return FALSE if not defined $msg;

    if ( _cryptx() ) {
        my $ok = eval {
            my $pk = Crypt::PK::Ed25519->new;
            $pk->import_key_raw( $pub, qw| public | );
            $pk->verify_message( $sig, $msg );
        };
        return $ok ? TRUE : FALSE;
    } elsif ( _crypt_ed25519() ) {
        return Crypt::Ed25519::verify( $msg, $pub, $sig ) ? TRUE : FALSE;
    }
    refuse('no ed25519 backend [ CryptX or Crypt::Ed25519 ]');
}

sub new_seed { return random_bytes(32) }

##[ SIGNERS ]#################################################################

sub seed_signer {
    my $seed = shift // '';
    refuse('ed25519 seed is not 32 bytes') if length $seed != 32;
    refuse('signing needs CryptX [ Crypt::PK::Ed25519 ]') if not _cryptx();

    my $pk = Crypt::PK::Ed25519->new;
    $pk->import_key_raw( $seed, qw| private | );
    my $pub = $pk->export_key_raw(qw| public |);

    return bless { qw| pk | => $pk, qw| pub | => $pub },
        qw| AMOS7::N7FS::Sign::Seed |;
}

sub key_file_write {
    my ( $path, $seed ) = @ARG;
    $seed //= new_seed();
    write_new_file( $path, sprintf "%s\n%s\n", $KEY_FILE_HEAD, b32($seed) );
    return seed_signer($seed);
}

## refuses a key file readable by group \ others
sub key_file_signer {
    my $path = shift // refuse('no key file');
    my @st   = stat $path or refuse( 'no key file %s', $path );
    refuse( 'key file %s is readable by others [ chmod 600 ]', $path )
        if $st[2] & 0077;
    my $text = read_file($path) // refuse( 'cannot read key file %s', $path );
    my ( $head, $seed_b32 ) = split m|\r?\n|, $text;
    refuse( 'not an n7fs key file : %s', $path )
        if ( $head // '' ) ne $KEY_FILE_HEAD;
    my $seed = unb32( $seed_b32 // '' );
    refuse( 'n7fs key file %s : bad seed', $path )
        if not defined $seed
        or length $seed != 32;
    return seed_signer($seed);
}

sub command_signer {
    my @argv = @ARG;
    refuse('command signer : no command') if not @argv;
    my $self = bless { qw| argv | => \@argv }, qw| AMOS7::N7FS::Sign::Cmd |;
    my $pub  = unb32( $self->_run( '', qw| public | ) );
    refuse('command signer : no 32 byte public key')
        if not defined $pub
        or length $pub != 32;
    $self->{'pub'} = $pub;
    return $self;
}

package AMOS7::N7FS::Sign::Seed;    #########################################

use English;

sub public { return $ARG[0]->{'pub'} }

sub sign {
    my ( $self, $msg ) = @ARG;
    return $self->{'pk'}->sign_message($msg);
}

package AMOS7::N7FS::Sign::Cmd;     ##########################################

use English;
use IPC::Open3  qw| open3 |;
use Symbol      qw| gensym |;
use AMOS7::N7FS qw| b32 unb32 refuse |;

sub public { return $ARG[0]->{'pub'} }

## the label is the n7fs record label inside the signed bytes
## [ after the 5 byte head, n/a* ] -- passed as an argument so the signer can
## refuse a foreign kind before reading the message
sub sign {
    my ( $self, $msg ) = @ARG;
    my $len   = unpack( qw| n |, substr( $msg, 5, 2 ) );
    my $label = substr( $msg, 7, $len );
    my $sig   = unb32( $self->_run( b32($msg), qw| sign |, $label ) );
    return ( defined $sig and length $sig == 64 ) ? $sig : undef;
}

## list-form exec, no shell. stdout : one base32 line
sub _run {
    my ( $self, $input, @args ) = @ARG;

    my ( $in, $out, $err ) = ( undef, undef, gensym() );
    my $pid = eval { open3( $in, $out, $err, $self->{'argv'}->@*, @args ) };
    refuse( 'command signer : cannot run %s', $self->{'argv'}[0] )
        if not $pid;

    ## the message is a few hundred bytes : one write, then read to eof ##
    binmode $in;
    print {$in} $input, "\n";
    close $in;
    my $text = do { local $INPUT_RECORD_SEPARATOR; <$out> }
        // '';
    close $out;
    waitpid( $pid, 0 );

    refuse(
        'command signer : %s exited %d',
        $self->{'argv'}[0],
        $CHILD_ERROR >> 8
    ) if $CHILD_ERROR;
    $text =~ s|\s+\z||;
    $text =~ s|\A\s+||;
    return $text;
}

1;

#,,.,,.,.,,,,,,,.,,,,,..,,,,.,,.,,.,.,.,.,..,,..,,...,...,...,,..,.,,,.,.,.,,,
#DUVSNKS6QU7FQ2DLBQ5YITSVHXKL6WWDXJ25GG5OEPHU5FKWQGGL3PFXKMFRCZHOBKUYJWQDVYYVS
#\\\|DJK3SSDXAKMX35RTVLHTAKN2AVWYR7GJTTJZL76S3HQRDMOPENT \ / AMOS7 \ YOURUM ::
#\[7]MRMF2EK63J3Z7RBXURZWFMKZRZ662OWT4IEUWXPZUOJ5WRAM2MCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
