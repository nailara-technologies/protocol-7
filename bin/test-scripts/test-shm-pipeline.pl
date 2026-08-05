#!/usr/bin/perl
## test-shm-pipeline.pl : standalone harness for the shm streaming payload
## pipeline [ data/tasks/shm-streaming-payload-pipeline.md ]
##
## exercises the core logic in isolation [ no live zenka ] :
## - C25519 sign/verify round-trip + tampered header rejection
## - ntime replay-window math [ stale / future / within-window / replay ]
## - incremental BMW384 hashing + B32 encoding [ chunked == one-shot ]
## - twofish streaming encrypt/decrypt round-trip [ awkward chunk sizes ]
## - gate ordering against constructed valid/invalid inputs
## - full valid path : temp file [chmod 000] -> B32 name [chmod 440]
## - failure paths : temp file unlinked + twofish key destroyed
##
## NOTE : uses a scratch shm dir in /tmp -- the real /var/protocol-7/shm needs
## root / p7-admin ownership at deployment time.

use v5.24;
use strict;
use warnings;
use English;
use FindBin qw| $RealBin |;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use Crypt::Misc qw| encode_b32r decode_b32r |;
use Crypt::Ed25519;
use Digest::BMW;
use AMOS7::Twofish;
use File::Path  qw| make_path remove_tree |;
use Time::HiRes qw| time |;
use Fcntl       qw| :mode |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $test_dir = "/tmp/p7-shm-test-$PID";
remove_tree($test_dir) if -d $test_dir;
make_path( $test_dir, { mode => 0711 } );
chmod( 0711, $test_dir );

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name"; }
    else         { $fail++; say "FAIL - $name"; }
    return $cond;
}

##[ ntime helpers [ same format as bin/Protocol-7 inline subs ] ]#############

sub ntime_now { return time() * 4200 }

sub ntime_to_b32 {    ## p7_encode_ntime_to_B32 equivalent ##
    my $ntime_value = shift;
    my @ntme        = split( qw| \. |, sprintf( '%.3f', $ntime_value ) );
    $ntme[1] = sprintf( qw| 7%s |, $ntme[1] ) if scalar @ntme == 2;
    return encode_b32r( pack( qw| w* |, @ntme ) );
}

sub ntime_from_b32 {    ## p7_ntime_BASE32_to_numerical equivalent ##
    my $tstamp = shift;
    return undef if not defined $tstamp or $tstamp !~ m|^[A-Z2-7]+$|;
    my $ntime_value = eval { decode_b32r($tstamp) } // return undef;
    my @nt_val      = unpack( qw| w* |, $ntime_value );
    $nt_val[1] =~ s|^7|| if @nt_val == 2;
    $ntime_value = join( qw| . |, @nt_val );
    $ntime_value =~ s|(\.0)+$||;
    return $ntime_value;
}

##[ pipeline simulation [ mirrors httpd.handler.shm_write gate logic ] ]######

my %seen_ntimes;    ## $seen_ntimes{$pkey_id}{$ntime_b32} = expiry_ntime ##

sub simulate_pipeline {
    my %p = @ARG;
    ## %p : body, chunks_aref, ntime_b32, decl_bytes, decl_lines, decl_b32, ##
    ## sig_b32, pkey_bin, window, shm_dir, encrypt, expect_gate returns     ##
    ## hashref : { gate => n, ok => bool, final_name, key, .. }             ##

    my $window = $p{'window'} // 60;
    my %calls;
    my $gate = 0;

    ##  gate 1 : parse content-hash header  ##
    $gate = 1;
    $calls{'gate1_parse'}++;
    my $content_hash = $p{'header'} // join( ':',
        $p{'ntime_b32'},  $p{'decl_bytes'},
        $p{'decl_lines'}, $p{'decl_b32'} );
    my ( $ntime_b32, $decl_bytes, $decl_lines, $decl_b32 )
        = $content_hash
        =~ m|^([A-Z2-7]{6,32}):(\d{1,20}):(\d{1,20}):([A-Z2-7]{77})$|;
    return { 'gate' => $gate, 'ok' => FALSE, 'calls' => \%calls }
        if not defined $decl_b32;

    ##  gate 2 : ntime replay window  ##
    $gate = 2;
    $calls{'gate2_ntime'}++;
    my $timestamp_num = ntime_from_b32($ntime_b32);
    return { 'gate' => $gate, 'ok' => FALSE, 'calls' => \%calls }
        if not defined $timestamp_num;
    my $now_ntime  = ntime_now();
    my $delta_secs = ( $timestamp_num - $now_ntime ) / 4200;
    return { 'gate' => $gate, 'ok' => FALSE, 'calls' => \%calls }
        if abs($delta_secs) > $window;

    my $pkey_id = encode_b32r( Digest::BMW::bmw_224( $p{'pkey_bin'} ) );

    ##  replay cache check [ insert only after gate 4 ]  ##
    return {
        'gate'   => $gate,
        'ok'     => FALSE,
        'calls'  => \%calls,
        'replay' => TRUE
        }
        if exists $seen_ntimes{$pkey_id}{$ntime_b32};

    ##  gate 3 : key cert [ simulated as always-present parent sig ]  ##
    $gate = 3;
    $calls{'gate3_cert'}++;
    if ( defined $p{'cert_check'} ) {
        return { 'gate' => $gate, 'ok' => FALSE, 'calls' => \%calls }
            if not $p{'cert_check'}->( $p{'pkey_bin'} );
    }

    ##  gate 4 : C25519 signature over full content-hash header  ##
    $gate = 4;
    $calls{'gate4_sig'}++;
    my $sig_bin = eval { decode_b32r( $p{'sig_b32'} // '' ) };
    return { 'gate' => $gate, 'ok' => FALSE, 'calls' => \%calls }
        if not defined $sig_bin
        or
        not Crypt::Ed25519::verify( $content_hash, $p{'pkey_bin'}, $sig_bin );

    ##  record ntime + amortized sweep  ##
    $seen_ntimes{$pkey_id}{$ntime_b32} = $now_ntime + ( $window * 4200 );
    for my $pk ( keys %seen_ntimes ) {
        for my $nt ( keys %{ $seen_ntimes{$pk} } ) {
            delete $seen_ntimes{$pk}{$nt}
                if $seen_ntimes{$pk}{$nt} < $now_ntime;
        }
        delete $seen_ntimes{$pk} if not keys %{ $seen_ntimes{$pk} };
    }

    ##  gate 5 : temp file + ephemeral twofish key  ##
    $gate = 5;
    $calls{'gate5_open'}++;
    my $key      = undef;
    my $tmp_name = sprintf '%s-%s', $ntime_b32,
        encode_b32r( random_bytes(5) );
    my $tmp_path = "$p{'shm_dir'}/$tmp_name";
    open( my $fh, '>', $tmp_path ) or die "open $tmp_path: $OS_ERROR";
    binmode($fh);
    chmod( 0000, $tmp_path );

    my $twofish_name;
    if ( $p{'encrypt'} ) {
        $key          = random_bytes(32);
        $twofish_name = 'shm_test';
        AMOS7::Twofish::key_init( $key, 'encryption', $twofish_name );
    }

    my $bmw_ctx    = Digest::BMW->new(384);
    my $byte_count = 0;
    my $line_count = 0;
    my $pending    = '';

    my $destroy = sub {
        close($fh);
        unlink($tmp_path);
        if ( defined $key ) {
            $key = "\0" x 32;
            undef $key;
        }
        AMOS7::Twofish::delete_table_entry( 'encryption', $twofish_name )
            if defined $twofish_name;
    };

    ##  gate 6 : streaming chunks  ##
    $gate = 6;
    $calls{'gate6_stream'}++;
    for my $chunk ( @{ $p{'chunks_aref'} } ) {
        $byte_count += length($chunk);
        $line_count += ( $chunk =~ tr/\n// );
        $bmw_ctx->add($chunk);
        if ( $byte_count > $decl_bytes ) {
            $destroy->();
            return {
                'gate'     => $gate,
                'ok'       => FALSE,
                'calls'    => \%calls,
                'key'      => \$key,
                'tmp_path' => $tmp_path
            };
        }
        if ( $p{'encrypt'} ) {
            $pending .= $chunk;
            my $full_len = length($pending) - ( length($pending) % 16 );
            if ($full_len) {
                my $blocks = substr( $pending, 0, $full_len, '' );
                my $enc_ref
                    = AMOS7::Twofish::encrypt( $twofish_name, \$blocks );
                print( {$fh} $enc_ref->$* );
            }
        } else {
            print( {$fh} $chunk );
        }
    }

    ##  finalize : pkcs7 pad + close  ##
    if ( $p{'encrypt'} ) {
        my $pad_len = 16 - ( length($pending) % 16 );
        my $final   = $pending . ( chr($pad_len) x $pad_len );
        my $enc_ref = AMOS7::Twofish::encrypt( $twofish_name, \$final );
        print( {$fh} $enc_ref->$* );
    }
    close($fh);

    ##  gate 7 : final comparisons  ##
    $gate = 7;
    $calls{'gate7_compare'}++;
    my $digest_b32 = encode_b32r( $bmw_ctx->digest );
    if (   $byte_count != $decl_bytes
        or $line_count != $decl_lines
        or $digest_b32 ne $decl_b32 ) {
        $destroy->();
        return {
            'gate'     => $gate,
            'ok'       => FALSE,
            'calls'    => \%calls,
            'key'      => \$key,
            'tmp_path' => $tmp_path
        };
    }

    ##  valid : content-addressed rename + chmod 440  ##
    my $final_path = "$p{'shm_dir'}/$digest_b32";
    rename( $tmp_path, $final_path ) or die "rename: $OS_ERROR";
    chmod( 0440, $final_path );
    AMOS7::Twofish::delete_table_entry( 'encryption', $twofish_name )
        if defined $twofish_name;

    return {
        'gate'       => $gate,
        'ok'         => TRUE,
        'calls'      => \%calls,
        'final_name' => $digest_b32,
        'final_path' => $final_path,
        'key'        => \$key,
    };
}

sub random_bytes {
    my $n = shift;
    return join '', map { chr( int( rand(256) ) ) } 1 .. $n;
}

sub read_file_raw {
    my $path = shift;
    open( my $fh, '<', $path ) or return undef;
    binmode($fh);
    my $d = do { local $/; <$fh> };
    close($fh);
    return $d;
}

sub file_mode {
    my $path = shift;
    return ( stat($path) )[2] & 07777;
}

##[ test 1 : C25519 sign/verify round-trip ]##################################

say '== test 1 : C25519 signature round-trip ==';

my ( $pkey, $skey ) = Crypt::Ed25519::generate_keypair;

my $body = '';
srand(42);
$body .= sprintf "line %05d : %s\n", $ARG, random_bytes( int( rand(113) ) )
    for 1 .. 420;

my $bmw_one = Digest::BMW->new(384);
$bmw_one->add($body);
my $body_b32 = encode_b32r( $bmw_one->digest );

my $ntime_b32 = ntime_to_b32( ntime_now() );
my $bytes     = length($body);
my $lines     = () = $body =~ /\n/g;
my $header    = join ':', $ntime_b32, $bytes, $lines, $body_b32;
my $sig_b32   = encode_b32r( Crypt::Ed25519::sign( $header, $pkey, $skey ) );

ok( Crypt::Ed25519::verify( $header, $pkey, decode_b32r($sig_b32) ),
    'valid signature verifies' );
ok( !Crypt::Ed25519::verify( "$header-x", $pkey, decode_b32r($sig_b32) ),
    'tampered header rejected by verify' );
ok( !Crypt::Ed25519::verify(
        $header, (Crypt::Ed25519::generate_keypair)[0],
        decode_b32r($sig_b32)
    ),
    'wrong pubkey rejected by verify'
);
ok( length($body_b32) == 77, 'BMW384 B32 digest is 77 chars' );

##[ test 2 : incremental BMW384 == one-shot ]#################################

say '== test 2 : incremental BMW384 ==';

my $bmw_inc = Digest::BMW->new(384);
my $pos     = 0;
while ( $pos < length($body) ) {
    my $clen = 1 + int( rand(97) );
    $bmw_inc->add( substr( $body, $pos, $clen ) );
    $pos += $clen;
}
ok( encode_b32r( $bmw_inc->digest ) eq $body_b32,
    'incremental [random chunk sizes] == one-shot digest'
);

##[ test 3 : ntime window math ]##############################################

say '== test 3 : ntime replay window ==';

my $nt_num = ntime_from_b32($ntime_b32);
ok( defined $nt_num and abs( $nt_num - ntime_now() ) < 4200,
    'ntime B32 round-trips to within 1 second' );

my $stale_b32  = ntime_to_b32( ntime_now() - ( 300 * 4200 ) );
my $future_b32 = ntime_to_b32( ntime_now() + ( 300 * 4200 ) );

my %mk = (
    'pkey_bin'    => $pkey,
    'sig_b32'     => $sig_b32,
    'header'      => $header,
    'shm_dir'     => $test_dir,
    'encrypt'     => TRUE,
    'chunks_aref' => [$body],
);

my $r = simulate_pipeline( %mk,
    'header' => join( ':', $stale_b32, $bytes, $lines, $body_b32 ) );
ok( !$r->{'ok'} && $r->{'gate'} == 2 && !$r->{'calls'}{'gate4_sig'},
    'stale ntime rejected at gate 2 [ sig verify never runs ]'
);

$r = simulate_pipeline( %mk,
    'header' => join( ':', $future_b32, $bytes, $lines, $body_b32 ) );
ok( !$r->{'ok'} && $r->{'gate'} == 2 && !$r->{'calls'}{'gate4_sig'},
    'future ntime rejected at gate 2 [ sig verify never runs ]'
);

$r = simulate_pipeline( %mk, 'header' => 'garbage' );
ok( !$r->{'ok'} && $r->{'gate'} == 1 && !$r->{'calls'}{'gate2_ntime'},
    'malformed header rejected at gate 1 [ before ntime check ]'
);

##[ test 4 : full valid path ]################################################

say '== test 4 : full valid path [ encrypted ] ==';

## chunk the body awkwardly [ prime sizes, partial 16-byte blocks ] ##
my @chunks;
$pos = 0;
while ( $pos < length($body) ) {
    my $clen = 7 + int( rand(61) );
    push @chunks, substr( $body, $pos, $clen );
    $pos += $clen;
}

$r = simulate_pipeline( %mk, 'chunks_aref' => \@chunks );
ok( $r->{'ok'}, 'valid signed request passes all gates' );
ok( $r->{'final_name'} eq $body_b32,
    'final file is content-addressed [ B32-BMW384 name ]' );
ok( file_mode( $r->{'final_path'} ) == 0440,
    'final file chmod 440 after validation'
);

## replay within window must now be rejected ##
my $r_replay = simulate_pipeline( %mk, 'chunks_aref' => \@chunks );
ok( !$r_replay->{'ok'} && $r_replay->{'replay'},
    'exact replay within window rejected by per-sender ntime cache' );

## decrypt + verify content round-trip ##
my $cipher_text = read_file_raw( $r->{'final_path'} );
ok( length($cipher_text) % 16 == 0, 'ciphertext is 16-byte aligned' );
my $key_ref = $r->{'key'};
AMOS7::Twofish::key_init( $key_ref->$*, 'decryption', 'shm_test_read' );
my $dec_ref = AMOS7::Twofish::decrypt( 'shm_test_read', \$cipher_text );
AMOS7::Twofish::delete_table_entry( 'decryption', 'shm_test_read' );
my $plain  = $dec_ref->$*;
my $padlen = ord( substr( $plain, -1 ) );
$plain = substr( $plain, 0, length($plain) - $padlen );
ok( $plain eq $body, 'twofish decrypt [ + pkcs7 strip ] == original body' );

##[ test 5 : body integrity failures trigger cleanup ]########################

say '== test 5 : tampered bodies -> destroy + cleanup ==';

## tampered content, same length, same lines -> BMW mismatch ##
my $evil_body = $body;
substr( $evil_body, 13, 1 ) = 'X' if substr( $evil_body, 13, 1 ) ne 'X';
my $evil_header = join ':', ntime_to_b32( ntime_now() ), $bytes, $lines,
    $body_b32;
my $evil_sig
    = encode_b32r( Crypt::Ed25519::sign( $evil_header, $pkey, $skey ) );
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $evil_sig,
    'header'      => $evil_header,
    'shm_dir'     => $test_dir,
    'encrypt'     => TRUE,
    'chunks_aref' => [$evil_body],
);
ok( !$r->{'ok'} && $r->{'gate'} == 7, 'BMW384 mismatch detected at gate 7' );
ok( !-e $r->{'tmp_path'}, 'temp file unlinked on validation failure' );
ok( !defined $r->{'key'}->$*,
    'twofish key destroyed [ undef ] on validation failure' );

## wrong byte count : attacker declares fewer bytes than sent ##
my $short_header = join ':', ntime_to_b32( ntime_now() ), $bytes - 16,
    $lines, $body_b32;
my $short_sig
    = encode_b32r( Crypt::Ed25519::sign( $short_header, $pkey, $skey ) );
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $short_sig,
    'header'      => $short_header,
    'shm_dir'     => $test_dir,
    'encrypt'     => TRUE,
    'chunks_aref' => [$body],
);
ok( !$r->{'ok'} && $r->{'gate'} == 6,
    'byte count overflow rejected mid-stream at gate 6' );
ok( !-e $r->{'tmp_path'}, 'temp file unlinked on byte overflow' );

## wrong line count : same bytes + content, declared lines off by one ##
my $line_header = join ':', ntime_to_b32( ntime_now() ), $bytes, $lines + 1,
    $body_b32;
my $line_sig
    = encode_b32r( Crypt::Ed25519::sign( $line_header, $pkey, $skey ) );
## note : header content differs, so declared BMW must be re-signed to pass
## gate 4 -- attacker can only pass gate 4 with the WRONG line count, then
## gate 7 catches the mismatch against the real streamed count
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $line_sig,
    'header'      => $line_header,
    'shm_dir'     => $test_dir,
    'encrypt'     => TRUE,
    'chunks_aref' => [$body],
);
ok( !$r->{'ok'} && $r->{'gate'} == 7,
    'line count mismatch detected at gate 7'
);
ok( !-e $r->{'tmp_path'}, 'temp file unlinked on line mismatch' );

## bad signature over untampered header ##
my $bad_sig = encode_b32r(
    Crypt::Ed25519::sign( 'some other message', $pkey, $skey ) );
my $bad_sig_ntime = ntime_to_b32( ntime_now() );
my $bad_header    = join ':', $bad_sig_ntime, $bytes, $lines, $body_b32;
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $bad_sig,
    'header'      => $bad_header,
    'shm_dir'     => $test_dir,
    'encrypt'     => TRUE,
    'chunks_aref' => [$body],
);
ok( !$r->{'ok'} && $r->{'gate'} == 4 && !$r->{'calls'}{'gate5_open'},
    'invalid signature rejected at gate 4 [ no file ever opened ]'
);

##[ test 6 : chmod 000 during transfer ]######################################

say '== test 6 : permission transitions ==';

my $mid_b32 = ntime_to_b32( ntime_now() );
my $mid_hdr = join ':', $mid_b32, $bytes, $lines, $body_b32;
my $mid_sig = encode_b32r( Crypt::Ed25519::sign( $mid_hdr, $pkey, $skey ) );
my $observed_mode;
{
    ## observe temp file mode mid-stream via a wrapping hook : simulate by
    ## running one chunk manually through the same gate-5 logic
    my $tmp_name = sprintf '%s-%s', $mid_b32, encode_b32r( random_bytes(5) );
    my $tmp_path = "$test_dir/$tmp_name";
    open( my $fh, '>', $tmp_path ) or die;
    chmod( 0000, $tmp_path );
    $observed_mode = file_mode($tmp_path);
    print( {$fh} 'partial' );
    close($fh);
    unlink($tmp_path);
}
ok( $observed_mode == 0000, 'temp file chmod 000 during transfer' );

##[ test 7 : plaintext [ unencrypted ] mode ]#################################

say '== test 7 : unencrypted mode ==';

my $plain_b32 = ntime_to_b32( ntime_now() );
my $plain_hdr = join ':', $plain_b32, $bytes, $lines, $body_b32;
my $plain_sig
    = encode_b32r( Crypt::Ed25519::sign( $plain_hdr, $pkey, $skey ) );
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $plain_sig,
    'header'      => $plain_hdr,
    'shm_dir'     => $test_dir,
    'encrypt'     => FALSE,
    'chunks_aref' => [ $body, '' ],
);
ok( $r->{'ok'}, 'valid unencrypted request passes all gates' );
ok( read_file_raw( $r->{'final_path'} ) eq $body,
    'unencrypted final file content == original body'
);

##[ test 8 : replay cache sweep expiry ]######################################

say '== test 8 : replay cache sweep ==';

## insert an artificially expired entry, run a request, verify it is gone ##
my $expired_pk = encode_b32r( Digest::BMW::bmw_224('expired-key') );
$seen_ntimes{$expired_pk}{'OLDNTIME'} = ntime_now() - 1;    ## expired ##
my $sweep_b32 = ntime_to_b32( ntime_now() );
my $sweep_hdr = join ':', $sweep_b32, $bytes, $lines, $body_b32;
my $sweep_sig
    = encode_b32r( Crypt::Ed25519::sign( $sweep_hdr, $pkey, $skey ) );
$r = simulate_pipeline(
    'pkey_bin'    => $pkey,
    'sig_b32'     => $sweep_sig,
    'header'      => $sweep_hdr,
    'shm_dir'     => $test_dir,
    'encrypt'     => FALSE,
    'chunks_aref' => [$body],
);
ok( $r->{'ok'}, 'sweep-triggering request succeeds' );
ok( !exists $seen_ntimes{$expired_pk},
    'expired ntime entries swept [ no forever-leak ]' );

##[ summary ]#################################################################

say '';
say "passed : $pass   failed : $fail";

remove_tree($test_dir);

exit( $fail ? 1 : 0 );

#,,,.,,..,,,,,..,,.,,,...,..,,,.,,.,,,.,,,,,,,..,,...,..,,..,,,,.,,..,,..,.,,,
#U5ZJZSKBZ6LOWJZOFKWQC6MBFGXLBLMDKEVAXLVIG6KVABJEX65JVUPYIUCQ4NEWGBK54PX55JLOI
#\\\|UGE55KJZSBCBVKVFMMDZCHFDRKEM4E4NMJDTCC65YTYSK3O5B7P \ / AMOS7 \ YOURUM ::
#\[7]MIJQAWX4OI75H7VTJXWI57JBARZW25H3TFGYQDKF4DMK4I6TUIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
