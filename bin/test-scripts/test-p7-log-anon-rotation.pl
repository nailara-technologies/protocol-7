#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## p7-log anon key rotation : a token stored under the OLD key stays      ##
## resolvable after the key is replaced -- the old key kept under an      ##
## archive name, its table renamed to log-anon/table.<name>.bin. the REAL ##
## p7-log.anon.key \ .store \ .resolve are compiled [ runtime pragmas ] ; ##
## the key resolver is stubbed onto a File::Temp key dir. no zenka.       ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use File::Temp            qw| tempdir |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use AMOS7::13;
use AMOS7::Twofish;
use Crypt::Misc qw| encode_b32r |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $test_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## no bytes : the harness's own 'use bytes' must not leak into the modules  ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

## $prefix : source prepended inside the compiled sub [ the .cmd. header ] ##
sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- tempdir : key dir + zenka data dir -------------------------------- ##
my $tmp      = tempdir( CLEANUP => 1 );
my $key_dir  = catfile( $tmp, 'user-keys' );
my $data_dir = catfile( $tmp, 'var' );
mkdir $key_dir  or die;
mkdir $data_dir or die;

my @logged;
$code{'base.logs'}         = sub { push @logged, [@ARG]; return };
$code{'base.log'}          = sub { push @logged, [@ARG]; return };
$code{'base.str.os_err'}   = sub { return "$OS_ERROR" };
$code{'base.perlmod.load'} = sub { eval "require $ARG[0]"; return TRUE };
$code{'file.slurp'}        = sub {
    open( my $fh, '<', $ARG[0] ) or return \undef;
    local $INPUT_RECORD_SEPARATOR;
    my $c = readline($fh);
    close($fh);
    return \$c;
};
$code{'file.zenka_dir.data_path'} = sub { return $data_dir };
$code{'file.make_path'}           = sub {
    require File::Path;
    File::Path::make_path( $ARG[0], { mode => $ARG[1] } );
    return -d $ARG[0] ? (TRUE) : ( FALSE, 'make_path failed' );
};
$code{'crypt.C25519.key_path'} = sub {
    my $base = catfile( $key_dir, $ARG[0] );
    return {
        key_dir      => $key_dir,
        key_basepath => $base,
        key_filename => { map { $ARG => "$base.$ARG" } qw| secret public | },
        holder       => 'user',
    };
};

## a plain [ unencrypted ] secret keyfile : base32 of 'U:' . 32 bytes ##
sub put_key {
    my ( $name, $byte ) = @ARG;
    my $path = catfile( $key_dir, "$name.secret" );
    open( my $fh, '>', $path ) or die;
    print {$fh} encode_b32r( 'U:' . ( chr($byte) x 32 ) ), "\n";
    close($fh);
    return;
}

compile_module($ARG)
    for qw| p7-log.anon.key p7-log.anon.key_id p7-log.anon.store
    p7-log.anon.resolve |;
compile_module( 'p7-log.cmd.archive-anon-table', 'my $call = shift // {};' );
my $archive_cmd = sub {
    return $code{'p7-log.cmd.archive-anon-table'}->( { args => shift } );
};

my $table = catfile( $data_dir, 'log-anon', 'table.bin' );

say ':: p7-log anon key rotation';

## key A : the current key, a token stored ##
put_key( 'svc.base', 0x41 );
$data{'p7-log'}{'anon'}{'key_name'} = 'svc.base';
ok( $code{'p7-log.anon.store'}->( [ [ 'TOKENAAAAAAAA', 'alpha secret' ] ] )
        == 1,
    'key A : one fragment stored'
);
ok( $code{'p7-log.anon.resolve'}->('[L:TOKENAAAAAAAA]') eq 'alpha secret',
    '  :.. resolves under key A' );

ok( -s "$table.key", '  :.. the table key id written next to it' );

## refusals before the rotation ##
ok( $archive_cmd->('')->{'mode'} eq 'false', 'archive : no name refused' );
ok( $archive_cmd->('svc.base')->{'data'} =~ m|current key name|,
    'archive : the current key name refused' );
put_key( 'other.base', 0x55 );
ok( $archive_cmd->('other.base')->{'data'} =~ m|did not write|,
    'archive : a key that did not write the table refused'
);
ok( -e $table, '  :.. table untouched' );

## rotation : p7-keys rename + create, then anon.archive-table ##
my $archive = 'svc.base-anon-2026-10-07';
rename(
    catfile( $key_dir, 'svc.base.secret' ),
    catfile( $key_dir, "$archive.secret" )
) or die;
put_key( 'svc.base', 0x42 );

## the rotated key without archiving : store refuses, logs once ##
delete $data{'p7-log'}{'anon'}{'key32'};    ## a restart ##
@logged = ();
ok( !$code{'p7-log.anon.store'}->( [ [ 'TOKENXXXXXXXX', 'not stored' ] ] )
        && !$code{'p7-log.anon.store'}
        ->( [ [ 'TOKENYYYYYYYY', 'not stored' ] ] ),
    'new key, old table : store refused'
);
ok( 1 == grep( { $ARG->[0] eq '0' && $ARG->[1] =~ m|another key| } @logged ),
    '  :.. logged once at level 0'
);
ok( $code{'p7-log.anon.resolve'}->('TOKENXXXXXXXX') eq FALSE,
    '  :.. nothing mixed into the old table' );

my $reply = $archive_cmd->($archive);
ok( $reply->{'mode'} eq 'size'
        && $reply->{'data'}
        =~ m|^archived under '\Q$archive\E'\n :\. .*table\.\Q$archive\E\.bin\n\z|,
    "archive under '$archive' : size reply, two lines"
);
ok( -e catfile( $data_dir, 'log-anon', "table.$archive.bin" )
        && -e catfile( $data_dir, 'log-anon', "table.$archive.bin.key" )
        && !-e $table
        && !-e "$table.key",
    '  :.. table + key id moved together'
);
ok( $archive_cmd->($archive)->{'mode'} eq 'false',
    '  :.. a second archive : refused [ no table ]'
);

ok( $code{'p7-log.anon.store'}->( [ [ 'TOKENBBBBBBBB', 'beta secret' ] ] )
        == 1,
    'key B : one fragment stored in a fresh table'
);
ok( $code{'p7-log.anon.resolve'}->('TOKENBBBBBBBB') eq 'beta secret',
    '  :.. new token resolves under key B' );
ok( $code{'p7-log.anon.resolve'}->('TOKENAAAAAAAA') eq 'alpha secret',
    'old token resolves from the archived table under the archived key'
);
ok( $code{'p7-log.anon.resolve'}->('TOKENCCCCCCCC') eq FALSE,
    'unknown token : FALSE' );
ok( $data{'p7-log'}{'anon'}{'key32'} ne
        $data{'p7-log'}{'anon'}{'archive_key32'}{$archive},
    'current and archived key32 differ [ separate caches ]'
);

## the archived key gone : the old token is not found, nothing dies ##
unlink catfile( $key_dir, "$archive.secret" );
delete $data{'p7-log'}{'anon'}{'archive_key32'};
ok( $code{'p7-log.anon.resolve'}->('TOKENAAAAAAAA') eq FALSE,
    'archived key missing : old token FALSE [ no die ]'
);
ok( $code{'p7-log.anon.resolve'}->('TOKENBBBBBBBB') eq 'beta secret',
    '  :.. current token still resolves' );

## === keyed tokens [ p7-log.anon.replace ] ============================= ##
say ':: p7-log.anon.replace : keyed tokens';

## stand-ins : classify marks 'host-a' ; the checksum is any stable hash [ ##
## the bmw-l13 itself is not under test -- only what goes into it ]        ##
require Digest::SHA;
my $sum_undef = FALSE;
$code{'chk-sum.bmw.L13-str'} = sub {
    return undef if $sum_undef;
    return uc substr( Digest::SHA::sha256_hex( $ARG[0] ), 0, 20 );
};
$code{'p7-log.anon.classify'} = sub {
    my $at = index( $ARG[0], 'host-a' );
    return $at < 0 ? [] : [ [ $at, $at + 6, 'host' ] ];
};
compile_module('p7-log.anon.replace');
my $replace = $code{'p7-log.anon.replace'};

delete $data{'p7-log'}{'anon'}{'token_key'};
my ( $l1, $p1 ) = $replace->('connect from host-a ok');
my ($tok1) = $l1 =~ m|\[L:([A-Z0-9]+)\]|;
ok( defined $tok1 && $l1 !~ m|host-a| && $p1->[0][1] eq 'host-a',
    'span replaced by a token, fragment in the pair'
);
ok( $tok1 ne uc substr( Digest::SHA::sha256_hex('host-a'), 0, 13 ),
    '  :.. NOT the bare fragment checksum [ keyed ]' );
my ($l2) = $replace->('again host-a');
ok( index( $l2, "[L:$tok1]" ) != -1, '  :.. same key, same token' );

## another key : another token ##
put_key( 'svc.base', 0x77 );
delete $data{'p7-log'}{'anon'}{$ARG} for qw| key32 token_key |;
my ($l3)   = $replace->('host-a again');
my ($tok3) = $l3 =~ m|\[L:([A-Z0-9]+)\]|;
ok( defined $tok3 && $tok3 ne $tok1, 'another key : another token' );

## no checksum : redacted, never plaintext ##
$sum_undef = TRUE;
my ( $l4, $p4 ) = $replace->('x host-a y');
ok( $l4 eq 'x [L:-] y' && !@$p4, 'no checksum : [L:-], no pair' );
$sum_undef = FALSE;

## no usable key : redacted, never plaintext ##
unlink catfile( $key_dir, 'svc.base.secret' );
delete $data{'p7-log'}{'anon'}{$ARG} for qw| key32 token_key |;
my ( $l5, $p5 ) = $replace->('x host-a y');
ok( $l5 eq 'x [L:-] y' && !@$p5, 'no key : [L:-], no pair' );

## transform : a line of only redactions is still replaced ##
compile_module('p7-log.anon.transform');
$data{'p7-log'}{'anon'}{'enabled'} = TRUE;
my $msg = 'x host-a y';
$code{'p7-log.anon.transform'}->( 'log', \$msg );
ok( $msg eq 'x [L:-] y', 'transform : redaction-only line replaced' );

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,,..,,,.,,,,,,.,,,..,,,,,,,,,,,,,,..,,..,..,,...,..,,.,.,,,.,...,...,.,,,
#G35OC45BYCPPWRCVHV77SPNYINKZREYJKUYZWI3F7PNKBS6APSW2ASGD23J5CYY2THFZEGF4DFSEC
#\\\|4PI5WYHL3EMO3ADVMXQLUB7AEMHRTE2VGKAKEBBQXDY3URD25ZM \ / AMOS7 \ YOURUM ::
#\[7]WN4ST6VJH4OYN7ANGH5DX4FETZNZQTAQWDTRMULN3CUWNY75VQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
