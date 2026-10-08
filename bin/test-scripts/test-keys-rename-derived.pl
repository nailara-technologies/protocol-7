#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## keys.console.rename on a passphrase-derived \ virtual key : the name is  ##
## part of the derivation -> warned, done only with '::yes::' ; a key with  ##
## its secret on disk renames as before. [ was : trust chain step 2         ##
## management tools [ data/md/design/TRUST-CHAIN- STEP2.md ] :              ##
## keys.console.certify-host \ accept-owner \ owner-pin \ owner-unpin \     ##
## owner-pins \ distrust \ undistrust + their helpers. the REAL modules are ##
## compiled [ runtime pragmas ] ; key files, homedir and load_keypair are   ##
## stubbed onto File::Temp directories. the flow end to end : certify ->    ##
## accept -> owner-pin -> trust.pin_decide [ owner path ].                  ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path getcwd |;
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
use Crypt::Misc               qw| encode_b32r decode_b32r |;
use Crypt::Ed25519;
use Digest::BMW;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $test_count = 0;

## prototype : a list-context match cannot shift the label ##
sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

use List::Util qw| max |;

my $tmp     = tempdir( CLEANUP => 1 );
my $key_dir = catfile( $tmp, 'user-keys' );
mkdir $key_dir or die;

my %flag = ( encrypted => 0, virtual => 0 );
$code{'base.exit'}       = sub { die sprintf "EXIT:%s\n", join '', @ARG };
$code{'base.str.os_err'} = sub { return "$OS_ERROR" };
$code{'base.sort'}       = sub {
    my $x = shift;
    return ref $x eq 'HASH' ? sort keys %$x : sort @{ [ $x, @ARG ] };
};
$code{'crypt.C25519.validate_keyname'} = sub { return 1 };
$code{'crypt.C25519.key_exists'} = sub {    ## no scalar glob : it iterates ##
    my $b = catfile( $key_dir, $ARG[0] );
    return ( grep { -e "$b.$ARG" } qw| secret private public virtual | )
        ? 1
        : 0;
};
$code{'crypt.C25519.encrypted_key'}  = sub { $flag{'encrypted'} };
$code{'crypt.C25519.key_is_virtual'} = sub { $flag{'virtual'} };
my $paths = sub {
    my $b = catfile( $key_dir, shift );
    return { map { $ARG => "$b.$ARG" } qw| secret private public virtual | };
};
$code{'crypt.C25519.key_path'} = sub {
    return {
        holder       => 'user',
        key_dir      => $key_dir,
        key_filename => $paths->( $ARG[0] )
    };
};
$code{'crypt.C25519.key_vars'} = sub {
    return { key_dir => $key_dir, key_filename => $paths->( $ARG[0] ) };
};
$data{'keys'}{'regex'} = {
    key_files => qr|\.(?:secret\|private\|public\|virtual)$|,
    key_file  => { public => qr|\.public$|, private => qr|\.private$| },
};

compile_module('keys.console.rename');

sub run {
    my $out = '';
    open( my $fh, '>', \$out ) or die;
    my $old = select($fh);
    eval { $code{'keys.console.rename'}->(shift) };
    my $err = $EVAL_ERROR;
    select($old);
    close($fh);
    my ($exit) = $err =~ m|\AEXIT:(\d+)|;
    return { out => $out, exit => $exit // '' };
}

sub put_key {
    open( my $fh, '>', catfile( $key_dir, shift ) ) or die;
    print {$fh} "x\n";
    close($fh);
}
my $has = sub { -e catfile( $key_dir, shift ) };

say ': keys.console.rename [ derived \ virtual keys ]';

put_key('derived.public');    ## passphrase-derived : only the public half ##
my $r = run('derived other');
ok( $r->{'exit'} eq '0010'
        && $r->{'out'} =~ m|DIFFERENT|
        && $has->('derived.public'),
    'derived key, no ::yes:: : warned, NOT renamed'
);
$r = run('derived other ::yes::');
ok( $has->('other.public') && !$has->('derived.public'),
    'derived key with ::yes:: : renamed' );

$flag{'virtual'} = 5;
put_key('seed.virtual');
$r = run('seed seed2');
ok( $r->{'exit'} eq '0010' && $has->('seed.virtual'),
    'virtual seed-phrase key : warned, NOT renamed'
);
$flag{'virtual'} = 0;

put_key('plain.public');
put_key('plain.secret');
$r = run('plain plain2');
ok( $has->('plain2.public')
        && $has->('plain2.secret')
        && $r->{'out'} !~ m|WARNING|,
    'a key with its secret on disk : renamed as before, no warning'
);

$flag{'encrypted'} = 5;
put_key('enc.public');
put_key('enc.private');
$r = run('enc enc2');
ok( $has->('enc2.public') && $r->{'out'} !~ m|WARNING|,
    'an encrypted key on disk : renamed as before'
);

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,,,.,...,,,,,,,,,.,,,.,,,.,.,,,,,...,...,..,,...,..,,,,,,.,,,.,.,,.,,.,.,
#E2GDPZX4FAKAYNQCTE74GBEHXIVNT3747TGA2NYGBE4C6D7TFHFCE7GMBFI5EIS5RF3ZRAEPBOALY
#\\\|RMRMA7SGFKUC7BAF2OGCLGX6LU2KROBZ5ZBHTUK7OVTF75LRS36 \ / AMOS7 \ YOURUM ::
#\[7]THB4F3M2LENMQA5QP42JUWDBSYGB65RUBDZQ52BYPFPS5KVU7WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
