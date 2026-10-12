#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## tests for the vault blobs [ data/md/design/VAULT-FORMAT.md ] : round trips
## over the chunk boundaries, dedup, vault-bound names, tamper detection. runs
## on throwaway dirs, cheap kdf -- never ~/.n/vault

use FindBin;
use File::Temp qw| tempdir |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw|
    vault_init vault_open vault_unlock
    blob_import blob_export blob_verify
    |;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

my %kdf = ( t => 1, m => 8192, p => 1 );    ## cheap, test only ##

my $tmp = tempdir( CLEANUP => 1 );
my $dir = "$tmp/vault";
my $v   = vault_init( $dir, 'pass phrase one', undef, %kdf );

sub write_file {
    my ( $path, $content ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return $path;
}

sub slurp {
    open( my $fh, '<:raw', $_[0] ) or die "cannot read $_[0] : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub blob_files {
    my $d = shift;
    opendir( my $dh, "$d/blobs" ) or return ();
    my @names = sort grep { not m|^\.| } readdir $dh;
    closedir $dh;
    return @names;
}

## round trips : empty, small, exactly 1 MiB, 2.5 MiB ##
my @cases = (
    [ 'empty',   '' ],
    [ 'small',   'hello vault blobs' ],
    [ 'one-mib', 'A' x 1048576 ],
    [ 'mib-and-half', ( 'B' x 1048576 ) x 2 . 'C' x ( 1048576 / 2 ) ],
);

my %name_of;
foreach my $case (@cases) {
    my ( $label, $content ) = @{$case};
    my $path = write_file( "$tmp/$label", $content );

    my ( $name, $size ) = blob_import( $v, $path );
    ok( $name =~ m|\A[A-Z2-7]{32}\z|, "$label : blob name shape" );
    ok( $size == length $content,     "$label : size reported" );
    ok( ( grep { $_ eq "$name.vlb" } blob_files($dir) ) == 1,
        "$label : one blob file" );

    open( my $out, '>:raw', "$tmp/out" ) or die $OS_ERROR;
    my $ok = eval { blob_export( $v, $name, $out ); 1 };
    close $out;
    ok( $ok,                           "$label : export completes" );
    ok( slurp("$tmp/out") eq $content, "$label : round trip" );
    ok( blob_verify( $v, $name ),      "$label : verify" );

    $name_of{$label} = $name;
}

## dedup : the same content twice is one blob ##
my $small_path = "$tmp/small";
my ( $again, $again_size ) = blob_import( $v, $small_path );
ok( $again eq $name_of{'small'}, 'dedup : same name for same content' );
ok( blob_files($dir) == @cases,  'dedup : blob count unchanged' );

## a blob of one vault fails the other's name check : names are vault-bound ##
my $dir2 = "$tmp/vault-two";
my $v2   = vault_init( $dir2, 'pass phrase two', undef, %kdf );
my ( $name2, undef ) = blob_import( $v2, $small_path );
ok( $name2 ne $name_of{'small'},
    'two vaults : same content, different names' );
ok( !blob_verify( $v, $name2 ), '  :.. the other vaults name is refused' );

## tamper : every change fails, on verify and on export ##
sub tamper {
    my ( $label, $mutate ) = @ARG;
    my $name   = $name_of{'mib-and-half'};
    my $bpath  = "$dir/blobs/$name.vlb";
    my $orig   = slurp($bpath);
    my $broken = $mutate->($orig);
    write_file( $bpath, $broken );
    ok( !blob_verify( $v, $name ), "tamper $label : verify fails" );
    my $ok = eval {
        open( my $out, '>:raw', "$tmp/out-t" ) or die $OS_ERROR;
        blob_export( $v, $name, $out );
        close $out;
        1;
    };
    ok( !$ok, "tamper $label : export dies" );
    write_file( $bpath, $orig );
    ok( blob_verify( $v, $name ), "tamper $label : restored blob verifies" );
}

tamper(
    'flipped byte',
    sub {
        $_ = $_[0];
        substr( $_, 40, 1 )
            = chr( ord( substr $_, 40, 1 ) ^ 0xff );
        $_;
    }
);

tamper(
    'swapped chunks',
    sub {
        my $bin    = $_[0];
        my $header = substr $bin, 0, 9, '';
        my @frames;
        while ( length $bin ) {
            my ($len) = unpack q{N}, substr $bin, 0, 4, '';
            push @frames, substr $bin, 0, $len + 28, '';    ## nonce ct tag ##
        }
        @frames[ 0, 1 ] = @frames[ 1, 0 ];
        return $header . join '',
            map { pack( q{N}, length($_) - 28 ) . $_ } @frames;
    }
);

tamper( 'truncated last chunk',
    sub { substr $_[0], 0, length( $_[0] ) - 10 } );

tamper( 'appended bytes', sub { $_[0] . 'trailing-junk' } );

## the name is not the contents plain blake2b-256 ##
require Crypt::Digest::BLAKE2b_256;
my $plain = Crypt::Digest::BLAKE2b_256->new;
$plain->add( slurp($small_path) );
my $plain_name = substr( AMOS7::Vault::_b32( $plain->digest ), 0, 32 );
ok( $plain_name ne $name_of{'small'},
    'blob name is not the plain blake2b-256 of the content' );

## a locked handle imports nothing ##
my ( $locked, undef ) = vault_open($dir);
my $locked_ok = eval { blob_import( $locked, $small_path ); 1 };
ok( !$locked_ok, 'locked vault : import refused' );

## content changing DURING the encrypt pass : the bytes encrypted are ##
## checked against the name -- import aborts, no blob is left behind  ##
{
    my $moving = "$tmp/moving";
    open( my $mfh, '>:raw', $moving ) or die $OS_ERROR;
    print {$mfh} 'm' x 5000;
    close $mfh;
    my $real = \&AMOS7::Vault::_read_chunk;
    no warnings qw| redefine |;
    local *AMOS7::Vault::_read_chunk = sub {
        my $chunk = $real->(@_);
        substr( $chunk, 0, 1, 'X' ) if length $chunk;    ## changed now ##
        return $chunk;
    };
    use warnings qw| redefine |;
    my $died = !eval { blob_import( $v, $moving ); 1 };
    ok( $died && $@ =~ m|changed while importing|,
        'content changed during encryption : import aborts' );
    opendir( my $bdh, "$dir/blobs" ) or die $OS_ERROR;
    ok( !grep( {m|\.tmp\.|} readdir $bdh ), '  :.. no temp file left' );
    closedir $bdh;
}

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,,.,,,,,,,.,.,.,,..,,..,.,,,...,.,.,,..,,.,,..,,...,...,...,.,,,,..,,.,,,,.,
#HV6OGL6BH5VLW7FAQNYXVX4SQCWMJFZVV5BESFGYMMIHFTM6MTVHYN66C6WCSMZ2DO6VSXJBSD3JU
#\\\|NISCLOSWHVYHHK4VIJX74JB6N4TEWMRCGHKFPZB6SDMNL5KIHDR \ / AMOS7 \ YOURUM ::
#\[7]6B3UMQYNHRPCU7OETKY7IDLHQSXMGBNPRC7COJ6MLHO4UE7Z3SDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
